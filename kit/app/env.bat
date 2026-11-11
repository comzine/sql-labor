@echo off
rem Gemeinsame Einstellungen aller Skripte des SQL-Labors.
rem Wird von START.bat, STOPP.bat, TEST.bat usw. per CALL eingebunden.

set "KIT_VERSION=@KIT_VERSION@"
set "APP=%~dp0"
set "APP=%APP:~0,-1%"
set "MDB=%APP%\mariadb\bin"
set "PHPDIR=%APP%\php"
set "WEBROOT=%APP%\phpmyadmin"
set "DB_PORT=13306"
set "WEB_PORT=18080"
rem Webserver fuer die eigenen Seiten der SuS (HTML, PHP), Ordner siehe webordner.bat
set "SUS_PORT=18000"
set "DB_USER=sus"
set "DB_PASS=sus"

rem Datenort: Standard ist die lokale Platte (schnell, InnoDB-tauglich).
rem Eine Datei DATENORT.txt neben START.bat ueberschreibt ihn (erste Zeile = Ordner).
if not defined SQLLABOR_DATA set "SQLLABOR_DATA=%LOCALAPPDATA%\SQL-Labor"
if exist "%APP%\..\DATENORT.txt" set /p SQLLABOR_DATA=<"%APP%\..\DATENORT.txt"
set "DATA=%SQLLABOR_DATA%\data"
rem Cache und Zwischendateien von phpMyAdmin (liest config.inc.php)
set "SQLLABOR_TMP=%SQLLABOR_DATA%\tmp"
rem Einziger Ordner fuer LOAD DATA INFILE und SELECT ... INTO OUTFILE (secure_file_priv)
set "SQLLABOR_FILES=%SQLLABOR_DATA%\dateien"
