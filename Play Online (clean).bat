@echo off
REM Mods OFF + internet block removed, then launches the game exactly like an unmodded install.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0mode.ps1" -Mode Online
pause
