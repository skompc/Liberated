@echo off
echo Stopping NGINX, PHP-CGI, and DNS Server...

REM Stop NGINX
taskkill /F /IM nginx.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo NGINX stopped successfully.
) else (
    echo NGINX is not running or could not be stopped.
)

REM Stop PHP-CGI
taskkill /F /IM php-cgi.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo PHP-CGI stopped successfully.
) else (
    echo PHP-CGI is not running or could not be stopped.
)

REM Stop DNS Server
taskkill /F /IM dnsserver.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo DNS Server stopped successfully.
) else (
    echo DNS Server is not running or could not be stopped.
)

echo All processes stopped.
pause
