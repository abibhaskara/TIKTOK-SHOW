#!/bin/bash
cd "$(dirname "$0")/bridge-server"
echo "================================================================"
echo "🎬 Starting TikTok Live -> Roblox Show Controller..."
echo "================================================================"
# Free port 3000 gracefully so localtunnel releases the fixed subdomain immediately
lsof -ti:3000 | xargs kill -15 2>/dev/null || true
sleep 1
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
if [ ! -d "node_modules" ]; then
  echo "📦 Installing dependencies..."
  npm install
fi
(sleep 2 && open "http://localhost:3000") &
node server.js

