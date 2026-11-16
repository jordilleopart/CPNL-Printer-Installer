#Requires -Version 5.1
<#
  Dades.ps1: llegeix el fitxer JSON de delegacions, valida les dades,
  busca una delegació pel nom i construeix el nom de les impressores.
  No s'executa sol: el carreguen els altres scripts amb ". .\Dades.ps1".
  Nota: les funcions que retornen llistes es poden cridar com @(Funcio ...)
  perquè el resultat sigui sempre una llista, encara que estigui buida.
#>

# Models SHARP coneguts: abreviatura -> nom exacte del controlador a l'INF
$script:ModelsSharp = @{
    'C31' = 'SHARP BP-70C31 PCL6'
    'M36' = 'SHARP BP-70M36 PCL6'
    'C36' = 'SHARP BP-70C36 PCL6'
}

# Retorna el text en majúscules i sense accents, per comparar noms sense errors
function Get-TextNormalitzat {
    param([string]$Text)
    # Si no hi ha text, retorna un text buit
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    # Separa cada lletra accentuada en la lletra base i l'accent
    $descomposat = $Text.Normalize([System.Text.NormalizationForm]::FormD)
    # Elimina els accents (són caràcters de tipus "marca", Mn)
    $senseAccents = [regex]::Replace($descomposat, '\p{Mn}', '')
    # Passa a majúscules i substitueix els espais repetits per un de sol
    $majuscules = [regex]::Replace($senseAccents.ToUpperInvariant(), '\s+', ' ')
    return $majuscules.Trim()
}

# Retorna el nom d'una delegació amb el format "CNL [ubicació] - [oficina/servei]"
function Get-NomDelegacioEstandard {
    param(
        [string]$Nom,
        [string]$Poblacio
    )
    if ([string]::IsNullOrWhiteSpace($Nom)) { return '' }

    $text = [regex]::Replace($Nom.Trim(), '\s+', ' ')
    $text = $text.Replace([char]0x2013, '-').Replace([char]0x2014, '-')
    $text = [regex]::Replace($text, '\s+-\s+', ' - ')
    $text = [regex]::Replace($text, '\.\s+', ' - ')
    $text = [regex]::Replace($text, '^\s*CONSORCI PER (LA )?NORMALITZACIO LINGUISTICA\s*-\s*', '', 'IgnoreCase')
    $text = [regex]::Replace($text, '^\s*CNL\s+', '', 'IgnoreCase')
    $text = [regex]::Replace($text, '^\s*(DE|DEL|D'')\s+', '', 'IgnoreCase')
    $text = [regex]::Replace($text, '^\s*DELEGACI[ÓO]\s+(DE\s+)?', '', 'IgnoreCase')
    $text = [regex]::Replace($text, '^\s*DELAGACIO\s+', '', 'IgnoreCase')
    $text = [regex]::Replace($text, '\s+-\s+DELEGACI[ÓO]\s+(DE\s+)?', ' - ', 'IgnoreCase')
    $text = [regex]::Replace($text, '\s+-\s+DELAGACIO\s+', ' - ', 'IgnoreCase')
    $text = $text.Trim(' ', '-')

    $parts = @($text -split '\s+-\s+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($parts.Count -gt 1 -and $parts[0] -match '^Barcelona$') {
        $ubicacio = $parts[0]
        $oficina = ($parts[1..($parts.Count - 1)] -join ' - ')
        $text = "$ubicacio - $oficina"
    }
    elseif ($Poblacio -eq 'Barcelona' -and $Nom -notmatch 'Barcelona') {
        $text = "Barcelona - $text"
    }

    $text = [regex]::Replace($text, '\s+-\s+', ' - ')
    return ("CNL " + $text.Trim()).ToUpperInvariant()
}

# Retorna $true si el text és una adreça IPv4 vàlida (quatre blocs entre 0 i 255)
function Test-AdrecaIP {
    param([string]$IP)
    $adreca = $null
    # Primer comprova el format (quatre blocs de xifres) i després que cada bloc sigui vàlid
    return (($IP -match '^\d{1,3}(\.\d{1,3}){3}$') -and [System.Net.IPAddress]::TryParse($IP, [ref]$adreca))
}

# Converteix "C31", "BP-70C31" o "SHARP BP-70C31 PCL6" al nom exacte del controlador; retorna $null si no el reconeix
function Resolve-ModelSharp {
    param([string]$Text)
    # Prepara el text (majúscules, sense accents ni espais sobrants)
    $clau = Get-TextNormalitzat $Text
    # Compara amb cada model conegut: abreviatura, abreviatura amb BP-70 o nom complet
    foreach ($m in $script:ModelsSharp.GetEnumerator()) {
        if ($clau -eq $m.Key -or $clau -eq "BP-70$($m.Key)" -or $clau -eq (Get-TextNormalitzat $m.Value)) {
            return $m.Value
        }
    }
    # Si no coincideix amb cap, retorna res
    return $null
}

# Llegeix el fitxer JSON i retorna la llista de delegacions
function Import-Delegacions {
    param(
        # Ruta del fitxer JSON
        [string]$Fitxer
    )
    # Comprova que el fitxer existeix
    if (-not (Test-Path $Fitxer)) { throw "No es troba el fitxer de dades: $Fitxer" }
    # Llegeix tot el fitxer com a UTF-8 (amb o sense BOM)
    $text = [System.IO.File]::ReadAllText((Resolve-Path $Fitxer).Path, [System.Text.Encoding]::UTF8)
    # Converteix el text JSON en objectes; si el JSON té errors de sintaxi, ho explica
    try {
        $dades = ConvertFrom-Json -InputObject $text
    }
    catch {
        throw "El fitxer JSON no és vàlid: $($_.Exception.Message)"
    }
    # Comprova que existeix la llista principal
    if ($null -eq $dades.delegacions) { throw "El fitxer JSON no té la llista 'delegacions'." }
    foreach ($delegacio in @($dades.delegacions)) {
        $delegacio.nom = Get-NomDelegacioEstandard -Nom $delegacio.nom -Poblacio $delegacio.poblacio
    }
    return @($dades.delegacions)
}

# Retorna la llista d'impressores d'una delegació (buida si no en té)
function Get-LlistaImpressores {
    param($Delegacio)
    # Si la propietat no existeix o és nul·la, retorna una llista buida
    if ($null -eq $Delegacio.impressores) { return @() }
    return @($Delegacio.impressores)
}

# Retorna una llista amb els problemes que té una delegació (buida si tot és correcte)
function Get-ProblemesDelegacio {
    param($Delegacio)
    $problemes = New-Object System.Collections.Generic.List[string]
    # La delegació ha de tenir nom
    if ([string]::IsNullOrWhiteSpace($Delegacio.nom)) { $problemes.Add('La delegació no té nom.') }
    # Revisa cada impressora de la delegació
    $llista = @(Get-LlistaImpressores $Delegacio)
    for ($i = 0; $i -lt $llista.Count; $i++) {
        $p = $llista[$i]
        # Número d'ordre (comença a 1) per poder identificar la impressora en el missatge
        $n = $i + 1
        if ([string]::IsNullOrWhiteSpace($p.marca)) { $problemes.Add("Impressora ${n}: la marca és buida.") }
        # El model és opcional (s'usa el per defecte), però si n'hi ha un de SHARP ha de ser conegut
        if (-not [string]::IsNullOrWhiteSpace($p.model) -and $p.marca -eq 'SHARP' -and -not (Resolve-ModelSharp $p.model)) {
            $problemes.Add("Impressora ${n}: el model '$($p.model)' no es reconeix (cal C31, M36 o C36).")
        }
        if ([string]::IsNullOrWhiteSpace($p.ip)) {
            $problemes.Add("Impressora ${n}: la IP és buida.")
        }
        elseif (-not (Test-AdrecaIP $p.ip)) {
            $problemes.Add("Impressora ${n}: la IP '$($p.ip)' no és vàlida.")
        }
    }
    return $problemes.ToArray()
}

# Busca delegacions pel nom: primer coincidència exacta, i si no n'hi ha, per paraules
function Find-Delegacio {
    param(
        # Llista de delegacions on buscar
        [object[]]$Delegacions,
        # Text que ha escrit o triat la persona
        [string]$Text
    )
    # Prepara el text buscat (majúscules, sense accents)
    $buscat = Get-TextNormalitzat $Text
    # Si no hi ha text, no hi ha cap resultat
    if ($buscat -eq '') { return @() }
    # 1) Coincidència exacta del nom complet
    $exactes = @($Delegacions | Where-Object { (Get-TextNormalitzat $_.nom) -eq $buscat })
    if ($exactes.Count -gt 0) { return $exactes }
    # 2) Si no n'hi ha, busca les delegacions que contenen TOTES les paraules escrites
    $paraules = $buscat -split ' '
    return @($Delegacions | Where-Object {
        $nomNormalitzat = Get-TextNormalitzat $_.nom
        $totesPresents = $true
        foreach ($paraula in $paraules) {
            if (-not $nomNormalitzat.Contains($paraula)) { $totesPresents = $false; break }
        }
        $totesPresents
    })
}

# Construeix el nom final: "<MODEL> - <DELEGACIÓ>" i, si Numero és més gran que 0, hi afegeix " <Numero>"
function Get-NomImpressora {
    param([string]$Model, [string]$NomDelegacio, [int]$Numero = 0)
    # Munta el nom base amb el model i el nom de la delegació
    $nom = "$Model - $NomDelegacio"
    # Si hi ha número d'ordre, l'afegeix al final
    if ($Numero -gt 0) { $nom = "$nom $Numero" }
    # Windows no admet la barra invertida en un nom d'impressora: es canvia per un guió
    return $nom.Replace('\', '-').Trim()
}

# Retorna les impressores d'una marca d'una delegació, ja amb el nom final i el controlador resolt
function Get-ImpressoresDelegacio {
    param(
        # Delegació (un element de la llista llegida del JSON)
        $Delegacio,
        # Marca a instal·lar (ara només SHARP)
        [string]$Marca = 'SHARP',
        # Controlador que s'usa quan una impressora SHARP no indica el model
        [string]$ModelPerDefecte = 'SHARP BP-70C31 PCL6'
    )
    # Es queda només amb les impressores d'aquesta marca (sense distingir majúscules)
    $seleccionades = @(Get-LlistaImpressores $Delegacio | Where-Object { $_.marca -eq $Marca })
    $total = $seleccionades.Count
    $resultat = @()
    for ($i = 0; $i -lt $total; $i++) {
        $p = $seleccionades[$i]
        # Només es numera si la delegació té més d'una impressora d'aquesta marca
        $numero = if ($total -gt 1) { $i + 1 } else { 0 }
        # Per defecte, el model és el que diu el JSON, i no hi ha cap error
        $model = $p.model
        $origen = 'JSON'
        $errorModel = ''
        if ($Marca -eq 'SHARP') {
            if ([string]::IsNullOrWhiteSpace($p.model)) {
                # Sense model al JSON: s'usa el per defecte
                $model = $ModelPerDefecte
                $origen = 'per defecte'
            }
            else {
                # Amb model: es converteix al nom exacte del controlador
                $resolt = Resolve-ModelSharp $p.model
                if ($resolt) { $model = $resolt }
                else { $errorModel = "El model '$($p.model)' no es reconeix (cal C31, M36 o C36)." }
            }
        }
        $resultat += [pscustomobject]@{
            Nom         = Get-NomImpressora -Model $model -NomDelegacio $Delegacio.nom -Numero $numero
            IP          = $p.ip
            Model       = $model
            Marca       = $p.marca
            ModelOrigen = $origen
            Error       = $errorModel
        }
    }
    return $resultat
}
