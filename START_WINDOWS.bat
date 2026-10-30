@echo off
title TikTok Live -^> Roblox Show Controller
cd /d "%~dp0bridge-server"
echo ================================================================
echo Starting TikTok Live -^> Roblox Show Controller (Windows 10/11)...
echo ================================================================

:: Free port 3000 if an older background node process is still running
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :3000 ^| findstr LISTENING') do (
  taskkill /f /pid %%a >nul 2>&1
)

if not exist "node_modules" (
  echo Installing dependencies...
  call npm install
)

:: Open http://localhost:3000 automatically after 2 seconds
start /b cmd /c "timeout /t 2 /nobreak >nul && start "" http://localhost:3000"

node server.js
pause

