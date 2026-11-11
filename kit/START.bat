@echo off
setlocal
title SQL-Labor
call "%~dp0app\env.bat"

echo.
echo  SQL-Labor %KIT_VERSION% von Tobias Weber  (Lizenzen: LIZENZEN.txt)
echo  Daten liegen in: %DATA%
echo.

if not exist "%SQLLABOR_DATA%\" mkdir "%SQLLABOR_DATA%"
if not exist "%SQLLABOR_TMP%\" mkdir "%SQLLABOR_TMP%"
if not exist "%SQLLABOR_DATA%\sessions\" mkdir "%SQLLABOR_DATA%\sessions"
if not exist "%SQLLABOR_FILES%\" mkdir "%SQLLABOR_FILES%"
set "SERVERLOG=%SQLLABOR_DATA%\server.err"
set "NEU="

rem Laeuft die Datenbank schon (zweiter Doppelklick)?
call :ping
if not errorlevel 1 goto web

rem Ein Datenordner ohne Unterordner mysql stammt von einem abgebrochenen
rem ersten Start. Er wird beiseite gelegt und neu angelegt.
if exist "%DATA%\mysql\" goto server
if not exist "%DATA%\" goto anlegen
echo  Der Datenordner ist unvollstaendig (abgebrochener erster Start).
call :beiseite unvollstaendig
if errorlevel 1 goto fehler_beiseite

:anlegen
echo  Lege die Datenbank an ...
"%MDB%\mariadb-install-db.exe" --datadir="%DATA%" --port=%DB_PORT% > "%SQLLABOR_DATA%\install.log" 2>&1
if errorlevel 1 goto fehler_install
set "NEU=1"

:server
if exist "%SERVERLOG%" del "%SERVERLOG%" >nul 2>&1
rem myisam-recover-options repariert MyISAM-Tabellen (northwind) nach hartem Ausschalten.
rem secure-file-priv: Dateizugriffe per SQL nur im Ordner dateien, nicht im ganzen Profil.
start "SQL-Labor Datenbank - nicht schliessen" /min "%MDB%\mariadbd.exe" --defaults-file="%DATA%\my.ini" --port=%DB_PORT% --bind-address=127.0.0.1 --init-file="%APP%\sql\init.sql" "--myisam-recover-options=BACKUP,FORCE" --secure-file-priv="%SQLLABOR_FILES%" --log-error="%SERVERLOG%"
set /a WARTE=0
:warten
ping -n 2 127.0.0.1 >nul
call :ping
if not errorlevel 1 goto bereit
set /a WARTE+=1
if %WARTE% lss 30 goto warten

rem Der Server kommt nicht hoch: Grund zeigen und anbieten, den Stand beiseite zu legen.
taskkill /fi "WINDOWTITLE eq SQL-Labor Datenbank*" /f >nul 2>&1
taskkill /im mariadbd.exe /f >nul 2>&1
echo.
echo  FEHLER: Der Datenbankserver startet nicht. Seine letzten Meldungen:
echo  ----------------------------------------------------------------------
if exist "%SERVERLOG%" type "%SERVERLOG%"
echo  ----------------------------------------------------------------------
if defined NEU goto fehler_server
echo.
echo  Vermutlich sind Dateien im Datenordner beschaedigt, etwa nach hartem
echo  Ausschalten. Der alte Stand wird nicht geloescht, sondern umbenannt.
choice /c jn /m " Datenbank neu anlegen (northwind im Ausgangsstand)"
if errorlevel 2 goto ende_fehler
ping -n 3 127.0.0.1 >nul
call :beiseite defekt
if errorlevel 1 goto fehler_beiseite
goto anlegen

:bereit
"%MDB%\mariadb.exe" -h127.0.0.1 -P%DB_PORT% -u%DB_USER% -p%DB_PASS% -e "USE northwind" >nul 2>&1
if not errorlevel 1 goto pmadb
echo  Lade die Beispieldatenbank northwind ...
"%MDB%\mariadb.exe" -h127.0.0.1 -P%DB_PORT% -u%DB_USER% -p%DB_PASS% --default-character-set=utf8mb4 < "%APP%\sql\northwind.sql"
if errorlevel 1 goto fehler_import

:pmadb
rem Konfigurationsspeicher von phpMyAdmin (Designer, SQL-Verlauf); Fehler hier sind nicht schlimm.
"%MDB%\mariadb.exe" -h127.0.0.1 -P%DB_PORT% -u%DB_USER% -p%DB_PASS% -e "USE phpmyadmin" >nul 2>&1
if not errorlevel 1 goto web
"%MDB%\mariadb.exe" -h127.0.0.1 -P%DB_PORT% -u%DB_USER% -p%DB_PASS% < "%WEBROOT%\sql\create_tables.sql" >nul 2>&1

:web
rem Laeuft der Webserver schon?
curl.exe -s -o nul --max-time 2 "http://127.0.0.1:%WEB_PORT%/lizenz.html" >nul 2>&1
if not errorlevel 1 goto susweb
start "SQL-Labor Web - nicht schliessen" /min "%PHPDIR%\php.exe" -c "%PHPDIR%\php.ini" -d extension_dir="%PHPDIR%\ext" -d session.save_path="%SQLLABOR_DATA%\sessions" -S 127.0.0.1:%WEB_PORT% -t "%WEBROOT%" "%APP%\router.php"
ping -n 3 127.0.0.1 >nul

:susweb
rem Zweiter Webserver fuer die eigenen Seiten der SuS (HTML, PHP mit Datenbank).
rem Ein neuer Webordner bekommt die Startdateien; vorhandene Dateien bleiben unberuehrt.
call "%APP%\webordner.bat"
if exist "%WEBORDNER%\" goto susweb_start
echo  Lege den Webordner an: %WEBORDNER%
mkdir "%WEBORDNER%" >nul 2>&1
if not exist "%WEBORDNER%\" goto susweb_fehler
xcopy "%APP%\web-vorlage\*" "%WEBORDNER%\" /e /i /q /y >nul
:susweb_start
curl.exe -s -o nul --max-time 2 "http://127.0.0.1:%SUS_PORT%/" >nul 2>&1
if not errorlevel 1 goto browser
start "SQL-Labor Webseiten - nicht schliessen" /min "%PHPDIR%\php.exe" -c "%PHPDIR%\php.ini" -d extension_dir="%PHPDIR%\ext" -d session.save_path="%SQLLABOR_DATA%\sessions" -d display_errors=1 -d display_startup_errors=1 -d error_reporting=E_ALL -S 127.0.0.1:%SUS_PORT% -t "%WEBORDNER%" "%APP%\router.php"
ping -n 2 127.0.0.1 >nul
goto browser

:susweb_fehler
echo  WARNUNG: Der Webordner %WEBORDNER% laesst sich nicht anlegen.
echo  Der Webserver fuer eigene Seiten startet nicht (WEBORDNER.txt anlegen, siehe LIESMICH.txt).

:browser
start "" "http://127.0.0.1:%WEB_PORT%/"
echo.
echo  ======================================================================
echo   SQL-Labor laeuft.
echo.
echo   phpMyAdmin im Browser:  http://127.0.0.1:%WEB_PORT%/
echo.
echo   Eigene Webseiten (HTML, PHP):  http://127.0.0.1:%SUS_PORT%/
echo     Ordner: %WEBORDNER%
echo     WEB.bat oeffnet Ordner und Browser. PHP-Verbindung zur Datenbank:
echo     new PDO('mysql:host=127.0.0.1;port=%DB_PORT%;dbname=northwind;charset=utf8mb4', '%DB_USER%', '%DB_PASS%')
echo.
echo   MySQL Workbench: Verbindung einmal anlegen
echo   (Plus-Zeichen neben "MySQL Connections"):
echo     Connection Name:  SQL-Labor
echo     Hostname:         127.0.0.1
echo     Port:             %DB_PORT%    (nicht 3306)
echo     Username:         %DB_USER%
echo     Password:         %DB_PASS%      (Store in Vault ...)
echo   Die Warnung "Incompatible/nonstandard server version" mit
echo   "Continue Anyway" bestaetigen: Das SQL-Labor ist MariaDB, kein MySQL.
echo   Workbench geht nur, solange das SQL-Labor laeuft.
echo.
echo   Dateien fuer LOAD DATA INFILE / INTO OUTFILE nur in:
echo     %SQLLABOR_FILES%
echo.
echo   Die drei minimierten Fenster "SQL-Labor ..." muessen offen bleiben.
echo   Beenden: STOPP.bat. Dieses Fenster darf geschlossen werden.
echo  ======================================================================
echo.
pause
exit /b 0


rem ---------------------------------------------------------------
:ping
"%MDB%\mariadb-admin.exe" -h127.0.0.1 -P%DB_PORT% -u%DB_USER% -p%DB_PASS% --silent ping >nul 2>&1
exit /b %errorlevel%

rem :beiseite GRUND  benennt den Datenordner in data-GRUND-JJJJMMTT-hhmmss um
:beiseite
set "STAMP=%DATE:~-4%%DATE:~3,2%%DATE:~0,2%-%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "STAMP=%STAMP: =0%"
set "STAMP=%STAMP:/=%"
set "STAMP=%STAMP::=%"
set "STAMP=%STAMP:.=%"
ren "%DATA%" "data-%~1-%STAMP%"
if errorlevel 1 exit /b 1
echo  Alter Stand liegt jetzt in: %SQLLABOR_DATA%\data-%~1-%STAMP%
exit /b 0

:fehler_beiseite
echo.
echo  FEHLER: Der Datenordner laesst sich nicht umbenennen (noch in Benutzung?).
echo  PC abmelden und neu anmelden, dann START.bat noch einmal.
pause
exit /b 1

:fehler_install
echo.
echo  FEHLER: Die Datenbank liess sich nicht anlegen (mariadb-install-db):
type "%SQLLABOR_DATA%\install.log"
echo  Bitte TEST.bat ausfuehren und das Testprotokoll der Lehrkraft zeigen.
pause
exit /b 1

:fehler_server
echo.
echo  Auch eine frisch angelegte Datenbank startet nicht.
echo  Bitte TEST.bat ausfuehren und das Testprotokoll der Lehrkraft zeigen.
pause
exit /b 1

:fehler_import
echo.
echo  FEHLER: northwind liess sich nicht laden.
pause
exit /b 1

:ende_fehler
echo  Nichts geaendert.
pause
exit /b 1
