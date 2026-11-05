@echo off
setlocal
title SQL-Labor beenden
call "%~dp0app\env.bat"

echo  Beende den Datenbankserver ...
"%MDB%\mariadb-admin.exe" -h127.0.0.1 -P%DB_PORT% -u%DB_USER% -p%DB_PASS% shutdown >nul 2>&1
echo  Beende den Webserver ...
taskkill /im php.exe /f >nul 2>&1
echo  Fertig. Die Daten bleiben in %DATA%
ping -n 3 127.0.0.1 >nul
