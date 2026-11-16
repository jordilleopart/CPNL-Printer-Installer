#Requires -Version 5.1
<#
  Instalar.ps1: aplicació per a l'usuari final. Mostra una finestra per triar una o més delegacions
  i instal·la totes les impressores SHARP de les delegacions triades, amb una finestra de progrés.
  Ús normal: la icona «Instal·la impressores SEU» (o el doble clic a INSTALAR_IMPRESSORES.bat).
  Demana permís d'administrador.
  Opcions per a proves i per a desplegaments:
    .\Instalar.ps1 -Simulacio                          (només mostra què faria, sense canviar res)
    .\Instalar.ps1 -Delegacio "eixample","corts"       (no obre la finestra de selecció)
    .\Instalar.ps1 -Delegacio "eixample" -SenseFinestres   (sense cap finestra; retorna codi 0 o 1)
  Opcions internes (les fa servir el mateix programa):
    -FitxerDelegacions  fitxer de text amb un nom de delegació per línia
    -FitxerRegistre     fitxer de registre on s'ha d'escriure
#>
param(
    # Textos amb el nom (o part del nom) de cada delegació; si no s'indiquen, es mostra la finestra de selecció
    [string[]]$Delegacio,
    # Fitxer JSON amb les delegacions i les impressores
    [string]$Fitxer = (Join-Path $PSScriptRoot '..\dades\impressores.json'),
    # Controlador que s'usa per a les impressores que no indiquen el model
    [string]$ModelPerDefecte = 'SHARP BP-70C31 PCL6',
    # Si s'indica, no es canvia res: només es mostra què es faria
    [switch]$Simulacio,
    # Si s'indica, no es mostra cap finestra (només la consola) i cal indicar -Delegacio; per a desplegaments automàtics
    [switch]$SenseFinestres,
    # (Intern) Fitxer de text amb un nom de delegació per línia; substitueix -Delegacio
    [string]$FitxerDelegacions,
    # (Intern) Fitxer de registre on s'ha d'escriure, en comptes de crear-ne un de nou
    [string]$FitxerRegistre
)

# Carrega les biblioteques que hi ha a la mateixa carpeta que aquest script
. (Join-Path $PSScriptRoot 'Registre.ps1')
. (Join-Path $PSScriptRoot 'Dades.ps1')
. (Join-Path $PSScriptRoot 'Motor.ps1')
. (Join-Path $PSScriptRoot 'Proces.ps1')
. (Join-Path $PSScriptRoot 'Finestra.ps1')

# Recorda si s'ha demanat el mode sense finestres (Show-Missatge ho consulta)
$script:SenseFinestres = [bool]$SenseFinestres

# Desa una llista de noms de delegació en un fitxer temporal (un per línia, UTF-8) i en retorna la ruta
function Export-NomsDelegacions {
    param([string[]]$Noms)
    $ruta = Join-Path $env:TEMP ('impressores_delegacions_{0}.txt' -f [guid]::NewGuid().ToString('N'))
    [System.IO.File]::WriteAllLines($ruta, $Noms, (New-Object System.Text.UTF8Encoding($false)))
    return $ruta
}

# Atura l'execució amb error en mode sense finestres (en mode normal, el codi continua amb el return de qui crida)
function Stop-AmbError {
    if ($SenseFinestres) { exit 1 }
}

# Si s'ha indicat un fitxer amb noms de delegació, els llegeix (i l'esborra, perquè només serveix una vegada)
if ($FitxerDelegacions) {
    if (-not (Test-Path -LiteralPath $FitxerDelegacions)) {
        Write-Host "ERROR: no es troba el fitxer de delegacions: $FitxerDelegacions" -ForegroundColor Red
        exit 1
    }
    $Delegacio = @(Get-Content -LiteralPath $FitxerDelegacions -Encoding UTF8 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    Remove-Item -LiteralPath $FitxerDelegacions -ErrorAction SilentlyContinue
}

# En mode sense finestres no es pot preguntar la delegació: cal indicar-la
if ($SenseFinestres -and -not $Delegacio) {
    Write-Host 'ERROR: amb -SenseFinestres cal indicar també -Delegacio.' -ForegroundColor Red
    exit 1
}

# Ruta completa del fitxer de dades (els altres PowerShell que s'obrin poden començar en una altra carpeta)
$fitxerComplet = if (Test-Path -LiteralPath $Fitxer) { (Resolve-Path -LiteralPath $Fitxer).Path } else { $Fitxer }

# Si no som administradors (i no és una simulació), torna a llançar aquest script amb permís d'administrador
if (-not $Simulacio -and -not (Test-Administrador)) {
    # Sense finestres no es pot demanar el permís: s'avisa i es surt amb error
    if ($SenseFinestres) {
        Write-Host 'ERROR: cal executar com a administrador.' -ForegroundColor Red
        exit 1
    }
    # Munta els paràmetres per al nou PowerShell
    $parametres = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Fitxer "{1}" -ModelPerDefecte "{2}"' -f $PSCommandPath, $fitxerComplet, $ModelPerDefecte
    if ($Delegacio) {
        # Els noms es passen en un fitxer, perquè poden tenir apòstrofs, guions llargs o comes
        $parametres += ' -FitxerDelegacions "{0}"' -f (Export-NomsDelegacions -Noms $Delegacio)
    }
    try {
        # Obre un PowerShell nou (amagat) i Windows demana el permís d'administrador
        Start-Process -FilePath 'powershell.exe' -ArgumentList $parametres -Verb RunAs -WindowStyle Hidden -ErrorAction Stop
    }
    catch {
        # L'usuari ha cancel·lat el permís o Windows l'ha denegat
        Show-Missatge -Icona Warning -Text "Per instal·lar impressores cal acceptar el permís d'administrador.`n`nTorna a obrir el programa i prem «Sí» quan Windows ho demani."
    }
    return
}

# Ruta completa de l'INF, calculada a partir de la carpeta d'aquest script
$inf = Join-Path $PSScriptRoot '..\controladors\SHARP_Driver\PCL6\64bit\su3emesp.inf'
# Converteix la ruta a absoluta si l'INF existeix
if (Test-Path -LiteralPath $inf) { $inf = (Resolve-Path -LiteralPath $inf).Path }

# Crea el registre (a la carpeta logs del projecte o, si no es pot escriure, a la carpeta temporal)
$carpetaLogs = Get-CarpetaLogs -Preferida (Join-Path $PSScriptRoot '..\logs')
Start-Registre -Carpeta $carpetaLogs -Simulacio:$Simulacio -Fitxer $FitxerRegistre

# Comprova que el controlador per defecte és un model conegut
$modelDefecte = Resolve-ModelSharp $ModelPerDefecte
if (-not $modelDefecte) {
    Write-Registre -Nivell ERROR -Text "El model per defecte '$ModelPerDefecte' no es reconeix (cal C31, M36 o C36)."
    Complete-Registre | Out-Null
    Show-Missatge -Icona Error -Text "Hi ha un error de configuració del programa.`n`nAvisa el servei informàtic i envia'ls aquest fitxer:`n$script:FitxerLog"
    Stop-AmbError
    return
}
# Avisa si l'INF no existeix (en una instal·lació real fallaria)
if (-not (Test-Path -LiteralPath $inf)) { Write-Registre -Nivell AVIS -Text "No es troba l'INF: $inf" }

# Llegeix el fitxer de delegacions
try {
    $delegacions = @(Import-Delegacions -Fitxer $Fitxer)
    Write-Registre -Nivell INFO -Text "Fitxer llegit: $Fitxer ($($delegacions.Count) delegacions)."
}
catch {
    Write-Registre -Nivell ERROR -Text $_.Exception.Message
    Complete-Registre | Out-Null
    Show-Missatge -Icona Error -Text "No s'ha pogut llegir el fitxer de dades.`n`n$($_.Exception.Message)`n`nAvisa el servei informàtic i envia'ls aquest fitxer:`n$script:FitxerLog"
    Stop-AmbError
    return
}

# Tria les delegacions: pel paràmetre -Delegacio o amb la finestra de selecció
$triades = @()
if ($Delegacio) {
    # Cada text ha de trobar exactament una delegació; si no, no s'instal·la res
    foreach ($text in $Delegacio) {
        $trobades = @(Find-Delegacio -Delegacions $delegacions -Text $text)
        if ($trobades.Count -ne 1) {
            Write-Registre -Nivell ERROR -Text "La cerca '$text' ha trobat $($trobades.Count) delegacions (cal exactament una)."
            Complete-Registre | Out-Null
            Show-Missatge -Icona Error -Text "La cerca '$text' ha trobat $($trobades.Count) delegacions, i en cal exactament una.`n`nNo s'ha instal·lat res."
            Stop-AmbError
            return
        }
        $triades += $trobades[0]
    }
    # Treu les delegacions repetides (si s'ha indicat dues vegades la mateixa)
    $triades = @($triades | Sort-Object { $_.nom } -Unique)
}
else {
    $triades = @(Show-SelectorDelegacions -Delegacions $delegacions -ModelPerDefecte $modelDefecte)
}
if ($triades.Count -eq 0) {
    Write-Registre -Nivell AVIS -Text "No s'ha triat cap delegació: no es fa res."
    Complete-Registre | Out-Null
    return
}
Write-Registre -Nivell INFO -Text "Delegacions triades: $($triades.Count)."

if (-not $SenseFinestres) {
    # MODE APLICACIÓ: la instal·lació la fa un procés fill (amagat) i aquesta finestra en mostra el progrés
    $totalImpressores = 0
    foreach ($triada in $triades) {
        $totalImpressores += @(Get-ImpressoresDelegacio -Delegacio $triada -Marca 'SHARP' -ModelPerDefecte $modelDefecte).Count
    }
    if ($totalImpressores -eq 0) {
        Write-Registre -Nivell AVIS -Text 'Les delegacions triades no tenen impressores SHARP.'
        Complete-Registre | Out-Null
        Show-Missatge -Icona Warning -Text 'Les delegacions triades no tenen impressores SHARP al fitxer de dades.'
        return
    }
    # Desa els noms triats en un fitxer perquè el procés fill els llegeixi
    $fitxerNoms = Export-NomsDelegacions -Noms @($triades | ForEach-Object { $_.nom })
    # Paràmetres del procés fill: aquest mateix script, en mode sense finestres i escrivint al mateix registre
    $parametresFill = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -SenseFinestres -Fitxer "{1}" -ModelPerDefecte "{2}" -FitxerDelegacions "{3}" -FitxerRegistre "{4}"' -f $PSCommandPath, $fitxerComplet, $ModelPerDefecte, $fitxerNoms, $script:FitxerLog
    if ($Simulacio) { $parametresFill += ' -Simulacio' }
    # El procés fill comença a llegir el registre just després del que ja s'ha escrit
    $posicioInicial = (Get-Item -LiteralPath $script:FitxerLog).Length
    $fill = Start-Process -FilePath 'powershell.exe' -ArgumentList $parametresFill -WindowStyle Hidden -PassThru
    # Accedir al Handle fa que Windows conservi el codi de sortida del procés
    $null = $fill.Handle
    # Mostra el progrés fins que el procés fill acaba (el resultat ja es veu a la mateixa finestra)
    [void](Show-Progres -Proces $fill -FitxerRegistre $script:FitxerLog -PosicioInicial $posicioInicial -TotalImpressores $totalImpressores -Simulacio:$Simulacio)
    return
}

# MODE SENSE FINESTRES (procés fill o desplegament): instal·la les impressores de cada delegació triada
foreach ($triada in $triades) {
    Install-Delegacio -Delegacio $triada -ModelDefecte $modelDefecte -Inf $inf
}

# Escriu el resum final i compta els resultats
$total = $script:Resultats.Count
$errors = [int](Complete-Registre)
$correctes = $total - $errors
$prefix = if ($Simulacio) { "SIMULACIÓ (no s'ha canviat res)`n`n" } else { '' }

# Llista dels noms curts de les delegacions triades (com a molt 8)
$noms = @($triades | ForEach-Object { '- ' + (Get-NomCurt $_.nom) })
$llistaNoms = ($noms | Select-Object -First 8) -join "`n"
if ($noms.Count -gt 8) { $llistaNoms += "`n... i $($noms.Count - 8) més" }

# Mostra el resultat per consola (en mode sense finestres, Show-Missatge escriu a la consola)
if ($total -eq 0) {
    Show-Missatge -Icona Warning -Text "${prefix}Les delegacions triades no tenen impressores SHARP al fitxer de dades."
}
elseif ($errors -eq 0) {
    Show-Missatge -Icona Information -Text "${prefix}Fet!`n`nImpressores instal·lades: $correctes`nDelegacions: $($triades.Count)`n$llistaNoms"
}
else {
    Show-Missatge -Icona Warning -Text "${prefix}Impressores instal·lades: $correctes de $total (n'han fallat $errors).`nDelegacions: $($triades.Count)`n$llistaNoms`n`nRegistre: $script:FitxerLog"
}

# Retorna un codi de sortida per al procés que l'ha cridat o per a les eines de desplegament (0 = correcte, 1 = hi ha errors)
exit $(if ($errors -gt 0) { 1 } else { 0 })
