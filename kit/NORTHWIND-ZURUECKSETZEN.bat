@echo off
setlocal
title SQL-Labor: northwind zuruecksetzen
call "%~dp0app\env.bat"

"%MDB%\mariadb-admin.exe" -h127.0.0.1 -P%DB_PORT% -u%DB_USER% -p%DB_PASS% --silent ping >nul 2>&1
if errorlevel 1 goto aus

echo.
echo  northwind wird geloescht und neu geladen.
echo  Alle eigenen Aenderungen und Tabellen in northwind gehen verloren.
choice /c jn /m " Wirklich zuruecksetzen"
if errorlevel 2 exit /b 0

"%MDB%\mariadb.exe" -h127.0.0.1 -P%DB_PORT% -u%DB_USER% -p%DB_PASS% -e "DROP DATABASE IF EXISTS northwind"
"%MDB%\mariadb.exe" -h127.0.0.1 -P%DB_PORT% -u%DB_USER% -p%DB_PASS% --default-character-set=utf8mb4 < "%APP%\sql\northwind.sql"
if errorlevel 1 goto fehler
echo  Fertig: northwind ist wieder im Ausgangsstand.
ping -n 4 127.0.0.1 >nul
exit /b 0

:aus
echo  Die Datenbank laeuft nicht. Erst START.bat doppelklicken.
pause
exit /b 1

:fehler
echo  FEHLER beim Laden von northwind.
pause
exit /b 1
