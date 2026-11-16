@echo off
rem Llançador per a l'usuari final: amb un doble clic s'obre l'eina d'instal·lació d'impressores.
rem %~dp0 és la carpeta on hi ha aquest fitxer (acaba amb una barra).
rem -ExecutionPolicy Bypass només val per a aquesta execució i no canvia res al Windows.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Instalar.ps1"
