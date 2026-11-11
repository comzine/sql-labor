@echo off
rem Ermittelt den Webordner der SuS (WEBORDNER) fuer START.bat, WEB.bat und TEST.bat.
rem Standard: Dokumente\SQL-Labor-Web. Den echten Dokumente-Ordner fragt PowerShell ab,
rem weil er auf Schul-PCs oft auf das Home-Laufwerk umgeleitet ist.
rem Eine Datei WEBORDNER.txt neben START.bat ueberschreibt ihn (erste Zeile = Ordner).

set "WEBORDNER="
if exist "%~dp0..\WEBORDNER.txt" set /p WEBORDNER=<"%~dp0..\WEBORDNER.txt"
if defined WEBORDNER goto :eof

set "DOKUMENTE="
for /f "usebackq delims=" %%d in (`powershell -NoProfile -NonInteractive -Command "[Environment]::GetFolderPath('MyDocuments')" 2^>nul`) do set "DOKUMENTE=%%d"
if not defined DOKUMENTE set "DOKUMENTE=%USERPROFILE%\Documents"
set "WEBORDNER=%DOKUMENTE%\SQL-Labor-Web"
