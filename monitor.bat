@echo off
setlocal

:: Set the program name (without path)
set "PROGRAM_NAME=php-cgi.exe"

:: Set the full path of the program
set "PROGRAM_PATH=php-cgi -b 9000 -c ./php.ini"

:LOOP
:: Check if the program is running
tasklist /FI "IMAGENAME eq %PROGRAM_NAME%" | find /I "%PROGRAM_NAME%" >nul
if %ERRORLEVEL% NEQ 0 (
    echo [%TIME%] %PROGRAM_NAME% is not running. Restarting...
    cd php
    start %PROGRAM_PATH%
    cd ..
)

:: Wait for 5 seconds before checking again (adjust as needed)
timeout /t 5 /nobreak >nul
goto LOOP
