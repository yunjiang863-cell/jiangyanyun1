@echo off
cd /d "%~dp0"
set "PWSUITE_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "PWSUITE_PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%PWSUITE_PS%" -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Suite.ps1"
if errorlevel 1 pause
