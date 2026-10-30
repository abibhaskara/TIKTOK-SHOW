/**
 * Roblox Users API Resolver & Smart Chat Username Extractor
 * Resolves a Roblox username typed in TikTok Live chat into a verified Roblox UserId.
 */

// In-memory cache: lowercase_username -> { userId, username, displayName } or null
const usernameCache = new Map();

// Common short chat reactions to ignore so normal chat words aren't queried as Roblox usernames
const COMMON_CHAT_WORDS = new Set([
  "lol", "lmao", "omg", "wow", "wtf", "wth", "gg", "ggs", "nice", "cool",
  "yes", "yep", "yeah", "nah", "nope", "hey", "hi", "hello", "hola", "halo",
  "hai", "bang", "kak", "bro", "sis", "guys", "first", "second", "third",
  "keren", "mantap", "anjay", "wkwk", "wkwkwk", "haha", "hahaha", "hehe",
  "follow", "followed", "udah", "sudah", "belum", "done", "hadir", "absen",
  "aku", "saya", "gua", "gue", "plis", "please", "pls", "help", "me", "join",
  "rose", "gift", "like", "share", "live", "tiktok", "roblox"
]);

/**
 * Extracts a candidate Roblox username from a raw TikTok chat comment.
 * Viewers are expected to type only their Roblox username (e.g. "builderman"),
 * though we also gracefully support "@builderman" or "!join builderman".
 *
 * @param {string} comment Raw chat message from TikTok Live
 * @returns {string|null} Candidate Roblox username or null if not a valid username format
 */
function extractCandidateUsername(comment) {
  if (!comment || typeof comment !== "string") return null;

  let text = comment.trim();

  // Strip optional command prefixes if a viewer uses them (e.g. "!join builderman", "user: builderman", "usn builderman")
  text = text.replace(/^(?:!join|!spawn|!roblox|roblox\s*:?|user\s*:?|username\s*:?|usn\s*:?|akun\s*:?|id\s*:?)\s*/i, "").trim();

  // Strip leading @ if they typed "@builderman"
  if (text.startsWith("@")) {
    text = text.slice(1).trim();
  }

  // Check if single word candidate
  if (!/\s/.test(text)) {
    if (/^[a-zA-Z0-9_]{3,20}$/.test(text) && !COMMON_CHAT_WORDS.has(text.toLowerCase()) && !/^_+$/.test(text)) {
      return text;
    }
  }

  // If multi-word, check for explicit keyword pattern like "usn builderman", "user: builderman", "roblox: builderman"
  const match = comment.match(/(?:usn|username|user|roblox|akun|id)\s*[:=]?\s*([a-zA-Z0-9_]{3,20})/i);
  if (match) {
    const candidate = match[1];
    if (!COMMON_CHAT_WORDS.has(candidate.toLowerCase()) && !/^_+$/.test(candidate)) {
      return candidate;
    }
  }

  return null;
}

/**
 * Resolves a Roblox username to { userId, username, displayName } using Roblox's official Users API.
 *
 * @param {string} rawUsername Candidate Roblox username
 * @returns {Promise<{userId: number, username: string, displayName: string} | null>}
 */
async function resolveRobloxUsername(rawUsername) {
  const candidate = extractCandidateUsername(rawUsername);
  if (!candidate) return null;

  const key = candidate.toLowerCase();
  if (usernameCache.has(key)) {
    return usernameCache.get(key);
  }

  try {
    const response = await fetch("https://users.roblox.com/v1/usernames/users", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: JSON.stringify({
        usernames: [candidate],
        excludeBannedUsers: false
      })
    });

    if (!response.ok) {
      console.error(`[RobloxAPI] HTTP ${response.status} when looking up "${candidate}"`);
      return null;
    }

    const json = await response.json();
    if (json && Array.isArray(json.data) && json.data.length > 0) {
      const user = json.data[0];
      const resolved = {
        userId: user.id,
        username: user.name,
        displayName: user.displayName || user.name
      };
      usernameCache.set(key, resolved);
      return resolved;
    }

    // Cache negative lookup so invalid words aren't re-queried repeatedly
    usernameCache.set(key, null);
    return null;
  } catch (err) {
    console.error(`[RobloxAPI] Failed to resolve username "${candidate}":`, err.message);
    return null;
  }
}

module.exports = {
  extractCandidateUsername,
  resolveRobloxUsername
};

