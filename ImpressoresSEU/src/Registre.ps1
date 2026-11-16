#Requires -Version 5.1
<#
  Registre.ps1: escriu missatges per pantalla i al fitxer de registre,
  i guarda el resultat de cada impressora per fer el resum final.
  No s'executa sol: el carreguen els altres scripts amb ". .\Registre.ps1".
#>

# Ruta del fitxer de registre actual (encara no n'hi ha cap)
$script:FitxerLog = $null
# Indica si estem en mode simulació (no es canvia res)
$script:Simulacio = $false
# Llista on guardem el resultat de cada impressora (nom, estat, detall)
$script:Resultats = New-Object System.Collections.Generic.List[object]
# Moment en què comença l'execució
$script:Inici = $null

# Escriu una línia amb data i hora, per pantalla (amb color) i al fitxer de registre
function Write-Registre {
    param(
        # Tipus de missatge: informació, correcte, avís o error
        [ValidateSet('INFO', 'OK', 'AVIS', 'ERROR')][string]$Nivell = 'INFO',
        # Text del missatge
        [string]$Text
    )
    # En mode simulació, afegeix un prefix perquè quedi clar que no és real
    $prefix = if ($script:Simulacio) { '[SIMULACIÓ] ' } else { '' }
    # Munta la línia completa: data i hora, nivell i text
    $linia = '{0} [{1}] {2}{3}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Nivell.PadRight(5), $prefix, $Text
    # Tria el color segons el nivell
    $color = switch ($Nivell) {
        'OK'    { 'Green' }
        'AVIS'  { 'Yellow' }
        'ERROR' { 'Red' }
        default { 'Gray' }
    }
    # Mostra la línia per pantalla
    Write-Host $linia -ForegroundColor $color
    # Si el fitxer de registre ja està creat, hi afegeix la mateixa línia
    if ($script:FitxerLog) {
        Add-Content -Path $script:FitxerLog -Value $linia -Encoding UTF8
    }
}

# Crea el fitxer de registre (un per execució) i escriu la capçalera
function Start-Registre {
    param(
        # Carpeta on es guarden els registres
        [string]$Carpeta,
        # Si s'indica, l'execució és una simulació
        [switch]$Simulacio,
        # Si s'indica, s'afegeix al fitxer de registre existent en comptes de crear-ne un de nou
        [string]$Fitxer
    )
    # Desa si és simulació i buida els resultats d'una execució anterior
    $script:Simulacio = [bool]$Simulacio
    $script:Resultats.Clear()
    $script:Inici = Get-Date
    # Crea la carpeta de registres si no existeix
    if (-not (Test-Path $Carpeta)) { New-Item -ItemType Directory -Path $Carpeta | Out-Null }
    # Si s'ha indicat un fitxer, s'usa; si no, el nom porta la data i l'hora i així mai se sobreescriu un registre
    if ($Fitxer) { $script:FitxerLog = $Fitxer }
    else { $script:FitxerLog = Join-Path $Carpeta ('registre_{0}.log' -f (Get-Date -Format 'yyyyMMdd_HHmmss')) }
    # Escriu la capçalera amb les dades de l'ordinador
    Write-Registre -Nivell INFO -Text "Inici de l'execució. Ordinador: $env:COMPUTERNAME. Usuari: $env:USERNAME."
    Write-Registre -Nivell INFO -Text "Versió de PowerShell: $($PSVersionTable.PSVersion)."
}

# Apunta el resultat d'una impressora per al resum final
function Add-Resultat {
    param(
        # Nom de la impressora
        [string]$Nom,
        # Resultat: OK o ERROR
        [ValidateSet('OK', 'ERROR')][string]$Estat,
        # Explicació breu (per exemple, el motiu de l'error)
        [string]$Detall = ''
    )
    # Afegeix un objecte amb les tres dades a la llista de resultats
    $script:Resultats.Add([pscustomobject]@{ Nom = $Nom; Estat = $Estat; Detall = $Detall })
}

# Escriu el resum final i retorna el nombre d'errors
function Complete-Registre {
    # Compta quantes impressores han anat bé i quantes han fallat
    $correctes = @($script:Resultats | Where-Object { $_.Estat -eq 'OK' }).Count
    $errors    = @($script:Resultats | Where-Object { $_.Estat -eq 'ERROR' }).Count
    # Calcula el temps que ha durat tot
    $durada = [int]((Get-Date) - $script:Inici).TotalSeconds
    # Escriu el resum
    Write-Registre -Nivell INFO -Text '----- RESUM -----'
    Write-Registre -Nivell INFO -Text "Impressores processades: $($script:Resultats.Count)"
    Write-Registre -Nivell OK   -Text "Correctes: $correctes"
    # Si hi ha errors, es marca en vermell; si no, en gris
    $nivellErrors = if ($errors -gt 0) { 'ERROR' } else { 'INFO' }
    Write-Registre -Nivell $nivellErrors -Text "Amb error: $errors"
    # Llista cada impressora que ha fallat amb el seu motiu
    foreach ($r in ($script:Resultats | Where-Object { $_.Estat -eq 'ERROR' })) {
        Write-Registre -Nivell ERROR -Text "  - $($r.Nom): $($r.Detall)"
    }
    Write-Registre -Nivell INFO -Text "Durada: $durada s. Registre: $script:FitxerLog"
    # Retorna el nombre d'errors per si el qui crida el vol fer servir
    return $errors
}
