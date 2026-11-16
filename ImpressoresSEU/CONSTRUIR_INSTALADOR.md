# Com crear l'aplicació instal·lable

Això es fa **una vegada a l'ordinador de l'administrador** (no als dels usuaris).
No s'ha pogut provar des d'aquí: no hi ha Windows ni Inno Setup. Proveu-ho en una màquina virtual.

## Què obtindreu

Un únic fitxer, `Setup_ImpressoresSEU.exe`. En executar-lo:

- Copia l'eina a `C:\Program Files\ImpressoresSEU` (els usuaris estàndard no la poden modificar).
- Crea la icona **«Instal·la impressores SEU»** al menú Inici i, si es deixa marcat, a l'escriptori.
- Crea la desinstal·lació a «Aplicacions instal·lades» del Windows.

L'usuari només fa clic a la icona: s'obre la finestra per triar la delegació, i després una finestra de progrés. No hi ha cap finestra negra ni cap carpeta.

## Passos

1. Instal·leu **Inno Setup 6.3 o superior** (gratuït, `jrsoftware.org`) a l'ordinador on construireu l'instal·lador.
2. Copieu la carpeta `SHARP_Driver` dins de `controladors\` (l'INF ha de quedar a `controladors\SHARP_Driver\PCL6\64bit\su3emesp.inf`) i comproveu `dades\impressores.json`.
3. Obriu `Instalador\ImpressoresSEU.iss` amb Inno Setup Compiler i premeu **Build > Compile** (F9). També es pot fer per línia d'ordres:
   ```powershell
   & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" .\Instalador\ImpressoresSEU.iss
   ```
4. L'instal·lador queda a `Instalador\Output\Setup_ImpressoresSEU.exe`.

Si el compilador diu que no troba `Catalan.isl`, comproveu que teniu la versió 6.3 o superior (o canvieu la línia `[Languages]` per un altre idioma).

## Instal·lar, desinstal·lar i actualitzar

| Què | Com |
|---|---|
| Instal·lar a mà | Doble clic a `Setup_ImpressoresSEU.exe` (demana permís d'administrador) |
| Instal·lar sense preguntes (desplegament) | `Setup_ImpressoresSEU.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART` |
| Desinstal·lar | «Aplicacions instal·lades» del Windows, o `"C:\Program Files\ImpressoresSEU\unins000.exe" /VERYSILENT` |
| Actualitzar dades o scripts | Canvieu els fitxers, pugeu `VersioApp` al `.iss`, compileu de nou i executeu el nou instal·lador **damunt** de l'anterior. L'`AppId` no s'ha de canviar mai: així s'actualitza en comptes de duplicar-se |

Les impressores ja instal·lades **no** s'eliminen en desinstal·lar l'aplicació.

## Signatura (molt recomanada)

- Un instal·lador sense signar fa saltar **SmartScreen** («Windows ha protegit el seu equip») i pot ser bloquejat per l'antivirus. Signeu `Setup_ImpressoresSEU.exe` amb un certificat de signatura de codi (a Inno Setup, amb `SignTool`; hi ha les dues línies comentades al `.iss`).
- Si la vostra empresa exigeix política d'execució `AllSigned`, caldrà signar també els `.ps1` (`Set-AuthenticodeSignature`). No puc saber què exigeix la vostra empresa.

## Prova abans de repartir (màquina virtual amb instantània)

1. Executeu l'instal·lador i comproveu que apareixen les icones.
2. Obriu l'aplicació amb un usuari normal: ha de sortir el permís d'administrador, després la finestra de delegacions, després la de progrés amb el missatge «Fet!».
3. Repetiu-ho amb la mateixa delegació i amb dues delegacions alhora.
4. Comproveu que `C:\Program Files\ImpressoresSEU\logs` té un registre.
5. Desinstal·leu i comproveu que desapareixen les icones.
6. Proveu-ho amb un usuari **sense** drets d'administrador (vegeu «Límits»).

## Límits i alternatives

- **L'aplicació continua necessitant permís d'administrador en usar-la**, perquè instal·lar controladors i impressores ho requereix. Si els vostres usuaris no són administradors, Windows els demanarà una contrasenya d'administrador. Aquest cas es pot resoldre amb una tasca programada que s'executi com a SYSTEM (instal·lada per l'instal·lador) i que l'aplicació dispari, però té implicacions de seguretat i no està feta.
- **Es veu un instant una finestra negra** en obrir l'aplicació: és PowerShell abans d'amagar-se. Només es pot evitar amb un llançador compilat.
- **Un únic `.exe` sense instal·lador** es podria fer amb PS2EXE (una eina de la comunitat). No l'he utilitzat aquí: els executables que genera solen ser marcats per antivirus, canvia el comportament de `Write-Host` i de les rutes, i no puc verificar-ho des d'aquí.
- **MSI per a desplegament per GPO:** Inno Setup no genera MSI. Si només podeu desplegar MSI, caldria WiX; si podeu desplegar un EXE (Intune, SCCM...), feu servir `Setup_ImpressoresSEU.exe /VERYSILENT`.
