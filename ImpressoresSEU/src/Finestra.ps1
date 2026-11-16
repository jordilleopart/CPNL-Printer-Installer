#Requires -Version 5.1
<#
  Finestra.ps1: finestres senzilles (Windows Forms) per a l'usuari final:
  missatges i selector de delegacions. Necessita que Dades.ps1 estigui carregat.
  No s'executa sol: el carreguen els altres scripts amb ". .\Finestra.ps1".
#>

# Carrega les biblioteques de finestres de Windows
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Mostra un missatge en una finestra amb un sol botó
function Show-Missatge {
    param(
        # Text del missatge
        [string]$Text,
        # Títol de la finestra
        [string]$Titol = "Instal·lació d'impressores",
        # Tipus d'icona: Information, Warning o Error
        [ValidateSet('Information', 'Warning', 'Error')][string]$Icona = 'Information'
    )
    # En mode sense finestres, el missatge s'escriu a la consola
    if ($script:SenseFinestres) { Write-Host $Text; return }
    [void][System.Windows.Forms.MessageBox]::Show(
        $Text, $Titol,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::$Icona)
}

# Posa la icona de l'aplicació a una finestra, si el fitxer de la icona existeix
function Set-IconaFinestra {
    param($Finestra)
    try {
        $ruta = Join-Path $PSScriptRoot '..\ImpressoresSEU.ico'
        if (Test-Path -LiteralPath $ruta) {
            $Finestra.Icon = New-Object System.Drawing.Icon((Resolve-Path -LiteralPath $ruta).Path)
        }
    }
    catch {
        # Si la icona no es pot carregar, la finestra es queda amb la icona per defecte
    }
}

# Retorna el nom de la delegació sense el prefix repetit "CONSORCI PER NORMALITZACIO LINGUISTICA -"
function Get-NomCurt {
    param([string]$Nom)
    # Treu el prefix (amb "LA" o sense, i amb guió normal o llarg), sense distingir majúscules
    $curt = [regex]::Replace($Nom, '^\s*CONSORCI PER (LA )?NORMALITZACIO LINGUISTICA\s*[-–]\s*', '', 'IgnoreCase')
    # Si no queda res, es deixa el nom complet
    if ([string]::IsNullOrWhiteSpace($curt)) { return $Nom }
    return $curt.Trim()
}

# Mostra la finestra per triar una o més delegacions; retorna les triades o res si es cancel·la
function Show-SelectorDelegacions {
    param(
        # Llista de totes les delegacions
        [object[]]$Delegacions,
        # Controlador per defecte (per comptar les impressores que s'instal·laran)
        [string]$ModelPerDefecte = 'SHARP BP-70C31 PCL6'
    )
    # Només es mostren les delegacions que tenen nom
    $Delegacions = @($Delegacions | Where-Object { -not [string]::IsNullOrWhiteSpace($_.nom) })
    # Dades compartides amb els esdeveniments de la finestra:
    # delegacions visibles, noms de les triades i un senyal per ignorar els canvis mentre s'omple la llista
    $estat = @{
        Visibles = @()
        Triades  = New-Object 'System.Collections.Generic.HashSet[string]'
        Omplint  = $false
    }

    # Finestra principal
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Instal·lació d'impressores"
    $form.StartPosition = 'CenterScreen'
    $form.ClientSize = New-Object System.Drawing.Size(620, 540)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    Set-IconaFinestra -Finestra $form

    # Text de la primera instrucció
    $etiqueta1 = New-Object System.Windows.Forms.Label
    $etiqueta1.Text = '1. Escriu part del nom de la teva delegació:'
    $etiqueta1.Location = New-Object System.Drawing.Point(15, 15)
    $etiqueta1.Size = New-Object System.Drawing.Size(590, 25)

    # Quadre de text per filtrar la llista
    $quadreText = New-Object System.Windows.Forms.TextBox
    $quadreText.Location = New-Object System.Drawing.Point(15, 45)
    $quadreText.Size = New-Object System.Drawing.Size(590, 28)

    # Text de la segona instrucció
    $etiqueta2 = New-Object System.Windows.Forms.Label
    $etiqueta2.Text = '2. Marca amb el quadradet les delegacions que vulguis:'
    $etiqueta2.Location = New-Object System.Drawing.Point(15, 85)
    $etiqueta2.Size = New-Object System.Drawing.Size(590, 25)

    # Llista de delegacions amb un quadradet per marcar-ne més d'una
    $llista = New-Object System.Windows.Forms.CheckedListBox
    $llista.CheckOnClick = $true
    $llista.Location = New-Object System.Drawing.Point(15, 115)
    $llista.Size = New-Object System.Drawing.Size(590, 250)

    # Text informatiu sobre les delegacions marcades
    $info = New-Object System.Windows.Forms.Label
    $info.Location = New-Object System.Drawing.Point(15, 372)
    $info.Size = New-Object System.Drawing.Size(590, 95)

    # Botó per continuar (no es pot prémer fins que hi ha delegacions marcades amb impressores)
    $boto = New-Object System.Windows.Forms.Button
    $boto.Text = 'Instal·la les impressores'
    $boto.Location = New-Object System.Drawing.Point(350, 480)
    $boto.Size = New-Object System.Drawing.Size(255, 40)
    $boto.Enabled = $false
    $boto.DialogResult = [System.Windows.Forms.DialogResult]::OK

    # Botó per treure totes les marques
    $netejar = New-Object System.Windows.Forms.Button
    $netejar.Text = 'Desmarca-ho tot'
    $netejar.Location = New-Object System.Drawing.Point(145, 480)
    $netejar.Size = New-Object System.Drawing.Size(190, 40)

    # Botó per cancel·lar
    $cancela = New-Object System.Windows.Forms.Button
    $cancela.Text = 'Cancel·la'
    $cancela.Location = New-Object System.Drawing.Point(15, 480)
    $cancela.Size = New-Object System.Drawing.Size(120, 40)
    $cancela.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    # Esc cancel·la (Intro no instal·la, per evitar instal·lacions per error)
    $form.CancelButton = $cancela

    # Actualitza el text informatiu i el botó segons les delegacions marcades
    $actualitza = {
        # Delegacions marcades (en l'ordre original) i total d'impressores que se'n instal·laran
        $triades = @($Delegacions | Where-Object { $estat.Triades.Contains($_.nom) })
        $totalImpressores = 0
        foreach ($d in $triades) {
            $totalImpressores += @(Get-ImpressoresDelegacio -Delegacio $d -Marca 'SHARP' -ModelPerDefecte $ModelPerDefecte).Count
        }
        if ($triades.Count -eq 0) {
            $info.Text = 'Marca una o més delegacions per continuar.'
            $boto.Enabled = $false
        }
        else {
            # Mostra els noms curts de les primeres quatre i el nombre de les altres
            $noms = @($triades | ForEach-Object { Get-NomCurt $_.nom } | Sort-Object)
            $mostrades = ($noms | Select-Object -First 4) -join ', '
            if ($noms.Count -gt 4) { $mostrades += " i $($noms.Count - 4) més" }
            $info.Text = "Delegacions marcades ($($triades.Count)): $mostrades`r`nImpressores que s'instal·laran: $totalImpressores"
            $boto.Enabled = ($totalImpressores -gt 0)
        }
    }

    # Omple la llista segons el text escrit (si no hi ha text, les mostra totes) i hi recupera les marques
    $omple = {
        $filtre = $quadreText.Text
        if ([string]::IsNullOrWhiteSpace($filtre)) { $trobades = @($Delegacions) }
        else { $trobades = @(Find-Delegacio -Delegacions $Delegacions -Text $filtre) }
        # Ordena per nom curt, sense accents ni majúscules
        $estat.Visibles = @($trobades | Sort-Object { Get-TextNormalitzat (Get-NomCurt $_.nom) })
        # Mentre s'omple la llista, els esdeveniments de marcar s'ignoren
        $estat.Omplint = $true
        $llista.BeginUpdate()
        $llista.Items.Clear()
        foreach ($d in $estat.Visibles) {
            $etiquetaItem = Get-NomCurt $d.nom
            # Avisa si la delegació no té impressores SHARP (no es podrà marcar)
            if (@(Get-ImpressoresDelegacio -Delegacio $d -Marca 'SHARP' -ModelPerDefecte $ModelPerDefecte).Count -eq 0) {
                $etiquetaItem += ' (cap impressora SHARP)'
            }
            # Afegeix la delegació, marcada si ja s'havia triat abans
            [void]$llista.Items.Add($etiquetaItem, $estat.Triades.Contains($d.nom))
        }
        $llista.EndUpdate()
        $estat.Omplint = $false
        & $actualitza
    }

    # Esdeveniment: marcar o desmarcar una delegació
    $llista.Add_ItemCheck({
        param($remitent, $e)
        # Mentre s'omple la llista no es fa res
        if ($estat.Omplint) { return }
        $d = $estat.Visibles[$e.Index]
        if ($e.NewValue -eq [System.Windows.Forms.CheckState]::Checked) {
            # Si no té impressores SHARP, no es deixa marcar
            $nombre = @(Get-ImpressoresDelegacio -Delegacio $d -Marca 'SHARP' -ModelPerDefecte $ModelPerDefecte).Count
            if ($nombre -eq 0) {
                $e.NewValue = [System.Windows.Forms.CheckState]::Unchecked
                return
            }
            [void]$estat.Triades.Add($d.nom)
        }
        else {
            [void]$estat.Triades.Remove($d.nom)
        }
        & $actualitza
    })
    # Esdeveniments: escriure filtra la llista i el botó "Desmarca-ho tot" treu totes les marques
    $quadreText.Add_TextChanged({ & $omple })
    $netejar.Add_Click({ $estat.Triades.Clear(); & $omple })
    # Quan s'obre la finestra, el cursor queda al quadre de text
    $form.Add_Shown({ $quadreText.Focus() })

    # Afegeix els controls a la finestra i omple la llista per primera vegada
    $form.Controls.AddRange(@($etiqueta1, $quadreText, $etiqueta2, $llista, $info, $cancela, $netejar, $boto))
    & $omple

    # Mostra la finestra i espera que l'usuari acabi
    $resposta = $form.ShowDialog()
    # Delegacions marcades, en l'ordre original
    $triades = @($Delegacions | Where-Object { $estat.Triades.Contains($_.nom) })
    $form.Dispose()
    if ($resposta -eq [System.Windows.Forms.DialogResult]::OK) { return $triades }
    return
}

# Mostra la finestra de progrés mentre un procés fill fa la instal·lació; retorna un objecte amb el resultat
function Show-Progres {
    param(
        # Procés (System.Diagnostics.Process) que fa la instal·lació
        [System.Diagnostics.Process]$Proces,
        # Fitxer de registre on escriu el procés
        [string]$FitxerRegistre,
        # Posició del fitxer des d'on s'ha de començar a llegir (els bytes anteriors ja eren al fitxer)
        [long]$PosicioInicial,
        # Nombre total d'impressores que s'instal·laran
        [int]$TotalImpressores,
        # Si s'indica, és una simulació (no s'ha canviat res)
        [switch]$Simulacio
    )
    # Dades compartides amb els esdeveniments de la finestra
    $estat = @{
        Posicio   = $PosicioInicial
        Text      = ''
        Iniciades = 0
        ExitVist  = $false
        Acabat    = $false
        Codi      = $null
        Correctes = 0
        Errors    = 0
    }

    # Finestra principal
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Instal·lació d'impressores"
    $form.StartPosition = 'CenterScreen'
    $form.ClientSize = New-Object System.Drawing.Size(620, 440)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    Set-IconaFinestra -Finestra $form

    # Títol gran que canvia quan s'acaba
    $titol = New-Object System.Windows.Forms.Label
    $titol.Text = "Instal·lant les impressores..."
    $titol.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
    $titol.Location = New-Object System.Drawing.Point(15, 12)
    $titol.Size = New-Object System.Drawing.Size(590, 32)

    # Barra de progrés (una unitat per cada impressora que s'ha començat)
    $barra = New-Object System.Windows.Forms.ProgressBar
    $barra.Minimum = 0
    $barra.Maximum = [Math]::Max(1, $TotalImpressores)
    $barra.Location = New-Object System.Drawing.Point(15, 52)
    $barra.Size = New-Object System.Drawing.Size(590, 24)

    # Text d'estat sota la barra
    $textEstat = New-Object System.Windows.Forms.Label
    $textEstat.Text = "Això pot trigar uns minuts. No tanquis aquesta finestra."
    $textEstat.Location = New-Object System.Drawing.Point(15, 84)
    $textEstat.Size = New-Object System.Drawing.Size(590, 40)

    # Quadre amb el detall del que va fent el programa
    $caixa = New-Object System.Windows.Forms.TextBox
    $caixa.Multiline = $true
    $caixa.ReadOnly = $true
    $caixa.ScrollBars = 'Vertical'
    $caixa.Font = New-Object System.Drawing.Font('Consolas', 8.5)
    $caixa.Location = New-Object System.Drawing.Point(15, 128)
    $caixa.Size = New-Object System.Drawing.Size(590, 250)

    # Botó per obrir el registre al Bloc de notes
    $botoRegistre = New-Object System.Windows.Forms.Button
    $botoRegistre.Text = 'Mostra el registre'
    $botoRegistre.Location = New-Object System.Drawing.Point(15, 390)
    $botoRegistre.Size = New-Object System.Drawing.Size(190, 40)

    # Botó per tancar (només es pot prémer quan s'ha acabat)
    $botoTanca = New-Object System.Windows.Forms.Button
    $botoTanca.Text = 'Tanca'
    $botoTanca.Location = New-Object System.Drawing.Point(415, 390)
    $botoTanca.Size = New-Object System.Drawing.Size(190, 40)
    $botoTanca.Enabled = $false
    $botoTanca.DialogResult = [System.Windows.Forms.DialogResult]::OK

    # Temporitzador que llegeix el registre cada mig segon
    $temporitzador = New-Object System.Windows.Forms.Timer
    $temporitzador.Interval = 500

    # Quan el procés ha acabat: calcula el resultat i el mostra
    $finalitza = {
        $temporitzador.Stop()
        $estat.Acabat = $true
        $estat.Codi = $Proces.ExitCode
        # Llegeix del resum final del registre les impressores correctes i les que han fallat
        $m = [regex]::Match($estat.Text, 'Correctes: (\d+)')
        if ($m.Success) { $estat.Correctes = [int]$m.Groups[1].Value }
        $m = [regex]::Match($estat.Text, 'Amb error: (\d+)')
        if ($m.Success) { $estat.Errors = [int]$m.Groups[1].Value }
        $total = $estat.Correctes + $estat.Errors
        $barra.Value = $barra.Maximum
        $sufix = if ($Simulacio) { " (SIMULACIÓ: no s'ha canviat res)" } else { '' }
        if ($total -gt 0 -and $estat.Errors -eq 0 -and $estat.Codi -eq 0) {
            $titol.Text = 'Fet!'
            $titol.ForeColor = [System.Drawing.Color]::ForestGreen
            $textEstat.Text = "Impressores instal·lades: $($estat.Correctes). Ja les tens a la llista d'impressores del Windows.$sufix"
        }
        elseif ($total -gt 0) {
            $titol.Text = 'Hi ha hagut errors'
            $titol.ForeColor = [System.Drawing.Color]::DarkOrange
            $textEstat.Text = "Impressores instal·lades: $($estat.Correctes) de $total. Prem «Mostra el registre» i envia'l al servei informàtic.$sufix"
        }
        else {
            $titol.Text = "No s'ha pogut instal·lar"
            $titol.ForeColor = [System.Drawing.Color]::Firebrick
            $textEstat.Text = "El procés ha acabat sense resultat (codi $($estat.Codi)). Prem «Mostra el registre» i envia'l al servei informàtic."
        }
        $botoTanca.Enabled = $true
    }

    # Cada mig segon: llegeix el que s'ha afegit al registre i actualitza la barra i el quadre
    $temporitzador.Add_Tick({
        $nou = ''
        try {
            # Obre el registre en mode lectura compartida (el procés fill hi continua escrivint)
            $fitxer = [System.IO.File]::Open($FitxerRegistre, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            try {
                [void]$fitxer.Seek($estat.Posicio, [System.IO.SeekOrigin]::Begin)
                $lector = New-Object System.IO.StreamReader($fitxer, [System.Text.Encoding]::UTF8)
                $nou = $lector.ReadToEnd()
                $estat.Posicio = $fitxer.Position
            }
            finally { $fitxer.Dispose() }
        }
        catch { $nou = '' }
        if ($nou) {
            $estat.Text += $nou
            $caixa.AppendText($nou)
            # Cada impressora comença amb una línia "=== nom (ip) ===": s'usa per avançar la barra
            $estat.Iniciades += ([regex]::Matches($nou, '\] === ')).Count
            $barra.Value = [Math]::Min($estat.Iniciades, $barra.Maximum)
        }
        # Quan el procés ha acabat, es fa una última lectura (al tic següent) abans de mostrar el resultat
        if ($Proces.HasExited) {
            if ($estat.ExitVist) { & $finalitza } else { $estat.ExitVist = $true }
        }
    })

    # El botó del registre l'obre al Bloc de notes
    $botoRegistre.Add_Click({ Start-Process -FilePath 'notepad.exe' -ArgumentList ('"{0}"' -f $FitxerRegistre) })

    # Si es tanca la finestra abans d'acabar, es demana confirmació (la instal·lació continuaria en segon pla)
    $form.Add_FormClosing({
        param($remitent, $e)
        if (-not $estat.Acabat) {
            $resposta = [System.Windows.Forms.MessageBox]::Show(
                "La instal·lació encara no ha acabat. Si tanques la finestra, continuarà en segon pla.`n`nVols tancar-la igualment?",
                "Instal·lació d'impressores",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($resposta -ne [System.Windows.Forms.DialogResult]::Yes) { $e.Cancel = $true }
        }
    })

    # Afegeix els controls, arrenca el temporitzador i mostra la finestra
    $form.Controls.AddRange(@($titol, $barra, $textEstat, $caixa, $botoRegistre, $botoTanca))
    $temporitzador.Start()
    [void]$form.ShowDialog()
    $temporitzador.Dispose()
    $form.Dispose()
    return [pscustomobject]@{ Codi = $estat.Codi; Correctes = $estat.Correctes; Errors = $estat.Errors }
}
