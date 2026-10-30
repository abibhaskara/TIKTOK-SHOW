# 🎬 TikTok Live → Roblox Avatar Stage Show (Final Production Edition)

Sistem interaktif **TikTok Live ke Roblox** lengkap dengan **Web Controller Dashboard (`http://localhost:3000`)**, **3-Scene Broadcast Camera Director**, **Live Dance & Emote Customizer**, dan dukungan penuh untuk **Roblox Studio** maupun **Roblox Player biasa (Cloud Tunnel)**.

---

## ✨ Fitur Utama (Final Release)

1. **Deteksi Username via Chat & Verifikasi Follower:**
   - Penonton cukup mengetik username Roblox mereka di kolom chat TikTok Live.
   - Jika sudah follow: Avatar 3D mereka langsung spawn di panggung utama, joget dengan lampu sorot & kembang api RGB, lalu berjalan dengan animasi langkah kaki alami menuju area penonton (maksimal 30 avatar aktif di arena).
   - Jika belum follow: Muncul notifikasi pengingat di tengah layar (9:16 portrait), dan otomatis spawn begitu mereka menekan tombol Follow.
2. **🐼 Gift Panda — Giant Titan Avatar (30 Detik) + Smooth POV (10 Detik):**
   - Jika penonton mengirim gift **Panda**, avatar mereka langsung di-*summon* (jika belum ada) atau diperbesar menjadi ukuran **Titan Raksasa (3.0x scale)** selama **30 detik** lengkap dengan aura Emerald & Gold.
   - Kamera POV langsung menyorot karakter raksasa tersebut selama **10 detik** sebelum kembali ke siklus kamera otomatis.
3. **🌹 Gift Rose / Mawar — VIP Spotlight & POV:**
   - Efek partikel mawar + glow emas, tarian VIP, dan sorotan kamera POV.
4. **🧙‍♂️ Gift Topi Penyihir (Witch Hat) — 3 Flying Dragons Event (20 Detik):**
   - Langit berubah menjadi malam dramatis, 3 naga terbang mengelilingi arena sambil menyemburkan api.
5. **🐬 Gift Finger Heart — 5 Leaping Dolphins Event (15 Detik):**
   - 5 lumba-lumba melompat secara melingkar dari permukaan air dengan efek cipratan air.
6. **🎥 3-Scene Broadcast Camera Director (Bebas Glitch):**
   - **Scene 1 (Drone View - 10s):** Kamera udara memutari seluruh arena.
   - **Scene 2 (Paparazzi Cam - 9s):** Bidikan lensa *telephoto handheld* realistis ke 1 karakter acak dari koridor depan yang bebas halangan.
   - **Scene 3 (Pull-In Runway Shot - 8s):** Pergerakan kamera sinematik dari `(50, 63.403, -10.701)` menuju `(50, 63.403, -69.701)`.
   - Dilengkapi *Broadcast Camera Cut* antar-scene dan filter posisi *world-space* sehingga kamera tidak pernah berputar liar atau menembus tembok.
7. **💃 Live Dance & Catalog Emote Controller:**
   - Paste ID Animasi atau ID Catalog Emote Roblox apa saja di `http://localhost:3000` untuk langsung mengganti goyangan seluruh avatar secara *real-time* (dilengkapi *Auto Emote Asset Resolver*).

---

## 🚀 Cara Menjalankan (Mac & Windows 10)

### 1. Menjalankan Bridge Server & Web Controller
* **Di macOS:** Klik 2x file [`START_MAC.command`](./START_MAC.command)
* **Di Windows 10:** Klik 2x file [`START_WINDOWS.bat`](./START_WINDOWS.bat)
* Atau melalui terminal:
  ```bash
  cd bridge-server
  npm install
  npm start
  ```
* Browser akan otomatis membuka **http://localhost:3000**.

---

## 🎮 Cara Main di Roblox Player Biasa (Tanpa Buka Roblox Studio)

Jika Anda ingin menjalankan acara di **Roblox Player biasa** (misal menggunakan **Bloxstrap** atau **Roblox Microsoft Store** di PC Windows 10 agar hemat RAM dan lancar):

1. Buka Web Controller di **http://localhost:3000**.
2. Pada bagian **🌐 Connect to Regular Roblox Player (Public Cloud Tunnel)**, klik tombol:
   **`🚀 Start 1-Click Free Public Tunnel`**
   *(Atau masukkan URL Cloudflare Tunnel / ngrok Anda lalu klik **Save URL**).*
3. Sistem secara otomatis menyinkronkan URL publik tersebut ke `TikTokShowServer.lua` dan atribut `Workspace.PublicBridgeUrl`.
4. Di Roblox Studio (cukup sekali saja), klik **File → Publish to Roblox** untuk menyimpan versi terbaru ke akun Roblox Anda.
5. Tutup Roblox Studio, lalu buka game Anda lewat **Roblox Player biasa**!
6. Semua kontrol di browser (`http://localhost:3000`) maupun dari smartphone Anda akan langsung mengendalikan game di Roblox Player secara *real-time*!

---

## 📂 Struktur File Utama

* [`START_MAC.command`](./START_MAC.command) — One-click starter untuk macOS.
* [`START_WINDOWS.bat`](./START_WINDOWS.bat) — One-click starter untuk Windows 10.
* [`bridge-server/server.js`](./bridge-server/server.js) — Server Node.js penghubung TikTok Live, Tunnel Manager, & API Controller.
* [`bridge-server/dashboard.html`](./bridge-server/dashboard.html) — Web Controller Dashboard lengkap (Simulator, Tunnel, Camera Switcher, Dance Customizer).
* [`roblox-scripts/TikTokShowServer.lua`](./roblox-scripts/TikTokShowServer.lua) — Script Server Roblox (`ServerScriptService.TikTokShowServer`).
* [`roblox-scripts/TikTokShowClient.lua`](./roblox-scripts/TikTokShowClient.lua) — Script Kamera & HUD Client Roblox (`StarterPlayer.StarterPlayerScripts.TikTokShowClient`).
