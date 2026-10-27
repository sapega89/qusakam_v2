---
type: plan
status: planned
tags: [art, rooms, critics, M6]
---

# Depth critics — from video and from play, not from screenshots

**Nothing implemented.** 2026-10-27. Sapega: «заплануй візуальних критиків для визначення глибини картинки, тільки
не по скріншотах, а по відео або по находженню в грі». Depth in a side-scroller lives in motion: parallax speeds,
planes sliding over each other, the foreground passing. A still frame shows none of it, and the backdrop work so far
was judged on stills (`comfy-backdrop` skill: «Judge it in the game, never by the PNG»). No Figma design (world art).

## What exists today
| Thing | Where | State |
|---|---|---|
| Room shots | `SampleProject/UI/capture_*.gd`, rooms loaded by `game.teleport_to_room` (`capture_meditation_spots.gd:29`) | ✅ stills only |
| The player's route with real keys | `SampleProject/UI/playthrough.gd`, `Scripts/Tools/playthrough.sh` | ✅ stills + transcript |
| Earlier critics | two read-only general-purpose agents, a pixel-art technician and an art director (`comfy-backdrop` skill) | ✅ judged stills |
| Video | `grep -rn 'write-movie\|MovieWriter'` → 0 hits; no ffmpeg on the PC (Python has `cv2` 4.12) | ❌ |
| A number for depth | — | ❌ nothing measures a plane's on-screen speed |

## Missing entirely
A film run per room, a depth probe (what each plane really does on screen), a pack a critic can read (an agent sees
images, not video), the critics' brief, and a place for their findings.

## How it works
1. **Film, in the game.** `SampleProject/UI/film_rooms.gd` loads each room and plays it with real input (the actions,
   not teleports): the hero runs the walk line one way, jumps, runs back, stands 1 s; the real camera follows. Godot's
   Movie Maker (`--write-movie <room>.avi --fixed-fps 30`) records it; in the cloud under xvfb + opengl3. 4–8 s a room.
2. **Probe, from inside.** The same run logs, every frame, each visual plane's screen position (every `Parallax2D`,
   the room's sprites, decor, `FrontDark`, the floor art) against the camera, and the hero's feet against the
   collision. Out: `layers.json` per room — each plane's measured speed (×camera), its z, its average value, contrast
   and saturation rendered solo (the other planes hidden for one frame).
3. **Pack for the critics**, per room (`Scripts/Tools/film_pack.py`, `cv2`):
   - a filmstrip: 8 frames 0.5 s apart in one sheet;
   - a slit-scan: the same row band of every frame stacked in time — each plane leaves streaks at its own slope, so
     the depth order and any plane that does not move are visible in one picture;
   - the probe table;
   - an mp4 for Sapega (sent from the PC, not committed).
4. **Critics** — three read-only agents, each alone (no one sees another's notes), all rooms:
   - **art director**: does the picture read as deep — how many planes slide at different speeds on each screen,
     overlap, aerial perspective (value, contrast and saturation fall with distance), scale cues, foreground framing
     (D750, D774), something to look at on every screen (M6 rule);
   - **motion technician**: what only motion shows — pixel shimmer and jitter of scrolling layers, repeat seams,
     layer ends and edges coming into view, planes popping, a plane pinned to the camera when the hero jumps, blur
     that does not match the depth;
   - **player**: from the hero's place — does the floor feel solid (B162), does the hero read against moving planes,
     does the foreground hide a threat or annoy, does the room say where you are.
   Each finding: room, second, what, why it breaks depth, the fix (art lane or code), proposed triage.
5. **Triage** (orchestrator): wrong → B-ID; a product call → Q-ID asked in the conversation; art work → a row in
   [[m6_backdrops]]. Findings in `design/depth_critique_<date>.md`.

## Decisions required
1. **Rules the probe can enforce** (a mechanism, not a re-read every time): planes ordered by z move in order (far
   slower than near); at least three distinct speeds on every screen; the floor plane moves at ×1.0 and its painted
   top is within a few pixels of the collision; a foreground piece in every room (D774). Recommendation: they become
   `verify_depth.gd` only room by room as each room is fixed, so the suite never goes red on a known open item;
   until then the probe's violations are filed as B-IDs. Not blocking.
2. **Clip length and fps**: 4–8 s, 30 fps. Provisional.

## Slices
### Slice 1 — film, probe, pack (☁ `depth-film`)
- `SampleProject/UI/film_rooms.gd`, `Scripts/Tools/film_pack.py`; packs for all rooms in `design/shots/depth/<room>/`
  (filmstrip and slit-scan as JPG, `layers.json`); no video in git.
- Own commit; the baseline of every room today.

### Slice 2 — critics (☁ `depth-critics`, waits for slice 1)
- Three critics as above, each a separate agent; `design/depth_critique_2026-10-27.md`; proposed triage per finding.

### Slice 3 — the loop
- After each M6 batch, B162 and A20: film + critics again on the changed rooms; Sapega gets the mp4s from the PC.
- A room whose findings are closed gets its `verify_depth` rules.

## Order and dependencies
`1 → 2 → 3`. Slice 1 adds files only, so it runs beside the room routines.

## Out of scope for this pass
Lighting and colour grading (D233), the UI, enemies and characters (their own critics).
