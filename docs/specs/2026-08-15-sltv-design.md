# SLTV — Kosmi-first synced TV for Second Life (design)

**Status: DRAFT — pending Jon's review.**
Architecture choice (A, below) was Claude's recommendation, auto-adopted after the
approach question went unanswered; overturn freely. Research backing every claim:
[docs/research/2026-08-15-kosmi-sl-research.md](../research/2026-08-15-kosmi-sl-research.md).

## Requirements (agreed in brainstorm, 2026-08-15)

- **Scope v1**: Kosmi-first watch-party TV. Other sources (radio, live TV, CyTube)
  are future channel types, but the channel model must not preclude them.
- **Product model**: personal TV now, sellable product later → no secrets in the
  object, per-TV isolation, easy setup, no infrastructure Jon must scale.
- **Synced viewing**: everyone near the TV sees the same Kosmi room (Kosmi syncs
  playback itself).
- **Synced controls**: fullscreen, channel switching, power — when owner/guest uses
  them, every watcher's screen follows automatically. Volume stays per-viewer.
- **Control surfaces**: touch the TV → dialog menu; wearable remote HUD (owner +
  grantable guests).
- **Hosting**: static (GitHub Pages); free-tier services acceptable but not required.

## ⚠ ARCHITECTURE AMENDMENT (2026-08-15, in-world finding)

**A is superseded by A2 ("fragment bus").** In-world acceptance revealed that
`llSetContentType` honors non-plain content types **only for the object
owner** — every other viewer receives `text/plain` and renders raw HTML
source. HTTP-in therefore cannot serve the page (or JSON, CORS-less) to
watchers at all. A2 keeps the same shell/UI/state model but changes transport:

- Media URL = `<pages>/web/index.html?r=<reload>#v=1&q=<seq>&p=&f=&l=&n=&u=`
  — the **entire state rides in the URL fragment**, rewritten by
  `llSetLinkMedia` (no sleep) on every command.
- The page (served by GitHub Pages — real HTML for everyone) parses the
  fragment on boot and on `hashchange`. Fragment-only changes are
  same-document navigation in Chromium (verified locally; in-world smoothness
  TBD — if the viewer reloads instead, the boot path handles it identically,
  at the cost of a Kosmi rejoin per command).
- Only the CURRENT channel travels (name+url); the channel list lives in LSL
  dialogs. Query param `?r=` changes force a real reload (owner Reload).
- Deleted entirely: HTTP-in server, long-poll client, heartbeats, cap-URL
  lifecycle, region-restart re-request. The prim serves nothing.

The section below documents superseded Architecture A for history.

## Architecture A (superseded): static shell + Kosmi iframe + LSL HTTP-in push

```
GitHub Pages (static)                       Second Life region
┌──────────────────────────┐               ┌─────────────────────────────┐
│ shell app (tv page)      │               │ TV prim                     │
│  ┌────────────────────┐  │   long-poll   │  sltv-tv.lsl                │
│  │ Kosmi room iframe  │  │◄──────────────│   • state authority         │
│  └────────────────────┘  │  GET /state   │   • HTTP-in server          │
│  OSD / idle screen /     │  GET /poll    │   • llSetPrimMediaParams    │
│  fullscreen CSS          │               │   • ACL + touch menu        │
└──────────────────────────┘               │       ▲ llRegionSayTo       │
     ▲ one CEF instance                    │  remote HUD (owner/guest)   │
     │ per watcher                         └─────────────────────────────┘
```

- The **prim is the sync server**. Each watcher's page holds a long-poll GET open to
  the prim's `llRequestURL` endpoint; the script answers all pending polls the
  moment state changes → every watcher applies the command near-simultaneously.
- The media URL stays **constant** during normal operation (so no reloads); it is
  rewritten only when the HTTP-in URL changes (region restart / script reset),
  which reloads every watcher once and re-heals the system.
- Late joiners / reloaded viewers fetch `GET /state` on page load → always correct.
  (Design consequence: state does NOT live in the URL — rewriting the URL per
  change would reload everyone and defeat the design.)

## Components

### 1. Web shell (static, no build step for the app itself)
- `web/index.html` + vanilla ES modules:
  - `state.js` — pure state reducer: `{power, channelIndex, fullscreen, seq}` +
    channel list; unit-testable.
  - `sync.js` — long-poll client: `GET {lp}/state` on boot, then `GET {lp}/poll`
    held open ~25 s (AbortController), ≥500 ms re-poll throttle, exponential
    backoff to 5 s on errors, "reconnecting" overlay on persistent failure.
  - `ui.js` — applies state: Kosmi iframe `src` (channel), CSS fullscreen class,
    power-off idle screen (unsets iframe `src` so audio actually stops), channel
    OSD toast.
- Kosmi iframe: `allow="autoplay; fullscreen; encrypted-media; microphone; camera;
  display-capture"`.
- **Same-origin serving (CORS correction, 2026-08-15)**: the media URL is the
  prim's own HTTP-in URL, which serves a ~500-byte bootstrap HTML that loads css/js
  from GitHub Pages (Pages sends `Access-Control-Allow-Origin: *`, so cross-origin
  module scripts load fine). All `fetch()` calls target the page's own origin (the
  cap URL) — no CORS anywhere. LSL cannot set CORS headers, so the originally
  drafted "page on Pages fetches the cap URL" would have been blocked by the
  browser. `web/index.html` exists only for local dev against the mock server.
- **Fullscreen semantics**: we cannot trigger fullscreen *inside* Kosmi's
  cross-origin iframe. Shell default renders a TV bezel/letterbox (~85% screen);
  synced fullscreen removes it → Kosmi fills 100% of the face for everyone.
  M2 experiment: Kosmi bundle contains `kioskMode`/`isBeingEmbedded` flags — if a
  URL param hides room chrome, offer it as per-channel config (not the fs toggle,
  since changing iframe src interrupts playback).
- Testing: Vitest for `state.js` and `sync.js` (mocked fetch/timers).

### 2. TV prim script — `lsl/sltv-tv.lsl`
- Boot: read config notecard → `llRequestSecureURL()` (**must** be the https
  variant: an http-served page is not a secure context, its iframes lose
  `navigator.mediaDevices`, and Kosmi crashes on an unguarded `getDisplayMedia`
  reference — found in-world 2026-08-15) → set media on screen face:
  `PRIM_MEDIA_CURRENT_URL/HOME_URL = <the HTTP-in cap URL itself>` (serves the
  bootstrap page; `page_base` from the notecard is baked into that HTML),
  `AUTO_PLAY TRUE`, `PERMS_INTERACT ANYONE` (guests may need one click to unmute),
  `PERMS_CONTROL OWNER` (hide the viewer's nav bar for others).
- HTTP-in routes (read-only; page never writes — no auth needed):
  - `GET /state` → JSON `{seq, power, channelIndex, fullscreen, channels:[{name,url}]}`
  - `GET /poll?since=<seq>` → held open; answered with the same JSON on change, or
    204-style heartbeat at ~20 s.
- `changed(CHANGED_REGION_START)` / `http_request(URL_REQUEST_DENIED|...)` → re-request
  URL, rewrite media params (single unavoidable reload), continue.
- State persisted with `llLinksetDataWrite` (survives script reset); ACL too.
- Touch → `llDialog` menu: Power, Fullscreen, Channel ▲/▼ + list page, (owner only:)
  Guests… (Add via sensor-scan of nearby avatars / Revoke / Clear), Reload TV.
- Command inputs validated against ACL: owner always; guests = avatars in the
  granted list (checked via `llDetectedKey` for touch, HUD-owner key for remote).

### 3. Remote HUD — `lsl/sltv-remote.lsl`

**Camera zoom (added 2026-08-15):** the TV menu's Zoom button locks the
wearer's camera onto the screen (TV computes framing from its scale, rotation
and the notecard `screen_axis`; HUD applies it via `llSetCameraParams` —
`PERMISSION_CONTROL_CAMERA` is auto-granted to attachments). Per-wearer, not
synced. Decision: the viewer's native media bar (which carries a native
zoom button) stays fully hidden (`PERMS_CONTROL NONE`) per Jon's choice —
hover-popup-free screen outweighs native zoom for everyone.
Refinements (same day): `PRIM_MEDIA_AUTO_ZOOM TRUE` gives every watcher the
native click-to-zoom without any bar (Jon found it on the wiki); the menu
Zoom's aim is calibrated by measurement — owner menu → Calibrate → click the
screen → `llDetectedTouchNormal` stored in LinksetData (face-tagged), beating
axis tables that break on cut/mesh prims.
- One script, owner and guest behavior decided by TV's ACL at command time.
- Buttons: Power, Fullscreen, Ch+, Ch−, channel list dialog. Pairing: HUD scans
  region for owner's SLTV prims (listen handshake on a fixed app channel derived
  from a constant + TV owner key), remembers target prim key in LinksetData.
- HUD → TV: `llRegionSayTo(tvKey, APP_CHANNEL, json command)`; TV validates the
  *HUD wearer's* key against ACL (`llGetOwnerKey` of the speaking object).
- Guest flow: owner grants avatar via TV menu → guest gets HUD copy from TV
  (`llGiveInventory`) → guest wears, pairs, controls.

### 4. Config notecard (`SLTV Config`)
```
page_base=https://<user>.github.io/<repo>/            # web shell URL
screen_face=4
channel=Movies Night|https://app.kosmi.io/room/xxxxx
channel=Music Hall|https://app.kosmi.io/room/yyyyy
```
Channel entries are `name|url`; future sources become `name|type:url` (type
defaults to `kosmi`) so v1 notecards stay valid later.

## Synced-control command flow (example: fullscreen)

1. Guest presses HUD **Fullscreen** → `llRegionSayTo(TV, APP_CHANNEL, {"cmd":"fs"})`.
2. TV script: wearer in ACL? → toggle `fullscreen`, `seq++`, LinksetData persist.
3. TV script answers every pending `/poll` with the new state JSON.
4. Each watcher's `sync.js` receives it (≤ ~1 s, typically instant), `ui.js` adds
   the fullscreen CSS class. Every screen in the parcel goes fullscreen together.
5. Watchers arriving later get the same state from `GET /state` on load.

## Error handling

- **Region restart / new HTTP-in URL**: script re-requests URL, rewrites media
  URL → one forced reload for all; page shows "reconnecting" until poll succeeds.
- **Poll failures** (sim throttle, timeouts): backoff + overlay after N failures;
  state re-fetched via `/state` on recovery (never trust a missed increment).
- **Notecard errors**: TV chats a specific line-numbered error to owner.
- **Kosmi room dead/renamed**: iframe shows Kosmi's own error; OSD keeps channel
  name visible so the owner knows which entry to fix. (We cannot detect inside the
  iframe — cross-origin.)
- **Media not visible for a watcher**: usually viewer media disabled — v1 ships a
  short "TV not showing?" notecard for guests (enable media, click screen once).
- **`llHTTPResponse` body size**: LSL caps HTTP-in response bodies (order of ~2 KB
  per the shared-media recipes). v1 caps channels at 24 and keeps JSON compact
  (~<1.5 KB); if that pinches, `/state` drops `channels` and the page fetches
  `/channels?page=n` separately. Verify the real limit during M2.

## Security

- No secrets anywhere: page is public, HTTP-in serves read-only state, commands
  enter only via in-world LSL with ACL checks. Spoofing `llRegionSayTo` requires
  the wearer's key to be in the ACL — the trust anchor is the avatar key.
- The 8-char-random HTTP-in URLs are unguessable in practice; worst case a reader
  sees channel names/URLs (not sensitive — any watcher's viewer shows the same).

## Out of scope for v1 (recorded for later)

- Volume/mute sync; non-Kosmi channel types (radio/IPTV/CyTube); playback-position
  memory; multi-screen sync groups; update notification system; kioskMode /
  isBeingEmbedded Kosmi flags (investigate when SDK opens up); realtime-service
  sync plugin (Architecture C) if sub-second push ever proves insufficient.

## Milestones

1. **M0 — in-world spike (needs Jon, ~20 min)**: manual prim, media URL set to a
   Kosmi room directly; verify: accountless guest join inside SL CEF, autoplay/
   unmute behavior, playback quality. Kills the project's only existential risk
   before any code. Checklist in `docs/spike-checklist.md` (to be written).
2. **M1 — web shell**: state/sync/ui modules + Vitest suite; local preview with a
   mock long-poll server; deploy to GitHub Pages.
3. **M2 — TV script**: LSL TV prim script + notecard config; integration test
   in-world with the deployed page.
4. **M3 — remotes**: touch menu polish + remote HUD + guest granting.
5. **M4 — productize-later seams**: setup notecard docs, guest help card, packaging.

## Open decisions for Jon

1. Confirm Architecture A (vs B URL-rewrite / C realtime service).
2. New GitHub repo name (old `SLTVInterface` stays untouched) — needed at M1 deploy.
3. Kosmi account: create one (free) so room URLs are stable — recommended.
4. Screen face + TV mesh/prim plans (affects nothing in code; face is config).
