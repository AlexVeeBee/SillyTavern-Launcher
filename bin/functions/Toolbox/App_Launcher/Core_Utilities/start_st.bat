@echo off

REM Check if the folder exists
if not exist "%st_install_path%" (
    echo %red_bg%[%time%]%reset% %red_fg_strong%[ERROR] Directory:%reset% %red_bg%SillyTavern%reset% %red_fg_strong%not found.%reset%
    echo %red_fg_strong%Please make sure SillyTavern is located in: %~dp0%reset%
    pause
    exit /b 1
)

REM Check if Node.js is installed
node --version > nul 2>&1
if %errorlevel% neq 0 (
    echo %red_bg%[%time%]%reset% %red_fg_strong%[ERROR] node command not found in PATH.%reset%
    echo %red_fg_strong%Node.js is not installed or not found in the system PATH.%reset%
    echo %red_fg_strong%To install Node.js go to:%reset% %blue_bg%/ Toolbox / App Installer / Core Utilities / Install Node.js%reset%
    pause
    exit /b 1
)

setlocal
set "command=%~1"
start /B cmd /C "%command%"
for /f "tokens=2 delims=," %%a in ('tasklist /FI "IMAGENAME eq cmd.exe" /FO CSV /NH') do (
    set "pid=%%a"
    echo %blue_bg%[%time%]%reset% %blue_fg_strong%[INFO]%reset% Started process with PID: %cyan_fg_strong%!pid!%reset%
    echo !pid!>>"%log_dir%\pids.txt"
    goto :st_found_pid
)
:st_found_pid
endlocal

REM Check if SSL info file exists and set the command accordingly
set "sslPathsFound=false"
if exist "%SSL_INFO_FILE%" (
    for /f %%i in ('type "%SSL_INFO_FILE%"') do (
        set "sslPathsFound=true"
        goto :ST_SSL_Start
    )
)

:ST_SSL_Start
if "%sslPathsFound%"=="true" (
    echo %blue_bg%[%time%]%reset% %blue_fg_strong%[INFO]%reset% SillyTavern opened with SSL in a new window.
    start cmd /k "title SillyTavern && cd /d %st_install_path% && call npm install --no-audit --no-fund --loglevel=error --no-progress --omit=dev && call %functions_dir%\Home\log_wrapper.bat ssl"
) else (
    echo %blue_bg%[%time%]%reset% %blue_fg_strong%[INFO]%reset% SillyTavern opened in a new window.
    start cmd /k "title SillyTavern && cd /d %st_install_path% && call npm install --no-audit --no-fund --loglevel=error --no-progress --omit=dev && call %functions_dir%\Home\log_wrapper.bat"
)

REM Clear the old log file if it exists
if exist "%logs_st_console_path%" (
    del "%logs_st_console_path%"
)
REM Wait for log file to be created, timeout after 30 seconds (10 iterations of 3 seconds)
echo %blue_bg%[%time%]%reset% %blue_fg_strong%[INFO]%reset% Waiting for 30 seconds for SillyTavern to fully launch...
set "counter=0"
:wait_for_log
timeout /t 3 > nul
set /a counter+=1
if not exist "%logs_st_console_path%" (
    if %counter% lss 10 (
        goto :wait_for_log
    ) else (
        echo %red_bg%[%time%]%reset% %red_fg_strong%[ERROR]%reset% Log file not found, something went wrong. Launching ST with fallback method.
        goto :fallback
    )
)

goto :scan_log

:fallback
REM Fallback to %st_install_path% and start
echo %blue_bg%[%time%]%reset% %blue_fg_strong%[INFO]%reset% Fallback: Starting SillyTavern from %st_install_path%...
start cmd /k "title SillyTavern && cd /d %st_install_path% && call npm install --no-audit --no-fund --loglevel=error --no-progress --omit=dev && call Start.bat"
echo %blue_bg%[%time%]%reset% %blue_fg_strong%[INFO]%reset% SillyTavern should now be launching in a new window, if you still receive errors please contact the launcher devs in the #launcher-help channel on discord.
timeout /t 10
exit /b 1

:scan_log
echo %blue_bg%[%time%]%reset% %blue_fg_strong%[INFO]%reset% Log file found, scanning log for errors...

:loop
REM Use PowerShell to search for the error message
powershell -Command "try { $content = Get-Content '%logs_st_console_path%' -Raw; if ($content -match 'Error: Cannot find module') { exit 1 } elseif ($content -match 'SillyTavern is listening' -or $content -match 'Go to' -or $content -match '\[\s*\r?\n\s*\x27') { exit 0 } else { exit 2 } } catch { exit 2 }"
set "ps_errorlevel=%errorlevel%"

if %ps_errorlevel% equ 0 (
    echo %blue_bg%[%time%]%reset% %blue_fg_strong%[INFO]%reset% %green_fg_strong%SillyTavern Launched Successfully. Returning home...%reset%
    timeout /t 10
    exit /b 0
) else if %ps_errorlevel% equ 1 (
    echo %red_bg%[%time%]%reset% %red_fg_strong%[ERROR] Node.js Code: MODULE_NOT_FOUND%reset%
    goto :attemptnodefix
) else (
    timeout /t 3 > nul
    goto :loop
)

:attemptnodefix
set /p "choice=Run troubleshooter to fix this error? (If yes, close any open SillyTavern Command Windows first)  [Y/n]: "
if /i "%choice%"=="" set choice=Y
if /i "%choice%"=="Y" (
    set "caller=home"
    call "%troubleshooting_dir%\remove_node_modules.bat"
    if %errorlevel% equ 0 goto :home
)
exit /b 1
