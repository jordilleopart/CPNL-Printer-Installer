#Requires -Version 5.1
<#
  ProvaAD.ps1: comprova la lectura del perfil Active Directory de l'usuari actual.
  No desa res i no modifica el sistema.
#>
param([string]$Usuari)

. (Join-Path $PSScriptRoot '..\src\DirectoriActiu.ps1')

if ([string]::IsNullOrWhiteSpace($Usuari)) { $Usuari = $env:USERNAME }
$perfil = Get-PerfilAD -Usuari $Usuari
if ($null -eq $perfil) {
    Write-Host "ERROR: $script:ErrorAD" -ForegroundColor Red
    exit 1
}

Write-Host "`nUsuari Active Directory:" -ForegroundColor Green
foreach ($camp in 'displayName','sAMAccountName','userPrincipalName','mail','physicalDeliveryOfficeName','department','company','city','streetAddress','description','jobTitle') {
    Write-Host ('  {0,-28} {1}' -f $camp, $perfil.$camp)
}
