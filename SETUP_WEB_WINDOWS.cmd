@echo off
setlocal
cd /d "%~dp0"
echo ============================================================
echo Halaqah Web Setup - React / Next.js / TypeScript
echo ============================================================
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\tools\setup_web.ps1" -CleanCache
if errorlevel 1 (
  echo.
  echo Setup failed. Keep this window open and send the error shown above.
  pause
  exit /b 1
)
echo.
echo Setup succeeded. Reopen VS Code, then use:
echo TypeScript: Restart TS Server
echo.
pause
endlocal
