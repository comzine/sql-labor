@echo off
setlocal
title SQL-Labor: Test an diesem PC
call "%~dp0app\env.bat"

rem Protokoll neben dem Kit; ist der Ordner schreibgeschuetzt, im Benutzerprofil.
set "LOG=%~dp0testprotokoll.txt"
(echo SQL-Labor Testprotokoll) > "%LOG%" 2>nul || set "LOG=%USERPROFILE%\testprotokoll-sql-labor.txt"
(echo SQL-Labor Testprotokoll) > "%LOG%"

set "E_EXE=?"
set "E_PHP=?"
set "E_LOKAL=?"
set "E_KIT=?"
set "E_HOME=nicht getestet"
set "E_WEB=?"
set "E_HOST=?"

call :log "Zeit: %DATE% %TIME%"
call :log "PC: %COMPUTERNAME%   Benutzer: %USERDOMAIN%\%USERNAME%"
call :log "Kit-Ordner: %~dp0"
call :log "LOCALAPPDATA: %LOCALAPPDATA%"
call :log "HOME: %HOMEDRIVE%%HOMEPATH%   Systemlaufwerk: %SystemDrive%"
ver >> "%LOG%"
echo --- net use --- >> "%LOG%"
net use >> "%LOG%" 2>&1

call :log ""
call :log "=== 1. Sperrvermerk aus dem Internet (Zone.Identifier) ==="
dir /r "%MDB%\mariadbd.exe" | find "Zone.Identifier" >nul
rem Kein zweites "if errorlevel" nach call :log: :log setzt den Errorlevel auf 0.
if errorlevel 1 goto ohne_vermerk
call :log "WARNUNG: Dateien tragen den Vermerk 'aus dem Internet'. Zip vor dem Entpacken entsperren (Eigenschaften, Zulassen)."
goto vermerk_ende
:ohne_vermerk
call :log "kein Sperrvermerk"
:vermerk_ende

call :log ""
call :log "=== 2. Programme starten ==="
"%MDB%\mariadbd.exe" --version >> "%LOG%" 2>&1
if errorlevel 1 set "E_EXE=FEHLER (mariadbd.exe startet nicht, Meldung im Protokoll)"
if not errorlevel 1 set "E_EXE=OK"
call :log "mariadbd.exe: %E_EXE%"
"%PHPDIR%\php.exe" -c "%PHPDIR%\php.ini" -d extension_dir="%PHPDIR%\ext" -v >> "%LOG%" 2>&1
"%PHPDIR%\php.exe" -c "%PHPDIR%\php.ini" -d extension_dir="%PHPDIR%\ext" -m 2>> "%LOG%" | find /i "mysqli" >nul
if errorlevel 1 set "E_PHP=FEHLER (php.exe oder mysqli laeuft nicht)"
if not errorlevel 1 set "E_PHP=OK"
call :log "php.exe mit mysqli: %E_PHP%"

call :log ""
call :log "=== 3. Ports ==="
netstat -an | find ":%DB_PORT% " >> "%LOG%"
if errorlevel 1 call :log "Port %DB_PORT% frei"
netstat -an | find ":%WEB_PORT% " >> "%LOG%"
if errorlevel 1 call :log "Port %WEB_PORT% frei"

call :log ""
call :log "=== 4. Datenablage ==="
call :datentest "%LOCALAPPDATA%\SQL-Labor-Test" "lokale Platte (LOCALAPPDATA)"
set "E_LOKAL=%ERG%"
call :datentest "%~dp0_datentest" "Kit-Ordner"
set "E_KIT=%ERG%"
if /i "%HOMEDRIVE%"=="%SystemDrive%" goto ohne_home
if "%HOMEDRIVE%"=="" goto ohne_home
set "HOMEDIR=%HOMEDRIVE%%HOMEPATH%"
if "%HOMEDIR:~-1%"=="\" set "HOMEDIR=%HOMEDIR:~0,-1%"
call :datentest "%HOMEDIR%\SQL-Labor-Test" "Home-Laufwerk %HOMEDRIVE%"
set "E_HOME=%ERG%"
:ohne_home

call :log ""
call :log "=== 5. Webserver (PHP) ==="
start "SQL-Labor Webtest" /min "%PHPDIR%\php.exe" -c "%PHPDIR%\php.ini" -d extension_dir="%PHPDIR%\ext" -S 127.0.0.1:18081 -t "%WEBROOT%" "%APP%\router.php"
ping -n 3 127.0.0.1 >nul
set "CODE=000"
for /f %%c in ('curl.exe -s -o nul -w "%%{http_code}" --max-time 5 "http://127.0.0.1:18081/lizenz.html" 2^>nul') do set "CODE=%%c"
if "%CODE%"=="200" set "E_WEB=OK"
if not "%CODE%"=="200" set "E_WEB=FEHLER (HTTP %CODE%)"
call :log "Webserver auf 127.0.0.1:18081: %E_WEB%"
rem Fremder Host-Kopf (DNS-Rebinding) muss 403 bekommen.
set "CODE=000"
for /f %%c in ('curl.exe -s -o nul -w "%%{http_code}" --max-time 5 -H "Host: fremd.example:18081" "http://127.0.0.1:18081/lizenz.html" 2^>nul') do set "CODE=%%c"
if "%CODE%"=="403" set "E_HOST=OK"
if not "%CODE%"=="403" set "E_HOST=FEHLER (HTTP %CODE% statt 403)"
call :log "Fremder Host-Kopf abgewiesen: %E_HOST%"
taskkill /fi "WINDOWTITLE eq SQL-Labor Webtest*" /f >nul 2>&1
taskkill /im php.exe /f >nul 2>&1

call :log ""
call :log "=== Ergebnis ==="
call :log "Programme starten:        %E_EXE%"
call :log "PHP mit mysqli:           %E_PHP%"
call :log "Daten lokale Platte:      %E_LOKAL%"
call :log "Daten im Kit-Ordner:      %E_KIT%"
call :log "Daten im Home-Laufwerk:   %E_HOME%"
call :log "Webserver:                %E_WEB%"
call :log "Schutz vor DNS-Rebinding: %E_HOST%"
call :log ""
call :log "Kam waehrend des Tests eine Windows-Sicherheitswarnung (Firewall, SmartScreen)? Bitte notieren."
call :log "Protokoll: %LOG%"
echo.
pause
exit /b 0


rem ---------------------------------------------------------------
rem :datentest ORDNER BESCHREIBUNG
rem Legt in ORDNER\sqllabor-test eine Datenbank an, startet den Server
rem auf Port 13307, schreibt und liest eine InnoDB-Tabelle, beendet ihn
rem und loescht den Testordner wieder. Ergebnis in ERG.
:datentest
set "ERG=?"
set "TBASE=%~1"
set "TD=%~1\sqllabor-test"
call :log "--- %~2: %TD%"
if not exist "%TBASE%\" mkdir "%TBASE%" >nul 2>&1
(echo test) > "%TBASE%\sqllabor-schreibtest.txt" 2>nul
if errorlevel 1 set "ERG=FEHLER (Ordner nicht beschreibbar)"
if errorlevel 1 goto dt_ende
del "%TBASE%\sqllabor-schreibtest.txt" >nul 2>&1
if exist "%TD%\" rd /s /q "%TD%"

call :log "Start %TIME%: mariadb-install-db"
"%MDB%\mariadb-install-db.exe" --datadir="%TD%" --port=13307 >> "%LOG%" 2>&1
if errorlevel 1 set "ERG=FEHLER (mariadb-install-db)"
if errorlevel 1 goto dt_ende

call :log "Start %TIME%: Server"
start "SQL-Labor Datentest" /min "%MDB%\mariadbd.exe" --defaults-file="%TD%\my.ini" --port=13307 --bind-address=127.0.0.1 --init-file="%APP%\sql\init.sql" --log-error="%TD%\server.err"
set /a WARTE=0
:dt_warten
ping -n 2 127.0.0.1 >nul
"%MDB%\mariadb-admin.exe" -h127.0.0.1 -P13307 -u%DB_USER% -p%DB_PASS% --silent ping >nul 2>&1
if not errorlevel 1 goto dt_bereit
set /a WARTE+=1
if %WARTE% lss 30 goto dt_warten
set "ERG=FEHLER (Server antwortet nicht)"
goto dt_log

:dt_bereit
call :log "Bereit %TIME%: schreibe InnoDB-Tabelle"
"%MDB%\mariadb.exe" -h127.0.0.1 -P13307 -u%DB_USER% -p%DB_PASS% -e "CREATE DATABASE t; CREATE TABLE t.x (id INT PRIMARY KEY, n VARCHAR(20)) ENGINE=InnoDB; START TRANSACTION; INSERT INTO t.x VALUES (1,'a'),(2,'b'); COMMIT; SELECT COUNT(*) AS zeilen FROM t.x;" >> "%LOG%" 2>&1
if errorlevel 1 set "ERG=FEHLER (SQL)"
if not errorlevel 1 set "ERG=OK"
"%MDB%\mariadb-admin.exe" -h127.0.0.1 -P13307 -u%DB_USER% -p%DB_PASS% shutdown >> "%LOG%" 2>&1
ping -n 4 127.0.0.1 >nul
call :log "Ende %TIME%"

:dt_log
echo --- server.err --- >> "%LOG%"
if exist "%TD%\server.err" type "%TD%\server.err" >> "%LOG%"
rem Server sicher beenden, bevor der Testordner geloescht wird.
taskkill /fi "WINDOWTITLE eq SQL-Labor Datentest*" /f >nul 2>&1
ping -n 2 127.0.0.1 >nul
if exist "%TD%\" rd /s /q "%TD%"

:dt_ende
call :log "Ergebnis: %ERG%"
exit /b 0


rem :log TEXT  schreibt eine Zeile auf den Bildschirm und ins Protokoll
:log
echo.%~1
>> "%LOG%" echo.%~1
exit /b 0
