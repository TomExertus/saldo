@echo off
title Saldo e Movimenti - Avvio Rapido Windows
set "APP_URL=file:///%~dp0..\www\index.html"
set "APP_URL=%APP_URL:\=/%"

where msedge >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    start "" msedge --app="%APP_URL%" --window-size=1200,860
    exit /b 0
)

if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" (
    start "" "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" --app="%APP_URL%" --window-size=1200,860
    exit /b 0
)

if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" (
    start "" "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" --app="%APP_URL%" --window-size=1200,860
    exit /b 0
)

start "" "%~dp0..\www\index.html"
