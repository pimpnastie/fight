@echo off
REM Double-click to install. Pass a game path if auto-detect fails:  install.bat "D:\Games\Street Fighter 6"
if "%~1"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -GamePath "%~1"
)
pause
