# Impressores SEU

Eina per instal·lar automàticament les impressores **SHARP, RICOH, HP, EPSON i LEXMARK** de les delegacions
del SEU en ordinadors Windows.

L'aplicació llegeix les delegacions i les adreces IP des de
[`dades/impressores.json`](dades/impressores.json), permet seleccionar una o
més delegacions i crea les impressores amb ports TCP/IP RAW (9100).
Els controladors només s'instal·len quan cal.

## Funcionalitats

- Cerca i selecció de delegacions per nom, sense distingir majúscules ni accents.
- Instal·lació de diverses impressores d'una o més delegacions.
- Selecció individual de les impressores que es volen instal·lar dins de cada delegació.
- Suport per als models SHARP C31, M36 i C36.
- Suport per al controlador universal RICOH PCL6.
- Suport per a impressores HP amb el controlador IPP integrat de Windows, sense paquet addicional.
- Suport per a impressores EPSON i LEXMARK amb el controlador IPP integrat de Windows, sense paquet addicional.
- Reexecució segura: elimina i recrea la impressora amb el mateix nom sense
  crear duplicats.
- Estat de cada impressora durant la instal·lació i registre detallat de cada execució.
- Mode de simulació que no modifica l'ordinador.
- Mode sense finestres per a desplegaments automatitzats.
- Conversió de dades d'un CSV exportat des d'Excel a JSON.

> **Abast actual:** els scripts instal·len impressores SHARP, RICOH, HP, EPSON i LEXMARK. Les altres
> marques del JSON no s'instal·len automàticament.

## Requisits

- Windows amb Windows PowerShell 5.1 o superior.
- Permisos d'administrador per instal·lar controladors, ports i impressores.
- Carpeta del projecte en un disc local, no en una unitat de xarxa.
- Controlador SHARP disponible a:
  `controladors\SHARP_Driver\PCL6\64bit\su3emesp.inf`
- Controlador RICOH disponible a:
  `controladors\RICOH\disk1\oemsetup.inf`
- Servei d'impressió de Windows (`Spooler`) en funcionament.

## Ús ràpid

### Aplicació per a l'usuari

1. Copieu el projecte a un disc local, per exemple `C:\ImpressoresSEU`.
2. Si prové d'un ZIP descarregat, desbloquegeu-lo des de les propietats del
   fitxer abans d'extreure'l.
3. Executeu [`INSTALAR_IMPRESSORES.bat`](INSTALAR_IMPRESSORES.bat) amb doble
   clic.
4. Accepteu el permís d'administrador i seleccioneu una o més delegacions.
5. A la segona finestra, deixa marcades només les impressores que vulguis
   instal·lar i prem **Continua**.
6. A la tercera pantalla, revisa l'estat agrupat per oficina fins que totes
   les impressores mostrin el vist de finalització.

Abans de fer una instal·lació real, es recomana executar:

```powershell
.\src\Comprova.ps1
.\src\Instalar.ps1 -Simulacio
```

### Ús des de PowerShell

```powershell
# Obrir el selector de delegacions
.\src\Instalar.ps1

# Simular una instal·lació
.\src\Instalar.ps1 -Simulacio

# Instal·lar una delegació concreta (totes les seves impressores)
.\src\Instalar.ps1 -Delegacio "nom de la delegació"

# Executar sense finestres, per a desplegaments automatitzats
.\src\Instalar.ps1 -Delegacio "nom de la delegació" -SenseFinestres

# Fer servir un fitxer de dades alternatiu
.\src\Instalar.ps1 -Fitxer .\proves\delegacions-prova.json -Simulacio
```

`-SenseFinestres` retorna el codi `0` si tot acaba correctament i `1` si hi ha
errors. Cal executar-lo com a administrador i indicar sempre `-Delegacio`.
La selecció individual d'impressores està disponible a la finestra gràfica;
les execucions amb `-Delegacio` instal·len totes les impressores de la delegació.

## Dades de les impressores

El fitxer [`dades/impressores.json`](dades/impressores.json) conté les
delegacions i les impressores. Cada impressora necessita una adreça IP. Les
SHARP poden indicar `C31`, `M36` o `C36`; les RICOH fan servir el controlador
universal. HP, EPSON i LEXMARK fan servir el controlador integrat de Windows:

```json
{
  "versio": 1,
  "delegacions": [
    {
      "codi": "SEU.000001",
      "nom": "NOM DE LA DELEGACIÓ",
      "poblacio": "Població",
      "impressores": [
        { "marca": "SHARP", "model": "C31", "ip": "192.0.2.10", "ubicacio": "Planta 1" },
        { "marca": "HP", "model": "M521dn", "ip": "192.0.2.11", "ubicacio": "Planta 2" }
      ]
    }
  ]
}
```

Si no s'indica el model d'una SHARP, s'utilitza C31 per defecte. Les marques
diferents de SHARP, RICOH, HP, EPSON i LEXMARK s'ignoren. HP, EPSON i LEXMARK
utilitzen `Microsoft IPP Class Driver`, que forma part de Windows i no requereix
cap paquet del projecte. El camp opcional `ubicacio` s'afegeix al nom final de
la impressora. Per actualitzar el JSON des d'un CSV:

```powershell
.\src\Converteix-CsvAJson.ps1 -Csv "C:\ruta\exportacio.csv"
```

Reviseu sempre l'informe de conversió abans de distribuir les dades.

## Instal·lador

Per crear `Setup_ImpressoresSEU.exe` cal instal·lar **Inno Setup 6.3 o
superior** i compilar [`Instalador/ImpressoresSEU.iss`](Instalador/ImpressoresSEU.iss):

```powershell
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" .\Instalador\ImpressoresSEU.iss
```

El resultat es crea a `Instalador\Output\Setup_ImpressoresSEU.exe`. Consulteu
[`CONSTRUIR_INSTALADOR.md`](CONSTRUIR_INSTALADOR.md) per als passos complets,
actualitzacions i desplegament silenciós.

## Estructura del projecte

| Ruta | Descripció |
|---|---|
| [`src/Instalar.ps1`](src/Instalar.ps1) | Punt d'entrada i flux principal |
| [`src/Dades.ps1`](src/Dades.ps1) | Lectura, validació i resolució de models |
| [`src/Motor.ps1`](src/Motor.ps1) | Instal·lació de controladors, ports i impressores |
| [`src/Proces.ps1`](src/Proces.ps1) | Processament d'una delegació |
| [`src/Finestra.ps1`](src/Finestra.ps1) | Pantalles de selecció i estat de la instal·lació |
| [`src/Comprova.ps1`](src/Comprova.ps1) | Diagnòstic sense instal·lar res |
| [`dades/`](dades/) | Fitxers JSON de configuració |
| [`controladors/`](controladors/) | Paquets de controladors |
| [`proves/`](proves/) | Dades i scripts de prova |

Els registres es guarden a `logs\registre_AAAAMMDD_HHMMSS.log`. Si la carpeta
no es pot escriure, l'eina utilitza `%TEMP%\ImpressoresSEU_logs`.

## Limitacions i incidències

- La instal·lació necessita permisos d'administrador.
- No es detecta automàticament la delegació de l'usuari.
- No es desinstal·len controladors ni impressores, excepte la impressora que
  té exactament el mateix nom que es recrea.
- El codi personal d'impressió no es desa ni es gestiona des d'aquesta eina.

Per diagnosticar problemes, executeu primer `.\src\Comprova.ps1` i consulteu
[`PUNTS_DE_FALLADA.md`](PUNTS_DE_FALLADA.md). Les instruccions adreçades a
l'usuari final són a [`INSTRUCCIONS_USUARI.txt`](INSTRUCCIONS_USUARI.txt) i la
documentació tècnica completa és a [`LLEGEIX-ME.md`](LLEGEIX-ME.md).

## Llicència i distribució

Aquest repositori inclou scripts propis, dades de configuració i fitxers de
controlador de tercers. Abans de redistribuir-lo fora de l'organització,
comproveu els termes de la llicència dels controladors SHARP i de qualsevol
altre paquet inclòs.
