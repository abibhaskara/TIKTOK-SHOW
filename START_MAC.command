#!/bin/bash
cd "$(dirname "$0")/bridge-server"
echo "================================================================"
echo "🎬 Starting TikTok Live -> Roblox Show Controller..."
echo "================================================================"
if [ ! -d "node_modules" ]; then
  echo "📦 Installing dependencies..."
  npm install
fi
(sleep 2 && open "http://localhost:3000") &
node server.js
