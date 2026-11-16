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

# Instal·la totes les impressores SHARP d'una delegació (cada resultat queda al registre)
function Install-Delegacio {
    param(
        # Delegació triada (un element de la llista llegida del JSON)
        $Delegacio,
        # Controlador que s'usa per a les impressores que no indiquen el model
        [string]$ModelDefecte,
        # Ruta completa del fitxer INF del controlador
        [string]$Inf
    )
    Write-Registre -Nivell INFO -Text "Delegació triada: $($Delegacio.nom)"

    # Avisa dels problemes de les dades d'aquesta delegació
    foreach ($problema in @(Get-ProblemesDelegacio $Delegacio)) {
        Write-Registre -Nivell AVIS -Text "Dades: $problema"
    }

    # Obté les impressores SHARP d'aquesta delegació, ja amb el nom final
    $impressores = @(Get-ImpressoresDelegacio -Delegacio $Delegacio -Marca 'SHARP' -ModelPerDefecte $ModelDefecte)
    if ($impressores.Count -eq 0) {
        Write-Registre -Nivell AVIS -Text 'Aquesta delegació no té impressores SHARP.'
    }

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
        Invoke-Impressora -Nom $i.Nom -IP $i.IP -Model $i.Model -Inf $Inf
    }
}
