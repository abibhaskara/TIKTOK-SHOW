require("dotenv").config();
const express = require("express");
const cors = require("cors");
const fs = require("fs");
const path = require("path");
const { TikTokLiveConnection, WebcastPushConnection } = require("tiktok-live-connector");
const LiveConnectionClass = TikTokLiveConnection || WebcastPushConnection;
const { extractCandidateUsername, resolveRobloxUsername } = require("./robloxApi");

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;
let currentTikTokUsername = (process.env.TIKTOK_USERNAME || "").replace(/^@/, "").trim();
let bypassFollowerCheck = String(process.env.BYPASS_FOLLOWER_CHECK).toLowerCase() === "true";

// ============================================================================
// Persistent Data Storage (Followers, User Mappings, & Dance Configuration)
// ============================================================================
const DATA_DIR = path.join(__dirname, "data");
const FOLLOWERS_FILE = path.join(DATA_DIR, "followers.json");
const MAPPINGS_FILE = path.join(DATA_DIR, "user_mappings.json");
const DANCE_CONFIG_FILE = path.join(DATA_DIR, "dance_config.json");

if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

function loadJson(filePath, defaultVal) {
  try {
    if (fs.existsSync(filePath)) {
      return JSON.parse(fs.readFileSync(filePath, "utf8"));
    }
  } catch (err) {
    console.error(`[Storage] Failed to load ${filePath}:`, err.message);
  }
  return defaultVal;
}

function saveJson(filePath, data) {
  try {
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2), "utf8");
  } catch (err) {
    console.error(`[Storage] Failed to save ${filePath}:`, err.message);
  }
}

// Default Built-in Roblox R15 Animations
const DEFAULT_DANCE_CONFIG = {
  avatarScale: 1.45,
  stageDances: [
    "rbxassetid://104131847054135"
  ],
  crowdDances: [
    "rbxassetid://104131847054135",
  ],
  vipDances: [
    "rbxassetid://507776043",
    "rbxassetid://507777268",
    "rbxassetid://507770677"
  ]
};

let danceConfig = loadJson(DANCE_CONFIG_FILE, DEFAULT_DANCE_CONFIG);
if (!danceConfig.avatarScale) {
  danceConfig.avatarScale = 1.45;
}

function normalizeAnimationId(input) {
  if (!input) return null;
  const str = String(input).trim();
  const digits = str.match(/\d{6,}/);
  if (digits) {
    return `rbxassetid://${digits[0]}`;
  }
  return null;
}

function normalizeAnimationList(list, defaultList) {
  if (!list) return defaultList;
  let items = [];
  if (Array.isArray(list)) {
    items = list;
  } else if (typeof list === "string") {
    items = list.split(/[\n,;]+/).map(s => s.trim()).filter(Boolean);
  }
  const normalized = items.map(normalizeAnimationId).filter(Boolean);
  return normalized.length > 0 ? normalized : defaultList;
}

// Set of lowercase TikTok uniqueIds known to follow the host
const followerSet = new Set(loadJson(FOLLOWERS_FILE, []));
// Map of lowercase TikTok uniqueId -> { robloxUserId, robloxUsername, robloxDisplayName, tiktokUniqueId, tiktokNickname }
const userMappings = loadJson(MAPPINGS_FILE, {});
// Pending Roblox lookups for viewers who commented their Roblox username BEFORE following
const pendingUnfollowedSpawns = new Map();
// Per-user spawn cooldown (tiktokUniqueId -> timestamp ms)
const spawnCooldowns = new Map();
const SPAWN_COOLDOWN_MS = 15000; // 15 seconds between free chat spawns per user

function markAsFollower(tiktokUniqueId) {
  if (!tiktokUniqueId) return;
  const key = tiktokUniqueId.toLowerCase();
  if (!followerSet.has(key)) {
    followerSet.add(key);
    saveJson(FOLLOWERS_FILE, Array.from(followerSet));
  }
}

function extractTikTokUser(data) {
  const userObj = data?.user || data || {};
  const uniqueId = userObj.displayId || userObj.uniqueId || data?.displayId || data?.uniqueId || "";
  const nickname = userObj.nickname || data?.nickname || uniqueId || "viewer";
  const followRole =
    userObj.followInfo?.followStatus ??
    userObj.followStatus ??
    (userObj.isFollowing ? 1 : 0) ??
    data?.followRole ??
    data?.followInfo?.followStatus ??
    data?.userDetails?.followRole ??
    0;
  return { uniqueId, nickname, followRole: Number(followRole) || 0 };
}

function isUserFollower(data) {
  if (bypassFollowerCheck) return true;
  const { uniqueId, followRole } = extractTikTokUser(data);
  if (!uniqueId) return false;

  const key = uniqueId.toLowerCase();

  // Check 1: TikTok event metadata (followRole/followStatus: 1 = following, 2 = mutual friend)
  if (followRole >= 1) {
    markAsFollower(key);
    return true;
  }

  // Check 2: Persistent local follower database (recorded from live follow events)
  return followerSet.has(key);
}

function saveUserMapping(tiktokUniqueId, tiktokNickname, robloxProfile) {
  const key = tiktokUniqueId.toLowerCase();
  userMappings[key] = {
    tiktokUniqueId,
    tiktokNickname: tiktokNickname || tiktokUniqueId,
    robloxUserId: robloxProfile.userId,
    robloxUsername: robloxProfile.username,
    robloxDisplayName: robloxProfile.displayName,
    updatedAt: new Date().toISOString()
  };
  saveJson(MAPPINGS_FILE, userMappings);
}

// ============================================================================
// Event Queue for Roblox Studio (Polled via GET /api/events)
// ============================================================================
const robloxEventQueue = [];
const recentLogs = [];

function addLog(type, message, meta = {}) {
  const entry = {
    id: Date.now() + "-" + Math.random().toString(36).slice(2, 6),
    time: new Date().toLocaleTimeString(),
    type,
    message,
    meta
  };
  recentLogs.unshift(entry);
  if (recentLogs.length > 60) recentLogs.pop();
  console.log(`[${entry.time}] [${type.toUpperCase()}] ${message}`);
}

function enqueueRobloxEvent(eventPayload) {
  robloxEventQueue.push({
    id: Date.now() + "-" + Math.random().toString(36).slice(2, 7),
    timestamp: Date.now(),
    ...eventPayload
  });
  // Cap queue size in case Roblox Studio isn't running yet
  if (robloxEventQueue.length > 100) {
    robloxEventQueue.shift();
  }
}

// ============================================================================
// Core Handlers: Chat, Follow, and Gift (Rose)
// ============================================================================
async function handleChatEvent(data) {
  const { uniqueId: rawId, nickname: tiktokNickname } = extractTikTokUser(data);
  const tiktokUniqueId = rawId || "viewer";
  const comment = (data.content || data.comment || "").trim();

  if (!comment) return;

  // Log all incoming live comments so streamer can see real-time chat in the dashboard!
  addLog("chat", `💬 @${tiktokUniqueId}: "${comment}"`);

  // 1. Check if the chat message is a candidate Roblox username
  const candidate = extractCandidateUsername(comment);
  if (!candidate) {
    return; // Normal chat comment (already logged)
  }

  // 2. Resolve the Roblox username via Roblox API
  const robloxProfile = await resolveRobloxUsername(candidate);
  if (!robloxProfile) {
    addLog("chat_ignored", `@${tiktokUniqueId} typed "${comment}" (Not a valid Roblox account)`);
    return;
  }

  // Save the TikTok -> Roblox mapping so future Rose gifts know their Roblox avatar!
  saveUserMapping(tiktokUniqueId, tiktokNickname, robloxProfile);

  // 3. Check if the TikTok user follows the host account
  const followed = isUserFollower(data);
  if (!followed) {
    pendingUnfollowedSpawns.set(tiktokUniqueId.toLowerCase(), {
      tiktokUniqueId,
      tiktokNickname,
      robloxProfile
    });

    addLog(
      "not_following",
      `@${tiktokUniqueId} wants to spawn "${robloxProfile.username}" — NOT FOLLOWING YET!`
    );

    enqueueRobloxEvent({
      type: "not_following",
      tiktokUniqueId,
      tiktokNickname,
      robloxUserId: robloxProfile.userId,
      robloxUsername: robloxProfile.username,
      robloxDisplayName: robloxProfile.displayName
    });
    return;
  }

  // 4. Check cooldown so one user doesn't flood the queue
  const now = Date.now();
  const lastSpawn = spawnCooldowns.get(tiktokUniqueId.toLowerCase()) || 0;
  if (now - lastSpawn < SPAWN_COOLDOWN_MS) {
    return;
  }
  spawnCooldowns.set(tiktokUniqueId.toLowerCase(), now);

  addLog(
    "spawn_avatar",
    `✅ Verified Follower @${tiktokUniqueId} -> Spawning Roblox Avatar: ${robloxProfile.username} (${robloxProfile.userId})`
  );

  enqueueRobloxEvent({
    type: "spawn_avatar",
    tiktokUniqueId,
    tiktokNickname,
    robloxUserId: robloxProfile.userId,
    robloxUsername: robloxProfile.username,
    robloxDisplayName: robloxProfile.displayName
  });
}

function handleFollowEvent(data) {
  const { uniqueId: tiktokUniqueId, nickname: tiktokNickname } = extractTikTokUser(data);
  if (!tiktokUniqueId) return;

  markAsFollower(tiktokUniqueId);
  const key = tiktokUniqueId.toLowerCase();

  // If this viewer already typed their Roblox username before clicking follow, spawn them automatically!
  if (pendingUnfollowedSpawns.has(key)) {
    const pending = pendingUnfollowedSpawns.get(key);
    pendingUnfollowedSpawns.delete(key);

    addLog(
      "follow_auto_spawn",
      `🎉 @${tiktokUniqueId} just followed! Auto-spawning their Roblox avatar: ${pending.robloxProfile.username}`
    );

    enqueueRobloxEvent({
      type: "spawn_avatar",
      tiktokUniqueId: pending.tiktokUniqueId,
      tiktokNickname: pending.tiktokNickname,
      robloxUserId: pending.robloxProfile.userId,
      robloxUsername: pending.robloxProfile.username,
      robloxDisplayName: pending.robloxProfile.displayName,
      justFollowed: true
    });
  } else {
    addLog("follow", `➕ @${tiktokUniqueId} followed the stream! (Saved to verified followers)`);
    enqueueRobloxEvent({
      type: "new_follower",
      tiktokUniqueId,
      tiktokNickname
    });
  }
}

async function handleGiftEvent(data) {
  const giftType = data.giftDetails?.giftType ?? data.giftType ?? 0;
  const repeatCount = data.repeatCount || 1;
  // Ignore streak in-progress events for streakable gifts (Type 1) until repeatEnd or first send
  if (giftType === 1 && !data.repeatEnd && repeatCount > 1) {
    return;
  }

  const { uniqueId: rawId, nickname: tiktokNickname } = extractTikTokUser(data);
  const tiktokUniqueId = rawId || "gifter";
  const giftName = (data.giftDetails?.giftName || data.gift?.name || data.giftName || "Rose").trim();
  const giftId = data.giftId;
  const giftNameLower = giftName.toLowerCase();

  // 1. Check for "Topi Penyihir" / "Witch Hat" / "Wizard Hat" gift event
  const isWitchHat =
    giftNameLower.includes("topi penyihir") ||
    giftNameLower.includes("witch hat") ||
    giftNameLower.includes("wizard hat") ||
    giftNameLower.includes("penyihir");

  if (isWitchHat) {
    markAsFollower(tiktokUniqueId);
    addLog(
      "witch_hat_dragon",
      `🧙‍♂️ @${tiktokUniqueId} sent "${giftName}"! Unleashing 3 flying dragons rotating the stage!`
    );
    enqueueRobloxEvent({
      type: "witch_hat_dragon",
      tiktokUniqueId,
      tiktokNickname,
      giftName,
      repeatCount
    });
    return;
  }

  // 2. Check for "Finger Heart" / "Finger Heartsh" gift event
  const isFingerHeart =
    giftNameLower.includes("finger heart") ||
    giftNameLower.includes("fingerheart") ||
    giftNameLower.includes("hati") ||
    giftNameLower.includes("heart");

  if (isFingerHeart && !giftNameLower.includes("rose")) {
    markAsFollower(tiktokUniqueId);
    addLog(
      "finger_heart_dolphin",
      `🐬 @${tiktokUniqueId} sent "${giftName}"! Unleashing 5 leaping dolphins with water splashes!`
    );
    enqueueRobloxEvent({
      type: "finger_heart_dolphin",
      tiktokUniqueId,
      tiktokNickname,
      giftName,
      repeatCount
    });
    return;
  }

  // 3. Check for "Panda" gift event (Summons or Enlarges avatar to Giant size for 30s + 10s POV)
  const isPanda = giftNameLower.includes("panda");
  if (isPanda) {
    markAsFollower(tiktokUniqueId);

    const key = tiktokUniqueId.toLowerCase();
    let mapping = userMappings[key];

    if (!mapping) {
      const fallbackProfile = await resolveRobloxUsername(tiktokUniqueId);
      if (fallbackProfile) {
        saveUserMapping(tiktokUniqueId, tiktokNickname, fallbackProfile);
        mapping = userMappings[key];
      }
    }

    addLog(
      "gift_panda",
      `🐼 @${tiktokUniqueId} sent Panda Gift! Summoning/Enlarging Giant Avatar for 30s (10s POV)!`
    );

    enqueueRobloxEvent({
      type: "panda_gift",
      tiktokUniqueId,
      tiktokNickname,
      robloxUserId: mapping ? mapping.robloxUserId : null,
      robloxUsername: mapping ? mapping.robloxUsername : tiktokUniqueId,
      robloxDisplayName: mapping ? mapping.robloxDisplayName : tiktokNickname,
      giftName: "Panda",
      repeatCount
    });
    return;
  }

  // Check if the gift is a Rose (giftId 5655 is standard TikTok Rose, or name includes "rose") or any gift
  const isRose =
    giftId === 5655 ||
    giftNameLower.includes("rose") ||
    giftNameLower.includes("mawar") ||
    true; // Trigger VIP Rose spotlight for Rose (and other gifts!)

  if (!isRose) return;

  // Anyone who sends a gift is also granted follower access if needed
  markAsFollower(tiktokUniqueId);

  const key = tiktokUniqueId.toLowerCase();
  let mapping = userMappings[key];

  // If the gifter hasn't typed a Roblox username in chat yet, check if their TikTok uniqueId itself is a valid Roblox username
  if (!mapping) {
    const fallbackProfile = await resolveRobloxUsername(tiktokUniqueId);
    if (fallbackProfile) {
      saveUserMapping(tiktokUniqueId, tiktokNickname, fallbackProfile);
      mapping = userMappings[key];
    }
  }

  addLog(
    "rose_gift",
    `🌹 @${tiktokUniqueId} sent ${repeatCount}x ${giftName}! Triggering Rose Effect, VIP Dance & Camera POV!`
  );

  enqueueRobloxEvent({
    type: "rose_gift",
    tiktokUniqueId,
    tiktokNickname,
    giftName,
    repeatCount,
    robloxUserId: mapping ? mapping.robloxUserId : null,
    robloxUsername: mapping ? mapping.robloxUsername : null,
    robloxDisplayName: mapping ? mapping.robloxDisplayName : null
  });
}

// ============================================================================
// TikTok Live Connection Manager
// ============================================================================
let tiktokConnection = null;
let connectionState = {
  connected: false,
  username: currentTikTokUsername,
  roomId: null,
  error: null
};

async function connectToTikTok(target) {
  let raw = (target || "").trim();
  let cleanUser = raw.replace(/^@/, "").trim();
  let explicitRoomId = null;

  // 1. Check if input is a direct numeric Room ID (15+ digits)
  if (/^\d{15,22}$/.test(cleanUser)) {
    explicitRoomId = cleanUser;
    cleanUser = "Room_" + explicitRoomId;
  }
  // 2. Check if input is a URL containing room_id
  else if (cleanUser.includes("room_id=")) {
    const match = cleanUser.match(/room_id=(\d+)/);
    if (match) {
      explicitRoomId = match[1];
      cleanUser = "Room_" + explicitRoomId;
    }
  }
  // 3. Check if input is a standard TikTok live or profile URL
  else if (cleanUser.includes("tiktok.com/@")) {
    const match = cleanUser.match(/tiktok\.com\/@([a-zA-Z0-9_.-]+)/);
    if (match) {
      cleanUser = match[1];
    }
  }

  if (!cleanUser || cleanUser === "your_tiktok_username") {
    connectionState = {
      connected: false,
      username: cleanUser,
      roomId: null,
      error: "Set your TikTok username or numeric Room ID in .env or via http://localhost:3000"
    };
    addLog("info", "Waiting for TikTok username or Room ID configuration (Test Mode ready at http://localhost:3000)");
    return connectionState;
  }

  if (tiktokConnection) {
    try {
      tiktokConnection.disconnect();
    } catch (_) { }
    tiktokConnection = null;
  }

  currentTikTokUsername = cleanUser;
  const options = {
    processInitialData: false,
    enableExtendedGiftInfo: false
  };

  if (process.env.SIGN_API_KEY && process.env.SIGN_API_KEY.trim() !== "") {
    options.signApiKey = process.env.SIGN_API_KEY.trim();
  }

  if (process.env.TIKTOK_SESSION_ID && process.env.TIKTOK_SESSION_ID.trim() !== "") {
    options.sessionId = process.env.TIKTOK_SESSION_ID.trim();
  }

  tiktokConnection = new LiveConnectionClass(explicitRoomId ? "" : cleanUser, options);

  tiktokConnection.on("chat", (data) => {
    handleChatEvent(data).catch((err) => console.error("[ChatError]", err));
  });

  tiktokConnection.on("follow", (data) => {
    handleFollowEvent(data);
  });

  tiktokConnection.on("member", (data) => {
    const { uniqueId, nickname } = extractTikTokUser(data);
    if (!uniqueId) return;
    addLog("member", `👋 @${uniqueId} joined the live stream! Launching RGB Fireworks!`);
    enqueueRobloxEvent({
      type: "member_join",
      tiktokUniqueId: uniqueId,
      tiktokNickname: nickname
    });
  });

  tiktokConnection.on("social", (data) => {
    if (data?.displayType && String(data.displayType).toLowerCase().includes("follow")) {
      handleFollowEvent(data);
    }
  });

  tiktokConnection.on("gift", (data) => {
    handleGiftEvent(data).catch((err) => console.error("[GiftError]", err));
  });

  tiktokConnection.on("disconnected", () => {
    connectionState.connected = false;
    addLog("warn", `Disconnected from ${explicitRoomId ? "Room " + explicitRoomId : "@" + cleanUser}'s TikTok Live.`);
  });

  tiktokConnection.on("streamEnd", () => {
    connectionState.connected = false;
    addLog("warn", `${explicitRoomId ? "Room " + explicitRoomId : "@" + cleanUser}'s TikTok Live stream ended.`);
  });

  try {
    const label = explicitRoomId ? `Room ID ${explicitRoomId}` : `@${cleanUser}`;
    addLog("info", `Connecting to TikTok Live for ${label}...`);
    const state = await tiktokConnection.connect(explicitRoomId || undefined);
    connectionState = {
      connected: true,
      username: cleanUser,
      roomId: state.roomId,
      error: null
    };
    addLog("success", `Connected to TikTok Live! (Room ID: ${state.roomId})`);
  } catch (err) {
    let friendlyError = err.message || "Failed to connect";
    if (friendlyError.includes("Failed to retrieve Room ID")) {
      friendlyError = "Account is either NOT LIVE right now, or TikTok blocked username lookup. If you are already streaming live, enter your numeric Room ID directly to bypass!";
    } else if (friendlyError.includes("eulerstream.com") || friendlyError.includes("sign a request") || friendlyError.includes("Business plan")) {
      friendlyError = "EulerStream signature required: Get a free API key at https://www.eulerstream.com (no credit card needed) and enter it in the EulerStream API Key box below!";
    }
    connectionState = {
      connected: false,
      username: cleanUser,
      roomId: null,
      error: friendlyError
    };
    addLog("error", `Could not connect to ${cleanUser}: ${friendlyError}`);
  }

  return connectionState;
}

// ============================================================================
// HTTP API Endpoints for Roblox Studio & Local Test Dashboard
// ============================================================================

// 1. Roblox Studio polls this endpoint every 0.5 seconds
app.get("/api/events", (req, res) => {
  const events = robloxEventQueue.splice(0, 15); // Drain up to 15 events per poll
  res.json({
    ok: true,
    events
  });
});

app.get("/api/sync_scripts", (req, res) => {
  res.sendFile(path.join(__dirname, "sync_payload.json"));
});

// 2. Status endpoint for Dashboard
app.get("/api/status", (req, res) => {
  res.json({
    ok: true,
    connectionState,
    bypassFollowerCheck,
    totalVerifiedFollowers: followerSet.size,
    totalMappedUsers: Object.keys(userMappings).length,
    queueLength: robloxEventQueue.length,
    recentLogs,
    danceConfig
  });
});

// 2b. Dance Configuration & Live Control Endpoints
app.get("/api/dance_config", (req, res) => {
  res.json({
    ok: true,
    config: danceConfig
  });
});

app.post("/api/dance_config", (req, res) => {
  const { stageDances, crowdDances, vipDances, forceDanceId, avatarScale } = req.body || {};

  if (avatarScale !== undefined && !isNaN(Number(avatarScale))) {
    danceConfig.avatarScale = Math.max(0.5, Math.min(3.0, Number(avatarScale)));
  }

  if (stageDances !== undefined) {
    danceConfig.stageDances = normalizeAnimationList(stageDances, danceConfig.stageDances);
  }
  if (crowdDances !== undefined) {
    danceConfig.crowdDances = normalizeAnimationList(crowdDances, danceConfig.crowdDances);
  }
  if (vipDances !== undefined) {
    danceConfig.vipDances = normalizeAnimationList(vipDances, danceConfig.vipDances);
  }

  let normalizedForceId = null;
  if (forceDanceId) {
    normalizedForceId = normalizeAnimationId(forceDanceId);
    if (normalizedForceId && crowdDances === undefined) {
      danceConfig.crowdDances = [normalizedForceId];
    }
  }

  saveJson(DANCE_CONFIG_FILE, danceConfig);

  // Enqueue event to update Roblox Studio in real time
  enqueueRobloxEvent({
    type: "update_dance_config",
    avatarScale: danceConfig.avatarScale,
    stageDances: danceConfig.stageDances,
    crowdDances: danceConfig.crowdDances,
    vipDances: danceConfig.vipDances,
    forceDanceId: normalizedForceId
  });

  if (normalizedForceId) {
    addLog("dance", `💃 [DANCE SYNC] Forcing ALL spawned avatars to dance: ${normalizedForceId} (Scale: ${danceConfig.avatarScale}x)`);
  } else {
    addLog("dance", `🎭 [DANCE CONFIG] Updated dance animation playlist! (Avatar Scale: ${danceConfig.avatarScale}x)`);
  }

  res.json({
    ok: true,
    config: danceConfig,
    forceDanceId: normalizedForceId
  });
});

// 2c. Camera Scene Switcher Endpoint (Auto-Cycle, Drone, Paparazzi, Pull-In)
let activeCameraScene = "auto";
app.get("/api/camera_scene", (req, res) => {
  res.json({ ok: true, scene: activeCameraScene });
});

app.post("/api/camera_scene", (req, res) => {
  const { scene } = req.body || {};
  activeCameraScene = scene || "auto";
  enqueueRobloxEvent({
    type: "set_camera_scene",
    scene: activeCameraScene
  });
  addLog("camera", `🎥 [CAMERA DIRECTOR] Switched camera mode to: ${activeCameraScene.toUpperCase()}`);
  res.json({ ok: true, scene: activeCameraScene });
});

// 3. Connect/Switch TikTok Live account at runtime
app.post("/api/connect", async (req, res) => {
  const { username, bypass, apiKey } = req.body || {};
  if (typeof bypass === "boolean") {
    bypassFollowerCheck = bypass;
  }
  if (typeof apiKey === "string" && apiKey.trim() !== "") {
    process.env.SIGN_API_KEY = apiKey.trim();
  }
  const state = await connectToTikTok(username || currentTikTokUsername);
  res.json({ ok: state.connected, connectionState: state, bypassFollowerCheck, hasSignApiKey: Boolean(process.env.SIGN_API_KEY) });
});

// 4. Simulate Events (Test Spawning, Non-Follower Alert, and Rose Gift POV without going Live!)
app.post("/api/simulate", async (req, res) => {
  const { action, tiktokUniqueId, robloxUsername } = req.body || {};
  const cleanTikTok = (tiktokUniqueId || "tiktok_fan99").replace(/^@/, "").trim();
  const cleanRoblox = (robloxUsername || "builderman").trim();

  if (action === "spawn_follower") {
    markAsFollower(cleanTikTok);
    const profile = await resolveRobloxUsername(cleanRoblox);
    if (!profile) {
      return res.status(400).json({ ok: false, error: `Roblox user "${cleanRoblox}" not found.` });
    }
    saveUserMapping(cleanTikTok, cleanTikTok, profile);
    addLog("simulate", `🧪 [TEST] Simulated Follower @${cleanTikTok} spawning Roblox user "${profile.username}"`);
    enqueueRobloxEvent({
      type: "spawn_avatar",
      tiktokUniqueId: cleanTikTok,
      tiktokNickname: cleanTikTok,
      robloxUserId: profile.userId,
      robloxUsername: profile.username,
      robloxDisplayName: profile.displayName
    });
    return res.json({ ok: true, profile });
  }

  if (action === "not_following") {
    const profile = await resolveRobloxUsername(cleanRoblox);
    if (!profile) {
      return res.status(400).json({ ok: false, error: `Roblox user "${cleanRoblox}" not found.` });
    }
    saveUserMapping(cleanTikTok, cleanTikTok, profile);
    addLog("simulate", `🧪 [TEST] Simulated Non-Follower @${cleanTikTok} trying to spawn "${profile.username}"`);
    enqueueRobloxEvent({
      type: "not_following",
      tiktokUniqueId: cleanTikTok,
      tiktokNickname: cleanTikTok,
      robloxUserId: profile.userId,
      robloxUsername: profile.username,
      robloxDisplayName: profile.displayName
    });
    return res.json({ ok: true, profile });
  }

  if (action === "rose_gift") {
    let profile = null;
    if (cleanRoblox) {
      profile = await resolveRobloxUsername(cleanRoblox);
      if (profile) {
        saveUserMapping(cleanTikTok, cleanTikTok, profile);
      }
    }
    const mapping = userMappings[cleanTikTok.toLowerCase()];
    addLog("simulate", `🧪 [TEST] Simulated 🌹 Rose Gift from @${cleanTikTok} (${mapping?.robloxUsername || "stage avatar"})`);
    enqueueRobloxEvent({
      type: "rose_gift",
      tiktokUniqueId: cleanTikTok,
      tiktokNickname: cleanTikTok,
      giftName: "Rose",
      repeatCount: 1,
      robloxUserId: mapping ? mapping.robloxUserId : null,
      robloxUsername: mapping ? mapping.robloxUsername : null,
      robloxDisplayName: mapping ? mapping.robloxDisplayName : null
    });
    return res.json({ ok: true, mapping });
  }

  if (action === "panda_gift") {
    let profile = null;
    if (cleanRoblox) {
      profile = await resolveRobloxUsername(cleanRoblox);
      if (profile) {
        saveUserMapping(cleanTikTok, cleanTikTok, profile);
      }
    }
    const mapping = userMappings[cleanTikTok.toLowerCase()];
    addLog("simulate", `🧪 [TEST] Simulated 🐼 Panda Gift from @${cleanTikTok} (${mapping?.robloxUsername || cleanRoblox || "stage avatar"})! Giant Avatar 30s + POV 10s!`);
    enqueueRobloxEvent({
      type: "panda_gift",
      tiktokUniqueId: cleanTikTok,
      tiktokNickname: cleanTikTok,
      giftName: "Panda",
      repeatCount: 1,
      robloxUserId: mapping ? mapping.robloxUserId : (profile ? profile.userId : null),
      robloxUsername: mapping ? mapping.robloxUsername : (profile ? profile.username : cleanRoblox),
      robloxDisplayName: mapping ? mapping.robloxDisplayName : (profile ? profile.displayName : cleanTikTok)
    });
    return res.json({ ok: true, mapping });
  }

  if (action === "member_join") {
    addLog("simulate", `🧪 [TEST] Simulated Viewer @${cleanTikTok} joining the stream! Launching RGB Fireworks!`);
    enqueueRobloxEvent({
      type: "member_join",
      tiktokUniqueId: cleanTikTok,
      tiktokNickname: cleanTikTok
    });
    return res.json({ ok: true });
  }

  if (action === "witch_hat_dragon") {
    addLog("simulate", `🧪 [TEST] Simulated 🧙‍♂️ "Topi Penyihir" gift from @${cleanTikTok}! Launching 3 Dragons Event!`);
    enqueueRobloxEvent({
      type: "witch_hat_dragon",
      tiktokUniqueId: cleanTikTok,
      tiktokNickname: cleanTikTok,
      giftName: "Topi Penyihir",
      repeatCount: 1
    });
    return res.json({ ok: true });
  }

  if (action === "finger_heart_dolphin") {
    addLog("simulate", `🧪 [TEST] Simulated 🐬 "Finger Heart" gift from @${cleanTikTok}! Launching 5 Leaping Dolphins!`);
    enqueueRobloxEvent({
      type: "finger_heart_dolphin",
      tiktokUniqueId: cleanTikTok,
      tiktokNickname: cleanTikTok,
      giftName: "Finger Heart",
      repeatCount: 1
    });
    return res.json({ ok: true });
  }

  res.status(400).json({ ok: false, error: "Unknown simulation action" });
});

// 5. Built-in Control & Test Dashboard UI at http://localhost:3000
app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "dashboard.html"));
});

app.listen(PORT, () => {
  console.log("================================================================");
  console.log(`🚀 TikTok Live -> Roblox Bridge Server running on http://localhost:${PORT}`);
  console.log(`🎮 Roblox Studio Polling Endpoint: http://localhost:${PORT}/api/events`);
  console.log(`🧪 Open http://localhost:${PORT} in your browser to test & control!`);
  console.log("================================================================");
  connectToTikTok(currentTikTokUsername);
});
