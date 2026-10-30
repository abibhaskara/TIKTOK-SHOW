# TikTok Live → Roblox Avatar Stage Show

Connects your **TikTok Live** stream to **Roblox Studio**:
1. **Chat Username Detection:** Viewers type **only** their Roblox username in TikTok Live chat (e.g. `builderman`).
2. **Follower Verification:** Checks if the TikTok viewer follows your account (`followRole` metadata + live `follow` event tracking stored in `bridge-server/data/followers.json`).
   - If **Not Following**: Displays an on-screen prompt in Roblox telling `@tiktok_user` to follow first (and automatically spawns their avatar the moment they click Follow!).
   - If **Following**: Spawns their 3D Roblox avatar on the **Main Stage Spotlight**, displays both their **TikTok `@username`** and **Roblox username** overhead, plays a **stage dance/pose** for 4.5 seconds, and walks them into the **Background Crowd**.
3. **🌹 Rose Gift Effect + Camera POV Zoom:** When a viewer sends a **Rose**, their avatar gets a Rose particle & golden glow effect, performs an energetic **VIP dance**, and the **Roblox Camera POV smoothly zooms in onto their avatar** for a few seconds before returning to the Main Stage!

---

## Quick Start Guide

### Step 1: Start the Node.js Bridge Server
Open a terminal in `bridge-server/` and run:

```bash
cd "bridge-server"
npm install
npm start
```

* Edit `bridge-server/.env` (or open **http://localhost:3000** in your browser) to set your `TIKTOK_USERNAME` (e.g. `b455ed`).
* **Important:** Your TikTok account **must be actively broadcasting LIVE right now** before the bridge can connect to it!
* **Bypassing TikTok Bot Protection:** If TikTok blocks automatic username scraping (`Failed to retrieve Room ID`), paste your 19-digit **Room ID** directly into http://localhost:3000 or in `.env`:
  - Open your live stream in a browser: `https://www.tiktok.com/@b455ed/live`
  - Right-click → **View Page Source** (or `Cmd+Option+U` / `Ctrl+U`)
  - Search (`Cmd+F` / `Ctrl+F`) for `"roomId"`
  - Copy the numeric ID (e.g. `7429182749182374912`) and paste it into the Dashboard to connect immediately!
* Keep **http://localhost:3000** open to test spawning avatars, non-follower alerts, and Rose Gift Camera POV zooms even before going live!

### Step 2: Set Up Roblox Studio (Takes 2 Minutes)
1. Open **Roblox Studio** and create a new **Baseplate** place (and save it so Game Settings is accessible).
2. Go to **Home / File → Game Settings → Security** and turn **ON** `Allow HTTP Requests`.
3. In the **Explorer** window:
   * Right-click **`ServerScriptService`** → **Insert Object** → **`Script`**. Name it `TikTokShowServer` and paste the contents of [`roblox-scripts/TikTokShowServer.lua`](./roblox-scripts/TikTokShowServer.lua).
   * Expand **`StarterPlayer` → `StarterPlayerScripts`**, right-click → **Insert Object** → **`LocalScript`**. Name it `TikTokShowClient` and paste the contents of [`roblox-scripts/TikTokShowClient.lua`](./roblox-scripts/TikTokShowClient.lua).
4. Press **Play** in Roblox Studio! The scripts will automatically build the 3D Main Stage, Spotlight, Background Crowd floor, Camera angle, and Stream Overlay HUD.

# roblox_tiktokshow
# roblox_tiktokshow
# roblox_tiktokshow
