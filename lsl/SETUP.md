# SLTV in-world setup

1. Create your Kosmi rooms at https://kosmi.io (sign in so the room URLs are
   permanent) and copy each room URL.
2. Rez the TV prim (a flat box, e.g. 4 x 2.25 x 0.1 m). Note which face is the
   screen: Edit → Select Face, hover — the face numbering for a default box
   front is usually 4. You can change `screen_face` later.
3. Create a notecard named exactly `SLTV Config` inside the prim, contents per
   `SLTV_Config.txt` (the `page_base` is pre-filled for this repo's GitHub
   Pages; set your channels).
4. Create a new script in the prim, paste `sltv-tv.lsl`, save.
5. The owner chat should report: `SLTV: screen attached to https://…` — the
   screen face now shows the TV (enable media in your viewer!).
6. Remote: upload `assets/remote-texture.png` (L$10), rez a flat box sized
   about 0.12 × 0.24 × 0.01, apply the texture to the front face, add
   `sltv-remote.lsl`, take it, attach as HUD (e.g. Bottom Right; resize on
   screen as you like). The buttons are live: Power, Fullscreen, CH −/+,
   Zoom, Channels (opens the picker), Menu (full dialog — Guests/Reload/
   Calibrate/Add Ch live there for the owner) and LOCK (owner only — toggles
   Interact mode without opening the menu). Give copies to guests AFTER
   granting them via TV touch → Guests → + Add.

## Camera zoom ("Zoom into Media")
- **Anyone can zoom by clicking the screen** — the TV enables the viewer's
  native auto-zoom (`PRIM_MEDIA_AUTO_ZOOM`), which frames the camera on the
  media face perfectly. Press Esc to release.
- The TV menu's **Zoom** button does the same without clicking the screen,
  for **remote wearers** (touch the remote once so it pairs) — Second Life
  only lets attachments steer your camera. Press Zoom again (or Esc) to
  release.
- If the menu Zoom aims at the wrong side: **stand squarely in front of the
  screen**, then owner menu → **Calibrate**. The TV knows a flat screen faces
  along its thinnest dimension; your position tells it which side. Stored
  permanently (survives resets; recalibrate if you change `screen_face`).
  Manual `screen_axis` in the notecard still works as a last-resort override.

## Picture quality tips
- **Best fullscreen: Kosmi local-file / screen sharing** — Kosmi's own player
  fills the room edge-to-edge (verified in-world; streams via WebRTC and works
  fine in SL's browser).
- **YouTube channels always show small letterbox bars** — that's YouTube's own
  embedded player inside Kosmi; neither Kosmi nor SLTV can remove it.
- **Pre-convert movies to WebM (VP8/VP9 + Vorbis) for free-tier Kosmi sharing**
  — H.264 appears premium-gated. VLC: Media → Convert/Save → profile
  "Video - VP80 + Vorbis (Webm)" (raise the video bitrate to ~3-6 Mb/s for
  1080p), or ffmpeg: `-c:v libvpx -crf 10 -b:v 4M -c:a libvorbis`.

## Channels & handy menu items
- **Add Ch** (owner): add a channel in-world without editing the notecard —
  enter `Name|https://…` in the text box, or `del Name` to remove a runtime
  channel. Stored in the object (LinksetData), survives resets. Notecard
  channels are still managed in the notecard.
- **Open Web** (owner + guests): opens the CURRENT channel's Kosmi room in
  your real browser — where your Kosmi login lives. The one-click path to
  full admin controls.
- First-time watchers get a one-time on-screen setup card (sound/volume
  tips) instead of chat spam; it never returns after "Got it".

## Managing the room from inside SL (Interact mode)
1. In your Kosmi room settings (desktop browser, as owner): allow guests to
   control playback.
2. In SL: TV Menu → **Unlock**. Every watcher's screen shield drops — clicks
   now reach Kosmi, so you can pause/queue directly on the prim.
3. When done: Menu → **Lock** (instant re-shield for everyone).
Note: while unlocked, ANY watcher can click the room too (all SL watchers are
equal guests to Kosmi). Unlock for private parties; keep public TVs locked.

## Why am I a guest in my own room on the TV?
Every watcher's SL viewer runs its own fresh embedded browser with no cookies —
including yours — so Kosmi sees a new anonymous guest, not your account.
That's by design: **manage the room from your normal desktop browser** (logged
in as owner — queue media, moderate, start file shares; Kosmi syncs it to all
watchers instantly), and treat the SL TV as the shared display, driven by its
own remote. Don't try to log in on the prim.

## Troubleshooting
- "no signal" on the screen → the media URL's state fragment is missing or
  invalid — usually a channel URL so long the media URL exceeds SL's 1024-char
  limit (the owner gets a chat warning), or the page was opened outside SL.
- Screen black for a guest → they must enable media (Preferences → Sound & Media)
  and may need to click the screen once.
- After a region restart everyone's screen reloads once — that is by design.
- Owner menu → Reload forces every watcher's page to reload (bumps a ?r= counter).
- The screen ignores mouse hover/clicks ~60 s after each watcher's first click
  (or channel change), so Kosmi's player controls can't pop up accidentally.
  The SL floating media bar is disabled for everyone (PERMS_CONTROL = NONE);
  use the TV menu / remote instead.
