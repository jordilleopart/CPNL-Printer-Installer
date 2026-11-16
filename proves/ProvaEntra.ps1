#Requires -Version 5.1
<#
  ProvaEntra.ps1: prova de l'inici de sessió a Microsoft Entra ID i de la lectura del perfil de la persona
  que fa la prova (nom, correu, oficina...). Només llegeix el perfil: no desa res i no canvia res.
  Ús:  .\ProvaEntra.ps1 -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -ClientId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
       (o ompliu dades\entra.json i executeu-lo sense paràmetres)
  Executeu-lo amb el vostre usuari normal, no des d'un PowerShell d'administrador.
#>
param(
    # Identificador del directori (tenant) de l'empresa
    [string]$TenantId,
    # Identificador de l'aplicació registrada a Entra
    [string]$ClientId
)

# Carrega la biblioteca d'Entra
. (Join-Path $PSScriptRoot '..\src\Entra.ps1')

# Si no s'han indicat, llegeix els identificadors de dades\entra.json
if (-not $TenantId -or -not $ClientId) {
    $config = Get-ConfigEntra -Fitxer (Join-Path $PSScriptRoot '..\dades\entra.json')
    if ($config) { $TenantId = $config.tenantId; $ClientId = $config.clientId }
}
if (-not $TenantId -or -not $ClientId) {
    Write-Host 'ERROR: falten TenantId i ClientId (indiqueu-los com a paràmetres o ompliu dades\entra.json).' -ForegroundColor Red
    return
}

Write-Host "S'obrirà el navegador per iniciar sessió. Quan acabi, torneu a aquesta finestra."
$perfil = Get-PerfilEntra -TenantId $TenantId -ClientId $ClientId -PistaUsuari (Get-UpnActual)
if (-not $perfil) {
    Write-Host "ERROR: $script:ErrorEntra" -ForegroundColor Red
    return
}

# Mostra els camps del perfil que podrien indicar la delegació
Write-Host "`nInici de sessió correcte. Dades del perfil:" -ForegroundColor Green
foreach ($camp in 'displayName', 'userPrincipalName', 'mail', 'officeLocation', 'department', 'companyName', 'city', 'jobTitle') {
    Write-Host ('  {0,-18} {1}' -f $camp, $perfil.$camp)
}