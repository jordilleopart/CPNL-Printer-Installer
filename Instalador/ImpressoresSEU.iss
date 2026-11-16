; Script d'Inno Setup (versió 6.3 o superior) que crea l'instal·lador de l'aplicació.
; Abans de compilar: copieu SHARP_Driver dins de ..\controladors\ i reviseu ..\dades\impressores.json.
; Compilació: obriu aquest fitxer amb Inno Setup Compiler i premeu Build > Compile (F9).
; Resultat: Output\Setup_ImpressoresSEU.exe

#define NomApp "Instal·la impressores SEU"
#define VersioApp "1.0.0"
#define Editor "Servei informàtic"

[Setup]
; L'AppId identifica l'aplicació: NO el canvieu mai, així un instal·lador nou actualitza el vell
AppId={{F83B3604-4D73-4EDF-B650-D4EBB8348D39}
AppName={#NomApp}
AppVersion={#VersioApp}
AppPublisher={#Editor}
; Es copia a Program Files (la carpeta de programes de 64 bits), que els usuaris estàndard no poden modificar
DefaultDirName={autopf}\ImpressoresSEU
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=Output
OutputBaseFilename=Setup_ImpressoresSEU
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\ImpressoresSEU.ico
UninstallDisplayIcon={app}\ImpressoresSEU.ico
; Si teniu un certificat de signatura de codi, definiu una eina de signatura a Inno Setup i descomenteu:
; SignTool=signtool
; SignedUninstaller=yes

[Languages]
Name: "catalan"; MessagesFile: "compiler:Languages\Catalan.isl"

[Tasks]
Name: "icona"; Description: "Crea una icona a l'escriptori"; GroupDescription: "Icones addicionals:"

[Files]
Source: "..\src\*"; DestDir: "{app}\src"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\dades\*"; DestDir: "{app}\dades"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\controladors\*"; DestDir: "{app}\controladors"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\ImpressoresSEU.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\INSTRUCCIONS_USUARI.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LLEGEIX-ME.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\PUNTS_DE_FALLADA.md"; DestDir: "{app}"; Flags: ignoreversion

[Dirs]
; La carpeta de registres es pot escriure sense ser administrador
Name: "{app}\logs"; Permissions: users-modify

[Icons]
; La icona obre PowerShell amagat (sense finestra negra) amb el programa; el programa demana sol el permís d'administrador
Name: "{autoprograms}\{#NomApp}"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\src\Instalar.ps1"""; WorkingDir: "{app}"; IconFilename: "{app}\ImpressoresSEU.ico"; Comment: "Instal·la les impressores de la teva delegació"
Name: "{autodesktop}\{#NomApp}"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\src\Instalar.ps1"""; WorkingDir: "{app}"; IconFilename: "{app}\ImpressoresSEU.ico"; Comment: "Instal·la les impressores de la teva delegació"; Tasks: icona

[UninstallDelete]
; En desinstal·lar, s'esborren també els registres que ha creat el programa
Type: filesandordirs; Name: "{app}\logs"
