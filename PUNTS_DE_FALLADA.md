# Punts de fallada probables i com diagnosticar-los

Primer pas sempre: executar `.\src\Comprova.ps1` i mirar el registre més recent de `logs\`.
Les proves que apareixen aquí només llegeixen, tret que es digui el contrari.

| # | Símptoma | Causa probable | Com es diagnostica | Solució |
|---|---|---|---|---|
| 1 | El `.bat` diu «No se puede ejecutar esta aplicación en el equipo» | El fitxer `.bat` és buit o s'ha copiat malament | `(Get-Item .\INSTALAR_IMPRESSORES.bat).Length` surt 0 | Tornar a copiar-lo (ha de fer unes poques centenars de bytes) |
| 2 | Un script diu «`'Start-Registre' no se reconoce`» (o una altra funció) | Un fitxer de `src\` és buit o té el contingut d'un altre | `Select-String -Path .\src\*.ps1 -Pattern '^function'` i comparar amb la taula del `LLEGEIX-ME.md` | Tornar a copiar el fitxer correcte |
| 3 | «La ejecución de scripts está deshabilitada» | Política d'execució | `Get-ExecutionPolicy -List` | Amb el `.bat` no passa. A mà: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`. Si `MachinePolicy` o `UserPolicy` mana (GPO), `Bypass` no s'imposa: cal que l'administrador del domini ho permeti o signar els scripts |
| 4 | No surt res / la finestra negra es tanca de seguida | S'ha cancel·lat el permís d'administrador o hi ha un error abans de la finestra | Executar `.\src\Instalar.ps1` des d'una consola per veure l'error | Acceptar el permís; corregir l'error que surti |
| 5 | Windows demana una contrasenya d'administrador i l'usuari no la té | Els usuaris no són administradors locals | Provar-ho amb un usuari estàndard | Desplegar-ho vosaltres (GPO, script d'inici...) amb `-Delegacio "..." -SenseFinestres`. **No s'ha provat** amb cap eina de desplegament |
| 6 | Avís de fitxers bloquejats a `Comprova.ps1` | ZIP baixat d'internet o d'un correu | `Comprova.ps1` ho avisa | `Get-ChildItem -Recurse C:\ImpressoresSEU \| Unblock-File` |
| 7 | No troba l'INF o fallen els fitxers en executar-ho des de la xarxa | L'eina és en una unitat de xarxa; amb permís d'administrador, les unitats de xarxa assignades no es veuen | `Comprova.ps1` ho avisa | Copiar l'eina a un disc local |
| 8 | `ERROR ... No es troba l'INF` | Falta `SHARP_Driver` o `RICOH` a `controladors\`, o l'INF SHARP és la versió en un altre idioma (`su3emcat.inf` en comptes de `su3emesp.inf`) | `Get-ChildItem .\controladors -Recurse -Filter *.inf` | Copiar les carpetes completes i comprovar `controladors\SHARP_Driver\PCL6\64bit\su3emesp.inf` i `controladors\RICOH\disk1\oemsetup.inf`. HP, EPSON i LEXMARK no necessiten INF propi |
| 9 | `AVIS pnputil ha retornat el codi N` | El paquet de controladors no s'ha pogut afegir | Mirar el codi al registre; `pnputil /enum-drivers` | Si després no hi ha `ERROR`, el controlador ja hi era. Si hi ha `ERROR`, comprovar que s'executa com a administrador i que l'INF és complet |
| 10 | `ERROR ... Add-PrinterDriver` per a un model | El nom del model no és exactament el de l'INF | `Comprova.ps1` indica si l'INF declara `C31`, `M36` i `C36` | Corregir la taula `$script:ModelsSharp` de `Dades.ps1` |
| 11 | `ERROR ... Add-Printer / Add-PrinterPort` | No és administrador o el servei d'impressió està aturat | `Comprova.ps1` mostra l'estat de Spooler | Executar com a administrador; `Start-Service Spooler` |
| 12 | `ERROR ... Remove-Printer` | La impressora té feines en cua o està en ús | `Get-PrintJob -PrinterName "<nom>"` | Cancel·lar les feines i repetir (és segur repetir-ho) |
| 13 | `AVIS Dades: ... IP no vàlida` / `model no es reconeix` | Dada errònia al JSON | Mirar els `AVIS Dades` del registre, o `Comprova.ps1` | Corregir `dades\impressores.json` (o el CSV i tornar-lo a convertir) |
| 14 | La impressora s'ha instal·lat però no imprimeix | La IP és errònia, la impressora és apagada o no hi ha xarxa/VPN | `Test-NetConnection <ip> -Port 9100` | Corregir la IP; comprovar xarxa |
| 15 | Surt la impressora amb el model equivocat (C31 en comptes de M36) | El JSON no indicava el model i s'ha fet servir el per defecte | El registre diu «no indica model, s'usa el per defecte» | Posar `"model": "M36"` al JSON i eliminar la impressora vella a mà (el nom inclou el model, vegeu `LLEGEIX-ME.md`) |
| 16 | S'han instal·lat les impressores d'una delegació equivocada | S'ha triat malament | El registre indica la delegació triada | `Get-Printer \| Where-Object Name -like '*NOM DE LA DELEGACIO*' \| Remove-Printer` (comproveu primer què selecciona sense el `Remove-Printer`) |
| 17 | Els accents es veuen malament als missatges | Un `.ps1` s'ha desat sense BOM | Obrir-lo a VS Code: la codificació ha de ser «UTF-8 with BOM» | Desar-lo com a UTF-8 amb BOM |
| 18 | No trobo el registre | No es podia escriure a `logs\` | `Comprova.ps1` ho avisa | Mirar `%TEMP%\ImpressoresSEU_logs` |
| 19 | Imprimeix però demana el codi personal cada vegada | Límit conegut: el codi no es desa (vegeu `LLEGEIX-ME.md`) | — | Configuració del SHARP o codi al primer ús |
| 20 | `Converteix-CsvAJson.ps1` dona menys impressores de les esperades | Files sense nom, línies d'IP i de model que no es corresponen, o models d'una altra marca | Llegir `informe-conversio.txt` | Corregir el CSV i repetir; no editeu el JSON a mà si podeu corregir l'Excel |
| 21 | La icona no fa res o no s'obre cap finestra | PowerShell va amagat i un error previ no es veu | Executar a mà: `powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\ImpressoresSEU\src\Instalar.ps1"` i mirar l'error i el registre | Corregir l'error que surti |
| 22 | Es veu un instant una finestra negra en obrir l'aplicació | PowerShell obre la consola un instant abans d'amagar-se | — | És normal; només es pot evitar amb un llançador compilat (vegeu `CONSTRUIR_INSTALADOR.md`) |
| 23 | La finestra de progrés no avança | El procés fill ha fallat o espera alguna cosa | Prémer «Mostra el registre»; `Get-Process powershell` | Esperar uns minuts; si no avança, mirar el registre |
| 24 | SmartScreen o l'antivirus bloqueja `Setup_ImpressoresSEU.exe` | L'instal·lador no està signat | Missatge de SmartScreen o de l'antivirus | Signar l'instal·lador amb un certificat de signatura de codi, o afegir una excepció |
| 25 | Les finestres no tenen la icona de l'aplicació | Falta `ImpressoresSEU.ico` a la carpeta de l'aplicació | `Test-Path "C:\Program Files\ImpressoresSEU\ImpressoresSEU.ico"` | Tornar a instal·lar |

## Si res d'això ajuda

Envieu aquests tres elements:

1. El fitxer `.log` més recent de `logs\`.
2. La sortida completa de `.\src\Comprova.ps1`.
3. El text exacte de l'error, o una captura de pantalla.
