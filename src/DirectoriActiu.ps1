#Requires -Version 5.1
<#
  DirectoriActiu.ps1: obté el perfil de l'usuari iniciat a un Active Directory local
  mitjançant ADsI/LDAP i els camps que poden indicar la seva delegació.
  No s'executa sol: el carreguen els altres scripts amb ". .\DirectoriActiu.ps1".
#>

$script:ErrorAD = ''

function ConvertTo-EscapeLdapFilter {
    param([string]$Text)
    $textEscaped = $Text.Replace('\', '\5c').Replace('*', '\2a').Replace('(', '\28').Replace(')', '\29').Replace([char]0, '\00')
    return $textEscaped
}

function Get-FirstADProperty {
    param($Properties,[string]$Name)
    if ($null -eq $Properties) { return '' }
    if ($Properties.Contains($Name) -and $Properties[$Name].Count -gt 0) {
        return [string]$Properties[$Name][0]
    }
    return ''
}

# Retorna el perfil AD de l'usuari actual, o $null si no es pot consultar el domini.
function Get-PerfilAD {
    param([string]$Usuari)
    $script:ErrorAD = ''
    if ([string]::IsNullOrWhiteSpace($Usuari)) { $Usuari = $env:USERNAME }
    if ([string]::IsNullOrWhiteSpace($Usuari)) {
        $script:ErrorAD = "No s'ha pogut determinar el nom d'usuari de Windows."
        return $null
    }
    try {
        $rootDse = New-Object System.DirectoryServices.DirectoryEntry('LDAP://RootDSE')
        $baseDn = [string]$rootDse.Properties['defaultNamingContext'][0]
        if ([string]::IsNullOrWhiteSpace($baseDn)) { throw 'No s''ha rebut el context predeterminat del domini.' }

        $escapedUser = ConvertTo-EscapeLdapFilter -Text $Usuari
        $filtresUsuari = "(sAMAccountName=$escapedUser)"
        if (-not [string]::IsNullOrWhiteSpace([string]$env:USERDNSDOMAIN)) {
            $upn = ConvertTo-EscapeLdapFilter -Text ("$Usuari@$env:USERDNSDOMAIN")
            $filtresUsuari += "(userPrincipalName=$upn)"
        }

        $search = New-Object System.DirectoryServices.DirectorySearcher
        $search.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$baseDn")
        $search.Filter = "(&(objectCategory=person)(objectClass=user)(|($filtresUsuari)))"
        $search.SearchScope = [System.DirectoryServices.SearchScope]::Subtree
        $search.PageSize = 100
        foreach ($property in @(
            'displayName','sAMAccountName','userPrincipalName','mail',
            'physicalDeliveryOfficeName','department','company','l','streetAddress','description','title'
        )) {
            [void]$search.PropertiesToLoad.Add($property)
        }

        $result = $search.FindOne()
        if ($null -eq $result) {
            $script:ErrorAD = "No s'ha trobat l'usuari '$Usuari' al domini."
            return $null
        }
        $entry = $result.Properties
        return [pscustomobject]@{
            displayName                  = Get-FirstADProperty $entry 'displayName'
            sAMAccountName               = Get-FirstADProperty $entry 'sAMAccountName'
            userPrincipalName            = Get-FirstADProperty $entry 'userPrincipalName'
            mail                         = Get-FirstADProperty $entry 'mail'
            physicalDeliveryOfficeName   = Get-FirstADProperty $entry 'physicalDeliveryOfficeName'
            department                   = Get-FirstADProperty $entry 'department'
            company                      = Get-FirstADProperty $entry 'company'
            city                         = Get-FirstADProperty $entry 'l'
            streetAddress                = Get-FirstADProperty $entry 'streetAddress'
            description                  = Get-FirstADProperty $entry 'description'
            jobTitle                     = Get-FirstADProperty $entry 'title'
        }
    }
    catch {
        $script:ErrorAD = $_.Exception.Message
        return $null
    }
}

# Retorna les delegacions que coincideixen amb els camps de localitzacio de l'usuari AD.
function Get-SuggerimentsDelegacionsAD {
    param(
        [object[]]$Delegacions,
        $Perfil
    )
    if ($null -eq $Perfil) { return @() }

    $suggeriments = New-Object 'System.Collections.Generic.List[object]'
    $afegides = New-Object 'System.Collections.Generic.HashSet[string]'
    $camps = @(
        $Perfil.physicalDeliveryOfficeName,
        $Perfil.department,
        $Perfil.streetAddress,
        $Perfil.city,
        $Perfil.company,
        $Perfil.description
    )

    foreach ($camp in $camps) {
        if ([string]::IsNullOrWhiteSpace([string]$camp)) { continue }
        $text = ([string]$camp).Trim()
        if ($text.Length -lt 3) { continue }

        foreach ($delegacio in @($Delegacions)) {
            $nomCurt = Get-NomCurt $delegacio.nom
            $normalNom = Get-TextNormalitzat ([string]$delegacio.nom)
            $normalCurt = Get-TextNormalitzat ([string]$nomCurt)
            $normalCamp = Get-TextNormalitzat $text

            $coincidencia = $normalCamp -eq $normalNom -or
                            $normalCamp -eq $normalCurt -or
                            $normalNom.Contains($normalCamp) -or
                            $normalCurt.Contains($normalCamp)
            if ($coincidencia -and $afegides.Add([string]$delegacio.nom)) {
                $suggeriments.Add($delegacio)
            }
        }
    }
    return @($suggeriments)
}
