#Requires -Version 5.1
<#
  Converteix-CsvAJson.ps1: converteix l'exportació de l'Excel (CSV amb ";") al fitxer JSON de delegacions.
  Només s'agafen les impressores SHARP. Cada impressora es forma amb la línia N de la columna IP
  i la línia N de la columna Model. Guarda una còpia del JSON anterior i escriu un informe amb
  tot el que ha exclòs o ha hagut de deduir, i amb les diferències respecte al JSON anterior.
  Ús:  .\Converteix-CsvAJson.ps1 -Csv "C:\ruta\exportacio.csv"
       .\Converteix-CsvAJson.ps1 -Csv "C:\ruta\exportacio.csv" -Sortida ".\proves\prova.json"
#>
param(
    # Fitxer CSV exportat de l'Excel (separador ";", UTF-8)
    [Parameter(Mandatory)][string]$Csv,
    # Fitxer JSON que es genera
    [string]$Sortida = (Join-Path $PSScriptRoot '..\dades\impressores.json')
)

# Carrega la biblioteca de dades (per validar IP i llegir el JSON anterior)
. (Join-Path $PSScriptRoot 'Dades.ps1')

# Posició de cada dada al CSV (la primera columna és la 0)
$colCodi = 1
$colNom = 2
$colPoblacio = 4
$colIP = 26
$colModel = 27

# Retorna el text sense espais sobrants (els espais repetits o estranys es converteixen en un de sol)
function Get-TextNet {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    return ([regex]::Replace($Text, '\s+', ' ')).Trim()
}

# Retorna les línies d'una cel·la (separades per salts de línia), cadascuna sense espais als extrems
function Get-LiniesCella {
    param([string]$Cella)
    if ([string]::IsNullOrEmpty($Cella)) { return @() }
    return @(($Cella -split '\r?\n') | ForEach-Object { $_.Trim() })
}

# Avisos agrupats per tipus, per escriure'ls a l'informe
$avisos = [ordered]@{}
function Add-Avis {
    param([string]$Tipus, [string]$Text)
    if (-not $avisos.Contains($Tipus)) { $avisos[$Tipus] = New-Object System.Collections.Generic.List[string] }
    $avisos[$Tipus].Add($Text)
}

# Comprova que el CSV existeix
if (-not (Test-Path -LiteralPath $Csv)) {
    Write-Host "ERROR: no es troba el fitxer $Csv" -ForegroundColor Red
    return
}

# Llegeix el CSV amb noms de columna genèrics (c0, c1, c2...) i descarta la primera fila (la capçalera)
$nomsColumnes = 0..80 | ForEach-Object { "c$_" }
$files = @(Import-Csv -LiteralPath $Csv -Delimiter ';' -Encoding UTF8 -Header $nomsColumnes | Select-Object -Skip 1)
Write-Host "Files de dades llegides: $($files.Count)"

# Construeix la llista de delegacions amb impressores SHARP
$delegacions = New-Object System.Collections.Generic.List[object]
for ($n = 0; $n -lt $files.Count; $n++) {
    $f = $files[$n]
    $fila = $n + 2
    $nom = Get-NomDelegacioEstandard -Nom (Get-TextNet $f.("c$colNom")) -Poblacio (Get-TextNet $f.("c$colPoblacio"))
    # Les files sense nom de delegació s'ignoren
    if ($nom -eq '') { continue }
    $ips = @(Get-LiniesCella $f.("c$colIP"))
    $models = @(Get-LiniesCella $f.("c$colModel"))
    $impressores = New-Object System.Collections.Generic.List[object]
    # La línia N de les IP es correspon amb la línia N dels models
    $total = [Math]::Min($ips.Count, $models.Count)
    for ($k = 0; $k -lt $total; $k++) {
        $model = $models[$k]
        # Només s'agafen les impressores SHARP
        if ($model.ToUpperInvariant() -notmatch 'SHARP') { continue }
        $lloc = "fila $fila, impressora $($k + 1)"
        # Extreu l'adreça IP de la cel·la (a vegades hi ha text davant)
        $coincidencia = [regex]::Match($ips[$k], '\b(\d{1,3}(?:\.\d{1,3}){3})\b')
        if (-not $coincidencia.Success) {
            Add-Avis 'EXCLOSA (no té IP)' "$nom [$lloc]: IP='$($ips[$k])', model='$model'"
            continue
        }
        $ip = $coincidencia.Groups[1].Value
        if (-not (Test-AdrecaIP $ip)) {
            Add-Avis 'EXCLOSA (IP no vàlida)' "$nom [$lloc]: IP='$($ips[$k])'"
            continue
        }
        if ($ips[$k] -ne $ip) {
            Add-Avis "IP extreta d'una cel·la amb text addicional" "$nom [$lloc]: cel·la='$($ips[$k])' -> IP $ip"
        }
        # Identifica el model (C31, M36 o C36) dins del text
        $majuscules = $model.ToUpperInvariant().Replace('BP70-', 'BP-70')
        $codiModel = [regex]::Match($majuscules, '70\s*-?\s*(C31|M36|C36)')
        $p = [ordered]@{ marca = 'SHARP' }
        if ($codiModel.Success) {
            $p['model'] = $codiModel.Groups[1].Value
        }
        elseif ($majuscules -match 'BP-?\s*[A-Z]?\d{2,}[A-Z0-9]*') {
            # Té un model concret que no és als models admesos: necessita un altre controlador
            Add-Avis "EXCLOSA (model no admès: cal afegir-lo a Dades.ps1 o usar un altre controlador)" "$nom [$lloc]: model='$model', IP $ip"
            continue
        }
        else {
            Add-Avis "Sense model identificable: s'usarà el controlador per defecte (C31)" "$nom [$lloc]: model='$model', IP $ip"
        }
        $p['ip'] = $ip
        $impressores.Add($p)
    }
    # Només es guarden les delegacions que tenen alguna impressora SHARP
    if ($impressores.Count -gt 0) {
        $codi = Get-TextNet $f.("c$colCodi")
        if ($codi -eq '') { Add-Avis 'Delegació sense codi SEU' "$nom [fila $fila]" }
        $delegacions.Add([ordered]@{
            codi        = $codi
            nom         = $nom
            poblacio    = (Get-TextNet $f.("c$colPoblacio"))
            impressores = $impressores.ToArray()
        })
    }
}

# Avisa de noms de delegació repetits i d'IP repetides
foreach ($g in @($delegacions | Group-Object { $_.nom } | Where-Object { $_.Count -gt 1 })) {
    Add-Avis 'Nom de delegació repetit' $g.Name
}
$totesIP = @($delegacions | ForEach-Object { $nomDel = $_.nom; $_.impressores | ForEach-Object { [pscustomobject]@{ IP = $_.ip; Nom = $nomDel } } })
foreach ($g in @($totesIP | Group-Object IP | Where-Object { $_.Count -gt 1 })) {
    Add-Avis 'IP repetida' ("$($g.Name): " + (($g.Group | ForEach-Object { $_.Nom }) -join ' | '))
}

# Rutes completes de la sortida i de l'informe
$rutaSortida = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Sortida)
$rutaInforme = Join-Path (Split-Path $rutaSortida) 'informe-conversio.txt'
$rutaCopia = Join-Path (Split-Path $rutaSortida) 'impressores.anterior.json'
if (-not (Test-Path -LiteralPath (Split-Path $rutaSortida))) { New-Item -ItemType Directory -Path (Split-Path $rutaSortida) | Out-Null }

# Llegeix el JSON anterior (si n'hi ha) per poder explicar què ha canviat, i en fa una còpia
$anterior = @()
if (Test-Path -LiteralPath $rutaSortida) {
    try { $anterior = @(Import-Delegacions -Fitxer $rutaSortida) } catch { $anterior = @() }
    Copy-Item -LiteralPath $rutaSortida -Destination $rutaCopia -Force
}

# Escriu el JSON en UTF-8 sense BOM (ConvertTo-Json escriu l'apòstrof com \u0027: es torna a convertir)
$json = ([ordered]@{ versio = 1; delegacions = $delegacions.ToArray() } | ConvertTo-Json -Depth 6)
$json = $json.Replace('\u0027', "'")
[System.IO.File]::WriteAllText($rutaSortida, $json, (New-Object System.Text.UTF8Encoding($false)))

# Compta les impressores i els models per a l'informe
$totalImpressores = 0
$perModel = @{}
foreach ($d in $delegacions) {
    foreach ($i in $d.impressores) {
        $totalImpressores++
        $clau = if ($i.Contains('model')) { $i['model'] } else { '(per defecte)' }
        $perModel[$clau] = 1 + [int]$perModel[$clau]
    }
}

# Escriu l'informe
$linies = New-Object System.Collections.Generic.List[string]
$linies.Add('INFORME DE LA CONVERSIÓ CSV -> JSON')
$linies.Add("Delegacions amb impressores SHARP: $($delegacions.Count). Impressores SHARP: $totalImpressores.")
$linies.Add('Models: ' + ((($perModel.Keys | Sort-Object) | ForEach-Object { "$_ : $($perModel[$_])" }) -join ', '))
$linies.Add('')
foreach ($tipus in $avisos.Keys) {
    $linies.Add("## $tipus ($($avisos[$tipus].Count))")
    foreach ($text in $avisos[$tipus]) { $linies.Add("  - $text") }
    $linies.Add('')
}
if ($anterior.Count -gt 0) {
    # Compara cada delegació amb l'anterior pel nom, mirant les IP
    $mapaAnt = @{}
    foreach ($d in $anterior) { $mapaAnt[$d.nom] = ((@($d.impressores | ForEach-Object { $_.ip }) | Sort-Object) -join ',') }
    $mapaNou = @{}
    foreach ($d in $delegacions) { $mapaNou[$d.nom] = ((@($d.impressores | ForEach-Object { $_.ip }) | Sort-Object) -join ',') }
    $afegides = @($mapaNou.Keys | Where-Object { -not $mapaAnt.ContainsKey($_) } | Sort-Object)
    $eliminades = @($mapaAnt.Keys | Where-Object { -not $mapaNou.ContainsKey($_) } | Sort-Object)
    $canviades = @($mapaNou.Keys | Where-Object { $mapaAnt.ContainsKey($_) -and $mapaAnt[$_] -ne $mapaNou[$_] } | Sort-Object)
    $linies.Add("## Comparació amb el JSON anterior ($($anterior.Count) delegacions)")
    $linies.Add("  Delegacions afegides ($($afegides.Count)):")
    foreach ($x in $afegides) { $linies.Add("    + $x") }
    $linies.Add("  Delegacions que ja no hi són ($($eliminades.Count)):")
    foreach ($x in $eliminades) { $linies.Add("    - $x") }
    $linies.Add("  Delegacions amb IP diferents ($($canviades.Count)):")
    foreach ($x in $canviades) { $linies.Add("    ~ $x : abans $($mapaAnt[$x]) -> ara $($mapaNou[$x])") }
    $linies.Add("  (còpia del JSON anterior: $rutaCopia)")
}
Set-Content -LiteralPath $rutaInforme -Value $linies -Encoding UTF8

# Resum per pantalla
Write-Host "JSON escrit: $rutaSortida" -ForegroundColor Green
Write-Host "Delegacions: $($delegacions.Count). Impressores SHARP: $totalImpressores."
foreach ($tipus in $avisos.Keys) { Write-Host "  $tipus : $($avisos[$tipus].Count)" -ForegroundColor Yellow }
Write-Host "Informe complet: $rutaInforme"
