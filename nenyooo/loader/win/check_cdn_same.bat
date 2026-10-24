@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "LOCAL_FILE=%~dp0bruh.efi.tester"
set "CDN_URL=https://github.com/Rendererrr/Rendererrr.github.io/raw/refs/heads/main/nenyooo/loader/win/bruh.efi.tester"
set "TEMP_FILE=%TEMP%\bruh.efi.tester.cdn.%RANDOM%.tmp"
set "LAST_STATUS="

echo Watching CDN every second. Press Ctrl+C to stop.
echo Local file: %LOCAL_FILE%
echo.

:check
set "STATUS="
set "LOCAL_HASH="
set "CDN_HASH="

if not exist "%LOCAL_FILE%" (
    set "STATUS=LOCAL FILE NOT FOUND"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri '%CDN_URL%' -OutFile '%TEMP_FILE%' -ErrorAction Stop } catch { exit 1 }" >nul 2>&1
    if errorlevel 1 (
        set "STATUS=CDN DOWNLOAD ERROR"
    ) else (
        for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "(Get-FileHash -LiteralPath '%LOCAL_FILE%' -Algorithm SHA256).Hash"`) do set "LOCAL_HASH=%%A"
        for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "(Get-FileHash -LiteralPath '%TEMP_FILE%' -Algorithm SHA256).Hash"`) do set "CDN_HASH=%%A"
        if /i "!LOCAL_HASH!"=="!CDN_HASH!" (
            set "STATUS=MATCH"
        ) else (
            set "STATUS=DIFFERENT"
        )
    )
)

if /i not "!STATUS!"=="!LAST_STATUS!" (
    echo [%date% %time%] !STATUS!
    if /i "!STATUS!"=="DIFFERENT" (
        echo   Local: !LOCAL_HASH!
        echo   CDN:   !CDN_HASH!
    )
    set "LAST_STATUS=!STATUS!"
)

del /q "%TEMP_FILE%" >nul 2>&1
ping 127.0.0.1 -n 2 >nul
goto check
