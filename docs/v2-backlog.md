# SLTV v2 backlog (parked 2026-08-16)

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
