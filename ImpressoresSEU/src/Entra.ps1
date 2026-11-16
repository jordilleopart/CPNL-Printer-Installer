#Requires -Version 5.1
<#
  Entra.ps1: obté el perfil de la persona que ha iniciat sessió (nom, correu, oficina...) a Microsoft Entra ID
  amb Microsoft Graph, per poder preseleccionar la seva delegació.
  Inicia la sessió pel navegador amb el flux "codi d'autorització amb PKCE": el programa no coneix mai la
  contrasenya ni porta cap secret, i només demana el permís User.Read (llegir el perfil de la mateixa persona).
  No desa mai el testimoni (token) ni cap contrasenya.
  No s'executa sol: el carreguen els altres scripts amb ". .\Entra.ps1".
#>

# Últim missatge d'error d'Entra (per mostrar-lo al registre o a la prova)
$script:ErrorEntra = ''

# Retorna els bytes en Base64 "segur per a adreces web" (sense +, / ni =), com demana el flux PKCE
function ConvertTo-Base64Url {
    param([byte[]]$Bytes)
    return [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

# Fa una petició web i retorna el JSON de la resposta ja convertit en objectes
# (Windows PowerShell 5.1 no llegeix sol els accents de les respostes de Microsoft, per això es llegeix com a UTF-8)
function Invoke-PeticioJson {
    param(
        # Adreça web de la petició
        [string]$Url,
        # Mètode HTTP: GET o POST
        [string]$Metode = 'GET',
        # Dades del formulari (només per a POST)
        $Cos = $null,
        # Capçaleres addicionals (per exemple, Authorization)
        [hashtable]$Capcaleres = @{}
    )
    $parametres = @{ Uri = $Url; Method = $Metode; Headers = $Capcaleres; UseBasicParsing = $true; ErrorAction = 'Stop' }
    if ($null -ne $Cos) {
        $parametres['Body'] = $Cos
        $parametres['ContentType'] = 'application/x-www-form-urlencoded'
    }
    try {
        $resposta = Invoke-WebRequest @parametres
        $text = [System.Text.Encoding]::UTF8.GetString($resposta.RawContentStream.ToArray())
        return ($text | ConvertFrom-Json)
    }
    catch {
        # Si el servidor ha respost amb un error, intenta llegir-ne el detall
        $detall = $_.Exception.Message
        if ($_.Exception.Response) {
            try {
                $lector = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream(), [System.Text.Encoding]::UTF8)
                $detall = $lector.ReadToEnd()
            }
            catch {
                # Si no es pot llegir el detall, es deixa el missatge general
            }
        }
        throw $detall
    }
}

# Retorna l'adreça d'usuari (UPN) de la sessió de Windows, o un text buit si no es pot saber
function Get-UpnActual {
    try {
        $sortida = (& whoami.exe /upn 2>$null) | Select-Object -First 1
        if ($sortida -match '^[^@\s]+@[^@\s]+$') { return $sortida.Trim() }
    }
    catch {
        # Si whoami falla, simplement no hi ha suggeriment d'usuari
    }
    return ''
}

# Llegeix la configuració d'Entra (tenantId i clientId); retorna $null si falta o és buida
function Get-ConfigEntra {
    param(
        # Fitxer JSON amb tenantId i clientId
        [string]$Fitxer
    )
    if (-not (Test-Path -LiteralPath $Fitxer)) { return $null }
    try {
        $text = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Fitxer).Path, [System.Text.Encoding]::UTF8)
        $config = ConvertFrom-Json -InputObject $text
        if ([string]::IsNullOrWhiteSpace($config.tenantId) -or [string]::IsNullOrWhiteSpace($config.clientId)) { return $null }
        return $config
    }
    catch {
        return $null
    }
}

# Fa iniciar sessió pel navegador i retorna el perfil de la persona (o $null si falla; el motiu queda a $script:ErrorEntra)
function Get-PerfilEntra {
    param(
        # Identificador del directori (tenant) de l'empresa
        [Parameter(Mandatory)][string]$TenantId,
        # Identificador de l'aplicació registrada a Entra
        [Parameter(Mandatory)][string]$ClientId,
        # Temps màxim (en segons) perquè la persona acabi l'inici de sessió al navegador
        [int]$EsperaSegons = 120,
        # Adreça d'usuari (UPN) que se suggereix al navegador
        [string]$PistaUsuari = ''
    )
    $script:ErrorEntra = ''
    $oient = $null
    try {
        # Windows PowerShell 5.1 necessita activar TLS 1.2 per parlar amb Microsoft
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        # PKCE: un secret aleatori d'un sol ús (verificador) i la seva empremta SHA-256 (repte)
        $generador = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $octets = New-Object byte[] 32
        $generador.GetBytes($octets)
        $verificador = ConvertTo-Base64Url $octets
        $repte = ConvertTo-Base64Url ([System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::ASCII.GetBytes($verificador)))
        # "state": text aleatori per comprovar que la resposta del navegador és de la nostra petició
        $octetsEstat = New-Object byte[] 16
        $generador.GetBytes($octetsEstat)
        $estat = ConvertTo-Base64Url $octetsEstat

        # Obre un port local lliure per rebre la resposta del navegador (prova fins a 10 ports a l'atzar)
        $port = 0
        for ($intent = 0; $intent -lt 10 -and $null -eq $oient; $intent++) {
            $port = Get-Random -Minimum 49152 -Maximum 65535
            $prova = New-Object System.Net.HttpListener
            $prova.Prefixes.Add("http://localhost:$port/")
            try {
                $prova.Start()
                $oient = $prova
            }
            catch {
                $prova.Close()
            }
        }
        if ($null -eq $oient) { throw "No s'ha pogut obrir un port local per rebre la resposta del navegador." }
        $redireccio = "http://localhost:$port"

        # Munta l'adreça d'inici de sessió de Microsoft i l'obre al navegador predeterminat
        $consulta = @(
            ('client_id=' + [uri]::EscapeDataString($ClientId)),
            'response_type=code',
            ('redirect_uri=' + [uri]::EscapeDataString($redireccio)),
            'response_mode=query',
            ('scope=' + [uri]::EscapeDataString('User.Read')),
            ('state=' + $estat),
            ('code_challenge=' + $repte),
            'code_challenge_method=S256'
        )
        if ($PistaUsuari) { $consulta += ('login_hint=' + [uri]::EscapeDataString($PistaUsuari)) }
        Start-Process ("https://login.microsoftonline.com/$TenantId/oauth2/v2.0/authorize?" + ($consulta -join '&'))

        # Espera que el navegador torni a l'adreça local amb el resultat
        $espera = $oient.BeginGetContext($null, $null)
        if (-not $espera.AsyncWaitHandle.WaitOne($EsperaSegons * 1000)) { throw "L'inici de sessió no s'ha completat a temps." }
        $peticio = $oient.EndGetContext($espera)
        $rebut = $peticio.Request.QueryString

        # Respon al navegador amb una pàgina senzilla perquè la persona sàpiga que pot tancar la pestanya
        $html = '<html><head><meta charset="utf-8"><title>Instal·lació d''impressores</title></head><body style="font-family:Segoe UI,sans-serif"><h2>Fet</h2><p>Ja pots tancar aquesta pestanya i tornar a l''aplicació.</p></body></html>'
        $octetsHtml = [System.Text.Encoding]::UTF8.GetBytes($html)
        $peticio.Response.ContentType = 'text/html; charset=utf-8'
        $peticio.Response.ContentLength64 = $octetsHtml.Length
        $peticio.Response.OutputStream.Write($octetsHtml, 0, $octetsHtml.Length)
        $peticio.Response.OutputStream.Close()

        # Comprova el resultat del navegador
        if ($rebut['error']) { throw ('Microsoft ha respost amb un error: ' + $rebut['error'] + ' - ' + $rebut['error_description']) }
        if ($rebut['state'] -ne $estat) { throw 'La resposta del navegador no correspon a la nostra petició.' }
        $codi = $rebut['code']
        if (-not $codi) { throw "No s'ha rebut cap codi d'autorització." }

        # Canvia el codi per un testimoni d'accés (es fa servir només en aquesta funció i no es desa enlloc)
        $cosToken = @{
            client_id     = $ClientId
            scope         = 'User.Read'
            code          = $codi
            redirect_uri  = $redireccio
            grant_type    = 'authorization_code'
            code_verifier = $verificador
        }
        $token = Invoke-PeticioJson -Url "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Metode POST -Cos $cosToken

        # Llegeix el perfil de la persona que ha iniciat sessió
        $camps = 'displayName,userPrincipalName,mail,officeLocation,department,companyName,city,jobTitle'
        $perfil = Invoke-PeticioJson -Url ('https://graph.microsoft.com/v1.0/me?$select=' + $camps) -Capcaleres @{ Authorization = ('Bearer ' + $token.access_token) }
        return $perfil
    }
    catch {
        $script:ErrorEntra = $_.Exception.Message
        return $null
    }
    finally {
        # Tanca el port local
        if ($null -ne $oient) { $oient.Close() }
    }
}