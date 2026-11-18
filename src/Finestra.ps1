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
    $Boto.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $Boto.Padding = New-Object System.Windows.Forms.Padding(12, 0, 12, 0)
    $Boto.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(
        [Math]::Max(0, $Fons.R - 18),
        [Math]::Max(0, $Fons.G - 18),
        [Math]::Max(0, $Fons.B - 18))
    $Boto.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(
        [Math]::Max(0, $Fons.R - 30),
        [Math]::Max(0, $Fons.G - 30),
        [Math]::Max(0, $Fons.B - 30))
}

function Set-EstilTextBox {
    param([System.Windows.Forms.TextBox]$Quadre)
    $Quadre.AutoSize = $false
    $Quadre.Height = 34
    $Quadre.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $Quadre.BackColor = [System.Drawing.Color]::White
    $Quadre.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
    $Quadre.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $Quadre.Padding = New-Object System.Windows.Forms.Padding(8, 4, 8, 4)
}

function Set-EstilLlista {
    param([System.Windows.Forms.CheckedListBox]$Llista)
    $Llista.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $Llista.BackColor = [System.Drawing.Color]::White
    $Llista.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
    $Llista.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $Llista.IntegralHeight = $false
    $Llista.ItemHeight = 30
}

function Set-EstilTargeta {
    param([System.Windows.Forms.Control]$Control)
    $Control.BackColor = [System.Drawing.Color]::White
    $Control.ForeColor = [System.Drawing.Color]::FromArgb(55, 65, 81)
    $Control.Padding = New-Object System.Windows.Forms.Padding(14, 10, 14, 10)
}

function Add-CapcaleraVisual {
    param([System.Windows.Forms.Form]$Finestra)
    $capcalera = New-Object System.Windows.Forms.Panel
    $capcalera.Location = New-Object System.Drawing.Point(0, 0)
    $capcalera.Size = New-Object System.Drawing.Size($Finestra.ClientSize.Width, 78)
    $capcalera.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $capcalera.BackColor = [System.Drawing.Color]::FromArgb(254, 242, 242)
    [void]$Finestra.Controls.Add($capcalera)

    $accent = New-Object System.Windows.Forms.Panel
    $accent.Location = New-Object System.Drawing.Point(0, 0)
    $accent.Size = New-Object System.Drawing.Size($Finestra.ClientSize.Width, 5)
    $accent.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $accent.BackColor = [System.Drawing.Color]::FromArgb(185, 28, 28)
    [void]$Finestra.Controls.Add($accent)
    $capcalera.SendToBack()
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
    return Show-SelectorDelegacionsHtml -Delegacions $Delegacions -ModelPerDefecte $ModelPerDefecte -ModelRicoh $ModelRicoh
    $Delegacions = @($Delegacions | Where-Object { -not [string]::IsNullOrWhiteSpace($_.nom) })
    $estat = @{ Oficines = New-Object 'System.Collections.Generic.HashSet[string]'; Impressores = New-Object 'System.Collections.Generic.HashSet[string]'; Pagina = 1; Acceptat = $false; Omplint = $false }
    $files = @()
    foreach ($d in $Delegacions) {
        foreach ($p in @(Get-ImpressoresCompatibles -Delegacio $d -ModelPerDefecte $ModelPerDefecte -ModelRicoh $ModelRicoh)) {
            $files += [pscustomobject]@{ Clau = "$($d.nom)|$($p.Nom)"; Delegacio = $d.nom; Oficina = Get-NomCurt $d.nom; Nom = $p.Nom; IP = $p.IP }
        }
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Instal·lació d'impressores"
    $form.StartPosition = 'CenterScreen'
    $form.ClientSize = New-Object System.Drawing.Size(860, 680)
    $form.MinimumSize = New-Object System.Drawing.Size(760, 600)
    $form.FormBorderStyle = 'Sizable'
    $form.MaximizeBox = $false
    $form.TopMost = $true
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $form.BackColor = [System.Drawing.Color]::FromArgb(247, 248, 250)
    Set-IconaFinestra -Finestra $form

    $brand = New-Object System.Windows.Forms.Panel
    $brand.Dock = 'Top'; $brand.Height = 88; $brand.BackColor = [System.Drawing.Color]::FromArgb(24, 31, 43)
    $brandTitle = New-Object System.Windows.Forms.Label
    $brandTitle.Text = 'SEU  /  IMPRESSORES'; $brandTitle.ForeColor = [System.Drawing.Color]::White
    $brandTitle.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
    $brandTitle.Location = New-Object System.Drawing.Point(32, 18); $brandTitle.Size = New-Object System.Drawing.Size(400, 24)
    $brandSub = New-Object System.Windows.Forms.Label
    $brandSub.Text = 'Configuració guiada'; $brandSub.ForeColor = [System.Drawing.Color]::FromArgb(166, 177, 194)
    $brandSub.Location = New-Object System.Drawing.Point(33, 47); $brandSub.Size = New-Object System.Drawing.Size(300, 22)
    [void]$brand.Controls.AddRange(@($brandTitle, $brandSub))

    $step = New-Object System.Windows.Forms.Label
    $step.Text = '01  OFICINES        02  IMPRESSORES        03  INSTAL·LACIÓ'
    $step.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $step.ForeColor = [System.Drawing.Color]::FromArgb(185, 28, 28)
    $step.Location = New-Object System.Drawing.Point(34, 108); $step.Size = New-Object System.Drawing.Size(790, 26)
    $title = New-Object System.Windows.Forms.Label
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = [System.Drawing.Color]::FromArgb(24, 31, 43)
    $title.Location = New-Object System.Drawing.Point(32, 142); $title.Size = New-Object System.Drawing.Size(790, 42)
    $hint = New-Object System.Windows.Forms.Label
    $hint.ForeColor = [System.Drawing.Color]::FromArgb(91, 101, 116)
    $hint.Location = New-Object System.Drawing.Point(34, 188); $hint.Size = New-Object System.Drawing.Size(790, 28)

    $page1 = New-Object System.Windows.Forms.Panel
    $page1.Location = New-Object System.Drawing.Point(32, 232); $page1.Size = New-Object System.Drawing.Size(796, 330)
    $search1 = New-Object System.Windows.Forms.TextBox
    $search1.Location = New-Object System.Drawing.Point(0, 0); $search1.Size = New-Object System.Drawing.Size(630, 34); Set-EstilTextBox $search1
    $selectOffices = New-Object System.Windows.Forms.Button
    $selectOffices.Text = 'Selecciona-ho tot'; $selectOffices.Location = New-Object System.Drawing.Point(646, 0); $selectOffices.Size = New-Object System.Drawing.Size(150, 34)
    Set-EstilBoto $selectOffices ([System.Drawing.Color]::FromArgb(225, 228, 233)) ([System.Drawing.Color]::FromArgb(24, 31, 43))
    $offices = New-Object System.Windows.Forms.CheckedListBox
    $offices.Location = New-Object System.Drawing.Point(0, 50); $offices.Size = New-Object System.Drawing.Size(796, 280)
    $offices.CheckOnClick = $true; Set-EstilLlista $offices; $offices.ItemHeight = 38
    $offices.DrawMode = [System.Windows.Forms.DrawMode]::OwnerDrawFixed
    $offices.Add_DrawItem({
        param($sender, $e)
        if ($e.Index -lt 0) { return }
        $text = [string]$sender.Items[$e.Index]
        $match = [regex]::Match($text, '^(.*?)\s+(\(\d+ impressores\))$')
        $officeName = if ($match.Success) { $match.Groups[1].Value.Trim() } else { $text.Trim() }
        $printerCount = if ($match.Success) { $match.Groups[2].Value } else { '' }
        $e.DrawBackground()
        $box = New-Object System.Drawing.Rectangle(6, ($e.Bounds.Height - 15) / 2, 15, 15)
        $boxPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(145, 153, 165))
        try {
            $e.Graphics.DrawRectangle($boxPen, $box)
            if ($sender.GetItemChecked($e.Index)) {
                $checkPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(185, 28, 28), 2)
                try {
                    $e.Graphics.DrawLine($checkPen, 9, ($e.Bounds.Height / 2), 13, ($e.Bounds.Height / 2 + 4))
                    $e.Graphics.DrawLine($checkPen, 13, ($e.Bounds.Height / 2 + 4), 20, ($e.Bounds.Height / 2 - 5))
                }
                finally {
                    $checkPen.Dispose()
                }
            }
        }
        finally {
            $boxPen.Dispose()
        }
        $font = $sender.Font
        $namePoint = New-Object System.Drawing.Point(30, ($e.Bounds.Height - $font.Height) / 2)
        [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, $officeName, $font, $namePoint, [System.Drawing.Color]::FromArgb(24, 31, 43))
        if ($printerCount) {
            $nameWidth = [System.Windows.Forms.TextRenderer]::MeasureText($officeName, $font).Width
            $countPoint = New-Object System.Drawing.Point((34 + $nameWidth), ($e.Bounds.Height - $font.Height) / 2)
            [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, $printerCount, $font, $countPoint, [System.Drawing.Color]::FromArgb(145, 153, 165))
        }
        $e.DrawFocusRectangle()
    })
    [void]$page1.Controls.AddRange(@($search1, $selectOffices, $offices))

    $page2 = New-Object System.Windows.Forms.Panel
    $page2.Location = New-Object System.Drawing.Point(32, 232); $page2.Size = New-Object System.Drawing.Size(796, 330); $page2.Visible = $false
    $search2 = New-Object System.Windows.Forms.TextBox
    $search2.Location = New-Object System.Drawing.Point(0, 0); $search2.Size = New-Object System.Drawing.Size(630, 34); Set-EstilTextBox $search2
    $selectPrinters = New-Object System.Windows.Forms.Button
    $selectPrinters.Text = 'Selecciona-ho tot'; $selectPrinters.Location = New-Object System.Drawing.Point(646, 0); $selectPrinters.Size = New-Object System.Drawing.Size(150, 34)
    Set-EstilBoto $selectPrinters ([System.Drawing.Color]::FromArgb(225, 228, 233)) ([System.Drawing.Color]::FromArgb(24, 31, 43))
    $printers = New-Object System.Windows.Forms.CheckedListBox
    $printers.Location = New-Object System.Drawing.Point(0, 50); $printers.Size = New-Object System.Drawing.Size(796, 280)
    $printers.CheckOnClick = $true; Set-EstilLlista $printers; $printers.ItemHeight = 34
    $printers.DrawMode = [System.Windows.Forms.DrawMode]::OwnerDrawFixed
    $printers.Add_DrawItem({
        param($sender, $e)
        if ($e.Index -lt 0) { return }
        $text = [string]$sender.Items[$e.Index]
        $isOffice = $text -match '^\s{5}\S'
        $e.DrawBackground()
        if (-not $isOffice) {
            $box = New-Object System.Drawing.Rectangle(6, ($e.Bounds.Height - 15) / 2, 15, 15)
            $boxPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(145, 153, 165))
            try {
                $e.Graphics.DrawRectangle($boxPen, $box)
            }
            finally {
                $boxPen.Dispose()
            }
            if ($sender.GetItemChecked($e.Index)) {
                $checkPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(185, 28, 28), 2)
                try {
                    $e.Graphics.DrawLine($checkPen, 9, ($e.Bounds.Height / 2), 13, ($e.Bounds.Height / 2 + 4))
                    $e.Graphics.DrawLine($checkPen, 13, ($e.Bounds.Height / 2 + 4), 20, ($e.Bounds.Height / 2 - 5))
                }
                finally {
                    $checkPen.Dispose()
                }
            }
        }
        $textColor = if ($isOffice) { [System.Drawing.Color]::FromArgb(24, 31, 43) } else { [System.Drawing.Color]::FromArgb(55, 65, 81) }
        $font = if ($isOffice) { New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold) } else { $sender.Font }
        try {
            $textX = if ($isOffice) { 12 } else { 30 }
            [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, $text.Trim(), $font, (New-Object System.Drawing.Point($textX, ($e.Bounds.Height - $font.Height) / 2)), $textColor)
        }
        finally {
            if ($isOffice) { $font.Dispose() }
        }
        $e.DrawFocusRectangle()
    })
    [void]$page2.Controls.AddRange(@($search2, $selectPrinters, $printers))

    $summary = New-Object System.Windows.Forms.Label
    $summary.Location = New-Object System.Drawing.Point(32, 575); $summary.Size = New-Object System.Drawing.Size(500, 35)
    $summary.ForeColor = [System.Drawing.Color]::FromArgb(91, 101, 116)
    $back = New-Object System.Windows.Forms.Button
    $back.Text = 'Enrere'; $back.Location = New-Object System.Drawing.Point(32, 620); $back.Size = New-Object System.Drawing.Size(110, 40); $back.Visible = $false
    Set-EstilBoto $back ([System.Drawing.Color]::FromArgb(225, 228, 233)) ([System.Drawing.Color]::FromArgb(24, 31, 43))
    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel·la'; $cancel.Location = New-Object System.Drawing.Point(672, 620); $cancel.Size = New-Object System.Drawing.Size(156, 40); $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    Set-EstilBoto $cancel ([System.Drawing.Color]::FromArgb(225, 228, 233)) ([System.Drawing.Color]::FromArgb(24, 31, 43))
    $next = New-Object System.Windows.Forms.Button
    $next.Text = 'Continua'; $next.Location = New-Object System.Drawing.Point(492, 620); $next.Size = New-Object System.Drawing.Size(164, 40)
    $next.Enabled = $false
    Set-EstilBoto $next ([System.Drawing.Color]::FromArgb(185, 28, 28))
    $form.CancelButton = $cancel

    $fillOffices = {
        $filter = Get-TextNormalitzat $search1.Text
        $visible = @($Delegacions | Where-Object { $filter -eq '' -or (Get-TextNormalitzat (Get-NomCurt $_.nom)).Contains($filter) } | Sort-Object { Get-TextNormalitzat (Get-NomCurt $_.nom) })
        $estat.Omplint = $true
        try {
            $offices.Items.Clear()
            foreach ($d in $visible) {
                $count = @(Get-ImpressoresCompatibles -Delegacio $d -ModelPerDefecte $ModelPerDefecte -ModelRicoh $ModelRicoh).Count
                [void]$offices.Items.Add("$(Get-NomCurt $d.nom)     ($count impressores)", $estat.Oficines.Contains($d.nom))
            }
        }
        finally {
            $estat.Omplint = $false
        }
        $summary.Text = "$($estat.Oficines.Count) oficines seleccionades"
    }
    $fillPrinters = {
        $filter = Get-TextNormalitzat $search2.Text
        $estat.Omplint = $true
        try {
            $printers.Items.Clear()
            $printerRows = @($files | Where-Object { $estat.Oficines.Contains($_.Delegacio) -and ($filter -eq '' -or (Get-TextNormalitzat "$($_.Oficina) $($_.Nom) $($_.IP)").Contains($filter)) } | Sort-Object Oficina, Nom, IP)
            $lastOffice = ''
            foreach ($p in $printerRows) {
                if ($p.Oficina -ne $lastOffice) { [void]$printers.Items.Add("     $($p.Oficina)", $false); $lastOffice = $p.Oficina }
                [void]$printers.Items.Add("        $($p.Nom)  ·  $($p.IP)", $estat.Impressores.Contains($p.Clau))
            }
        }
        finally {
            $estat.Omplint = $false
        }
        $summary.Text = "$($estat.Impressores.Count) impressores seleccionades"
    }
    $offices.Add_ItemCheck({
        param($sender, $e)
        if ($estat.Omplint) { return }
        if ($e.Index -ge 0) {
            $filter = Get-TextNormalitzat $search1.Text
            $visible = @($Delegacions | Where-Object { $filter -eq '' -or (Get-TextNormalitzat (Get-NomCurt $_.nom)).Contains($filter) } | Sort-Object { Get-TextNormalitzat (Get-NomCurt $_.nom) })
            if ($e.NewValue -eq [System.Windows.Forms.CheckState]::Checked) { [void]$estat.Oficines.Add($visible[$e.Index].nom) } else { [void]$estat.Oficines.Remove($visible[$e.Index].nom) }
            $form.BeginInvoke([Action]{ $summary.Text = "$($estat.Oficines.Count) oficines seleccionades"; $next.Enabled = $estat.Oficines.Count -gt 0 }) | Out-Null
        }
    })
    $printers.Add_ItemCheck({
        param($sender, $e)
        if ($estat.Omplint) { return }
        $row = $printers.Items[$e.Index]
        $match = @($files | Where-Object { $_.Delegacio -in @($estat.Oficines) -and ("        $($_.Nom)  ·  $($_.IP)" -eq $row) } | Select-Object -First 1)
        if ($match.Count -gt 0) {
            if ($e.NewValue -eq [System.Windows.Forms.CheckState]::Checked) { [void]$estat.Impressores.Add($match[0].Clau) } else { [void]$estat.Impressores.Remove($match[0].Clau) }
            $form.BeginInvoke([Action]{ $summary.Text = "$($estat.Impressores.Count) impressores seleccionades"; $printers.Invalidate() }) | Out-Null
        } else { $e.NewValue = [System.Windows.Forms.CheckState]::Unchecked }
    })
    $search1.Add_TextChanged({ & $fillOffices })
    $search2.Add_TextChanged({ & $fillPrinters })
    $selectOffices.Add_Click({
        foreach ($d in $Delegacions) { [void]$estat.Oficines.Add($d.nom) }
        & $fillOffices
        $next.Enabled = $estat.Oficines.Count -gt 0
    })
    $selectPrinters.Add_Click({
        foreach ($p in $files | Where-Object { $estat.Oficines.Contains($_.Delegacio) }) { [void]$estat.Impressores.Add($p.Clau) }
        & $fillPrinters
    })
    $back.Add_Click({
        $page2.Visible = $false; $page1.Visible = $true; $back.Visible = $false
        $next.Text = 'Continua'; $title.Text = 'Tria les oficines'; $hint.Text = 'Selecciona una o més oficines per veure les seves impressores.'; $step.Text = '01  OFICINES        02  IMPRESSORES        03  INSTAL·LACIÓ'
    })
    $next.Add_Click({
        if ($estat.Pagina -eq 1) {
            foreach ($p in $files | Where-Object { $estat.Oficines.Contains($_.Delegacio) }) { [void]$estat.Impressores.Add($p.Clau) }
            $estat.Pagina = 2; $page1.Visible = $false; $page2.Visible = $true; $back.Visible = $true; $next.Text = 'Inicia la instal·lació'
            $title.Text = 'Tria les impressores'; $hint.Text = 'Les impressores estan agrupades per oficina. Pots ajustar la selecció abans de continuar.'; $step.Text = '01  OFICINES   ·   02  IMPRESSORES        03  INSTAL·LACIÓ'; & $fillPrinters
        } elseif ($estat.Impressores.Count -gt 0) { $estat.Acceptat = $true; $form.Close() }
    })
    $form.Controls.AddRange(@($brand, $step, $title, $hint, $page1, $page2, $summary, $back, $cancel, $next))
    & $fillOffices
    $search1.Focus()
    [void]$form.ShowDialog()
    $resultat = @($Delegacions | Where-Object { $estat.Oficines.Contains($_.nom) })
    foreach ($d in $resultat) {
        $selected = @($files | Where-Object { $_.Delegacio -eq $d.nom -and $estat.Impressores.Contains($_.Clau) } | ForEach-Object { $_.Nom })
        $d | Add-Member -NotePropertyName impressoresSeleccionades -NotePropertyValue $selected -Force
    }
    $form.Dispose()
    if ($estat.Acceptat) { return $resultat }
    return
}

# Mostra les impressores de les delegacions triades i retorna la selecció feta
function Show-SelectorImpressores {
    param(
        [object[]]$Delegacions,
        [string]$ModelPerDefecte = 'SHARP BP-70C31 PCL6',
        [string]$ModelRicoh = 'RICOH PCL6 UniversalDriver V4.46'
    )
    # La selecció forma part del wizard de Show-SelectorDelegacions.
    return $Delegacions
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
    $form.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
    Set-IconaFinestra -Finestra $form
    Add-CapcaleraVisual -Finestra $form

    $capcalera = New-Object System.Windows.Forms.Label
    $capcalera.Text = 'Selecciona les impressores'
    $capcalera.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $capcalera.ForeColor = [System.Drawing.Color]::FromArgb(153, 27, 27)
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
    Set-EstilTextBox -Quadre $quadreText

    $llista = New-Object System.Windows.Forms.CheckedListBox
    $llista.CheckOnClick = $true
    $llista.Location = New-Object System.Drawing.Point(24, 133)
    $llista.Size = New-Object System.Drawing.Size(760, 410)
    $llista.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    Set-EstilLlista -Llista $llista

    $info = New-Object System.Windows.Forms.Label
    $info.Location = New-Object System.Drawing.Point(24, 553)
    $info.Size = New-Object System.Drawing.Size(760, 35)
    $info.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    Set-EstilTargeta -Control $info

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
    $form.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
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
        $sufix = if ($Simulacio) { ' (SIMULACIO: no s''ha canviat res)' } else { '' }
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
    return Show-InstallacioHtml -Proces $Proces -FitxerRegistre $FitxerRegistre -PosicioInicial $PosicioInicial -Delegacions $Delegacions -ModelPerDefecte $ModelPerDefecte -ModelRicoh $ModelRicoh -Simulacio:$Simulacio
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
    $formes = @('◐', '◓', '◑', '◒')

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Instal·lació d'impressores"
    $form.StartPosition = 'CenterScreen'
    $form.ClientSize = New-Object System.Drawing.Size(820, 700)
    $form.MinimumSize = New-Object System.Drawing.Size(760, 580)
    $form.FormBorderStyle = 'Sizable'
    $form.MaximizeBox = $false
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $form.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
    Set-IconaFinestra -Finestra $form
    $titol = New-Object System.Windows.Forms.Label
    $titol.Text = 'Instal·lant les impressores'
    $titol.Font = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Bold)
    $titol.ForeColor = [System.Drawing.Color]::FromArgb(24, 31, 43)
    $titol.Location = New-Object System.Drawing.Point(32, 24)
    $titol.Size = New-Object System.Drawing.Size(760, 42)
    $titol.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $pas = New-Object System.Windows.Forms.Label
    $pas.Text = '03  INSTAL·LACIÓ'
    $pas.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $pas.ForeColor = [System.Drawing.Color]::FromArgb(185, 28, 28)
    $pas.Location = New-Object System.Drawing.Point(34, 8)
    $pas.Size = New-Object System.Drawing.Size(300, 20)

    $textEstat = New-Object System.Windows.Forms.Label
    $textEstat.Text = 'No tanquis aquesta finestra mentre es processen les impressores.'
    $textEstat.ForeColor = [System.Drawing.Color]::FromArgb(75, 85, 99)
    $textEstat.Location = New-Object System.Drawing.Point(34, 72)
    $textEstat.Size = New-Object System.Drawing.Size(750, 30)
    $textEstat.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

    $llista = New-Object System.Windows.Forms.FlowLayoutPanel
    $llista.Location = New-Object System.Drawing.Point(32, 120)
    $llista.Size = New-Object System.Drawing.Size(756, 505)
    $llista.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $llista.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $llista.WrapContents = $false
    $llista.AutoScroll = $true
    $llista.Padding = New-Object System.Windows.Forms.Padding(8, 8, 16, 8)
    $llista.BackColor = [System.Drawing.Color]::FromArgb(247, 248, 250)
    $llista.BorderStyle = [System.Windows.Forms.BorderStyle]::None

    foreach ($delegacio in $Delegacions) {
        $impressores = @($files | Where-Object { $_.Delegacio -eq $delegacio.nom })
        if ($impressores.Count -eq 0) { continue }
        $grup = New-Object System.Windows.Forms.Panel
        $grup.Width = 718
        $grup.Height = 48 + ($impressores.Count * 42)
        $grup.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 14)
        $grup.BackColor = [System.Drawing.Color]::White
        $capcalera = New-Object System.Windows.Forms.Label
        $capcalera.Text = Get-NomCurt $delegacio.nom
        $capcalera.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $capcalera.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
        $capcalera.Location = New-Object System.Drawing.Point(18, 12)
        $capcalera.Size = New-Object System.Drawing.Size(680, 26)
        [void]$grup.Controls.Add($capcalera)
        $filaIndex = 0
        foreach ($fila in $impressores) {
            $filaPanel = New-Object System.Windows.Forms.Panel
            $filaPanel.Location = New-Object System.Drawing.Point(18, (44 + ($filaIndex * 42)))
            $filaPanel.Size = New-Object System.Drawing.Size(680, 38)
            $filaPanel.BackColor = [System.Drawing.Color]::FromArgb(247, 248, 250)
            $icona = New-Object System.Windows.Forms.Label
            $icona.Text = '·'
            $icona.Font = New-Object System.Drawing.Font('Segoe UI Symbol', 15, [System.Drawing.FontStyle]::Bold)
            $icona.ForeColor = [System.Drawing.Color]::FromArgb(107, 114, 128)
            $icona.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            $icona.Location = New-Object System.Drawing.Point(12, 5)
            $icona.Size = New-Object System.Drawing.Size(32, 28)
            $nom = New-Object System.Windows.Forms.Label
            $nom.Text = $fila.Nom
            $nom.ForeColor = [System.Drawing.Color]::FromArgb(55, 65, 81)
            $nom.Location = New-Object System.Drawing.Point(58, 7)
            $nom.Size = New-Object System.Drawing.Size(600, 25)
            $nom.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
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
    $botoTanca.Location = New-Object System.Drawing.Point(618, 645)
    $botoTanca.Size = New-Object System.Drawing.Size(170, 40)
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
        $sufix = if ($Simulacio) { ' (SIMULACIO: no s''ha canviat res)' } else { '' }
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
    $form.Controls.AddRange(@($pas, $titol, $textEstat, $llista, $botoTanca))
    $temporitzador.Start()
    [void]$form.ShowDialog()
    $temporitzador.Dispose()
    $form.Dispose()
    return [pscustomobject]@{ Codi = $estat.Codi; Correctes = $estat.Correctes; Errors = $estat.Errors }
}

function Show-HtmlForm {
    param(
        [string]$Html,
        [int]$Width,
        [int]$Height,
        [hashtable]$State,
        [scriptblock]$OnNavigate
    )
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Instal·lació d'impressores"
    $form.StartPosition = 'CenterScreen'
    $form.ClientSize = New-Object System.Drawing.Size($Width, $Height)
    $form.MinimumSize = New-Object System.Drawing.Size($Width, $Height)
    $form.MaximumSize = New-Object System.Drawing.Size($Width, $Height)
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MaximizeBox = $false
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    Set-IconaFinestra -Finestra $form

    $browser = New-Object System.Windows.Forms.WebBrowser
    $browser.Dock = [System.Windows.Forms.DockStyle]::Fill
    $browser.ScriptErrorsSuppressed = $true
    $browser.AllowNavigation = $true
    $browser.Add_Navigating({
        param($sender, $e)
        if ($e.Url.Scheme -eq 'app') {
            $e.Cancel = $true
            & $OnNavigate $e.Url.AbsoluteUri $form
        }
    })
    [void]$form.Controls.Add($browser)
    $browser.DocumentText = $Html
    [void]$form.ShowDialog()
    $browser.Dispose()
    $form.Dispose()
}

function Get-HtmlShell {
    param([string]$Body, [string]$Script)
    return @"
<!doctype html>
<html lang="ca">
<head>
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<meta charset="utf-8">
<style>
* { box-sizing: border-box; }
html, body { margin: 0; width: 100%; height: 100%; font-family: "Segoe UI", Arial, sans-serif; color: #18202d; background: #f7f8fa; }
body { overflow: hidden; }
.top { height: 88px; padding: 18px 34px; background: #18202d; color: white; }
.brand { font-size: 15px; font-weight: 700; letter-spacing: 1.4px; }
.brand-sub { margin-top: 6px; color: #a6b1c2; font-size: 12px; }
.content { padding: 20px 34px 26px; height: calc(100% - 88px); }
.steps { color: #b91c1c; font-size: 11px; font-weight: 700; letter-spacing: .5px; }
h1 { margin: 12px 0 4px; font-size: 29px; line-height: 38px; }
.hint { margin: 0 0 18px; color: #5b6574; font-size: 14px; }
.toolbar { height: 36px; display: flex; margin-bottom: 12px; }
input[type=text] { flex: 1; height: 36px; border: 1px solid #d5d9df; border-radius: 6px; padding: 0 12px; font: 14px "Segoe UI"; color: #18202d; }
button { border: 0; border-radius: 6px; height: 38px; padding: 0 18px; font: 700 13px "Segoe UI"; cursor: pointer; }
.secondary { margin-left: 10px; color: #18202d; background: #e1e4e9; }
.primary { color: white; background: #b91c1c; }
.primary:hover { background: #991b1b; }
.list { height: 345px; overflow-y: auto; padding: 4px; background: white; border: 1px solid #e4e7eb; border-radius: 8px; }
.row { min-height: 48px; display: flex; align-items: center; padding: 8px 14px; border-bottom: 1px solid #f0f1f3; }
.row:last-child { border-bottom: 0; }
.row label { display: flex; align-items: center; width: 100%; cursor: pointer; }
.row.disabled { opacity: .58; background: #fafafa; }
.row.disabled label { cursor: not-allowed; }
input[type=checkbox] { width: 17px; height: 17px; margin: 0 13px 0 0; accent-color: #b91c1c; }
.office-name { font-size: 14px; font-weight: 600; }
.muted { margin-left: 8px; color: #9199a5; font-size: 13px; }
.office-header { padding: 16px 14px 7px; color: #18202d; font-size: 13px; font-weight: 700; }
.printer-row { min-height: 42px; padding-left: 28px; }
.printer-name { font-size: 13px; color: #374151; }
.printer-ip { margin-left: 8px; color: #9199a5; font-size: 12px; }
.footer { height: 54px; display: flex; align-items: end; justify-content: space-between; }
.footer-left { color: #5b6574; font-size: 13px; padding-bottom: 10px; }
.footer-right button { margin-left: 10px; }
.hidden { display: none; }
.error { height: 20px; margin-top: 7px; color: #b91c1c; font-size: 12px; }
.install-list { height: 390px; }
.install-group { margin-bottom: 14px; padding: 0 12px 8px; border-radius: 8px; background: white; }
.install-office { padding: 15px 6px 9px; font-size: 14px; font-weight: 700; }
.install-row { min-height: 40px; display: flex; align-items: center; border-top: 1px solid #f0f1f3; font-size: 13px; color: #374151; }
.status { width: 28px; margin-right: 8px; text-align: center; color: #9aa2ad; font-size: 18px; }
.spinner-ring { display: inline-block; width: 17px; height: 17px; border: 2px solid #f1caca; border-top-color: #b91c1c; border-radius: 50%; animation: spin .8s linear infinite; vertical-align: middle; }
.check { display: inline-block; width: 16px; height: 9px; border-left: 2px solid #18804b; border-bottom: 2px solid #18804b; transform: rotate(-45deg); vertical-align: 3px; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
.done { color: #18804b; }
.failed { color: #b91c1c; }
.install-summary { margin-top: 10px; color: #5b6574; font-size: 13px; }
</style>
</head>
<body>
$Body
<script>
$Script
</script>
</body>
</html>
"@
}

function Show-SelectorDelegacionsHtml {
    param(
        [object[]]$Delegacions,
        [string]$ModelPerDefecte,
        [string]$ModelRicoh
    )
    $Delegacions = @($Delegacions | Where-Object { -not [string]::IsNullOrWhiteSpace($_.nom) })
    $officeData = @()
    $printerData = @()
    for ($i = 0; $i -lt $Delegacions.Count; $i++) {
        $d = $Delegacions[$i]
        $printers = @(Get-ImpressoresCompatibles -Delegacio $d -ModelPerDefecte $ModelPerDefecte -ModelRicoh $ModelRicoh | Where-Object { Test-AdrecaIP ([string]$_.IP) })
        $disabled = ($printers.Count -eq 0)
        $officeData += [pscustomobject]@{ index = $i; name = Get-NomCurt $d.nom; count = $printers.Count; disabled = $disabled }
        foreach ($p in $printers) {
            $printerData += [pscustomobject]@{ index = $printerData.Count; office = $i; name = $p.Nom; ip = $p.IP }
        }
    }
    $officesJson = (ConvertTo-Json -InputObject @($officeData) -Compress -Depth 4).Replace('</', '<\/')
    $printersJson = (ConvertTo-Json -InputObject @($printerData) -Compress -Depth 4).Replace('</', '<\/')
    $body = @'
<div class="top"><div class="brand">SEU  /  IMPRESSORES</div><div class="brand-sub">Configuració guiada</div></div>
<div class="content">
  <div id="steps" class="steps">01  OFICINES&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;02  IMPRESSORES&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;03  INSTAL·LACIÓ</div>
  <h1 id="title">Tria les oficines</h1>
  <p id="hint" class="hint">Selecciona una o més oficines per veure les seves impressores.</p>
  <section id="office-page">
    <div class="toolbar"><input id="office-search" type="text" placeholder="Cerca una oficina..."><button id="office-all" class="secondary">Selecciona-ho tot</button></div>
    <div id="office-list" class="list"></div><div id="office-error" class="error"></div>
  </section>
  <section id="printer-page" class="hidden">
    <div class="toolbar"><input id="printer-search" type="text" placeholder="Cerca una impressora..."><button id="printer-all" class="secondary">Selecciona-ho tot</button></div>
    <div id="printer-list" class="list"></div><div id="printer-error" class="error"></div>
  </section>
  <div class="footer"><div id="summary" class="footer-left">0 oficines seleccionades</div><div class="footer-right"><button id="back" class="secondary hidden">Enrere</button><button id="next" class="primary" disabled>Continua</button></div></div>
</div>
'@
    $script = @'
var offices = __OFFICES__;
var printers = __PRINTERS__;
var selectedOffices = {};
var selectedPrinters = {};
var page = 1;
function el(id) { return document.getElementById(id); }
function clearError() { el("office-error").innerText = ""; el("printer-error").innerText = ""; }
function officeMatches(o, q) { return !q || o.name.toLowerCase().indexOf(q) >= 0; }
function renderOffices() {
  var q = el("office-search").value.toLowerCase(), html = "";
  var selectable = 0, allSelected = true;
  for (var k = 0; k < offices.length; k++) {
    if (!offices[k].disabled) {
      selectable++;
      if (!selectedOffices[offices[k].index]) allSelected = false;
    }
  }
  if (selectable === 0) allSelected = false;
  for (var i = 0; i < offices.length; i++) {
    var o = offices[i]; if (!officeMatches(o, q)) continue;
    if (o.disabled) {
      html += '<div class="row disabled"><label><input type="checkbox" disabled><span class="office-name">' + o.name + '</span><span class="muted">(sense IP configurada — contacta amb Informàtica)</span></label></div>';
    } else {
      html += '<div class="row"><label><input type="checkbox" data-office="' + o.index + '"' + (selectedOffices[o.index] ? " checked" : "") + '><span class="office-name">' + o.name + '</span><span class="muted">(' + o.count + ' impressores)</span></label></div>';
    }
  }
  el("office-list").innerHTML = html || '<div class="row"><span class="muted">No s’han trobat oficines.</span></div>';
  var boxes = el("office-list").getElementsByTagName("input");
  for (var j = 0; j < boxes.length; j++) boxes[j].onclick = officeChanged;
  el("next").disabled = countKeys(selectedOffices) === 0;
  el("summary").innerText = countKeys(selectedOffices) + " oficines seleccionades";
  el("office-all").innerText = allSelected ? "Desselecciona-ho tot" : "Selecciona-ho tot";
}
function officeChanged() {
  var officeIndex = parseInt(this.getAttribute("data-office"), 10);
  if (offices[officeIndex].disabled) { this.checked = false; return; }
  selectedOffices[this.getAttribute("data-office")] = this.checked;
  if (!this.checked) delete selectedOffices[this.getAttribute("data-office")];
  renderOffices();
}
function renderPrinters() {
  var q = el("printer-search").value.toLowerCase(), html = "", last = -1;
  for (var i = 0; i < printers.length; i++) {
    var p = printers[i]; if (!selectedOffices[p.office]) continue;
    var hay = (p.name + " " + p.ip).toLowerCase(); if (q && hay.indexOf(q) < 0) continue;
    if (p.office !== last) { html += '<div class="office-header">' + offices[p.office].name + '</div>'; last = p.office; }
    html += '<div class="row printer-row"><label><input type="checkbox" data-printer="' + p.index + '"' + (selectedPrinters[p.index] ? " checked" : "") + '><span class="printer-name">' + p.name + '</span><span class="printer-ip">' + p.ip + '</span></label></div>';
  }
  el("printer-list").innerHTML = html || '<div class="row"><span class="muted">No hi ha impressores compatibles.</span></div>';
  var boxes = el("printer-list").getElementsByTagName("input");
  for (var j = 0; j < boxes.length; j++) boxes[j].onclick = printerChanged;
  el("summary").innerText = countKeys(selectedPrinters) + " impressores seleccionades";
}
function printerChanged() {
  selectedPrinters[this.getAttribute("data-printer")] = this.checked;
  if (!this.checked) delete selectedPrinters[this.getAttribute("data-printer")];
  el("summary").innerText = countKeys(selectedPrinters) + " impressores seleccionades";
}
function countKeys(o) { var n = 0; for (var k in o) if (o.hasOwnProperty(k)) n++; return n; }
function indexes(o) { var a = []; for (var k in o) if (o.hasOwnProperty(k)) a.push(k); return a.join(","); }
el("office-search").onkeyup = renderOffices;
el("printer-search").onkeyup = renderPrinters;
el("office-all").onclick = function() {
  var selectableCount = 0;
  for (var i = 0; i < offices.length; i++) if (!offices[i].disabled) selectableCount++;
  var allSelected = countKeys(selectedOffices) === selectableCount;
  selectedOffices = {};
  if (!allSelected) {
    for (var i = 0; i < offices.length; i++) if (!offices[i].disabled) selectedOffices[offices[i].index] = true;
  }
  renderOffices();
};
el("printer-all").onclick = function() { for (var i = 0; i < printers.length; i++) if (selectedOffices[printers[i].office]) selectedPrinters[printers[i].index] = true; renderPrinters(); };
el("back").onclick = function() {
  page = 1; el("office-page").className = ""; el("printer-page").className = "hidden"; el("back").className = "secondary hidden";
  el("next").innerText = "Continua"; el("title").innerText = "Tria les oficines"; el("hint").innerText = "Selecciona una o més oficines per veure les seves impressores."; el("steps").innerHTML = "01  OFICINES&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;02  IMPRESSORES&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;03  INSTAL·LACIÓ"; renderOffices();
};
el("next").onclick = function() {
  clearError();
  if (page === 1) {
    if (countKeys(selectedOffices) === 0) { el("office-error").innerText = "Selecciona almenys una oficina."; return; }
    for (var i = 0; i < printers.length; i++) if (selectedOffices[printers[i].office]) selectedPrinters[printers[i].index] = true;
    page = 2; el("office-page").className = "hidden"; el("printer-page").className = ""; el("back").className = "secondary"; el("next").innerText = "Inicia la instal·lació"; el("title").innerText = "Tria les impressores"; el("hint").innerText = "Les impressores estan agrupades per oficina. Pots desmarcar les que no vulguis instal·lar."; el("steps").innerHTML = "01  OFICINES&nbsp;&nbsp; · &nbsp;&nbsp;02  IMPRESSORES&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;03  INSTAL·LACIÓ"; renderPrinters();
  } else {
    if (countKeys(selectedPrinters) === 0) { el("printer-error").innerText = "Selecciona almenys una impressora."; return; }
    window.location.href = "app://done?offices=" + indexes(selectedOffices) + "&printers=" + indexes(selectedPrinters);
  }
};
renderOffices();
'@
    $script = $script.Replace('__OFFICES__', $officesJson).Replace('__PRINTERS__', $printersJson)
    $html = Get-HtmlShell -Body $body -Script $script
    $state = @{ Done = $false; Offices = @(); Printers = @() }
    $navigate = {
        param($url, $form)
        $uri = [uri]$url
        if ($uri.Host -ne 'done') { return }
        $query = @{}
        foreach ($part in $uri.Query.TrimStart('?').Split('&')) {
            if ($part -match '^([^=]+)=(.*)$') { $query[$matches[1]] = [uri]::UnescapeDataString($matches[2]) }
        }
        $state.Done = $true
        $state.Offices = @($query['offices'] -split ',' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ })
        $state.Printers = @($query['printers'] -split ',' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ })
        $form.Close()
    }
    Show-HtmlForm -Html $html -Width 900 -Height 720 -State $state -OnNavigate $navigate
    if (-not $state.Done) { return }
    $selectedOfficeIndexes = @($state.Offices)
    foreach ($officeIndex in $selectedOfficeIndexes) {
        $d = $Delegacions[$officeIndex]
        $selectedNames = @($printerData | Where-Object { $_.office -eq $officeIndex -and $state.Printers -contains $_.index } | ForEach-Object { $_.name })
        $d | Add-Member -NotePropertyName impressoresSeleccionades -NotePropertyValue $selectedNames -Force
    }
    return @($Delegacions | Where-Object { $selectedOfficeIndexes -contains [array]::IndexOf($Delegacions, $_) })
}

function Show-InstallacioHtml {
    param(
        [System.Diagnostics.Process]$Proces,
        [string]$FitxerRegistre,
        [long]$PosicioInicial,
        [object[]]$Delegacions,
        [string]$ModelPerDefecte,
        [string]$ModelRicoh,
        [switch]$Simulacio
    )
    $files = @()
    foreach ($d in $Delegacions) {
        foreach ($p in @(Get-ImpressoresCompatiblesSeleccionades -Delegacio $d -ModelPerDefecte $ModelPerDefecte -ModelRicoh $ModelRicoh | Where-Object { Test-AdrecaIP ([string]$_.IP) })) {
            $files += [pscustomobject]@{ Index = $files.Count; Delegacio = $d.nom; Oficina = Get-NomCurt $d.nom; Nom = $p.Nom; IP = $p.IP; Estat = 'pendent' }
        }
    }
    $groups = @($files | Group-Object Oficina | ForEach-Object {
        [pscustomobject]@{ name = $_.Name; printers = @($_.Group | ForEach-Object { [pscustomobject]@{ index = $_.Index; name = $_.Nom; ip = $_.IP } }) }
    })
    $groupsJson = (ConvertTo-Json -InputObject @($groups) -Compress -Depth 6).Replace('</', '<\/')
    $body = @'
<div class="top"><div class="brand">SEU  /  IMPRESSORES</div><div class="brand-sub">Instal·lació en curs</div></div>
<div class="content">
  <div class="steps">03  INSTAL·LACIÓ</div><h1 id="title">Instal·lant les impressores</h1>
  <p id="hint" class="hint">No tanquis aquesta finestra mentre es processen les impressores.</p>
  <div id="install-list" class="list install-list"></div><div id="summary" class="install-summary">Preparant la instal·lació...</div>
  <div class="footer"><div></div><button id="close" class="primary" disabled>Tanca</button></div>
</div>
'@
    $script = @'
var groups = __GROUPS__;
function render() {
  var html = "";
  for (var i = 0; i < groups.length; i++) {
    html += '<div class="install-group"><div class="install-office">' + groups[i].name + '</div>';
    for (var j = 0; j < groups[i].printers.length; j++) {
      var p = groups[i].printers[j];
      html += '<div class="install-row" id="printer-' + p.index + '"><span class="status" id="status-' + p.index + '">·</span><span>' + p.name + '</span><span class="printer-ip">' + p.ip + '</span></div>';
    }
    html += '</div>';
  }
  document.getElementById("install-list").innerHTML = html;
}
function setPrinterStatus(index, status) {
  var icon = document.getElementById("status-" + index), row = document.getElementById("printer-" + index);
  if (!icon) return;
  icon.className = "status";
  if (status === "installing") { icon.innerHTML = '<span class="spinner-ring"></span>'; }
  else if (status === "done") { icon.innerHTML = '<span class="check"></span>'; icon.className += " done"; }
  else if (status === "error") { icon.innerText = "!"; icon.className += " failed"; }
  else { icon.innerText = "·"; }
}
function setResult(title, message, success) {
  document.getElementById("title").innerText = title; document.getElementById("hint").innerText = message;
  document.getElementById("close").innerText = "Fet";
  document.getElementById("close").disabled = false;
  document.getElementById("summary").innerText = success ? "Instal·lació completada" : "Instal·lació finalitzada amb incidències";
}
document.getElementById("close").onclick = function() { window.location.href = "app://close"; };
render();
'@
    $html = Get-HtmlShell -Body $body -Script $script.Replace('__GROUPS__', $groupsJson)
    $state = @{ Posicio = $PosicioInicial; Text = ''; ExitVist = $false; Acabat = $false; Codi = $null; Correctes = 0; Errors = 0 }
    $navigate = {
        param($url, $form)
        if (([uri]$url).Host -eq 'close') { $form.Close() }
    }
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 250
    $timer.Add_Tick({
        $newText = ''
        try {
            $stream = [System.IO.File]::Open($FitxerRegistre, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            try {
                [void]$stream.Seek($state.Posicio, [System.IO.SeekOrigin]::Begin)
                $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
                $newText = $reader.ReadToEnd()
                $state.Posicio = $stream.Position
                $reader.Dispose()
            }
            finally { $stream.Dispose() }
        }
        catch { $newText = '' }
        if ($newText) {
            $state.Text += $newText
            foreach ($m in [regex]::Matches($newText, '=== (.+?) \(([^)]+)\) ===')) {
                $file = $files | Where-Object { $_.Nom -eq $m.Groups[1].Value -and $_.IP -eq $m.Groups[2].Value } | Select-Object -First 1
                if ($file) { $file.Estat = 'instal·lant'; [void]$browser.Document.InvokeScript('setPrinterStatus', @($file.Index, 'installing')) }
            }
            foreach ($m in [regex]::Matches($newText, "Impressora '(.+?)' correcta\.")) {
                $file = $files | Where-Object { $_.Nom -eq $m.Groups[1].Value } | Select-Object -First 1
                if ($file) { $file.Estat = 'correcte'; [void]$browser.Document.InvokeScript('setPrinterStatus', @($file.Index, 'done')) }
            }
            foreach ($m in [regex]::Matches($newText, "Impressora '(.+?)':")) {
                $file = $files | Where-Object { $_.Nom -eq $m.Groups[1].Value -and $_.Estat -ne 'correcte' } | Select-Object -First 1
                if ($file) { $file.Estat = 'error'; [void]$browser.Document.InvokeScript('setPrinterStatus', @($file.Index, 'error')) }
            }
        }
        if ($Proces.HasExited) {
            if ($state.ExitVist) {
                $timer.Stop(); $state.Acabat = $true; $state.Codi = $Proces.ExitCode
                $m = [regex]::Match($state.Text, 'Correctes: (\d+)'); if ($m.Success) { $state.Correctes = [int]$m.Groups[1].Value }
                $m = [regex]::Match($state.Text, 'Amb error: (\d+)'); if ($m.Success) { $state.Errors = [int]$m.Groups[1].Value }
                foreach ($file in $files | Where-Object { $_.Estat -eq 'pendent' -or $_.Estat -eq 'instal·lant' }) { [void]$browser.Document.InvokeScript('setPrinterStatus', @($file.Index, 'error')) }
                $suffix = if ($Simulacio) { ' (SIMULACIÓ: no s''ha canviat res)' } else { '' }
                $success = ($state.Errors -eq 0 -and $state.Codi -eq 0)
                $message = if ($success) { "Totes les impressores seleccionades s'han processat correctament.$suffix" } else { "Algunes impressores no s'han pogut instal·lar. Consulta el registre si cal.$suffix" }
                [void]$browser.Document.InvokeScript('setResult', @($(if ($success) { 'Fet!' } else { 'Instal·lació finalitzada amb incidències' }), $message, $success))
            }
            else { $state.ExitVist = $true }
        }
    })
    $browser = $null
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Instal·lació d'impressores"; $form.StartPosition = 'CenterScreen'; $form.ClientSize = New-Object System.Drawing.Size(900, 720)
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog; $form.MaximizeBox = $false
    Set-IconaFinestra -Finestra $form
    $browser = New-Object System.Windows.Forms.WebBrowser; $browser.Dock = [System.Windows.Forms.DockStyle]::Fill; $browser.ScriptErrorsSuppressed = $true
    $browser.AllowNavigation = $true
    $browser.Add_Navigating({
        param($sender, $e)
        if ($e.Url.Scheme -eq 'app') {
            $e.Cancel = $true
            if ($e.Url.Host -eq 'close') { $form.Close() }
        }
    })
    [void]$form.Controls.Add($browser); $browser.DocumentText = $html
    $form.Add_FormClosing({
        param($sender, $e)
        if (-not $state.Acabat) {
            $answer = [System.Windows.Forms.MessageBox]::Show("La instal·lació encara no ha acabat. Vols tancar la finestra igualment?", "Instal·lació d'impressores", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { $e.Cancel = $true }
        }
    })
    $timer.Start()
    [void]$form.ShowDialog()
    $timer.Stop(); $timer.Dispose(); $browser.Dispose(); $form.Dispose()
    return [pscustomobject]@{ Codi = $state.Codi; Correctes = $state.Correctes; Errors = $state.Errors }
}
