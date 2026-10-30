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
4. **🎩 Gift Hat and Mustache (Topi dan Kumis) — 3 Flying Dragons Event (20 Detik):**
   - Langit berubah menjadi malam dramatis, 3 naga terbang mengelilingi arena sambil menyemburkan api.
5. **🐬 Gift Finger Heart — 5 Leaping Dolphins Event (15 Detik):**
   - 5 lumba-lumba melompat secara melingkar dari permukaan air dengan efek cipratan air.
6. **🥔 Gift Potato (Kentang) — Giant Tsunami Wave Event (15 Detik):**
   - Gelombang Tsunami raksasa muncul (`Transparency 1 → 0` dalam 2 detik), menerjang dari `(59.32, 34.43, -689.134)` menuju `(59.32, 74.414, 77.776)` selama 15 detik, dan memudar (`0 → 1` di detik 12–15).
7. **🎲 Auto Random Gift Loop (Slider 1s – 30s):**
   - Secara otomatis memberikan efek gift acak ke avatar aktif dengan interval yang bisa diatur *real-time* lewat slider **1 detik hingga 30 detik** (default `7s`):
     - **🐼 Panda Gigantic (30s Giant + 10s POV):** peluang **15%**
     - **🌹 Rose VIP**, **🎩 3 Dragons**, dan **🐬 5 Leaping Dolphins:** membagi rata **85%** sisanya (~28.3% masing-masing).
8. **🎥 3-Scene Broadcast Camera Director (Bebas Glitch):**
   - **Scene 1 (Drone View - 10s):** Kamera udara memutari seluruh arena.
   - **Scene 2 (Paparazzi Cam - 9s):** Bidikan lensa *telephoto handheld* realistis ke 1 karakter acak dari koridor depan yang bebas halangan.
   - **Scene 3 (Pull-In Runway Shot - 8s):** Pergerakan kamera sinematik dari `(50, 63.403, -10.701)` menuju `(50, 63.403, -69.701)`.
   - Dilengkapi *Broadcast Camera Cut* antar-scene dan filter posisi *world-space* sehingga kamera tidak pernah berputar liar atau menembus tembok.
9. **💃 Live Dance & Catalog Emote Controller (Tersimpan Permanen):**
   - Paste ID Animasi atau ID Catalog Emote Roblox apa saja di `http://localhost:3000` untuk langsung mengganti goyangan seluruh avatar secara *real-time* (dilengkapi *Auto Emote Asset Resolver*). Semua pengaturan tersimpan di `bridge-server/data/dance_config.json` dan otomatis disinkronkan saat game Roblox terhubung.

---

## 🚀 Cara Memulai Kembali (Mac & Windows 10)

### Di macOS
1. Klik 2x file [`START_MAC.command`](./START_MAC.command) *(atau jalankan `./START_MAC.command` di Terminal)*.
2. Script otomatis menutup proses lama di port `3000`, menyalakan server lokal, menghidupkan **Public Tunnel otomatis**, dan membuka **http://localhost:3000**.

### Di Windows 10 / 11
1. Tarik update terbaru (`git pull`) atau salin folder project terbaru ke PC Windows Anda.
2. Klik 2x file [`START_WINDOWS.bat`](./START_WINDOWS.bat).
3. Script otomatis membersihkan port `3000` jika ada proses lama, meng-install dependency jika belum ada, menyalakan **Public Tunnel otomatis**, dan membuka **http://localhost:3000**.

---

## 🎮 Cara Main di Roblox Player Biasa (Tanpa Buka Roblox Studio)

1. Jalankan [`START_MAC.command`](./START_MAC.command) (Mac) atau [`START_WINDOWS.bat`](./START_WINDOWS.bat) (Windows).
2. Tunggu 2–3 detik hingga di terminal/log muncul pesan:
   `🌐 [PUBLIC TUNNELS ACTIVE] Listening on: https://fast-days-sin.loca.lt, ...`
3. Langsung buka game Anda di **Roblox Player biasa** (atau **Bloxstrap**).
4. Lihat pojok kanan atas di **http://localhost:3000** — badge akan otomatis berubah menjadi hijau:
   **`🎮 Connected: Roblox Player (Cloud)`**
5. Sekarang semua tombol simulator, slider interval (1s–30s), kamera, dan dance di **http://localhost:3000** akan langsung mengendalikan game Anda secara *real-time*!

*(Catatan: Jika suatu saat Anda ingin meng-update script di dalam Roblox Studio secara manual, cukup copy isi file [`roblox-scripts/TikTokShowServer.lua`](./roblox-scripts/TikTokShowServer.lua) ke `ServerScriptService.TikTokShowServer` dan [`roblox-scripts/TikTokShowClient.lua`](./roblox-scripts/TikTokShowClient.lua) ke `StarterPlayer.StarterPlayerScripts.TikTokShowClient`, lalu klik **File → Publish to Roblox**).*

---

## 📂 Struktur File Utama

* [`START_MAC.command`](./START_MAC.command) — One-click starter untuk macOS.
* [`START_WINDOWS.bat`](./START_WINDOWS.bat) — One-click starter untuk Windows 10.
* [`bridge-server/server.js`](./bridge-server/server.js) — Server Node.js penghubung TikTok Live, Tunnel Manager, & API Controller.
* [`bridge-server/dashboard.html`](./bridge-server/dashboard.html) — Web Controller Dashboard lengkap (Simulator, Tunnel, Camera Switcher, Dance Customizer).
* [`roblox-scripts/TikTokShowServer.lua`](./roblox-scripts/TikTokShowServer.lua) — Script Server Roblox (`ServerScriptService.TikTokShowServer`).
* [`roblox-scripts/TikTokShowClient.lua`](./roblox-scripts/TikTokShowClient.lua) — Script Kamera & HUD Client Roblox (`StarterPlayer.StarterPlayerScripts.TikTokShowClient`).
