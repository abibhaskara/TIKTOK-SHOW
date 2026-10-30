@echo off
cd /d "%~dp0bridge-server"
echo ================================================================
echo Starting TikTok Live -^> Roblox Show Controller...
echo ================================================================
if not exist "node_modules" (
  echo Installing dependencies...
  call npm install
)
start "" "http://localhost:3000"
node server.js
pause
