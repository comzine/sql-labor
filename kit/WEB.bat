@echo off
setlocal
title SQL-Labor: Webordner
call "%~dp0app\env.bat"
call "%APP%\webordner.bat"

curl.exe -s -o nul --max-time 2 "http://127.0.0.1:%SUS_PORT%/" >nul 2>&1
if errorlevel 1 goto aus

echo  Webordner: %WEBORDNER%
echo  Im Browser: http://127.0.0.1:%SUS_PORT%/
start "" "%WEBORDNER%"
start "" "http://127.0.0.1:%SUS_PORT%/"
exit /b 0

:aus
echo  Der Webserver fuer eigene Seiten laeuft nicht. Erst START.bat doppelklicken.
pause
exit /b 1
