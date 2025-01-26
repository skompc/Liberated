@echo off
echo IP Address List
echo.
netsh interface ip show address | findstr "IP Address"
echo. 
echo.
echo Now you should configure DNS settings with the first
echo address shown above (Usually it's the first. 
echo It should look like 192.168.xxx.xxx.)
echo.
echo.

start dnsserver.exe

cd php
start php-cgi -b 9000

cd ../web
call "nginx.exe"