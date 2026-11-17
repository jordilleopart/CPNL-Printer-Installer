#Requires -Version 5.1
<#
  Proces.ps1: passos comuns de la instal·lació d'una delegació.
  Necessita que Registre.ps1, Motor.ps1 i Dades.ps1 estiguin carregats abans.
  No s'executa sol: el carreguen els altres scripts amb ". .\Proces.ps1".
#>

# Retorna la carpeta on es poden escriure els registres: la preferida o, si no es pot escriure, la temporal
function Get-CarpetaLogs {
    param(
        # Carpeta que es vol fer servir normalment
        [string]$Preferida
    )
    try {
        # Crea la carpeta si no existeix
        if (-not (Test-Path -LiteralPath $Preferida)) {
            New-Item -ItemType Directory -Path $Preferida -ErrorAction Stop | Out-Null
        }
        # Prova d'escriure un fitxer petit per comprovar que es pot escriure a la carpeta
        $prova = Join-Path $Preferida ('.prova_{0}.tmp' -f [guid]::NewGuid().ToString('N'))
        Set-Content -LiteralPath $prova -Value 'x' -ErrorAction Stop
        Remove-Item -LiteralPath $prova -ErrorAction SilentlyContinue
        return $Preferida
    }
    catch {
        # Si no es pot escriure (per exemple, unitat de només lectura), usa la carpeta temporal
        return (Join-Path $env:TEMP 'ImpressoresSEU_logs')
    }
}

# Instal·la totes les impressores compatibles d'una delegació (cada resultat queda al registre)
function Install-Delegacio {
    param(
        # Delegació triada (un element de la llista llegida del JSON)
        $Delegacio,
        # Controlador que s'usa per a les impressores que no indiquen el model
        [string]$ModelDefecte,
        # Ruta completa del fitxer INF del controlador
        [string]$Inf,
        # Nom del controlador universal RICOH
        [string]$ModelRicoh,
        # Ruta completa de l'INF RICOH
        [string]$InfRicoh
    )
    Write-Registre -Nivell INFO -Text "Delegació triada: $($Delegacio.nom)"

    # Avisa dels problemes de les dades d'aquesta delegació
    foreach ($problema in @(Get-ProblemesDelegacio $Delegacio)) {
        Write-Registre -Nivell AVIS -Text "Dades: $problema"
    }

    $configuracions = @(
        [pscustomobject]@{ Marca = 'SHARP'; Model = $ModelDefecte; Inf = $Inf },
        [pscustomobject]@{ Marca = 'RICOH'; Model = $ModelRicoh; Inf = $InfRicoh },
        [pscustomobject]@{ Marca = 'HP'; Model = $script:ModelSensePaquet; Inf = '' },
        [pscustomobject]@{ Marca = 'EPSON'; Model = $script:ModelSensePaquet; Inf = '' },
        [pscustomobject]@{ Marca = 'LEXMARK'; Model = $script:ModelSensePaquet; Inf = '' }
    )
    $totalImpressores = 0
    foreach ($configuracio in $configuracions) {
        # Obté les impressores de la marca, ja amb el nom final i el controlador resolt
        $impressores = @(Get-ImpressoresDelegacio -Delegacio $Delegacio -Marca $configuracio.Marca -ModelPerDefecte $ModelDefecte -ModelRicoh $configuracio.Model)
        if ($Delegacio.PSObject.Properties.Name -contains 'impressoresSeleccionades') {
            $seleccionades = @($Delegacio.impressoresSeleccionades | ForEach-Object { [string]$_ })
            $impressores = @($impressores | Where-Object { $seleccionades -contains $_.Nom })
        }
        $totalImpressores += $impressores.Count

        # Instal·la cada impressora; si una falla, les altres continuen
        foreach ($i in $impressores) {
            if ($i.Error) {
                # Model no reconegut: no s'intenta instal·lar i es compta com a error
                Write-Registre -Nivell ERROR -Text "Impressora '$($i.Nom)': $($i.Error)"
                Add-Resultat -Nom $i.Nom -Estat ERROR -Detall $i.Error
                continue
            }
            # Si el model no venia al JSON, ho deixa escrit al registre
            if ($i.ModelOrigen -eq 'per defecte') {
                Write-Registre -Nivell INFO -Text "'$($i.Nom)': no indica model, s'usa el per defecte ($($i.Model))."
            }
            Invoke-Impressora -Nom $i.Nom -IP $i.IP -Model $i.Model -Inf $configuracio.Inf
        }
    }
    if ($totalImpressores -eq 0) {
        Write-Registre -Nivell AVIS -Text 'Aquesta delegació no té impressores SHARP, RICOH, HP, EPSON ni LEXMARK.'
    }
}
