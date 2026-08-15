# M0 spike — prove Kosmi works on a prim before writing any code

~20 minutes in-world. Goal: kill the existential risks from
[research §5](research/2026-08-15-kosmi-sl-research.md) with zero code.

## Prep (5 min, out of world)
1. In a normal browser: create a Kosmi room at https://kosmi.io (recommended: sign
   up free first so the room URL is stable). Note the room URL.
2. Start a YouTube video in the room so something is playing.

## In-world (15 min)
Use a sandbox or your own parcel (you need media permissions on the land).

1. Rez a cube, size ~4 × 2.25 × 0.1 m.
2. Edit → Select Face → pick the large front face.
3. Texture tab → Media → **+** (Add) → Home Page = your Kosmi room URL.
   Check "Auto Play Media" and set size 1024 × 512 (or leave default).
4. Click off; then check each item:

| # | Test | Pass looks like | Result |
|---|------|-----------------|--------|
| 1 | Room renders on the prim | Kosmi UI appears on the face | ☐ |
| 2 | Guest join without account | You get into the room (as guest / with your Kosmi login on YOUR viewer — for the guest case use an alt or ask a friend WITHOUT a Kosmi account) | ☐ |
| 3 | Video plays | The YouTube video runs on the prim | ☐ |
| 4 | Audio | Sound after at most one click on the face | ☐ |
| 5 | Sync | Pause the video from a normal browser on the same room → prim viewers see it pause within ~2 s | ☐ |
| 6 | Second avatar | Friend/alt nearby sees the same, synced | ☐ |
| 7 | Performance | Watchable framerate on the prim | ☐ |

## Record
- Viewer + version used (e.g., Firestorm 7.x): ______
- Any login wall / cookie prompt / black screen: ______
- Clicks needed before audio: ______

## Interpretation
- **All pass** → architecture A proceeds unchanged; start M1.
- **#2 fails (login wall in CEF)** → investigate Kosmi guest-link settings; if
  fundamental, the project pivots (e.g., CyTube as top-level URL) — stop and rethink.
- **#4 needs a click per session** → acceptable; document in guest help card.
- **#7 poor** → try 1280 × 720 media size; note GPU/viewer settings.
