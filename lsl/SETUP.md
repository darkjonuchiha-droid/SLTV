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
6. Remote: rez a small prim, add `sltv-remote.lsl`, take it, attach as HUD.
   Touch it → the TV's menu opens. Give copies to guests AFTER granting them
   via TV touch → Guests → + Add.

## Troubleshooting
- "no HTTP-in URL available" → the parcel/region is out of URLs; the script
  retries every 60 s (the 5 s timer requests as soon as one frees up).
- Kosmi shows "Unexpected Application Error … getDisplayMedia" → the page was
  served over http instead of https. The script uses `llRequestSecureURL()`
  precisely for this; make sure the prim runs the current script version.
- Screen black for a guest → they must enable media (Preferences → Sound & Media)
  and may need to click the screen once.
- After a region restart everyone's screen reloads once — that is by design.
- Owner menu → Reload forces every watcher's page to reload (bumps a ?r= counter).
- The screen ignores mouse hover/clicks ~60 s after each watcher's first click
  (or channel change), so Kosmi's player controls can't pop up accidentally.
  The SL floating media bar is disabled for everyone (PERMS_CONTROL = NONE);
  use the TV menu / remote instead.
