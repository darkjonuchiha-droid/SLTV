# SLTV research — Kosmi + Second Life shared media (2026-08-15)

Method note: a 4-agent background research workflow was killed twice by host crashes
(~3–5 min in, zero completed agents). Findings below were salvaged from the crashed
agents' transcripts and then verified/completed inline (curl, WebFetch, WebSearch).

## 1. Kosmi platform

- **Free**: "No subscriptions, no hidden fees. Kosmi is completely free." (kosmi.io)
- **Guests join by link, no account**: "Jump in, explore, and invite your friends with
  a link. No sign-up, no hassle." (kosmi.io)
- **Media**: "Netflix, YouTube, or any streaming service—all perfectly synced"; shared
  browsing, screen sharing, link/file sharing; retro game emulators (SNES/NES/PSX…).
  Kosmi does its own playback sync between room members (server-mediated).
- **Embeddable**: `kosmi.io`, `app.kosmi.io`, `kosmi.tv` all serve **no
  X-Frame-Options and no CSP frame-ancestors** (verified via curl 2026-08-15) → rooms
  can be iframed by our own page. Their JS bundle contains `kioskMode` and
  `isBeingEmbedded` flags (salvaged from crashed agent's bundle inspection) —
  embedding is an anticipated use; exact activation params still unknown.
- **SDK**: no public SDK. `kosmi-sdk` not on npm (verified). GitHub org is
  `kosmigramma`; SDK is early-access by emailing the founder (hauxir[at]gmail.com).
  ⇒ **We wrap Kosmi (iframe + our chrome); we cannot script the room from outside.**
- Open: room persistence guarantees for accountless owners → recommend owner creates
  a (free) Kosmi account so room URLs are stable. Verify in-world.
- **Bundle findings (2026-08-15, from app.kosmi.io/core.js):**
  - `kioskMode` is a **realm setting** (server-side, from `realmInfo`), not a URL
    param — hides sidebar/nav for realm rooms (realms = premium custom spaces).
  - **TV mode**: route `tv/:room` (also `kosmi.tv` domain, Chromecast receiver).
    Hides all chrome — but **metered**: `tvUsage` = 30 min/session, 5 h total for
    non-premium viewers, then a `TVPaywall` modal. Anonymous SL watchers would
    all hit it → **unusable for SLTV**. Verified `/tv/lobby` loads anonymously
    with a live countdown.
  - **`hideSidebarForNonAdmins`**: per-room setting; sidebar renders `null` for
    non-admin viewers when enabled → the free, unmetered way to give SL watchers
    a chrome-less media view. Owner keeps admin UI in their own browser.

## 2. Second Life shared media (MOAP) constraints

- **`llSetPrimMediaParams`** ([wiki](https://wiki.secondlife.com/wiki/LlSetPrimMediaParams)):
  forced **1.0 s script sleep** per call; `PRIM_MEDIA_CURRENT_URL` / `HOME_URL` max
  **1024 chars**; whitelist ≤ 64 URLs / 1024 chars; one face per call.
- **Navigation propagation**: changing `PRIM_MEDIA_CURRENT_URL` navigates viewers;
  "The page will reload automatically if PRIM_MEDIA_AUTO_PLAY is enabled and if the
  new PRIM_MEDIA_CURRENT_URL is different." Without AUTO_PLAY, users must press
  Reload manually. (Becky Pippen recipes, SL wiki)
- **Per-viewer vs all-viewer**: a user clicking links / fragment navigation inside
  their own instance is **per-viewer only**. The documented all-viewer, no-reload
  push mechanism is **long-polling the prim's HTTP-in URL**:
  > "the Javascript side always keeps an HTTP GET open to the prim's HTTP-in URL,
  > and the LSL side responds whenever it wants to with a response consisting of
  > strings of Javascript to be executed by the web browser"
  Timing from the recipes: ~20 s long-poll cycle, ≥500 ms re-poll throttle to avoid
  hammering the sim. ([Becky Pippen / Shared Media LSL Recipes](https://wiki.secondlife.com/wiki/User:Becky_Pippen/Shared_Media_LSL_Recipes))
- **Perms**: `PRIM_MEDIA_PERMS_INTERACT` = who can interact with the media face;
  `PRIM_MEDIA_PERMS_CONTROL` = who sees the viewer's media control bar.
  Values: NONE/OWNER/GROUP/ANYONE.
- **Browser engine**: SL Viewer 2025.07 (Oct 2025) updated Dullahan to **CEF 139**
  (modern Chromium) ([release notes](https://releasenotes.secondlife.com/viewer/7.2.2.18475198968.html)).
  Modern JS/CSS fine. H.264/AAC shipped in official+Firestorm builds.
- **Unverified, test early in-world**: (a) whether an LSL URL change that differs
  only in `#fragment` reloads or fires `hashchange` in current CEF (2010-era docs
  predate this); (b) autoplay-with-audio policy inside CEF 139 on MOAP (may need one
  click on the face to unmute); (c) WebRTC availability inside the SL media plugin
  (affects Kosmi voice chat / screenshare, NOT core watch sync); (d) `llRequestURL`
  URL changes on region restart/script reset → script must re-set media URL.

## 3. Prior art (it works — others ship it)

- SL Marketplace sells working Kosmi TVs: [Snickz Kosmi HDTV](https://marketplace.secondlife.com/p/Snickz-Kosmi-HDTV/25724381)
  ("watch your Kosmi.io lobby … with your friends in sync", prim-media based, guests
  need no HUD), [KOSMI Streaming TV by 8exy](https://marketplace.secondlife.com/p/KOSMI-Streaming-TV-by-8exy/19097238),
  multi-service "Easy Streaming TV". ⇒ Kosmi rooms demonstrably play on MOAP.
  None advertise TV-level synced *controls* (fullscreen-for-everyone) — that's our
  differentiator.
- **CyTube**: `cytu.be` sends `X-Frame-Options: DENY` (verified by crashed agent) →
  cannot be wrapped; would have to be the top-level MOAP URL. Kosmi is the wrap-able
  choice; CyTube support would be a later, more limited channel type.

## 4. Sync-channel options for TV-level controls (ranked)

1. **LSL HTTP-in long-poll push (RECOMMENDED)** — page holds a GET open to the
   prim's `llRequestURL` endpoint; LSL answers with a JSON command (fullscreen,
   channel, power) the moment a control fires; every watcher applies it ~instantly.
   Zero external services, zero keys, per-TV isolation for free (each prim is its
   own channel), and it's the 15-years-proven SL pattern. Costs: LSL plumbing,
   URL churn on region restart, sim HTTP throttles (fine for tens of watchers:
   30 watchers × 20 s cycle ≈ 1.5 req/s).
2. **State-in-URL via `llSetPrimMediaParams`** — encode full TV state in the media
   URL query; every change rewrites URL → all viewers reload (1 s throttle).
   Robust but reloads rejoin the Kosmi room on every toggle — bad UX as the *only*
   channel. **Keep as the state-restore layer**: the canonical state always lives in
   the URL, so late joiners and reloaded viewers come up correct, and it's the
   fallback if HTTP-in misbehaves.
3. **Free-tier realtime service** (Supabase Realtime / Firebase RTDB / Ably / public
   MQTT-WSS) — instant push, no LSL quirks, but public keys ship inside a
   distributable product, quotas/abuse become the owner's problem, one more account
   to manage. Keep the sync layer pluggable so this can slot in later if needed.

**CRITICAL in-world finding (2026-08-15): `llSetContentType` non-plain types
are honored only for the OBJECT OWNER'S viewer** — a second avatar loading the
prim-served bootstrap saw raw HTML as text/plain. HTTP-in can never serve
pages or CORS-less JSON to watchers. This killed Architecture A's serving leg;
v1 moved to the fragment-bus (state in the media URL's #fragment, page on
GitHub Pages). Fragment-only URL changes are same-document navigation in
desktop Chromium (verified); in-world viewer behavior determines smoothness.

**In-world confirmations (2026-08-15, Jon, Firestorm 7.2.4):** Kosmi local-file
sharing (WebRTC-streamed) plays on the prim and fills the app area perfectly →
WebRTC works in SL's CEF (risk 5.c resolved). YouTube playback letterboxes
inside YouTube's own embedded player — inherent, not fixable by Kosmi or SLTV.

## 5. Key risks to test first in-world

1. Kosmi room joins as an accountless guest inside SL's CEF (login wall? cookies?).
2. Autoplay/unmute behavior on the media face (one-click-to-start acceptable?).
3. HTTP-in long-poll stability with several watchers + region restart recovery.
4. Fragment-only URL change behavior (nice-to-have optimization).
5. Kosmi room URL stability over days/weeks (owner account).

## 6. Architecture directions considered

- **A. Shell page + Kosmi iframe + LSL HTTP-in push + state-in-URL restore** —
  GitHub Pages static shell renders TV chrome (idle/power-off screen, channel OSD,
  fullscreen CSS) around a Kosmi iframe; controls flow HUD/touch → LSL ACL → HTTP-in
  push to all watchers; canonical state mirrored into the media URL for
  joiners/reloads. Zero backend. **Recommended.**
- **B. URL-rewrite only** — every control = new media URL = full reload + room
  rejoin. Simplest LSL, worst UX. Rejected as primary; survives as A's restore layer.
- **C. Realtime-service channel** — instant sync, external dependency + keys.
  Deferred; pluggable upgrade path inside A's design.
