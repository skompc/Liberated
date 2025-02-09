@echo off
setlocal

:: Find and terminate the monitoring script

:: Get the PIDs of all cmd.exe processes running
for /f "tokens=2 delims=," %%a in ('tasklist /FI "IMAGENAME eq cmd.exe" /FO CSV /NH') do (
    tasklist /FI "PID eq %%a" /V | find /I "monitor.bat" >nul
    if not errorlevel 1 (
        echo Stopping monitor.bat (PID: %%a)
        taskkill /PID %%a /F
    )
)

echo Monitoring script stopped.
exit
