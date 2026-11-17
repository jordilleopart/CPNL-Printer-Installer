#Requires -Version 5.1
<#
  Finestra.ps1: finestres senzilles (Windows Forms) per a l'usuari final:
  missatges i selectors de delegacions i impressores. Necessita que Dades.ps1 estigui carregat.
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

function Set-EstilBoto {
    param(
        [System.Windows.Forms.Button]$Boto,
        [System.Drawing.Color]$Fons,
        [System.Drawing.Color]$Text = [System.Drawing.Color]::White
    )
    $Boto.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $Boto.FlatAppearance.BorderSize = 0
    $Boto.BackColor = $Fons
    $Boto.ForeColor = $Text
    $Boto.UseVisualStyleBackColor = $false
    $Boto.Cursor = [System.Windows.Forms.Cursors]::Hand
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
        [string]$ModelPerDefecte = 'SHARP BP-70C31 PCL6',
        # Controlador universal RICOH (per comptar les impressores que s'instal·laran)
        [string]$ModelRicoh = 'RICOH PCL6 UniversalDriver V4.46'
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
    $form.ClientSize = New-Object System.Drawing.Size(700, 600)
    $form.MinimumSize = New-Object System.Drawing.Size(640, 650)
    $form.FormBorderStyle = 'Sizable'
    $form.MaximizeBox = $false
    $form.TopMost = $true
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
    Set-IconaFinestra -Finestra $form

    # Capçalera
    $capcalera = New-Object System.Windows.Forms.Label
    $capcalera.Text = "Instal·la les impressores"
    $capcalera.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $capcalera.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
    $capcalera.Location = New-Object System.Drawing.Point(24, 18)
    $capcalera.Size = New-Object System.Drawing.Size(640, 34)
    $capcalera.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    $subtitol = New-Object System.Windows.Forms.Label
    $subtitol.Text = 'Pas 1 de 3 · Tria una o més delegacions per començar.'
    $subtitol.ForeColor = [System.Drawing.Color]::FromArgb(75, 85, 99)
    $subtitol.Location = New-Object System.Drawing.Point(26, 53)
    $subtitol.Size = New-Object System.Drawing.Size(640, 24)
    $subtitol.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    # Text de la primera instrucció
    $etiqueta1 = New-Object System.Windows.Forms.Label
    $etiqueta1.Text = 'Cerca una delegació'
    $etiqueta1.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $etiqueta1.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
    $etiqueta1.Location = New-Object System.Drawing.Point(24, 91)
    $etiqueta1.Size = New-Object System.Drawing.Size(640, 24)
    $etiqueta1.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    # Quadre de text per filtrar la llista
    $quadreText = New-Object System.Windows.Forms.TextBox
    $quadreText.Location = New-Object System.Drawing.Point(24, 117)
    $quadreText.Size = New-Object System.Drawing.Size(640, 28)
    $quadreText.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $quadreText.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

    # Text de la segona instrucció
    $etiqueta2 = New-Object System.Windows.Forms.Label
    $etiqueta2.Text = 'Selecciona les delegacions'
    $etiqueta2.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $etiqueta2.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
    $etiqueta2.Location = New-Object System.Drawing.Point(24, 158)
    $etiqueta2.Size = New-Object System.Drawing.Size(640, 24)
    $etiqueta2.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    # Llista de delegacions amb un quadradet per marcar-ne més d'una
    $llista = New-Object System.Windows.Forms.CheckedListBox
    $llista.CheckOnClick = $true
    $llista.Location = New-Object System.Drawing.Point(24, 184)
    $llista.Size = New-Object System.Drawing.Size(640, 275)
    $llista.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $llista.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

    # Text informatiu sobre les delegacions marcades
    $info = New-Object System.Windows.Forms.Label
    $info.Location = New-Object System.Drawing.Point(24, 469)
    $info.Size = New-Object System.Drawing.Size(640, 62)
    $info.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $info.Padding = New-Object System.Windows.Forms.Padding(12, 8, 12, 8)
    $info.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $info.BackColor = [System.Drawing.Color]::White
    $info.ForeColor = [System.Drawing.Color]::FromArgb(55, 65, 81)

    # Botó per continuar (no es pot prémer fins que hi ha delegacions marcades amb impressores)
    $boto = New-Object System.Windows.Forms.Button
    $boto.Text = 'Continua'
    $boto.Location = New-Object System.Drawing.Point(453, 545)
    $boto.Size = New-Object System.Drawing.Size(211, 38)
    $boto.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $boto.Enabled = $false
    $boto.DialogResult = [System.Windows.Forms.DialogResult]::OK
    Set-EstilBoto -Boto $boto -Fons ([System.Drawing.Color]::FromArgb(185, 28, 28))

    # Botó per treure totes les marques
    $netejar = New-Object System.Windows.Forms.Button
    $netejar.Text = 'Desmarca-ho tot'
    $netejar.Location = New-Object System.Drawing.Point(144, 545)
    $netejar.Size = New-Object System.Drawing.Size(145, 38)
    $netejar.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
    Set-EstilBoto -Boto $netejar -Fons ([System.Drawing.Color]::FromArgb(107, 114, 128))

    # Botó per cancel·lar
    $cancela = New-Object System.Windows.Forms.Button
    $cancela.Text = 'Cancel·la'
    $cancela.Location = New-Object System.Drawing.Point(24, 545)
    $cancela.Size = New-Object System.Drawing.Size(105, 38)
    $cancela.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
    $cancela.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    Set-EstilBoto -Boto $cancela -Fons ([System.Drawing.Color]::FromArgb(229, 231, 235)) -Text ([System.Drawing.Color]::FromArgb(31, 41, 55))

    # Esc cancel·la (Intro no instal·la, per evitar instal·lacions per error)
    $form.CancelButton = $cancela

    # Actualitza el text informatiu i el botó segons les delegacions marcades
    $actualitza = {
        # Delegacions marcades (en l'ordre original) i total d'impressores que se'n instal·laran
        $triades = @($Delegacions | Where-Object { $estat.Triades.Contains($_.nom) })
        $totalImpressores = 0
        foreach ($d in $triades) {
            $totalImpressores += @(Get-ImpressoresDelegacio -Delegacio $d -Marca 'SHARP' -ModelPerDefecte $ModelPerDefecte).Count
            $totalImpressores += @(Get-ImpressoresDelegacio -Delegacio $d -Marca 'RICOH' -ModelPerDefecte $ModelPerDefecte -ModelRicoh $ModelRicoh).Count
            $totalImpressores += @(Get-ImpressoresDelegacio -Delegacio $d -Marca 'HP' -ModelPerDefecte $ModelPerDefecte).Count
            $totalImpressores += @(Get-ImpressoresDelegacio -Delegacio $d -Marca 'EPSON' -ModelPerDefecte $ModelPerDefecte).Count
            $totalImpressores += @(Get-ImpressoresDelegacio -Delegacio $d -Marca 'LEXMARK' -ModelPerDefecte $ModelPerDefecte).Count
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
            # Avisa si la delegació no té impressores compatibles (no es podrà marcar)
            $nombreSharp = @(Get-ImpressoresDelegacio -Delegacio $d -Marca 'SHARP' -ModelPerDefecte $ModelPerDefecte).Count
            $nombreRicoh = @(Get-ImpressoresDelegacio -Delegacio $d -Marca 'RICOH' -ModelPerDefecte $ModelPerDefecte -ModelRicoh $ModelRicoh).Count
            $nombreHp = @(Get-ImpressoresDelegacio -Delegacio $d -Marca 'HP' -ModelPerDefecte $ModelPerDefecte).Count
            $nombreEpson = @(Get-ImpressoresDelegacio -Delegacio $d -Marca 'EPSON' -ModelPerDefecte $ModelPerDefecte).Count
            $nombreLexmark = @(Get-ImpressoresDelegacio -Delegacio $d -Marca 'LEXMARK' -ModelPerDefecte $ModelPerDefecte).Count
            if (($nombreSharp + $nombreRicoh + $nombreHp + $nombreEpson + $nombreLexmark) -eq 0) {
                $etiquetaItem += ' (cap impressora SHARP/RICOH/HP/EPSON/LEXMARK)'
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
            # Si no té impressores compatibles, no es deixa marcar
            $nombre = @(Get-ImpressoresDelegacio -Delegacio $d -Marca 'SHARP' -ModelPerDefecte $ModelPerDefecte).Count
            $nombre += @(Get-ImpressoresDelegacio -Delegacio $d -Marca 'RICOH' -ModelPerDefecte $ModelPerDefecte -ModelRicoh $ModelRicoh).Count
            $nombre += @(Get-ImpressoresDelegacio -Delegacio $d -Marca 'HP' -ModelPerDefecte $ModelPerDefecte).Count
            $nombre += @(Get-ImpressoresDelegacio -Delegacio $d -Marca 'EPSON' -ModelPerDefecte $ModelPerDefecte).Count
            $nombre += @(Get-ImpressoresDelegacio -Delegacio $d -Marca 'LEXMARK' -ModelPerDefecte $ModelPerDefecte).Count
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
    $form.Controls.AddRange(@($capcalera, $subtitol, $etiqueta1, $quadreText, $etiqueta2, $llista, $info, $cancela, $netejar, $boto))
    & $omple

    # Mostra la finestra i espera que l'usuari acabi
    $resposta = $form.ShowDialog()
    # Delegacions marcades, en l'ordre original
    $triades = @($Delegacions | Where-Object { $estat.Triades.Contains($_.nom) })
    $form.Dispose()
    if ($resposta -eq [System.Windows.Forms.DialogResult]::OK) { return $triades }
    return
}

# Mostra les impressores de les delegacions triades i retorna la selecció feta
function Show-SelectorImpressores {
    param(
        [object[]]$Delegacions,
        [string]$ModelPerDefecte = 'SHARP BP-70C31 PCL6',
        [string]$ModelRicoh = 'RICOH PCL6 UniversalDriver V4.46'
    )
    $files = @()
    foreach ($delegacio in $Delegacions) {
        foreach ($impressora in @(Get-ImpressoresCompatibles -Delegacio $delegacio -ModelPerDefecte $ModelPerDefecte -ModelRicoh $ModelRicoh)) {
            $files += [pscustomobject]@{
                Clau       = "$($delegacio.nom)|$($impressora.Nom)"
                Delegacio  = $delegacio.nom
                Nom        = $impressora.Nom
                IP         = $impressora.IP
                Oficina    = Get-NomCurt $delegacio.nom
                Text       = "$(Get-NomCurt $delegacio.nom)  ·  $($impressora.Nom) [$($impressora.IP)]"
            }
        }
    }
    $files = @($files | Sort-Object Oficina, Nom, IP)
    if ($files.Count -eq 0) { return }

    $estat = @{
        Visibles = @()
        Triades  = New-Object 'System.Collections.Generic.HashSet[string]'
        Omplint  = $false
    }
    foreach ($fila in $files) { [void]$estat.Triades.Add($fila.Clau) }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Selecciona les impressores"
    $form.StartPosition = 'CenterScreen'
    $form.ClientSize = New-Object System.Drawing.Size(820, 650)
    $form.MinimumSize = New-Object System.Drawing.Size(700, 650)
    $form.FormBorderStyle = 'Sizable'
    $form.MaximizeBox = $false
    $form.TopMost = $true
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
    Set-IconaFinestra -Finestra $form

    $capcalera = New-Object System.Windows.Forms.Label
    $capcalera.Text = 'Selecciona les impressores'
    $capcalera.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $capcalera.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
    $capcalera.Location = New-Object System.Drawing.Point(24, 18)
    $capcalera.Size = New-Object System.Drawing.Size(760, 34)
    $capcalera.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    $subtitol = New-Object System.Windows.Forms.Label
    $subtitol.Text = 'Pas 2 de 3 · Impressores agrupades per oficina. Totes estan seleccionades per defecte.'
    $subtitol.ForeColor = [System.Drawing.Color]::FromArgb(75, 85, 99)
    $subtitol.Location = New-Object System.Drawing.Point(26, 53)
    $subtitol.Size = New-Object System.Drawing.Size(760, 24)
    $subtitol.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    $quadreText = New-Object System.Windows.Forms.TextBox
    $quadreText.Location = New-Object System.Drawing.Point(24, 91)
    $quadreText.Size = New-Object System.Drawing.Size(760, 28)
    $quadreText.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $quadreText.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

    $llista = New-Object System.Windows.Forms.CheckedListBox
    $llista.CheckOnClick = $true
    $llista.Location = New-Object System.Drawing.Point(24, 133)
    $llista.Size = New-Object System.Drawing.Size(760, 410)
    $llista.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $llista.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

    $info = New-Object System.Windows.Forms.Label
    $info.Location = New-Object System.Drawing.Point(24, 553)
    $info.Size = New-Object System.Drawing.Size(760, 35)
    $info.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $info.Padding = New-Object System.Windows.Forms.Padding(12, 8, 12, 8)
    $info.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $info.BackColor = [System.Drawing.Color]::White
    $info.ForeColor = [System.Drawing.Color]::FromArgb(55, 65, 81)

    $cancela = New-Object System.Windows.Forms.Button
    $cancela.Text = 'Cancel·la'
    $cancela.Location = New-Object System.Drawing.Point(24, 598)
    $cancela.Size = New-Object System.Drawing.Size(105, 38)
    $cancela.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
    $cancela.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    Set-EstilBoto -Boto $cancela -Fons ([System.Drawing.Color]::FromArgb(229, 231, 235)) -Text ([System.Drawing.Color]::FromArgb(31, 41, 55))

    $totes = New-Object System.Windows.Forms.Button
    $totes.Text = 'Marca-ho tot'
    $totes.Location = New-Object System.Drawing.Point(144, 598)
    $totes.Size = New-Object System.Drawing.Size(125, 38)
    $totes.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
    Set-EstilBoto -Boto $totes -Fons ([System.Drawing.Color]::FromArgb(107, 114, 128))

    $boto = New-Object System.Windows.Forms.Button
    $boto.Text = 'Continua'
    $boto.Location = New-Object System.Drawing.Point(580, 598)
    $boto.Size = New-Object System.Drawing.Size(204, 38)
    $boto.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $boto.DialogResult = [System.Windows.Forms.DialogResult]::OK
    Set-EstilBoto -Boto $boto -Fons ([System.Drawing.Color]::FromArgb(185, 28, 28))
    $form.CancelButton = $cancela

    $actualitza = {
        $info.Text = "Impressores seleccionades: $($estat.Triades.Count) de $($files.Count)"
        $boto.Enabled = ($estat.Triades.Count -gt 0)
    }
    $omple = {
        $filtre = Get-TextNormalitzat $quadreText.Text
        $estat.Visibles = @($files | Where-Object {
            $filtre -eq '' -or (Get-TextNormalitzat $_.Text).Contains($filtre)
        })
        $estat.Omplint = $true
        $llista.BeginUpdate()
        $llista.Items.Clear()
        foreach ($fila in $estat.Visibles) {
            [void]$llista.Items.Add($fila.Text, $estat.Triades.Contains($fila.Clau))
        }
        $llista.EndUpdate()
        $estat.Omplint = $false
        & $actualitza
    }
    $llista.Add_ItemCheck({
        param($remitent, $e)
        if ($estat.Omplint) { return }
        $fila = $estat.Visibles[$e.Index]
        if ($e.NewValue -eq [System.Windows.Forms.CheckState]::Checked) {
            [void]$estat.Triades.Add($fila.Clau)
        }
        else {
            [void]$estat.Triades.Remove($fila.Clau)
        }
        & $actualitza
    })
    $quadreText.Add_TextChanged({ & $omple })
    $totes.Add_Click({
        foreach ($fila in $files) { [void]$estat.Triades.Add($fila.Clau) }
        & $omple
    })
    $form.Add_Shown({ $quadreText.Focus() })
    $form.Controls.AddRange(@($capcalera, $subtitol, $quadreText, $llista, $info, $cancela, $totes, $boto))
    & $omple

    $resposta = $form.ShowDialog()
    if ($resposta -eq [System.Windows.Forms.DialogResult]::OK) {
        foreach ($delegacio in $Delegacions) {
            $seleccionades = @($files | Where-Object {
                $_.Delegacio -eq $delegacio.nom -and $estat.Triades.Contains($_.Clau)
            } | ForEach-Object { $_.Nom })
            $delegacio | Add-Member -NotePropertyName impressoresSeleccionades -NotePropertyValue $seleccionades -Force
        }
    }
    $form.Dispose()
    if ($resposta -eq [System.Windows.Forms.DialogResult]::OK) { return $Delegacions }
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
        Objectiu  = 0
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
    $form.ClientSize = New-Object System.Drawing.Size(700, 500)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
    Set-IconaFinestra -Finestra $form

    # Títol gran que canvia quan s'acaba
    $titol = New-Object System.Windows.Forms.Label
    $titol.Text = "Instal·lant les impressores..."
    $titol.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
    $titol.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
    $titol.Location = New-Object System.Drawing.Point(24, 20)
    $titol.Size = New-Object System.Drawing.Size(650, 32)
    $titol.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    # Barra de progrés (una unitat per cada impressora que s'ha començat)
    $barra = New-Object System.Windows.Forms.ProgressBar
    $barra.Minimum = 0
    $barra.Maximum = [Math]::Max(1, $TotalImpressores)
    $barra.Location = New-Object System.Drawing.Point(24, 68)
    $barra.Size = New-Object System.Drawing.Size(650, 24)
    $barra.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $barra.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous

    $percentatge = New-Object System.Windows.Forms.Label
    $percentatge.Text = "0 de $TotalImpressores"
    $percentatge.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $percentatge.ForeColor = [System.Drawing.Color]::FromArgb(75, 85, 99)
    $percentatge.Location = New-Object System.Drawing.Point(520, 96)
    $percentatge.Size = New-Object System.Drawing.Size(154, 24)
    $percentatge.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right

    # Text d'estat sota la barra
    $textEstat = New-Object System.Windows.Forms.Label
    $textEstat.Text = "Això pot trigar uns minuts. No tanquis aquesta finestra."
    $textEstat.Location = New-Object System.Drawing.Point(24, 98)
    $textEstat.Size = New-Object System.Drawing.Size(480, 40)
    $textEstat.ForeColor = [System.Drawing.Color]::FromArgb(75, 85, 99)
    $textEstat.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left

    # Estat resumit, sense mostrar el registre tècnic
    $activitat = New-Object System.Windows.Forms.Label
    $activitat.Text = 'Preparant la instal·lació...'
    $activitat.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
    $activitat.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
    $activitat.Location = New-Object System.Drawing.Point(24, 145)
    $activitat.Size = New-Object System.Drawing.Size(650, 42)
    $activitat.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    $resum = New-Object System.Windows.Forms.Label
    $resum.Text = 'La instal·lació començarà en uns instants.'
    $resum.Location = New-Object System.Drawing.Point(24, 195)
    $resum.Size = New-Object System.Drawing.Size(650, 210)
    $resum.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $resum.Padding = New-Object System.Windows.Forms.Padding(16)
    $resum.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $resum.BackColor = [System.Drawing.Color]::White
    $resum.ForeColor = [System.Drawing.Color]::FromArgb(55, 65, 81)

    # Botó per tancar (només es pot prémer quan s'ha acabat)
    $botoTanca = New-Object System.Windows.Forms.Button
    $botoTanca.Text = 'Tanca'
    $botoTanca.Location = New-Object System.Drawing.Point(504, 445)
    $botoTanca.Size = New-Object System.Drawing.Size(170, 38)
    $botoTanca.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $botoTanca.Enabled = $false
    $botoTanca.DialogResult = [System.Windows.Forms.DialogResult]::OK
    Set-EstilBoto -Boto $botoTanca -Fons ([System.Drawing.Color]::FromArgb(185, 28, 28))

    # Temporitzador que llegeix el registre cada mig segon
    $temporitzador = New-Object System.Windows.Forms.Timer
    $temporitzador.Interval = 500
    # Temporitzador independent per animar suaument la barra entre impressores
    $animacio = New-Object System.Windows.Forms.Timer
    $animacio.Interval = 30

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
        $estat.Objectiu = $barra.Maximum
        $barra.Value = $barra.Maximum
        $percentatge.Text = "$total de $TotalImpressores"
        $sufix = if ($Simulacio) { " (SIMULACIÓ: no s'ha canviat res)" } else { '' }
        if ($total -gt 0 -and $estat.Errors -eq 0 -and $estat.Codi -eq 0) {
            $titol.Text = 'Fet!'
            $titol.ForeColor = [System.Drawing.Color]::ForestGreen
            $activitat.Text = 'Instal·lació completada'
            $resum.Text = "S'han processat correctament $($estat.Correctes) impressores.$sufix"
            $textEstat.Text = "Impressores instal·lades: $($estat.Correctes). Ja les tens a la llista d'impressores del Windows.$sufix"
        }
        elseif ($total -gt 0) {
            $titol.Text = 'Hi ha hagut errors'
            $titol.ForeColor = [System.Drawing.Color]::DarkOrange
            $activitat.Text = 'Instal·lació finalitzada amb incidències'
            $resum.Text = "S'han instal·lat $($estat.Correctes) impressores i n'han fallat $($estat.Errors). Consulta el registre si el servei informàtic necessita més detalls.$sufix"
            $textEstat.Text = "Impressores instal·lades: $($estat.Correctes) de $total. El registre tècnic s'ha desat per si el servei informàtic necessita més detalls.$sufix"
        }
        else {
            $titol.Text = "No s'ha pogut instal·lar"
            $titol.ForeColor = [System.Drawing.Color]::Firebrick
            $activitat.Text = 'La instal·lació no ha produït cap resultat'
            $resum.Text = "El procés ha acabat sense impressores instal·lades (codi $($estat.Codi)). Consulta el registre si necessites ajuda."
            $textEstat.Text = "El procés ha acabat sense resultat (codi $($estat.Codi)). El registre tècnic s'ha desat per consultar-lo si cal."
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
            $mActual = [regex]::Matches($nou, '=== (.+?) \([^)]+\) ===')
            if ($mActual.Count -gt 0) {
                $activitat.Text = "Instal·lant: $($mActual[$mActual.Count - 1].Groups[1].Value)"
            }
            # Cada impressora comença amb una línia "=== nom (ip) ===": s'usa per avançar la barra
            $estat.Iniciades += ([regex]::Matches($nou, '\] === ')).Count
            $estat.Objectiu = [Math]::Min($estat.Iniciades, $barra.Maximum)
        }
        # Quan el procés ha acabat, es fa una última lectura (al tic següent) abans de mostrar el resultat
        if ($Proces.HasExited) {
            if ($estat.ExitVist) { & $finalitza } else { $estat.ExitVist = $true }
        }
    })

    # Anima la barra de progrés sense mostrar el registre tècnic
    $animacio.Add_Tick({
        if ($barra.Value -lt $estat.Objectiu) {
            $barra.Value = [Math]::Min($barra.Value + 1, $estat.Objectiu)
            $percentatge.Text = "$($barra.Value) de $TotalImpressores"
        }
    })

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
    $form.Controls.AddRange(@($titol, $barra, $percentatge, $textEstat, $activitat, $resum, $botoTanca))
    $temporitzador.Start()
    $animacio.Start()
    [void]$form.ShowDialog()
    $temporitzador.Dispose()
    $animacio.Dispose()
    $form.Dispose()
    return [pscustomobject]@{ Codi = $estat.Codi; Correctes = $estat.Correctes; Errors = $estat.Errors }
}

# Mostra la instal·lació com una llista agrupada per delegació, sense barra de progrés
function Show-Installacio {
    param(
        [System.Diagnostics.Process]$Proces,
        [string]$FitxerRegistre,
        [long]$PosicioInicial,
        [object[]]$Delegacions,
        [string]$ModelPerDefecte = 'SHARP BP-70C31 PCL6',
        [string]$ModelRicoh = 'RICOH PCL6 UniversalDriver V4.46',
        [switch]$Simulacio
    )
    $files = @()
    foreach ($delegacio in $Delegacions) {
        foreach ($impressora in @(Get-ImpressoresCompatiblesSeleccionades -Delegacio $delegacio -ModelPerDefecte $ModelPerDefecte -ModelRicoh $ModelRicoh)) {
            $files += [pscustomobject]@{
                Clau      = "$($delegacio.nom)|$($impressora.Nom)|$($impressora.IP)"
                Delegacio = $delegacio.nom
                Nom       = $impressora.Nom
                IP        = $impressora.IP
                Estat     = 'pendent'
                Icona     = $null
                Text      = $null
            }
        }
    }

    $estat = @{
        Posicio   = $PosicioInicial
        Text      = ''
        Fase      = 0
        Acabat    = $false
        Codi      = $null
        Correctes = 0
        Errors    = 0
        ExitVist  = $false
    }
    $formes = @('|', '/', '-', '\')

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Instal·lació d'impressores"
    $form.StartPosition = 'CenterScreen'
    $form.ClientSize = New-Object System.Drawing.Size(760, 650)
    $form.MinimumSize = New-Object System.Drawing.Size(700, 500)
    $form.FormBorderStyle = 'Sizable'
    $form.MaximizeBox = $false
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
    Set-IconaFinestra -Finestra $form

    $titol = New-Object System.Windows.Forms.Label
    $titol.Text = 'Pas 3 de 3 · Instal·lant les impressores'
    $titol.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $titol.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
    $titol.Location = New-Object System.Drawing.Point(24, 18)
    $titol.Size = New-Object System.Drawing.Size(710, 34)
    $titol.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    $textEstat = New-Object System.Windows.Forms.Label
    $textEstat.Text = 'No tanquis aquesta finestra mentre es processen les impressores.'
    $textEstat.ForeColor = [System.Drawing.Color]::FromArgb(75, 85, 99)
    $textEstat.Location = New-Object System.Drawing.Point(26, 53)
    $textEstat.Size = New-Object System.Drawing.Size(710, 24)
    $textEstat.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    $llista = New-Object System.Windows.Forms.FlowLayoutPanel
    $llista.Location = New-Object System.Drawing.Point(24, 90)
    $llista.Size = New-Object System.Drawing.Size(710, 490)
    $llista.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $llista.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $llista.WrapContents = $false
    $llista.AutoScroll = $true
    $llista.Padding = New-Object System.Windows.Forms.Padding(8)
    $llista.BackColor = [System.Drawing.Color]::White
    $llista.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

    foreach ($delegacio in $Delegacions) {
        $impressores = @($files | Where-Object { $_.Delegacio -eq $delegacio.nom })
        if ($impressores.Count -eq 0) { continue }
        $grup = New-Object System.Windows.Forms.Panel
        $grup.Width = 665
        $grup.Height = 36 + ($impressores.Count * 34)
        $grup.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 12)
        $grup.BackColor = [System.Drawing.Color]::FromArgb(249, 250, 251)
        $capcalera = New-Object System.Windows.Forms.Label
        $capcalera.Text = Get-NomCurt $delegacio.nom
        $capcalera.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $capcalera.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
        $capcalera.Location = New-Object System.Drawing.Point(12, 7)
        $capcalera.Size = New-Object System.Drawing.Size(640, 24)
        [void]$grup.Controls.Add($capcalera)
        $filaIndex = 0
        foreach ($fila in $impressores) {
            $filaPanel = New-Object System.Windows.Forms.Panel
            $filaPanel.Location = New-Object System.Drawing.Point(12, (34 + ($filaIndex * 34)))
            $filaPanel.Size = New-Object System.Drawing.Size(640, 30)
            $filaPanel.BackColor = [System.Drawing.Color]::White
            $icona = New-Object System.Windows.Forms.Label
            $icona.Text = '·'
            $icona.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
            $icona.ForeColor = [System.Drawing.Color]::FromArgb(107, 114, 128)
            $icona.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            $icona.Location = New-Object System.Drawing.Point(8, 2)
            $icona.Size = New-Object System.Drawing.Size(28, 26)
            $nom = New-Object System.Windows.Forms.Label
            $nom.Text = $fila.Nom
            $nom.ForeColor = [System.Drawing.Color]::FromArgb(55, 65, 81)
            $nom.Location = New-Object System.Drawing.Point(44, 4)
            $nom.Size = New-Object System.Drawing.Size(580, 24)
            $nom.AutoEllipsis = $true
            [void]$filaPanel.Controls.Add($icona)
            [void]$filaPanel.Controls.Add($nom)
            [void]$grup.Controls.Add($filaPanel)
            $fila.Icona = $icona
            $fila.Text = $nom
            $filaIndex++
        }
        [void]$llista.Controls.Add($grup)
    }

    $botoTanca = New-Object System.Windows.Forms.Button
    $botoTanca.Text = 'Tanca'
    $botoTanca.Location = New-Object System.Drawing.Point(564, 595)
    $botoTanca.Size = New-Object System.Drawing.Size(170, 38)
    $botoTanca.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $botoTanca.Enabled = $false
    $botoTanca.DialogResult = [System.Windows.Forms.DialogResult]::OK
    Set-EstilBoto -Boto $botoTanca -Fons ([System.Drawing.Color]::FromArgb(185, 28, 28))

    $finalitza = {
        $temporitzador.Stop()
        $estat.Acabat = $true
        $estat.Codi = $Proces.ExitCode
        $m = [regex]::Match($estat.Text, 'Correctes: (\d+)')
        if ($m.Success) { $estat.Correctes = [int]$m.Groups[1].Value }
        $m = [regex]::Match($estat.Text, 'Amb error: (\d+)')
        if ($m.Success) { $estat.Errors = [int]$m.Groups[1].Value }
        foreach ($fila in $files | Where-Object { $_.Estat -eq 'pendent' -or $_.Estat -eq 'instal·lant' }) {
            $fila.Estat = 'error'
            $fila.Icona.Text = '!'
            $fila.Icona.ForeColor = [System.Drawing.Color]::Firebrick
        }
        $sufix = if ($Simulacio) { " (SIMULACIÓ: no s'ha canviat res)" } else { '' }
        if ($estat.Errors -eq 0 -and $estat.Codi -eq 0) {
            $titol.Text = 'Fet!'
            $titol.ForeColor = [System.Drawing.Color]::ForestGreen
            $textEstat.Text = "Totes les impressores seleccionades s'han processat correctament.$sufix"
        }
        else {
            $titol.Text = 'Instal·lació finalitzada amb incidències'
            $titol.ForeColor = [System.Drawing.Color]::DarkOrange
            $textEstat.Text = "Algunes impressores no s'han pogut instal·lar. Consulta el registre si cal.$sufix"
        }
        $botoTanca.Enabled = $true
    }

    $temporitzador = New-Object System.Windows.Forms.Timer
    $temporitzador.Interval = 250
    $temporitzador.Add_Tick({
        $nou = ''
        try {
            $fitxer = [System.IO.File]::Open($FitxerRegistre, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            try {
                [void]$fitxer.Seek($estat.Posicio, [System.IO.SeekOrigin]::Begin)
                $lector = New-Object System.IO.StreamReader($fitxer, [System.Text.Encoding]::UTF8)
                $nou = $lector.ReadToEnd()
                $estat.Posicio = $fitxer.Position
                $lector.Dispose()
            }
            finally { $fitxer.Dispose() }
        }
        catch { $nou = '' }
        if ($nou) {
            $estat.Text += $nou
            foreach ($m in [regex]::Matches($nou, '=== (.+?) \(([^)]+)\) ===')) {
                $fila = $files | Where-Object { $_.Nom -eq $m.Groups[1].Value -and $_.IP -eq $m.Groups[2].Value } | Select-Object -First 1
                if ($fila) {
                    $fila.Estat = 'instal·lant'
                    $fila.Icona.Text = $formes[$estat.Fase]
                    $fila.Icona.ForeColor = [System.Drawing.Color]::FromArgb(185, 28, 28)
                    $textEstat.Text = "Instal·lant: $($fila.Nom)"
                }
            }
            foreach ($m in [regex]::Matches($nou, "Impressora '(.+?)' correcta\.")) {
                $fila = $files | Where-Object { $_.Nom -eq $m.Groups[1].Value } | Select-Object -First 1
                if ($fila) {
                    $fila.Estat = 'correcte'
                    $fila.Icona.Text = '✓'
                    $fila.Icona.ForeColor = [System.Drawing.Color]::ForestGreen
                }
            }
            foreach ($m in [regex]::Matches($nou, "Impressora '(.+?)':")) {
                $fila = $files | Where-Object { $_.Nom -eq $m.Groups[1].Value } | Select-Object -First 1
                if ($fila -and $fila.Estat -ne 'correcte') {
                    $fila.Estat = 'error'
                    $fila.Icona.Text = '!'
                    $fila.Icona.ForeColor = [System.Drawing.Color]::Firebrick
                }
            }
        }
        $estat.Fase = ($estat.Fase + 1) % $formes.Count
        foreach ($fila in ($files | Where-Object { $_.Estat -eq 'instal·lant' })) {
            $fila.Icona.Text = $formes[$estat.Fase]
        }
        if ($Proces.HasExited) {
            if ($estat.ExitVist) { & $finalitza } else { $estat.ExitVist = $true }
        }
    })

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
    $form.Controls.AddRange(@($titol, $textEstat, $llista, $botoTanca))
    $temporitzador.Start()
    [void]$form.ShowDialog()
    $temporitzador.Dispose()
    $form.Dispose()
    return [pscustomobject]@{ Codi = $estat.Codi; Correctes = $estat.Correctes; Errors = $estat.Errors }
}
