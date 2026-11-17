#Requires -Version 5.1
<#
  Motor.ps1: instal·la impressores (controlador, port i cua d'impressió).
  Necessita que Registre.ps1 i Dades.ps1 estiguin carregats abans.
  No s'executa sol: el carreguen els altres scripts amb ". .\Motor.ps1".
#>

# Recorda quins controladors ja hem tractat en aquesta execució (nom -> $true/$false)
$script:ControladorsTractats = @{}

# Retorna $true si l'script s'executa amb drets d'administrador
function Test-Administrador {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Instal·la un controlador només una vegada per execució
function Install-Controlador {
    param(
        # Nom del model tal com el declara l'INF
        [string]$Model,
        # Ruta completa del fitxer INF
        [string]$Inf
    )
    # HP, EPSON i LEXMARK utilitzen el controlador IPP integrat de Windows i no necessiten cap INF.
    if ([string]::IsNullOrWhiteSpace($Inf)) {
        Write-Registre -Nivell INFO -Text "S'usa el controlador integrat de Windows '$Model'."
        $script:ControladorsTractats[$Model] = $true
        return
    }
    # Si ja l'hem tractat abans, no repetim la feina
    if ($script:ControladorsTractats.ContainsKey($Model)) {
        # Si la vegada anterior va fallar, tornem a donar l'error sense reintentar
        if (-not $script:ControladorsTractats[$Model]) {
            throw "El controlador '$Model' ja ha fallat abans en aquesta execució."
        }
        return
    }
    try {
        if (Get-PrinterDriver -Name $Model -ErrorAction SilentlyContinue) {
            # Windows ja té el controlador: no cal fer res
            Write-Registre -Nivell INFO -Text "Controlador '$Model' ja instal·lat: s'omet."
        }
        else {
            Write-Registre -Nivell INFO -Text "Instal·lant controlador '$Model'..."
            if (-not $script:Simulacio) {
                # Comprova que el fitxer INF existeix
                if (-not (Test-Path $Inf)) { throw "No es troba l'INF: $Inf" }
                # Copia el paquet del controlador a l'emmagatzematge de Windows
                & pnputil.exe /add-driver $Inf /install | Out-Null
                # 0 = correcte, 3010 = correcte però demana reiniciar; qualsevol altre és un avís
                if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) {
                    Write-Registre -Nivell AVIS -Text "pnputil ha retornat el codi $LASTEXITCODE."
                }
                # Registra el model concret; si no existeix a l'INF, aquí és on falla
                Add-PrinterDriver -Name $Model -ErrorAction Stop
            }
        }
        # Apunta que aquest controlador ja està tractat i ha anat bé
        $script:ControladorsTractats[$Model] = $true
    }
    catch {
        # Apunta que ha fallat i passa l'error al qui ha cridat la funció
        $script:ControladorsTractats[$Model] = $false
        throw
    }
}

# Fa tot el procés d'UNA impressora; si alguna cosa falla, llança un error
function Install-Impressora {
    param(
        # Nom final de la impressora
        [string]$Nom,
        # Adreça IP de la impressora
        [string]$IP,
        # Nom del model (controlador)
        [string]$Model,
        # Ruta completa de l'INF
        [string]$Inf
    )
    # Valida que hi ha nom i model
    if ([string]::IsNullOrWhiteSpace($Nom))   { throw 'El nom de la impressora és buit.' }
    if ([string]::IsNullOrWhiteSpace($Model)) { throw 'El model és buit.' }
    # Valida l'IP amb la funció de Dades.ps1 (quatre blocs de xifres entre 0 i 255)
    if (-not (Test-AdrecaIP $IP)) { throw "IP no vàlida: '$IP'" }
    # Nom del port TCP/IP
    $nomPort = "IP_$IP"

    # PAS 1: controlador (només una vegada per model)
    Install-Controlador -Model $Model -Inf $Inf

    # PAS 2: si la impressora ja existeix, s'elimina (només aquest nom exacte)
    if (Get-Printer -Name $Nom -ErrorAction SilentlyContinue) {
        Write-Registre -Nivell INFO -Text "La impressora '$Nom' ja existeix: s'elimina."
        if (-not $script:Simulacio) { Remove-Printer -Name $Nom -ErrorAction Stop }
    }

    # PAS 3: port TCP/IP (RAW, 9100 per defecte), només si no existeix
    if (Get-PrinterPort -Name $nomPort -ErrorAction SilentlyContinue) {
        Write-Registre -Nivell INFO -Text "El port '$nomPort' ja existeix: s'omet."
    }
    else {
        Write-Registre -Nivell INFO -Text "Creant el port '$nomPort'..."
        if (-not $script:Simulacio) { Add-PrinterPort -Name $nomPort -PrinterHostAddress $IP -ErrorAction Stop }
    }

    # PAS 4: crea la impressora unint controlador i port
    Write-Registre -Nivell INFO -Text "Creant la impressora '$Nom'..."
    if (-not $script:Simulacio) { Add-Printer -Name $Nom -DriverName $Model -PortName $nomPort -ErrorAction Stop }
}

# Processa una impressora sense aturar res si falla: ho registra i continua
function Invoke-Impressora {
    param([string]$Nom, [string]$IP, [string]$Model, [string]$Inf)
    Write-Registre -Nivell INFO -Text "=== $Nom ($IP) ==="
    try {
        # Intenta instal·lar la impressora
        Install-Impressora -Nom $Nom -IP $IP -Model $Model -Inf $Inf
        # Si no ha saltat cap error, és correcte
        Write-Registre -Nivell OK -Text "Impressora '$Nom' correcta."
        Add-Resultat -Nom $Nom -Estat OK
    }
    catch {
        # Si ha fallat qualsevol pas, ho registra i deixa que la resta continuï
        Write-Registre -Nivell ERROR -Text "Impressora '$Nom': $($_.Exception.Message)"
        Add-Resultat -Nom $Nom -Estat ERROR -Detall $_.Exception.Message
    }
}
