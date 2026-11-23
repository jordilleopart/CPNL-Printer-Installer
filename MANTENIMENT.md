# Manteniment de l'eina d'impressores

Aquest document descriu com afegir oficines i impressores, validar els canvis i
crear una nova versió.

## Fitxer principal

Les oficines i impressores actives estan a
[dades/impressores.json](dades/impressores.json).

Cada oficina té aquesta estructura:

```json
{
  "codi": "SEU.000001",
  "nom": "CNL EXEMPLE - OFICINA",
  "poblacio": "Barcelona",
  "impressores": [
    {
      "marca": "SHARP",
      "model": "C31",
      "ip": "10.129.200.10",
      "ubicacio": "Administració"
    }
  ]
}
```

### Camps

| Camp | Obligatori | Significat |
|---|---|---|
| `codi` | Sí | Identificador únic de l'oficina. Mantén el format `SEU.`. |
| `nom` | Sí | Nom visible i base dels noms de les impressores. |
| `poblacio` | Sí | Població; serveix per normalitzar alguns noms. |
| `impressores` | Sí | Matriu d'impressores. Pot ser `[]` si l'oficina no n'ha de tenir. |
| `marca` | Sí | `SHARP`, `RICOH`, `HP`, `EPSON` o `LEXMARK`. |
| `model` | Depèn | SHARP: `C31`, `M36` o `C36`. HP i les altres marques poden portar el model habitual. |
| `ip` | Sí | IPv4 única i accessible des dels ordinadors clients. |
| `ubicacio` | Recomanat | Planta, sala o servei; apareix al nom final de la impressora. |

No utilitzis coma al final de l'últim element d'una matriu o d'un objecte.

## Afegir una oficina

1. Fes una còpia de seguretat de `dades/impressores.json`.
2. Edita el fitxer amb un editor que guardi en UTF-8.
3. Afegiu un nou objecte dins de `"delegacions"` amb un `codi` únic.
4. Afegiu a `impressores` les impressores de l'oficina.
5. Desa el fitxer i executa:

```powershell
.\src\Comprova.ps1
```

No apareixerà cap oficina sense una impressora compatible al selector.

Exemple d'oficina nova:

```json
{
  "codi": "SEU.999999",
  "nom": "CNL EXEMPLE - OFICINA NOVA",
  "poblacio": "Exemple",
  "impressores": []
}
```

## Afegir una impressora a una oficina existent

1. Cerca l'objecte de l'oficina pel camp `codi` o `nom`.
2. Afegiu un objecte a l'array `impressores`.
3. Comprova que la marca és compatible i que l'IP no s'ha repetit.
4. Per a SHARP, utilitza `C31`, `M36` o `C36`; si es deixa el model buit,
   l'eina usa C31 i ho indica al registre.

Exemple:

```json
{
  "marca": "HP",
  "model": "M521dn",
  "ip": "10.129.200.11",
  "ubicacio": "Recepció"
}
```

## Modificar o retirar una impressora

- Si canvies la IP, reutilitza el mateix nom i el nom de la impressora ja
  instal·lada es recrearà al port nou.
- Si canvies el model o la ubicació, pot canviar el nom final. En aquest cas
  podràs veure una impressora nova i l'antiga al Windows. Elimina l'antiga
  manualment només quan confirmis que ja no es fa servir.
- Si retires una impressora, elimina el seu objecte del JSON. Això no elimina
  cap impressora ja instal·lada als ordinadors.
- Els noms SHARP canvien de forma concreta quan canvies el model. Revisa
  `PUNTS_DE_FALLADA.md` per eliminar una cua obsoleta si cal.

## Canviar una ubicació o el nom d'una oficina

Canviar `nom` canvia els noms que es generen per a totes les impressores
d'aquella oficina i pot crear cues noves als ordinadors. Abans de fer-ho:

1. Cerca totes les aparicions del nom antic al JSON.
2. Revisa si hi ha una prova o script que tingui el nom fix.
3. Prova amb `-Simulacio -Fitxer .\dades\impressores.json`.
4. Aviseu els usuaris si han de mirar els noms nous a Windows.

## Afegir un model SHARP nou

Només cal modificar `Dades.ps1` si el nou model té un controlador diferent als
models C31, M36 i C36.

1. Obre `src/Dades.ps1`.
2. Afegiu l'abreviatura i el nom exacte que mostra l'INF a `$script:ModelsSharp`.
3. Comprova que el mateix nom apareix a
   `controladors\SHARP_Driver\PCL6\64bit\su3emesp.inf`.
4. Executa `.\src\Comprova.ps1`.
5. Executa una simulació amb una impressora de prova.

Exemple:

```powershell
$script:ModelsSharp = @{
    'C31' = 'SHARP BP-70C31 PCL6'
    'M36' = 'SHARP BP-70M36 PCL6'
    'C36' = 'SHARP BP-70C36 PCL6'
}
```

Si el model no apareix a l'INF, cal obtenir i validar el paquet de controlador
correcte abans de distribuir l'eina.

## Conversió des d'un CSV

La conversió actual importa principalment impressores SHARP:

```powershell
.\src\Converteix-CsvAJson.ps1 -Csv "C:\ruta\exportacio.csv"
```

El script:

- guarda una còpia a `dades\impressores.anterior.json`;
- escriu l'informe a `dades\informe-conversio.txt`;
- pot substituir les dades actuals.

Revisa sempre les diferències i les IP repetides abans de continuar. Els
models HP, EPSON, LEXMARK i RICOH no formen part del procés actual i cal
comprovar-los manualment al JSON després de la conversió.

## Proves abans de publicar

Executa aquestes comprovacions des d'una màquina de prova:

```powershell
# Comprova el sistema, els controladors i el JSON
.\src\Comprova.ps1

# No modifica impressores ni ports
.\src\Instalar.ps1 -Simulacio

# Prova només les dades alternatives
.\src\Instalar.ps1 -Simulacio -Fitxer .\proves\delegacions-prova.json
```

Abans de distribuir un canvi, verifica:

- El JSON s'obre sense errors i `Comprova.ps1` no mostra errors.
- Les IP noves fan ping i tenen el port RAW 9100 disponible.
- Cada marca i model existeix entre els compatibles de l'eina.
- No hi ha noms d'oficina repetits ni IP repetides.
- Una oficina amb impressores es mostra al selector.
- Una oficina sense impressores no es pot triar.
- Repetir la instal·lació no crea cues duplicades.
- Els registres indiquen el resultat correcte.

## Crear i distribuir una versió nova

1. Aplica els canvis i actualitza la documentació relacionada.
2. Prova amb un usuari normal i drets d'administrador en una màquina virtual.
3. Augmenta `VersioApp` a `Instalador\ImpressoresSEU.iss`.
4. Compila l'instal·lador:

```powershell
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" .\Instalador\ImpressoresSEU.iss
```

5. Comprova `Instalador\Output\Setup_ImpressoresSEU.exe`.
6. Prova una instal·lació damunt de la versió anterior i una desinstal·lació.
7. Si és possible, signa l'EXE i els scripts PowerShell.

Els passos complets i les opcions silencioses estan a
[CONSTRUIR_INSTALADOR.md](CONSTRUIR_INSTALADOR.md).

## On buscar incidències

- Diagnòstic general: `.\src\Comprova.ps1`
- Instruccions d'usuari: [INSTRUCCIONS_USUARI.txt](INSTRUCCIONS_USUARI.txt)
- Problemes coneguts i solucions: [PUNTS_DE_FALLADA.md](PUNTS_DE_FALLADA.md)
- Resultats detallats: carpeta `logs\`
