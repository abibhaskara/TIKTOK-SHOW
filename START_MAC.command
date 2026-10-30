#!/bin/bash
cd "$(dirname "$0")/bridge-server"
echo "================================================================"
echo "🎬 Starting TikTok Live -> Roblox Show Controller..."
echo "================================================================"
# Free port 3000 if an older background instance is still running
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
if [ ! -d "node_modules" ]; then
  echo "📦 Installing dependencies..."
  npm install
fi
(sleep 2 && open "http://localhost:3000") &
node server.js

