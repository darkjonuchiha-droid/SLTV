# SLTV v2 backlog (parked 2026-08-16)

## Agreed v2 shape (design session 2026-08-16)

**Goal order:** 1) synced YouTube, 2) synced self-hosted video + music.
Personal use: one owner streaming to friends in SL. No backend required for
either (see "Control model"); a realtime bus is optional polish, not a
prerequisite.

**Own the player.** YouTube via the IFrame Player API (playVideo/pauseVideo/
seekTo/getCurrentTime + onStateChange) and `<video>`/`<audio>` for files —
both same-origin, so no Kosmi chrome, no guest identity, no meters, and our
own OSD/subtitles/fit. Kosmi remains a channel type for zero-prep screen and
local-file sharing (their servers fan out; our uplink doesn't).

**Control model (decided):**
- *Shared* (rides the bus, all screens obey): play/pause, seek, plus existing
  power/channel/fullscreen/lock. Issued from the REMOTE, because LSL is the
  only layer that knows which avatar is acting → per-avatar permissions via
  the existing guest ACL. Remote texture v2 needs a playback row
  (◀◀ / ⏯ / ▶▶); these no-op on Kosmi channels.
- *Per-viewer* (local, never synced): volume + mute (each watcher's own
  `<video>.volume`, remembered in localStorage), subtitles on/off + size,
  picture fit, and a **resync** button (snap back to group position after a
  buffer/drift).
- Constraint that forces this split: every watcher loads the identical page,
  so on-screen controls cannot identify the clicker — they are all-or-nothing
  (already gated by Lock). Per-person permission must come from in-world.

**Sync math (no backend needed):** state carries `position`, `playing`,
`at` (sim time of command); each screen computes expected position and
self-corrects when drift > ~2 s. Commands are human-paced, so the existing
fragment bus suffices; a Durable Object (free tier, ~100 lines, WebSocket
hibernation) only buys sub-second feel, long playlists, non-SL participants,
and chat.

**Source menu (complementary, not competing):**
| Mode | Prep | Quality | Load | Needs you online |
|---|---|---|---|---|
| Kosmi share | none | live re-encode | your CPU, 1 upload | yes |
| Local file + `cloudflared` tunnel | seconds | original | uplink × viewers | yes |
| R2 hosted | upload once | original | none (free egress) | no |
| VLC/ffmpeg live stream | minutes | re-encode | CPU + uplink × viewers | yes |
HTTPS is mandatory for all of them (our page is HTTPS → mixed content blocks
plain http). Tunnel URLs change per run; TV's **Add Ch** absorbs that without
notecard edits.

**Codec reality with our own player:** MP4/H.264+AAC plays natively — the
WebM conversions were only needed for Kosmi's free-tier transmission codec.
MKV needs a seconds-long remux (`-c copy -movflags +faststart`, pick one
audio track), HEVC/AC3 need real transcode, AV1 likely decodes (CEF 139).
Prim renders at 1280×720, so 720p is the native target; VP9 ≈ half of VP8.

Collected during the v1/v1.1 build. Ordered roughly by value-per-effort.

1. **Native `video:` channel type** — our shell plays direct stream URLs
   (MP4/WebM, radio, HLS via hls.js) in a same-origin `<video>`: 100% picture,
   zero foreign chrome, play/pause/seek synced as commands on the existing
   fragment bus. Open question: hosting for large files (converted .webm
   episodes exceed GitHub Pages limits). ~1 day.
2. **Kosmi Premium kiosk realm** — the paid, supported chrome-free room
   (no sidebar AND no floating chat box). Room-side: one owner subscription
   cleans the picture for every watcher. Zero engineering.
3. **Kosmi SDK email** (hauxir@gmail.com) — scoped to plumbing they have no
   reason to monetize: scoped device tokens ("this TV may display room X"),
   a URL for the account page. NOT chrome-hiding (that's their premium tier —
   they won't give it away, per Jon's read).
4. **Volume/mute sync** (deliberately out of scope in v1 design).
5. **Playback-position memory** (UltraVision parity: resume where you left off
   — needs native player (item 1) or Kosmi cooperation).
6. **Productization seams** — packaging for sale: mod/copy variants, update
   notification channel, marketplace listing, guest quick-help card polish.
7. **Tampermonkey admin relay** (rejected for v1, kept for reference): HUD →
   prim → userscript in the owner's logged-in desktop tab executes privileged
   Kosmi actions. Fragile to Kosmi UI changes.

## Evaluated & set aside
- **Stremio+Torrentio+WatchParty** (github.com/MateusAquino/WatchParty):
  BetterStremio plugin — requires a PATCHED Stremio desktop client per
  participant; syncs state only (each participant streams their own source);
  no web link for viewers → can never reach prim browsers. Desktop-party
  stack, parallel to the TV. Its open ws sync protocol is technically
  speakable by our shell, but the prim still needs direct stream URLs, so it
  reduces to the R2+native-player plan with added fragility.
- **Stremio SDK / addon API as a source for the native player**: SDK is for
  BUILDING addons (wrong tool). The addon API IS queryable cross-origin from
  our shell (GET /stream/{type}/{id}.json). Returns torrents (unplayable in a
  browser without WebTorrent — no fan-out) OR, with PAID debrid, a direct
  HTTPS URL our native player could use. Catches that push it back to R2:
  (a) auto-resolve needs a debrid key → exposed to all watchers client-side,
  or a resolver backend server-side (infra/keys we avoid); (b) debrid links
  are time-limited + account/IP-bound (channels rot, may not play for
  watchers); (c) usually MKV/HEVC → CEF <video> can't play → convert anyway.
  Only no-backend version = owner manually pastes a debrid direct URL as a
  video: channel = the existing "paste a URL" path + expiry pain. Legal:
  Torrentio surfaces pirated content.
- **Google Drive / Dropbox as video hosting**: >100MB virus-scan
  interstitial, expiring signed URLs, download quotas, unreliable Range
  support — file-sharing services engineer against streaming. Object storage
  (R2 first, B2+CF second) is the hosting tier.

## Known dead-ends (do not revisit without new facts)
- Hiding elements inside the Kosmi iframe (cross-origin wall; proxy = MITM of
  user logins + ToS violation — disqualified).
- Kosmi TV mode `/tv/:room` (metered: 30 min/session paywall for anon viewers).
- Credentials in notecards / distributed to watchers (every watcher runs the
  same page; scope-token designs only, and only with Kosmi cooperation).
- Live-toggling PRIM_MEDIA_* perms (apply only on media reload).

## v1 close-out still pending
Second-avatar acceptance checks 5/6/8/9 + fragment-smoothness + hover verdict
+ hard-lock (CLICK_ACTION_IGNORE) verdict → then merge feat/v1 → main, flip
Pages to main, write docs/acceptance-v1.md.
