@echo off
REM Mods ON + SF6 blocked from the internet, then launches the game. Training Mode only.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0mode.ps1" -Mode Modded
pause
