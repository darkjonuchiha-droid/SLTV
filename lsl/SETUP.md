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

## Hard lock (CLICK_ACTION toggle)
Locking the TV now also sets the prim to `CLICK_ACTION_IGNORE`: the whole
object ignores clicks at the platform level (unlock restores normal touch).
Consequences to know:
- A locked TV can't be touched — not even by the owner. Unlock via the
  remote's LOCK button, or the owner chat failsafe: **/77 unlock** (also
  /77 lock, /77 menu). A freshly rezzed TV boots locked!
- While locked, new arrivals can't click-to-unmute; briefly Unlock (or flick
  channels while unlocked) when someone joins mid-show.
- Clicks pass through to whatever is behind the TV while locked.

## Managing the room from inside SL (Interact mode)
1. In your Kosmi room settings (desktop browser, as owner): allow guests to
   control playback.
2. In SL: TV Menu → **Unlock**. Every watcher's screen shield drops — clicks
   now reach Kosmi, so you can pause/queue directly on the prim.
3. When done: Menu → **Lock** (instant re-shield for everyone).
Note: while unlocked, ANY watcher can click the room too (all SL watchers are
equal guests to Kosmi). Unlock for private parties; keep public TVs locked.

## Why am I a guest in my own room on the TV?
Every watcher's SL viewer runs its own embedded browser with its own cookies —
so Kosmi sees an anonymous guest, not your desktop login. Anonymous guests get
a NEW identity every session, which is why per-session admin grants don't
stick. The fix is giving the TV its own *registered* identity:

## The TV-account pattern (your profile on the TV, permanently)
1. Create a **dedicated Kosmi account** for the TV (username+password login,
   its own unique password — never your main account's).
2. From your desktop (main account, room owner): **promote the TV account to
   admin** in your room. Roles stick to registered users — this is one-time.
3. In SL: press **LOG IN** on the remote (bottom-left pill, owner only). The
   TV itself switches to Kosmi's login screen — every watcher sees their OWN
   private page (typing is never visible to others), and the screen is
   temporarily unlocked so you can click and type. Log in with the TV
   account, then press **LOG IN** again (or any channel button) — the TV
   returns to the channel and the lock state is restored. The viewer's
   cookie store keeps the session — it survives channel switches, power
   cycles, and normally full SL relogs (verified in-world 2026-08-15). One
   login per machine/viewer install. Log out / switch accounts the same way
   (Kosmi's account menu on that screen).
Result: the TV is a persistent, admin-capable identity in your room — no
desktop ritual. If it's ever logged out (viewer cache cleared), repeat step 3.
Security note: the TV account holds only room-admin power; your main account
never touches the prim. For quick full-account tasks, **Open Web** jumps your
desktop browser to the current room.

## Troubleshooting
- Web updates (new page features) reach screens via Menu → **Reload** — but
  browsers may cache the page's files for up to ~10 minutes, so a Reload right
  after an update can serve the old version. Wait a few minutes and Reload
  again.
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
