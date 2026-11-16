#Requires -Version 5.1
<#
  Comprova.ps1: revisa si aquest ordinador i les dades estan a punt per instal·lar impressores.
  No instal·la ni elimina res (com a molt, crea la carpeta logs si no existeix).
  Es pot executar sense drets d'administrador.
  Ús:  .\Comprova.ps1
#>
param(
    # Fitxer JSON amb les delegacions i les impressores
    [string]$Fitxer = (Join-Path $PSScriptRoot '..\dades\impressores.json')
)

# Carrega les biblioteques que hi ha a la mateixa carpeta que aquest script
. (Join-Path $PSScriptRoot 'Dades.ps1')
. (Join-Path $PSScriptRoot 'Motor.ps1')
. (Join-Path $PSScriptRoot 'Proces.ps1')

# Comptadors d'avisos i d'errors trobats
$script:Avisos = 0
$script:Errors = 0

# Escriu el resultat d'una comprovació amb color i l'apunta als comptadors
function Write-Comprovacio {
    param(
        # Resultat: OK, INFO, AVIS o ERROR
        [ValidateSet('OK', 'INFO', 'AVIS', 'ERROR')][string]$Estat,
        # Text de la comprovació
        [string]$Text
    )
    $color = switch ($Estat) {
        'OK'    { 'Green' }
        'AVIS'  { 'Yellow' }
        'ERROR' { 'Red' }
        default { 'Gray' }
    }
    if ($Estat -eq 'AVIS') { $script:Avisos++ }
    if ($Estat -eq 'ERROR') { $script:Errors++ }
    Write-Host ('[{0}] {1}' -f $Estat.PadRight(5), $Text) -ForegroundColor $color
}

Write-Host "--- Ordinador ---" -ForegroundColor Cyan

# Versió de PowerShell
if ($PSVersionTable.PSVersion -ge [version]'5.1') { Write-Comprovacio OK "PowerShell $($PSVersionTable.PSVersion)." }
else { Write-Comprovacio AVIS "PowerShell $($PSVersionTable.PSVersion): es recomana la 5.1 o superior." }

# Versió de Windows
try { Write-Comprovacio INFO ("Sistema: " + (Get-CimInstance Win32_OperatingSystem).Caption) }
catch { Write-Comprovacio INFO "No s'ha pogut llegir la versió de Windows." }

# Drets d'administrador (només informatiu: l'eina el demana sola)
if (Test-Administrador) { Write-Comprovacio INFO 'Aquest PowerShell té drets d''administrador.' }
else { Write-Comprovacio INFO 'Aquest PowerShell no té drets d''administrador (l''eina els demanarà en instal·lar).' }

# Ordres d'impressió que necessita l'eina
foreach ($ordre in 'Add-Printer', 'Add-PrinterPort', 'Add-PrinterDriver', 'Get-PrinterDriver', 'Remove-Printer', 'pnputil.exe') {
    if (Get-Command $ordre -ErrorAction SilentlyContinue) { Write-Comprovacio OK "Ordre disponible: $ordre" }
    else { Write-Comprovacio ERROR "Falta l'ordre: $ordre" }
}

# Servei d'impressió de Windows
$servei = Get-Service -Name Spooler -ErrorAction SilentlyContinue
if ($servei -and $servei.Status -eq 'Running') { Write-Comprovacio OK "El servei d'impressió (Spooler) està en marxa." }
else { Write-Comprovacio ERROR "El servei d'impressió (Spooler) no està en marxa." }

Write-Host "`n--- Ubicació de l'eina ---" -ForegroundColor Cyan

# Carpeta de l'eina: no ha de ser una carpeta de xarxa ni una unitat de xarxa
$arrel = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$esXarxa = $arrel.StartsWith('\\')
if (-not $esXarxa) {
    try { $esXarxa = ([System.IO.DriveInfo]$arrel.Substring(0, 1)).DriveType -eq 'Network' } catch { $esXarxa = $false }
}
if ($esXarxa) { Write-Comprovacio AVIS "L'eina és en una ubicació de xarxa ($arrel). Copia-la a un disc local: amb permís d'administrador, les unitats de xarxa no es veuen." }
else { Write-Comprovacio OK "L'eina és en un disc local: $arrel" }

# Fitxers bloquejats per haver-se baixat d'internet o d'un correu (marca "Zone.Identifier")
$bloquejats = @(Get-ChildItem -LiteralPath $arrel -Recurse -File -Include *.ps1, *.bat, *.json -ErrorAction SilentlyContinue |
    Where-Object { $null -ne (Get-Item -LiteralPath $_.FullName -Stream Zone.Identifier -ErrorAction SilentlyContinue) })
if ($bloquejats.Count -gt 0) { Write-Comprovacio AVIS "$($bloquejats.Count) fitxers estan bloquejats. Solució: Get-ChildItem -Recurse '$arrel' | Unblock-File" }
else { Write-Comprovacio OK 'Cap fitxer bloquejat.' }

# Carpeta de registres: s'ha de poder escriure
$logsPreferida = Join-Path $PSScriptRoot '..\logs'
$logsReal = Get-CarpetaLogs -Preferida $logsPreferida
if ($logsReal -eq $logsPreferida) { Write-Comprovacio OK 'Es pot escriure a la carpeta logs.' }
else { Write-Comprovacio AVIS "No es pot escriure a la carpeta logs; els registres aniran a $logsReal" }

Write-Host "`n--- Controlador ---" -ForegroundColor Cyan

# El fitxer INF ha d'existir i declarar els models que fem servir
$inf = Join-Path $PSScriptRoot '..\controladors\SHARP_Driver\PCL6\64bit\su3emesp.inf'
if (Test-Path -LiteralPath $inf) {
    Write-Comprovacio OK 'Fitxer INF trobat.'
    foreach ($nomModel in ($script:ModelsSharp.Values | Sort-Object)) {
        # Busca el nom del model dins de l'INF
        if (Select-String -LiteralPath $inf -Pattern $nomModel -SimpleMatch -Quiet) { Write-Comprovacio OK "L'INF declara '$nomModel'." }
        else { Write-Comprovacio ERROR "L'INF no declara '$nomModel'." }
        # Mostra si Windows ja té el controlador
        if (Get-PrinterDriver -Name $nomModel -ErrorAction SilentlyContinue) { Write-Comprovacio INFO "Windows ja té el controlador '$nomModel'." }
        else { Write-Comprovacio INFO "Windows encara no té el controlador '$nomModel' (s'instal·larà quan calgui)." }
    }
}
else {
    Write-Comprovacio ERROR "No es troba l'INF: $inf"
}

Write-Host "`n--- Dades ---" -ForegroundColor Cyan

# Llegeix el fitxer de delegacions
try {
    $delegacions = @(Import-Delegacions -Fitxer $Fitxer)
    Write-Comprovacio OK "Fitxer llegit: $($delegacions.Count) delegacions."
}
catch {
    Write-Comprovacio ERROR $_.Exception.Message
    Write-Host "`nHi ha $($script:Errors) errors i $($script:Avisos) avisos." -ForegroundColor Red
    return
}

# Delegacions amb noms repetits (no es podrien distingir a la cerca)
$repetits = @($delegacions | Group-Object nom | Where-Object { $_.Count -gt 1 })
if ($repetits.Count -eq 0) { Write-Comprovacio OK 'Cap nom de delegació repetit.' }
foreach ($g in $repetits) { Write-Comprovacio AVIS "Nom de delegació repetit: '$($g.Name)'" }

# Problemes de les dades de cada delegació (IP no vàlida, model desconegut, etc.)
$ambProblemes = 0
foreach ($d in $delegacions) {
    foreach ($problema in @(Get-ProblemesDelegacio $d)) {
        $ambProblemes++
        Write-Comprovacio AVIS "$($d.nom): $problema"
    }
}
if ($ambProblemes -eq 0) { Write-Comprovacio OK 'Cap problema a les dades de les delegacions.' }

# Recompte d'impressores SHARP per model i delegacions sense impressores
$sense = 0
$perModel = @{}
$errorsModel = 0
foreach ($d in $delegacions) {
    $imp = @(Get-ImpressoresDelegacio -Delegacio $d -Marca 'SHARP')
    if ($imp.Count -eq 0) { $sense++ }
    foreach ($i in $imp) {
        if ($i.Error) { $errorsModel++ }
        else { $perModel[$i.Model] = 1 + [int]$perModel[$i.Model] }
    }
}
foreach ($m in ($perModel.Keys | Sort-Object)) { Write-Comprovacio INFO "Impressores $m : $($perModel[$m])" }
if ($errorsModel -gt 0) { Write-Comprovacio ERROR "$errorsModel impressores tenen un model desconegut." }
if ($sense -gt 0) { Write-Comprovacio INFO "Delegacions sense impressores SHARP: $sense (no sortiran per triar)." }

# Resum final
Write-Host ''
if ($script:Errors -gt 0) { Write-Host "Hi ha $($script:Errors) errors i $($script:Avisos) avisos." -ForegroundColor Red }
elseif ($script:Avisos -gt 0) { Write-Host "Cap error, però hi ha $($script:Avisos) avisos." -ForegroundColor Yellow }
else { Write-Host 'Tot correcte.' -ForegroundColor Green }
