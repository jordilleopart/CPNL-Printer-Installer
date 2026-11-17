# Eina d'instal·lació d'impressores SHARP, RICOH, HP, EPSON i LEXMARK

Instal·la, amb un doble clic, les impressores SHARP, RICOH, HP, EPSON i LEXMARK de la delegació (o delegacions) que tria la persona.
Les dades surten d'un fitxer JSON, no d'un script per delegació.

## Què fa

- Mostra una finestra per triar una o més delegacions pel nom (es poden escriure només unes lletres).
- Instal·la cada controlador **una sola vegada**, encara que hi hagi moltes impressores.
- Per a cada impressora: elimina la que ja existeix amb el mateix nom, crea el port TCP/IP RAW 9100 `IP_<ip>` i crea la impressora.
- Si una impressora falla, continua amb les altres.
- Escriu un registre amb data i hora i un resum final.
- Es pot executar diverses vegades sense efectes secundaris.
- No depèn de l'idioma del Windows (usa ordres de PowerShell, no rutes com `es-ES`).

Noms de les impressores: `<MARCA> <MODEL> - <NOM DE LA DELEGACIÓ> <UBICACIÓ>`.
Si hi ha diverses impressores del mateix model sense ubicació, s'hi afegeix ` 1`, ` 2`, ` 3`...

## Carpetes

```
ImpressoresSEU\
├── INSTALAR_IMPRESSORES.bat   ← el que fa servir l'usuari (doble clic)
├── ImpressoresSEU.ico         ← icona de l'aplicació
├── INSTRUCCIONS_USUARI.txt    ← full d'instruccions per a l'usuari
├── CONSTRUIR_INSTALADOR.md    ← com crear l'aplicació instal·lable (Setup.exe)
├── Instalador\ImpressoresSEU.iss ← script d'Inno Setup
├── LLEGEIX-ME.md              ← aquest fitxer
├── PUNTS_DE_FALLADA.md        ← problemes probables i com diagnosticar-los
├── src\                       ← els scripts (veure "Com funciona")
├── dades\impressores.json     ← delegacions i impressores
├── controladors\              ← aquí es copien SHARP_Driver i RICOH
├── proves\delegacions-prova.json ← dades inventades per fer proves
└── logs\                      ← es crea sol; un fitxer .log per execució
```

## Posada en marxa (a fer una vegada)

1. Copieu la carpeta a un **disc local** de l'ordinador (per exemple `C:\ImpressoresSEU`), no a una unitat de xarxa.
2. Si heu baixat el ZIP d'internet o d'un correu: abans d'extreure'l, clic dret al ZIP → Propietats → marqueu **Desbloqueja** → Aplica.
3. Copieu la carpeta `SHARP_Driver` dins de `controladors\` i comproveu que els INF siguin a `controladors\SHARP_Driver\PCL6\64bit\su3emesp.inf` i `controladors\RICOH\disk1\oemsetup.inf`. HP, EPSON i LEXMARK no necessiten cap carpeta de controladors.
4. Feu una revisió prèvia (no instal·la res):
   ```powershell
   cd C:\ImpressoresSEU
   .\src\Comprova.ps1
   ```
   Si surt algun `ERROR` o `AVIS`, mireu `PUNTS_DE_FALLADA.md`.
5. Proveu-ho primer en simulació (no canvia res): `.\src\Instalar.ps1 -Simulacio`.
6. Feu una prova real en un ordinador de prova abans de repartir-ho.

## Política d'execució (execution policy)

`INSTALAR_IMPRESSORES.bat` ja arrenca PowerShell amb `-ExecutionPolicy Bypass`. Això val només per a aquella execució i **no canvia res al Windows**. Si executeu un script a mà i Windows diu que els scripts estan desactivats, escriviu abans, a la mateixa finestra:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Si una directiva de grup (GPO) ho impedeix, mireu `PUNTS_DE_FALLADA.md`.

## Ús

**Usuari final:** doble clic a `INSTALAR_IMPRESSORES.bat`. Windows demana permís d'administrador; després es tria la delegació, es desmarquen les impressores que no es volen instal·lar i es prem el botó.

**Administrador** (`.\src\Instalar.ps1` amb opcions):

| Opció | Què fa |
|---|---|
| `-Simulacio` | No canvia res: només mostra què faria. No cal ser administrador. |
| `-Delegacio "eixample","corts"` | No obre la finestra de selecció. Cada text ha de trobar exactament una delegació; instal·la totes les impressores d'aquestes delegacions. |
| `-SenseFinestres` | No mostra cap finestra, només la consola. Cal indicar també `-Delegacio` i executar-ho ja com a administrador. Retorna codi de sortida 0 (correcte) o 1 (error). Pensat per a desplegaments automàtics. |
| `-Fitxer ruta.json` | Fa servir un altre fitxer de dades (per exemple `proves\delegacions-prova.json`). |
| `-ModelPerDefecte C31` | Controlador per a les impressores que no indiquen model (per defecte, C31). |
| `-FitxerDelegacions`, `-FitxerRegistre` | Opcions internes: l'aplicació les fa servir per passar dades al procés fill. No cal usar-les. |

Exemple de desplegament automàtic (**no s'ha provat** amb cap eina de desplegament):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ImpressoresSEU\src\Instalar.ps1" -Delegacio "serveis centrals" -SenseFinestres
```

Altres scripts: `Comprova.ps1` (revisió de l'ordinador i de les dades) i `Converteix-CsvAJson.ps1` (veure més avall).

## Aplicació instal·lable (icona al menú Inici)

Per repartir l'eina com una aplicació (icona al menú Inici o a l'escriptori, sense carpetes ni finestra negra), s'ha de crear un instal·lador amb Inno Setup. Les instruccions són a `CONSTRUIR_INSTALADOR.md`. L'aplicació funciona així:

1. La icona obre PowerShell amagat amb `Instalar.ps1`, que demana el permís d'administrador i es torna a obrir amb ell.
2. Mostra la finestra per triar delegacions.
3. La instal·lació la fa un **procés fill amagat** (el mateix `Instalar.ps1` en mode `-SenseFinestres`) que escriu al registre. La tercera pantalla llegeix aquest registre i actualitza cada impressora agrupada per delegació: mostra un indicador mentre s'instal·la i un vist quan acaba.

Sense instal·lador, la mateixa aplicació funciona amb el doble clic a `INSTALAR_IMPRESSORES.bat`.

## Les dades: `dades\impressores.json`

```json
{
  "versio": 1,
  "delegacions": [
    {
      "codi": "SEU.000001",
      "nom": "CONSORCI PER NORMALITZACIO LINGUISTICA - CNL DE GIRONA",
      "poblacio": "Girona",
      "impressores": [
        { "marca": "SHARP", "model": "C31", "ip": "10.1.2.3", "ubicacio": "Planta 1" },
        { "marca": "HP", "model": "M521dn", "ip": "10.1.2.4", "ubicacio": "Planta 2" }
      ]
    }
  ]
}
```

- `nom` és el que serveix per cercar i per formar el nom de la impressora. Si el canvieu, canvia el nom de les impressores noves.
- `ubicacio` és opcional i s'afegeix al nom final de la impressora. Si hi ha diverses impressores del mateix model i delegació sense ubicació, s'afegeix un número automàtic.
- `model` és opcional: `C31`, `M36` o `C36` (també s'accepta `BP-70M36` o el nom complet del controlador). Si falta, s'usa C31 i el registre ho anota.
- Només s'instal·len les impressores amb `"marca": "SHARP"`, `"marca": "RICOH"`, `"marca": "HP"`, `"marca": "EPSON"` o `"marca": "LEXMARK"`. Les altres marques s'ignoren. Les HP, EPSON i LEXMARK utilitzen el controlador IPP integrat de Windows i no necessiten cap paquet addicional.
- Un model que no es reconeix és un error només d'aquella impressora; les altres continuen.

**Atenció:** el nom de la impressora inclou el model. Si canvieu el model d'una impressora que ja estava instal·lada (de C31 a M36, per exemple), es crearà una impressora **nova** amb un altre nom i la vella no s'esborra sola. Elimineu-la a mà:

```powershell
Remove-Printer -Name "SHARP BP-70C31 PCL6 - NOM DE LA DELEGACIO"
```

### Actualitzar el JSON des de l'Excel (CSV)

```powershell
.\src\Converteix-CsvAJson.ps1 -Csv "C:\ruta\exportacio.csv"
```

Llegeix el CSV (separador `;`, UTF-8) i agafa de cada fila: codi (columna 1), nom (2), població (4), IP (26) i model (27). Les columnes d'IP i de model tenen una línia per impressora, i la línia N d'una es correspon amb la línia N de l'altra. Aquest conversor valida i importa actualment les impressores SHARP; les dades d'HP, EPSON, LEXMARK i RICOH s'han de revisar o mantenir al JSON després de la conversió.

Abans d'escriure guarda una còpia del JSON antic (`impressores.anterior.json`) i genera `informe-conversio.txt` amb: impressores excloses (sense IP, IP no vàlida, model amb un altre controlador), les que han quedat sense model i usaran el per defecte, IP repetides, i les diferències respecte al JSON anterior. **Reviseu sempre l'informe.**

## Com funciona (per mantenir-ho)

| Fitxer | Què fa |
|---|---|
| `Instalar.ps1` | Programa principal: demana permís d'administrador, llegeix les dades, coordina les tres pantalles i en mode `-SenseFinestres` fa la instal·lació. |
| `Finestra.ps1` | Les finestres: selecció d'oficines, selecció d'impressores i estat de la instal·lació. |
| `Proces.ps1` | `Install-Delegacio`: instal·la totes les impressores SHARP, RICOH, HP, EPSON i LEXMARK d'una delegació. També tria la carpeta de registres. |
| `Motor.ps1` | `Install-Controlador` (una vegada per model), `Install-Impressora` (port + cua) i `Invoke-Impressora` (no s'atura si falla). |
| `Dades.ps1` | Llegeix el JSON, valida, cerca per nom sense accents ni majúscules, resol els models (`C31`, `M36`, `C36`) i construeix els noms. |
| `Registre.ps1` | Escriu el registre per pantalla i a fitxer, i el resum final. |
| `Comprova.ps1` | Revisió de l'ordinador i de les dades. No instal·la res. |
| `Converteix-CsvAJson.ps1` | Passa el CSV de l'Excel al JSON. |

Per **afegir un model SHARP nou**: afegiu-lo a la taula `$script:ModelsSharp` al principi de `Dades.ps1` (abreviatura → nom exacte del controlador tal com surt a l'INF) i comproveu amb `Comprova.ps1` que l'INF el declara. Els scripts es desen en UTF-8 **amb BOM** i salts de línia de Windows (CRLF), perquè Windows PowerShell 5.1 llegeixi bé els accents.

## Registres

Cada execució crea `logs\registre_AAAAMMDD_HHMMSS.log` amb una línia per pas (`INFO`, `OK`, `AVIS`, `ERROR`) i un resum final. Si no es pot escriure a `logs\` (per exemple, en un disc de només lectura), es fa servir `%TEMP%\ImpressoresSEU_logs`. El registre no guarda mai codis personals.

## Què NO fa (límits actuals)

- **Codi personal d'impressió.** No es desa al controlador. Vam fer proves amb el controlador SHARP (fitxer de configuració de la impressora, comparació de fitxers `.dat` i cerca al registre del Windows) i en cap cas es va veure el codi emmagatzemat en un lloc que es pugui llegir o escriure. L'opció que queda és configurar el SHARP perquè identifiqui l'usuari pel nom d'inici de sessió del Windows (es configura a la impressora, no a aquesta eina; no s'ha comprovat que els vostres models ho permetin), o que cada persona escrigui el codi al primer ús.
- **Controladors de marques sense paquet propi:** HP, EPSON i LEXMARK utilitzen el controlador IPP integrat de Windows (`Microsoft IPP Class Driver`); no es copia ni s'instal·la cap paquet específic d'aquestes marques.
- **No desinstal·la** impressores ni controladors, tret de l'impressora que té exactament el mateix nom que es va a crear.
- **No detecta** la delegació sola: la persona l'ha de triar.

## Proves recomanades abans de repartir-ho

Totes en una màquina virtual amb instantània (snapshot):

1. `.\src\Comprova.ps1` sense errors.
2. `.\src\Instalar.ps1 -Simulacio -Fitxer .\proves\delegacions-prova.json` (la delegació «SENSE IMPRESSORES» no s'ha de poder marcar).
3. Doble clic al `.bat` com a usuari normal: surt el permís, es tria una delegació i apareix el missatge «Fet!».
4. Mateixa delegació una segona vegada: cap error i cap impressora duplicada.
5. Una delegació amb dos models (per exemple Serveis Centrals: C31 i M36).
6. Cancel·lar el permís d'administrador: ha de sortir un missatge, no un error.
7. Una prova amb un usuari **sense** drets d'administrador (vegeu `PUNTS_DE_FALLADA.md`).
