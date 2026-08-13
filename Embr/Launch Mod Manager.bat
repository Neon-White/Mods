@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0EmbrModInstaller.ps1"
echo.
pause
