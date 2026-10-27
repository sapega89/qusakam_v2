---
type: report
tags: [cloud, routines, art, rooms, critics, M6]
---

# depth-film — slice 1 of [[depth_critics_plan]] (film, probe, pack)

**Summary.** Done: `SampleProject/UI/film_rooms.gd` films every room with real input (Movie Maker, 30 fps, xvfb + opengl3)
and probes each visual plane every frame; `Scripts/Tools/film_pack.py` makes a filmstrip and a slit-scan per room;
`Scripts/Tools/film_rooms.sh` runs all of it. Baseline packs for all 16 rooms are in `design/shots/depth/<room>/`
(filmstrip.jpg, slitscan.jpg, layers.json; 13 MB, no video in git). A full run takes **~19 min** (1124 s for 16 films, 50–93 s a
room) plus **75 s** to pack. Probe: measured speeds match every `Parallax2D.scroll_scale` to ±0.002; no room has a plane out
of speed order. Proposed: 5 B rows and 1 Q (below); the outdoor «floor painted 21–27 px above the collision» is D559, not a bug.
Not done (by the plan): `verify_depth.gd`, the critics (slice 2). No D-ID, no B row fixed. Full suite: `SUITE: 4 FAIL` — all red on the base too (below), none from this branch.

## What was built
- `SampleProject/UI/film_rooms.gd` — one Godot run per room (Movie Maker writes one file per run):
  `-- room=<Room> out=<dir>` → `<dir>/<Room>.avi`, `<Room>.layers.json`, `<Room>.probe.json` (per frame, scratch only).
  Loads the room the capture way (`game.teleport_to_room`, start marker `Arrival` / `Arrival_Start` / first `SavePoint*`),
  then `Input.action_press`: run toward the room's middle 2.5 s with a jump at 1 s, back 2.5 s, stand 1 s; the game's own
  camera follows. A leg stops early at a wall (20 frames without moving) or 64 px before the room edge (MetSys would swap
  rooms: CityGates ran into DesertRoad before this guard).
  Film-only changes (nothing in the game code): every `DefaultEnemy` disabled and hidden as it appears; every `Area2D` of the
  room stops monitoring (story triggers, talks, doors, save points) from `node_added`, before the room's `_ready`; the
  `DemoEndScreen` frozen (its finale detaches the camera and pans it up, D473) and the hero's movement re-enabled; LabCells
  gets `lab_cells_cutscene_complete` + `lab_acquaintance_complete` (else its intro holds the camera on the cells and the hero
  runs off-screen); every `CanvasLayer` outside the room hidden (HUD, dialogue, menus); hints off (D746).
- **Probe.** A plane = every `Parallax2D`; every direct child of the room with drawing nodes outside a `Parallax2D`; a
  `top_level` node; the camera's children. Characters are not planes. Sampled on `RenderingServer.frame_pre_draw` (what is
  on screen). Speed ×camera = least squares of the plane's screen x on the camera's x (plus a time term for `autoscroll`;
  repeat wraps unwrapped). Solo stats on three screens (start/stand, middle, turn): every other plane and the characters
  hidden, rendered on black and on white → true alpha and colour; `coverage`, `visible` (minus what planes drawn over it cover,
  by z then tree order), value (mean luma), contrast (σ luma), saturation (HSV S), `painted_top_px` (first opaque row in five
  columns at the hero's feet). Stats are **before** the WorldEnvironment grade and glow (D233), which also tint the clear
  colour and would fake the alpha. Hero: feet vs the collision under him every frame on the floor (ray), and his drawn feet
  (solo) vs his collision.
- `Scripts/Tools/film_pack.py` (`python3 -I`, cv2 + numpy): `pack <src> <dst> [Room…]` — filmstrip (8 frames 0.5 s apart,
  2×4) and slit-scan (bands at 30/55/80 % of the height, 3 px a frame, time down), JPG q85 ≤1920 px, `layers.json`
  copied; `report <dst>` — the tables and the decision-1 rule check below.
- `Scripts/Tools/film_rooms.sh <video dir> [Room…]` — all rooms, then the pack into `design/shots/depth/`.
- `heavy_battle.mp3.import`: the importer's own output (uid, path, dest_files). The committed file had none, so after a
  checkout of it `AudioManager` asserted on every sound event; harmless to the picture, but noise in every log.

## Rule check (plan, decision 1) and proposed triage
Rules as run: (1) a plane drawn behind another (z, then tree order) must not move faster by > 0.03, on a screen both show;
(2) ≥ 3 distinct speeds (0.05 steps) among the planes seen on each screen; (3) the floor plane (a ×1.0 plane with a painted top
within 80 px of the feet, widest first) at ×1.0 ± 0.02 with its top within 4 px of the collision; (4) something drawn in front
of the hero (z above his). `TopShade` (×0.00 at z 19, pinned to the view, D749) is a screen overlay and is left out of (1)–(2).

| Room | (1) order | (2) speeds on a screen | (3) floor plane | (4) foreground | Proposed |
|---|---|---|---|---|---|
| BanditCamp | ok | **1** (×1.00 only: `Back` 98 % of the view) | **none**: `Back` is solid from above at the feet | **none** | B-new-1 |
| Canyon | ok | ok (0.00 … 0.75, 1.30) | `Terrain` top 23–25 px above | FrontDark ×1.30 | D559 |
| City | ok | ok | `Terrain` 24 px above | ok | D559 |
| CityGates | ok | ok | `Terrain` 24–25 px above | ok | D559 |
| DesertRoad | ok | ok | `Terrain` 21–24 px above | ok | D559 |
| DragonMural | — | camera does not pan | **none** (baked `Back`) | FrontDark | B-new-2 |
| ElderHouse | — | camera does not pan | `TileMap` | ok | — |
| GatehouseCellar | ok | **2** (`Back` ×1.00, FrontDark ×1.30) | **none** (baked `Back`) | ok | B-new-3 |
| LabBoss | ok | ok | `Surfaces` on the collision (+0) | ok | — |
| LabCells | ok | ok | ok | ok | — |
| Laboratory | ok | ok | ok | ok | — |
| LaboratoryOutside | ok | ok | `Terrain` 24–27 px above | ok | D559 |
| LizardCave | ok | **2** (`Back` ×1.00, FrontDark ×1.30) | **none** (baked `Back`; the shrine on one screen) | ok | B162 (confirmed) |
| MayorHall | — | camera does not pan | `TileMap` | **none** | B-new-4 |
| MesaClimb | — | camera does not pan | **none** (baked `Back`) | FrontDark | B-new-2 |
| Village | ok | ok | `Terrain` 25–27 px above | ok | D559 |

«Camera does not pan»: DragonMural, ElderHouse, MayorHall and MesaClimb fit the view across (camera x moves ≤ 10 px), so no
plane can show a speed and rules (1)–(2) do not apply; their depth can only come from overlap, value and scale (and in
MesaClimb from the climb, which the film does not do: it walks one line).

**D559, not a bug.** In every road room the floor plane `Terrain` is painted 21–27 px above the collision. D559: «the walk line
runs along the band's middle, so the road shows above and below the hero's feet». Rule (3) needs a road-room form when
`verify_depth.gd` comes: the band's far edge above the feet and its near edge below them, not «top on the collision».

### Proposed B rows (orchestrator: number and file them; not edited here)
- **B-new-1 — BanditCamp has no depth in motion.** One plane speed on every screen (`Back` ×1.00 covers 98 % of the view;
  the stockade and the door ×1.00 too), no floor plane (the walk line is inside one baked backdrop), nothing in front of the
  hero (D774 names BanditCamp). Fix: art lane — cut `Back` into far / mid / floor planes on their own parallax, the floor
  plane's top on the walk line, and the D774 foreground at the top and sides ([[m6_backdrops]]).
- **B-new-2 — DragonMural and MesaClimb: the floor is part of one baked backdrop** (no plane has a painted top at the hero's
  feet on any screen; same defect as B162 in LizardCave, the hero walks over a picture of a floor). Fix: as B162 — the
  backdrop's front plane cut out with its floor on the walk line.
- **B-new-3 — GatehouseCellar: two speeds and a baked floor.** `Back` ×1.00 is the whole room behind the hero; only the
  pillars (FrontDark ×1.30) move differently; no floor plane. Fix: as B162 (cut planes, floor on the walk line).
- **B-new-4 — MayorHall has no foreground** (rule 4, D774 names it: a chandelier, banners at the top and sides, never over
  the fight's middle).
- B162 (open): the probe confirms it — LizardCave shows two speeds (`Back` ×1.00, FrontDark ×1.30) and no painted floor top
  at the feet on two of three screens (on the third the nearest top is the shrine, 29 px above).

### Proposed Q (product/art call, not asked: routines cannot reach Sapega)
- **Q-new — the hero's drawn feet are 12 px (world) below his collision box in every room** (his solo render's lowest opaque
  row, three screens per room, all 16 rooms: +11…+12). With D559 bands this reads as standing inside the band; indoors on a
  flat top (LabBoss `Surfaces`: its top exactly on the collision) his feet overlap the walkway by 12 px. Is that the intended
  3/4 look, or should the sprite (or the collision box) move so the drawn feet meet the floor? Default until answered: no
  change; slice 2's «player» critic looks at it on the films.

## Notes and limits
- Measured speeds equal `scroll_scale` for every `Parallax2D` (e.g. Canyon 0.002/0.102/0.151/0.122/0.202/0.302/0.451/0.751/
  1.299 against 0/0.1/0.15/0.12/0.2/0.3/0.45/0.75/1.3); the camera plane (`Player/Camera2D`, ambient dust in world
  coordinates) has no speed: the camera node is the smoothing target, not the view.
- Solo stats and painted tops come from three screens only (start/stand, middle, turn), not from every frame.
- The walk is straight: Laboratory's return leg stopped after 218 px at an obstacle; no ladders or climbs are filmed.
- The `comfy-backdrop` skill named in the prompt is not in this checkout (`.claude/` does not exist on `feature/backlog`);
  the plan's quotes of it were used.
- Disk: an .avi is 80–122 MB a room (MJPEG); keep them out of git (`film_rooms.sh` writes them to the dir you give).
- Reproduce: `export G=…; Scripts/Tools/film_rooms.sh /tmp/films` (all rooms) or `… /tmp/films Canyon LabCells`;
  `python3 -I Scripts/Tools/film_pack.py report design/shots/depth`.

## Tests
- `verify_scripts_compile`: RESULT: ALL PASS.
- Full suite (`Scripts/Tools/run_verify.sh`, 3030 s, run while the films were recording): `SUITE: 4 FAIL` —
  `verify_city_gates_raid` (1 FAIL «the hero falls after the teleport»; ALL PASS when re-run alone: CPU contention with
  the films), `verify_progression` (4 FAIL: the save point's sit and save screen), `verify_save_load` (2 FAIL + SCRIPT ERROR
  `SavePoint.gd:62` `$Seat` on null), `verify_save_load_room` (2 FAIL: the save point does not open the save screen).
  The last three fail the same alone, and on a clean worktree of `origin/feature/backlog` (7accd1d7) `verify_save_load_room`
  and `verify_progression` give the identical RESULT lines: the D764 meditation seat, not this branch (it changes no game
  code). Proposed B row for the orchestrator: **B-new-5 — the save point used by `verify_save_load*` / `verify_progression`
  has no `Seat`, so `SavePoint._meditate` errors and the save screen never opens** (D764 follow-up).
- The base also lacks the importer's fields in `heavy_battle.mp3.import`: on the clean worktree every run asserts
  «AudioManager: music fight → heavy_battle.mp3 not found» and «unknown sound event …»; this branch commits the fixed file.

## Probe tables (all rooms)
`seen` = the largest share of the view the plane really shows on the three screens (after occlusion); value / contrast /
saturation from the screen where it covers most; «top at feet» in world px on the far, middle and stand screens (− above
the collision); «—» = not on those screens, or no painted top within 80 px.

### BanditCamp

Start `Arrival`, ran +901 px and back -901 px; film frames 105–287; enemies frozen 0; hero on the floor 161 frames, feet–collision gap median 0.07 px, max 0.07 px; the hero's drawn feet vs the collision: far +12, mid +12, stand +12 (world px, + below).

| plane | kind | z | speed ×cam | scroll_scale | seen | value | contrast | sat | top at feet (px) |
|---|---|---|---|---|---|---|---|---|---|
| `Back` | room | -10 | 1.00 | — | 0.983 | 0.58 | 0.21 | 0.37 | —, —, — |
| `ExitDoorEntrance` | room | -2 | 1.00 | — | 0.034 | 0.38 | 0.20 | 0.54 | —, —, — |
| `ShortcutDoorEntrance` | room | -2 | 1.00 | — | — | — | — | — | —, —, — |
| `ExitDoor` | room | 0 | 1.00 | — | 0.001 | 0.96 | 0.01 | 0.45 | —, —, — |
| `Fight_Camp` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Gate_Stockade` | room | 0 | 1.00 | — | 0.024 | 0.20 | 0.10 | 0.30 | —, —, — |
| `Chest_Loot` | room | 0 | 1.00 | — | 0.004 | 0.33 | 0.17 | 0.51 | —, —, — |
| `ShortcutDoor` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `RoomInstance` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Player/Camera2D` | camera | 1 | — | — | 0.005 | 0.43 | 0.30 | 0.42 | —, —, — |

Violations: 

- screen `far` (hero x 1037): 1 distinct speeds (×1.00)
- screen `mid` (hero x 586): 1 distinct speeds (×1.00)
- screen `stand` (hero x 136): 1 distinct speeds (×1.00)
- screen `far`: no plane has a painted top at the hero's feet (within 80 px; what is there is solid from above, e.g. one baked backdrop)
- screen `mid`: no plane has a painted top at the hero's feet (within 80 px; what is there is solid from above, e.g. one baked backdrop)
- screen `stand`: no plane has a painted top at the hero's feet (within 80 px; what is there is solid from above, e.g. one baked backdrop)
- no foreground piece (nothing drawn in front of the hero, D774)

### Canyon

Start `Arrival`, ran -585 px and back +607 px; film frames 105–263; enemies frozen 0; hero on the floor 137 frames, feet–collision gap median 0.07 px, max 0.08 px; the hero's drawn feet vs the collision: far +12, mid +12, stand +12 (world px, + below).

| plane | kind | z | speed ×cam | scroll_scale | seen | value | contrast | sat | top at feet (px) |
|---|---|---|---|---|---|---|---|---|---|
| `DepthUnderlay` | room | -11 | 1.00 | — | 0.000 | 0.17 | 0.00 | 0.51 | -4, -4, -4 |
| `HighSky` | room | -11 | 1.00 | — | 0.000 | 0.84 | 0.00 | 0.16 | —, —, — |
| `HighClouds` | parallax | -10 | 0.10 | 0.10 | — | — | — | — | —, —, — |
| `Backdrop/Plan5` | parallax | -10 | 0.00 | 0.00 | 0.313 | 0.81 | 0.02 | 0.15 | —, —, — |
| `Backdrop/Plan4` | parallax | -10 | 0.10 | 0.10 | 0.178 | 0.73 | 0.13 | 0.31 | —, —, — |
| `Backdrop/DriftingClouds/Cloud1` | parallax | -10 | 0.15 | 0.15 | — | — | — | — | —, —, — |
| `Backdrop/DriftingClouds/Cloud2` | parallax | -10 | 0.12 | 0.12 | 0.026 | 0.75 | 0.12 | 0.28 | —, —, — |
| `Backdrop/DriftingClouds/Cloud3` | parallax | -10 | 0.20 | 0.20 | 0.007 | 0.65 | 0.10 | 0.34 | —, —, — |
| `Backdrop/Plan3` | parallax | -10 | 0.30 | 0.30 | 0.139 | 0.66 | 0.16 | 0.21 | —, —, — |
| `Backdrop/Walls` | parallax | -10 | 0.45 | 0.45 | 0.068 | 0.57 | 0.11 | 0.47 | —, —, — |
| `Backdrop/Plan1` | parallax | -10 | 0.75 | 0.75 | 0.000 | 0.60 | 0.08 | 0.52 | —, —, — |
| `CanyonDepths` | parallax | -9 | 0.45 | 0.45 | 0.000 | 0.43 | 0.05 | 0.31 | +13, +17, +9 |
| `LizardCaveDoorEntrance` | room | -2 | 1.00 | — | 0.023 | 0.33 | 0.17 | 0.66 | —, -11, — |
| `DragonMuralDoorEntrance` | room | -2 | 1.00 | — | — | — | — | — | —, —, — |
| `Supports` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `TileMap` | room | 0 | 1.00 | — | 0.012 | 0.52 | 0.19 | 0.44 | —, —, — |
| `Decor` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Terrain` | room | 0 | 1.00 | — | 0.298 | 0.47 | 0.19 | 0.50 | -25, -23, -25 |
| `Bridge` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Meditation` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `RoomInstance` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `LizardCaveDoor` | room | 0 | 1.00 | — | 0.001 | 0.96 | 0.01 | 0.45 | —, —, — |
| `Wall_Mural` | room | 0 | 1.00 | — | 0.002 | 0.34 | 0.10 | 0.65 | —, —, — |
| `Player/Camera2D` | camera | 1 | — | — | 0.006 | 0.42 | 0.29 | 0.42 | —, —, — |
| `ForegroundRock` | room | 20 | 1.00 | — | — | — | — | — | —, —, — |
| `FrontDark` | parallax | 20 | 1.30 | 1.30 | 0.024 | 0.14 | 0.05 | 0.43 | —, —, — |

Violations: 

- screen `far`: the floor plane `Terrain` is painted 25 px above the collision under the hero
- screen `mid`: the floor plane `Terrain` is painted 23 px above the collision under the hero
- screen `stand`: the floor plane `Terrain` is painted 25 px above the collision under the hero

### City

Start `SavePoint`, ran +901 px and back -901 px; film frames 105–287; enemies frozen 0; hero on the floor 161 frames, feet–collision gap median 0.07 px, max 0.07 px; the hero's drawn feet vs the collision: far +12, mid +12, stand +12 (world px, + below).

| plane | kind | z | speed ×cam | scroll_scale | seen | value | contrast | sat | top at feet (px) |
|---|---|---|---|---|---|---|---|---|---|
| `Backdrop/Plan5` | parallax | -10 | 0.00 | 0.00 | 0.272 | 0.81 | 0.02 | 0.15 | —, —, — |
| `Backdrop/Plan4` | parallax | -10 | 0.10 | 0.10 | 0.107 | 0.73 | 0.13 | 0.31 | —, —, — |
| `Backdrop/DriftingClouds/Cloud1` | parallax | -10 | 0.15 | 0.15 | — | — | — | — | —, —, — |
| `Backdrop/DriftingClouds/Cloud2` | parallax | -10 | 0.12 | 0.12 | 0.027 | 0.75 | 0.12 | 0.28 | —, —, — |
| `Backdrop/DriftingClouds/Cloud3` | parallax | -10 | 0.20 | 0.20 | 0.015 | 0.75 | 0.12 | 0.27 | —, —, — |
| `Backdrop/Plan3` | parallax | -10 | 0.30 | 0.30 | 0.023 | 0.66 | 0.16 | 0.21 | —, —, — |
| `Backdrop/Plan1` | parallax | -10 | 0.75 | 0.75 | 0.000 | 0.61 | 0.08 | 0.52 | —, —, — |
| `CityFar` | parallax | -9 | 0.40 | 0.40 | 0.122 | 0.63 | 0.13 | 0.23 | —, —, — |
| `CityNear` | parallax | -9 | 0.85 | 0.85 | 0.208 | 0.53 | 0.18 | 0.33 | -13, —, — |
| `Forge` | room | 0 | 1.00 | — | 0.148 | 0.50 | 0.25 | 0.44 | —, —, — |
| `Chapel` | room | 0 | 1.00 | — | 0.085 | 0.69 | 0.24 | 0.27 | —, —, — |
| `WitchHut` | room | 0 | 1.00 | — | 0.036 | 0.34 | 0.16 | 0.52 | —, —, — |
| `DervishTent` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `MayorHallDoorEntrance` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Decor` | room | 0 | 1.00 | — | 0.002 | 0.42 | 0.10 | 0.68 | —, —, — |
| `Terrain` | room | 0 | 1.00 | — | 0.168 | 0.56 | 0.13 | 0.45 | -24, -24, -24 |
| `RoomInstance` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Crowd` | room | 0 | 1.00 | — | 0.045 | 0.38 | 0.25 | 0.49 | —, -26, — |
| `Props` | room | 0 | 1.00 | — | 0.002 | 0.75 | 0.19 | 0.52 | -28, —, — |
| `SavePoint` | room | 0 | 1.00 | — | 0.008 | 0.47 | 0.18 | 0.42 | —, —, -20 |
| `Anvil` | room | 0 | 1.00 | — | 0.001 | 0.26 | 0.19 | 0.27 | —, —, — |
| `Blacksmith` | room | 0 | 1.00 | — | 0.013 | 0.26 | 0.22 | 0.38 | —, —, — |
| `OathPriest` | room | 0 | 1.00 | — | 0.009 | 0.64 | 0.35 | 0.28 | —, —, — |
| `OathWitch` | room | 0 | 1.00 | — | 0.010 | 0.18 | 0.25 | 0.20 | —, —, — |
| `OathDervish` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `GuardLeft` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `GuardRight` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `MayorHallDoor` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Player/Camera2D` | camera | 1 | — | — | 0.005 | 0.42 | 0.29 | 0.42 | —, —, — |
| `FrontDark` | parallax | 20 | 1.30 | 1.30 | 0.025 | 0.14 | 0.13 | 0.38 | —, —, — |

Violations: 

- screen `far`: the floor plane `Terrain` is painted 24 px above the collision under the hero
- screen `mid`: the floor plane `Terrain` is painted 24 px above the collision under the hero
- screen `stand`: the floor plane `Terrain` is painted 24 px above the collision under the hero

### CityGates

Start `Arrival`, ran -841 px and back +901 px; film frames 105–283; enemies frozen 0; hero on the floor 157 frames, feet–collision gap median 0.07 px, max 0.07 px; the hero's drawn feet vs the collision: far +12, mid +12, stand +12 (world px, + below).

| plane | kind | z | speed ×cam | scroll_scale | seen | value | contrast | sat | top at feet (px) |
|---|---|---|---|---|---|---|---|---|---|
| `Backdrop/Plan5` | parallax | -10 | 0.00 | 0.00 | 0.262 | 0.81 | 0.02 | 0.15 | —, —, — |
| `Backdrop/Plan4` | parallax | -10 | 0.10 | 0.10 | 0.108 | 0.73 | 0.13 | 0.31 | —, —, — |
| `Backdrop/DriftingClouds/Cloud1` | parallax | -10 | 0.15 | 0.15 | — | — | — | — | —, —, — |
| `Backdrop/DriftingClouds/Cloud2` | parallax | -10 | 0.12 | 0.12 | 0.026 | 0.75 | 0.12 | 0.28 | —, —, — |
| `Backdrop/DriftingClouds/Cloud3` | parallax | -10 | 0.20 | 0.20 | 0.023 | 0.75 | 0.12 | 0.27 | —, —, — |
| `Backdrop/Plan3` | parallax | -10 | 0.30 | 0.30 | 0.009 | 0.66 | 0.16 | 0.21 | —, —, — |
| `Backdrop/Plan1` | parallax | -10 | 0.75 | 0.75 | 0.000 | 0.60 | 0.08 | 0.52 | —, —, +29 |
| `Mid` | parallax | -9 | 0.70 | 0.70 | 0.269 | 0.74 | 0.14 | 0.31 | —, —, — |
| `CellarArch` | room | -1 | 1.00 | — | 0.042 | 0.19 | 0.16 | 0.60 | —, —, — |
| `TileMap` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `GatePassage` | room | 0 | 1.00 | — | 0.034 | 0.61 | 0.20 | 0.48 | —, —, — |
| `Terrain` | room | 0 | 1.00 | — | 0.173 | 0.55 | 0.13 | 0.45 | -25, -25, -24 |
| `RoomInstance` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `GuardLeft` | room | 0 | 1.00 | — | 0.010 | 0.33 | 0.22 | 0.49 | —, —, — |
| `GuardRight` | room | 0 | 1.00 | — | 0.011 | 0.33 | 0.23 | 0.48 | —, —, — |
| `GateScribe` | room | 0 | 1.00 | — | 0.009 | 0.42 | 0.26 | 0.46 | —, —, — |
| `EnemySpawner` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `CellarDoor` | room | 0 | 1.00 | — | 0.001 | 0.96 | 0.01 | 0.45 | —, —, — |
| `Player/Camera2D` | camera | 1 | — | — | 0.005 | 0.42 | 0.29 | 0.42 | —, —, — |
| `FrontDark` | parallax | 20 | 1.30 | 1.30 | 0.167 | 0.09 | 0.03 | 0.65 | —, —, — |

Violations: 

- screen `far`: the floor plane `Terrain` is painted 25 px above the collision under the hero
- screen `mid`: the floor plane `Terrain` is painted 25 px above the collision under the hero
- screen `stand`: the floor plane `Terrain` is painted 24 px above the collision under the hero

### DesertRoad

Start `Arrival_Start`, ran +901 px and back -901 px; film frames 105–287; enemies frozen 4; hero on the floor 161 frames, feet–collision gap median 0.07 px, max 0.07 px; the hero's drawn feet vs the collision: far +12, mid +12, stand +12 (world px, + below).

| plane | kind | z | speed ×cam | scroll_scale | seen | value | contrast | sat | top at feet (px) |
|---|---|---|---|---|---|---|---|---|---|
| `Backdrop/Plan5` | parallax | -10 | 0.00 | 0.00 | 0.272 | 0.81 | 0.02 | 0.15 | —, —, — |
| `Backdrop/Plan4` | parallax | -10 | 0.10 | 0.10 | 0.144 | 0.73 | 0.13 | 0.31 | —, —, — |
| `Backdrop/DriftingClouds/Cloud1` | parallax | -10 | 0.15 | 0.15 | — | — | — | — | —, —, — |
| `Backdrop/DriftingClouds/Cloud2` | parallax | -10 | 0.12 | 0.12 | 0.026 | 0.75 | 0.12 | 0.28 | —, —, — |
| `Backdrop/DriftingClouds/Cloud3` | parallax | -10 | 0.20 | 0.20 | 0.028 | 0.75 | 0.12 | 0.27 | —, —, — |
| `Backdrop/Plan3` | parallax | -10 | 0.30 | 0.30 | 0.058 | 0.66 | 0.16 | 0.21 | —, —, — |
| `Backdrop/Plan1` | parallax | -10 | 0.75 | 0.75 | 0.000 | 0.60 | 0.08 | 0.52 | —, —, — |
| `Mid` | parallax | -9 | 0.60 | 0.60 | 0.250 | 0.57 | 0.19 | 0.32 | —, —, — |
| `BanditCampDoorEntrance` | room | -2 | 1.00 | — | — | — | — | — | —, —, — |
| `MesaClimbDoorEntrance` | room | -2 | 1.00 | — | — | — | — | — | —, —, — |
| `CampShortcutDoorEntrance` | room | -2 | 1.00 | — | — | — | — | — | —, —, — |
| `Ladder_Shop` | room | -1 | 1.00 | — | 0.009 | 0.31 | 0.08 | 0.61 | —, —, — |
| `Ladder_Tower` | room | -1 | 1.00 | — | — | — | — | — | —, —, — |
| `BanditCampTent` | room | -1 | 1.00 | — | — | — | — | — | —, —, — |
| `CampShortcutTent` | room | -1 | 1.00 | — | — | — | — | — | —, —, — |
| `TileMap` | room | 0 | 1.00 | — | 0.012 | 0.53 | 0.19 | 0.44 | —, —, — |
| `Shop` | room | 0 | 1.00 | — | 0.165 | 0.52 | 0.25 | 0.52 | -19, —, — |
| `Tower` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Wreck` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Shrine` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Decor` | room | 0 | 1.00 | — | 0.003 | 0.47 | 0.18 | 0.49 | —, —, — |
| `Terrain` | room | 0 | 1.00 | — | 0.183 | 0.56 | 0.12 | 0.45 | -23, -24, -21 |
| `RoomInstance` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `SavePoint_BeforeCity` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `EnemySpawner` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Merchant` | room | 0 | 1.00 | — | 0.009 | 0.53 | 0.30 | 0.67 | —, —, — |
| `Fight_LoneShield` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Fight_LoneVulture` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Fight_LoneElite` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Fight_Dunes` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Fight_Mesa` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Fight_Caravan` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Fight_OldVulture` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Chest_OldVulture` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Pickup_ShopRoofRubble` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Rubble_ShopRoof` | room | 0 | 1.00 | — | 0.078 | 0.32 | 0.12 | 0.64 | —, —, — |
| `Pickup_ShopRoof` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Chest_TowerStash` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Cage_TowerStash` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `BanditCampDoor` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `MesaClimbDoor` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `CampShortcutDoor` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Player/Camera2D` | camera | 1 | — | — | 0.005 | 0.42 | 0.29 | 0.42 | —, —, — |
| `FrontDark` | parallax | 20 | 1.30 | 1.30 | 0.167 | 0.09 | 0.03 | 0.65 | —, —, — |

Violations: 

- screen `far`: the floor plane `Terrain` is painted 23 px above the collision under the hero
- screen `mid`: the floor plane `Terrain` is painted 24 px above the collision under the hero
- screen `stand`: the floor plane `Terrain` is painted 21 px above the collision under the hero

### DragonMural

Start `Arrival`, ran +732 px and back -840 px; film frames 105–285; enemies frozen 0; hero on the floor 159 frames, feet–collision gap median 0.07 px, max 0.08 px; the hero's drawn feet vs the collision: far +12, mid +12, stand +12 (world px, + below).

| plane | kind | z | speed ×cam | scroll_scale | seen | value | contrast | sat | top at feet (px) |
|---|---|---|---|---|---|---|---|---|---|
| `Back` | room | -10 | — | — | 0.768 | 0.48 | 0.25 | 0.45 | —, —, — |
| `ExitDoorEntrance` | room | -2 | — | — | 0.029 | 0.33 | 0.17 | 0.66 | —, —, — |
| `ExitDoor` | room | 0 | — | — | 0.001 | 0.96 | 0.01 | 0.45 | —, —, — |
| `DragonMural` | room | 0 | — | — | — | — | — | — | —, —, — |
| `Chest_Mural` | room | 0 | — | — | 0.005 | 0.31 | 0.16 | 0.54 | —, —, — |
| `RoomInstance` | room | 0 | — | — | — | — | — | — | —, —, — |
| `Player/Camera2D` | camera | 1 | — | — | 0.005 | 0.43 | 0.30 | 0.41 | —, —, — |
| `TopShade` | room | 19 | — | — | 0.143 | 0.03 | 0.00 | 0.55 | —, —, — |
| `FrontDark` | parallax | 20 | — | 1.30 | 0.052 | 0.13 | 0.09 | 0.49 | —, —, — |

Violations: 

- the camera does not pan (the room fits the view): no parallax is possible, depth only from overlap, value and scale
- screen `far`: no plane has a painted top at the hero's feet (within 80 px; what is there is solid from above, e.g. one baked backdrop)
- screen `mid`: no plane has a painted top at the hero's feet (within 80 px; what is there is solid from above, e.g. one baked backdrop)
- screen `stand`: no plane has a painted top at the hero's feet (within 80 px; what is there is solid from above, e.g. one baked backdrop)

### ElderHouse

Start `Arrival`, ran +724 px and back -776 px; film frames 105–284; enemies frozen 0; hero on the floor 158 frames, feet–collision gap median 0.07 px, max 0.08 px; the hero's drawn feet vs the collision: far +12, mid +12, stand +12 (world px, + below).

| plane | kind | z | speed ×cam | scroll_scale | seen | value | contrast | sat | top at feet (px) |
|---|---|---|---|---|---|---|---|---|---|
| `Wall` | room | -10 | — | — | 0.523 | 0.40 | 0.19 | 0.51 | —, —, — |
| `ExitDoorEntrance` | room | -2 | — | — | 0.014 | 0.47 | 0.29 | 0.42 | —, —, — |
| `TileMap` | room | 0 | — | — | 0.199 | 0.63 | 0.10 | 0.38 | +0, +0, +0 |
| `Attic` | room | 0 | — | — | 0.055 | 0.30 | 0.17 | 0.62 | —, —, — |
| `RoomInstance` | room | 0 | — | — | — | — | — | — | —, —, — |
| `ExitDoor` | room | 0 | — | — | 0.001 | 0.96 | 0.01 | 0.45 | —, —, — |
| `OldManQuest` | room | 0 | — | — | 0.013 | 0.30 | 0.22 | 0.46 | —, —, — |
| `Player/Camera2D` | camera | 1 | — | — | 0.005 | 0.42 | 0.30 | 0.42 | —, —, — |
| `TopShade` | room | 19 | — | — | 0.158 | 0.03 | 0.00 | 0.55 | —, —, — |
| `FrontDark` | parallax | 20 | — | 1.30 | 0.034 | 0.13 | 0.08 | 0.50 | —, —, — |

Violations: 

- the camera does not pan (the room fits the view): no parallax is possible, depth only from overlap, value and scale

### GatehouseCellar

Start `Arrival`, ran +901 px and back -901 px; film frames 105–287; enemies frozen 0; hero on the floor 161 frames, feet–collision gap median 0.07 px, max 0.07 px; the hero's drawn feet vs the collision: far +12, mid +12, stand +12 (world px, + below).

| plane | kind | z | speed ×cam | scroll_scale | seen | value | contrast | sat | top at feet (px) |
|---|---|---|---|---|---|---|---|---|---|
| `Back` | room | -10 | 1.00 | — | 0.756 | 0.27 | 0.18 | 0.53 | —, —, — |
| `ExitDoor` | room | 0 | 1.00 | — | 0.001 | 0.96 | 0.01 | 0.45 | —, —, — |
| `Fight_LoneBat` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Fight_Bats` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Chest_Cellar` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `RoomInstance` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Player/Camera2D` | camera | 1 | — | — | 0.006 | 0.42 | 0.30 | 0.42 | —, —, — |
| `TopShade` | room | 19 | 0.00 | — | 0.164 | 0.03 | 0.00 | 0.55 | —, —, — |
| `FrontDark` | parallax | 20 | 1.30 | 1.30 | 0.147 | 0.03 | 0.03 | 0.51 | —, —, — |

Violations: 

- screen `far` (hero x 997): 2 distinct speeds (×1.00, ×1.30)
- screen `mid` (hero x 546): 2 distinct speeds (×1.00, ×1.30)
- screen `stand` (hero x 96): 2 distinct speeds (×1.00, ×1.30)
- screen `far`: no plane has a painted top at the hero's feet (within 80 px; what is there is solid from above, e.g. one baked backdrop)
- screen `mid`: no plane has a painted top at the hero's feet (within 80 px; what is there is solid from above, e.g. one baked backdrop)
- screen `stand`: no plane has a painted top at the hero's feet (within 80 px; what is there is solid from above, e.g. one baked backdrop)

### LabBoss

Start `Arrival`, ran +901 px and back -901 px; film frames 105–287; enemies frozen 0; hero on the floor 161 frames, feet–collision gap median 0.07 px, max 0.07 px; the hero's drawn feet vs the collision: far +12, mid +12, stand +12 (world px, + below).

| plane | kind | z | speed ×cam | scroll_scale | seen | value | contrast | sat | top at feet (px) |
|---|---|---|---|---|---|---|---|---|---|
| `Atmosphere/Far1` | parallax | -10 | 0.40 | 0.40 | 0.619 | 0.05 | 0.04 | 0.54 | —, —, — |
| `Gates` | room | -3 | 1.00 | — | 0.028 | 0.33 | 0.16 | 0.54 | —, —, — |
| `CorridorDoorEntrance` | room | -2 | 1.00 | — | 0.020 | 0.32 | 0.14 | 0.40 | —, —, -24 |
| `Supports` | room | 0 | 1.00 | — | 0.005 | 0.39 | 0.22 | 0.46 | —, —, — |
| `Surfaces` | room | 0 | 1.00 | — | 0.293 | 0.29 | 0.16 | 0.47 | +0, +0, +0 |
| `Decor` | room | 0 | 1.00 | — | 0.003 | 0.49 | 0.23 | 0.45 | —, —, — |
| `RoomInstance` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `CorridorDoor` | room | 0 | 1.00 | — | 0.001 | 0.96 | 0.01 | 0.45 | —, —, — |
| `Atmosphere` | room | 0 | 1.00 | — | 0.002 | 0.56 | 0.37 | 0.46 | —, —, — |
| `Player/Camera2D` | camera | 1 | — | — | 0.005 | 0.43 | 0.30 | 0.42 | —, —, — |
| `Atmosphere/Front1` | parallax | 20 | 1.25 | 1.25 | 0.082 | 0.02 | 0.02 | 0.77 | —, —, — |

Violations: none


### LabCells

Start `Arrival`, ran +901 px and back -901 px; film frames 105–287; enemies frozen 0; hero on the floor 161 frames, feet–collision gap median 0.07 px, max 0.07 px; the hero's drawn feet vs the collision: far +12, mid +12, stand +12 (world px, + below).

| plane | kind | z | speed ×cam | scroll_scale | seen | value | contrast | sat | top at feet (px) |
|---|---|---|---|---|---|---|---|---|---|
| `Atmosphere/Far1` | parallax | -10 | 0.40 | 0.40 | 0.448 | 0.05 | 0.04 | 0.66 | —, —, — |
| `CorridorDoorEntrance` | room | -3 | 1.00 | — | — | — | — | — | —, —, — |
| `Cells` | room | -3 | 1.00 | — | 0.172 | 0.30 | 0.15 | 0.41 | —, —, — |
| `Table` | room | -1 | 1.00 | — | 0.030 | 0.32 | 0.13 | 0.43 | —, —, — |
| `Surfaces` | room | 0 | 1.00 | — | 0.293 | 0.30 | 0.15 | 0.47 | +0, +0, +0 |
| `Decor` | room | 0 | 1.00 | — | 0.001 | 0.52 | 0.26 | 0.44 | —, —, — |
| `RoomInstance` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `CorridorDoor` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Atmosphere` | room | 0 | 1.00 | — | 0.003 | 0.58 | 0.37 | 0.44 | —, —, — |
| `Prisoner` | room | 0 | 1.00 | — | 0.008 | 0.40 | 0.27 | 0.55 | —, —, — |
| `CompanionNPC_astrit` | room | 0 | 1.00 | — | 0.008 | 0.25 | 0.24 | 0.62 | —, —, — |
| `CompanionNPC_alisia` | room | 0 | 1.00 | — | 0.016 | 0.50 | 0.36 | 0.33 | —, —, — |
| `CompanionNPC_urizen` | room | 0 | 1.00 | — | 0.008 | 0.35 | 0.33 | 0.57 | —, —, — |
| `Player/Camera2D` | camera | 1 | — | — | 0.005 | 0.43 | 0.30 | 0.41 | —, —, — |
| `Atmosphere/Front1` | parallax | 20 | 1.25 | 1.25 | 0.082 | 0.02 | 0.02 | 0.77 | —, —, — |
| `FrontDark` | parallax | 20 | 1.30 | 1.30 | 0.131 | 0.02 | 0.01 | 0.51 | —, —, — |

Violations: none


### Laboratory

Start `SavePoint_Entrance`, ran +733 px and back -218 px; film frames 105–243; enemies frozen 0; hero on the floor 111 frames, feet–collision gap median 0.07 px, max 0.07 px; the hero's drawn feet vs the collision: far +11, mid +12, stand +12 (world px, + below).

| plane | kind | z | speed ×cam | scroll_scale | seen | value | contrast | sat | top at feet (px) |
|---|---|---|---|---|---|---|---|---|---|
| `Atmosphere/Far1` | parallax | -10 | 0.40 | 0.40 | 0.337 | 0.06 | 0.04 | 0.64 | —, —, — |
| `Atmosphere/Far2` | parallax | -10 | 0.40 | 0.40 | 0.173 | 0.03 | 0.02 | 0.72 | —, —, — |
| `Atmosphere/Far3` | parallax | -10 | 0.40 | 0.40 | — | — | — | — | —, —, — |
| `Atmosphere/Mid1` | parallax | -9 | 0.75 | 0.75 | 0.246 | 0.10 | 0.05 | 0.61 | —, —, -5 |
| `Atmosphere/Mid2` | parallax | -9 | 0.75 | 0.75 | — | — | — | — | —, —, — |
| `Atmosphere/Mid3` | parallax | -9 | 0.75 | 0.75 | — | — | — | — | —, —, — |
| `CellsDoorEntrance` | room | -2 | 1.00 | — | — | — | — | — | —, —, — |
| `BossDoorEntrance` | room | -2 | 1.00 | — | — | — | — | — | —, —, — |
| `Ladder1` | room | -1 | 1.00 | — | — | — | — | — | —, —, — |
| `Ladder2` | room | -1 | 1.00 | — | — | — | — | — | —, —, — |
| `Supports` | room | 0 | 1.00 | — | 0.005 | 0.39 | 0.22 | 0.46 | —, +22, — |
| `Surfaces` | room | 0 | 1.00 | — | 0.261 | 0.28 | 0.17 | 0.49 | -0, +0, +0 |
| `Decor` | room | 0 | 1.00 | — | 0.005 | 0.49 | 0.26 | 0.48 | —, -21, — |
| `RoomInstance` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `CellsDoor` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `BossDoor` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `SavePoint_Entrance` | room | 0 | 1.00 | — | 0.011 | 0.48 | 0.18 | 0.42 | —, —, — |
| `SavePoint_PreBoss` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Fight_Fly` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Fight_Upper` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Fight_TowerGuard` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Chest_TowerGuard` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Fight_Cursed` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Fight_Middle` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Fight_Lower` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Atmosphere` | room | 0 | 1.00 | — | 0.002 | 0.58 | 0.35 | 0.48 | —, —, — |
| `Player/Camera2D` | camera | 1 | — | — | 0.006 | 0.42 | 0.29 | 0.42 | —, —, — |
| `Atmosphere/Front1` | parallax | 20 | 1.25 | 1.25 | 0.021 | 0.03 | 0.04 | 0.70 | —, —, — |
| `Atmosphere/Front2` | parallax | 20 | 1.25 | 1.25 | 0.078 | 0.01 | 0.01 | 0.79 | —, —, — |
| `Atmosphere/Front3` | parallax | 20 | 1.25 | 1.25 | — | — | — | — | —, —, — |
| `FrontDark` | parallax | 20 | 1.30 | 1.30 | 0.015 | 0.02 | 0.01 | 0.51 | —, —, — |

Violations: none


### LaboratoryOutside

Start `Arrival`, ran +901 px and back -901 px; film frames 105–287; enemies frozen 0; hero on the floor 161 frames, feet–collision gap median 0.07 px, max 0.07 px; the hero's drawn feet vs the collision: far +12, mid +12, stand +12 (world px, + below).

| plane | kind | z | speed ×cam | scroll_scale | seen | value | contrast | sat | top at feet (px) |
|---|---|---|---|---|---|---|---|---|---|
| `HighSky` | room | -11 | 1.00 | — | — | — | — | — | —, —, — |
| `HighClouds` | parallax | -10 | 0.10 | 0.10 | — | — | — | — | —, —, — |
| `Backdrop/Plan5` | parallax | -10 | 0.00 | 0.00 | 0.259 | 0.81 | 0.02 | 0.15 | —, —, — |
| `Backdrop/Plan4` | parallax | -10 | 0.10 | 0.10 | 0.132 | 0.73 | 0.13 | 0.31 | —, —, — |
| `Backdrop/DriftingClouds/Cloud1` | parallax | -10 | 0.15 | 0.15 | — | — | — | — | —, —, — |
| `Backdrop/DriftingClouds/Cloud2` | parallax | -10 | 0.12 | 0.12 | 0.026 | 0.75 | 0.12 | 0.28 | —, —, — |
| `Backdrop/DriftingClouds/Cloud3` | parallax | -10 | 0.20 | 0.20 | 0.027 | 0.75 | 0.12 | 0.27 | —, —, — |
| `Backdrop/Plan3` | parallax | -10 | 0.30 | 0.30 | 0.015 | 0.65 | 0.16 | 0.21 | —, —, — |
| `Backdrop/Plan1` | parallax | -10 | 0.75 | 0.75 | 0.000 | 0.60 | 0.08 | 0.52 | —, —, — |
| `Mid` | parallax | -9 | 0.60 | 0.60 | 0.372 | 0.66 | 0.16 | 0.34 | —, —, — |
| `TileMap` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Decor` | room | 0 | 1.00 | — | 0.006 | 0.49 | 0.24 | 0.47 | —, —, — |
| `Terrain` | room | 0 | 1.00 | — | 0.198 | 0.45 | 0.15 | 0.35 | -25, -27, -24 |
| `RoomInstance` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Player/Camera2D` | camera | 1 | — | — | 0.005 | 0.42 | 0.29 | 0.42 | —, —, — |
| `FrontDark` | parallax | 20 | 1.30 | 1.30 | 0.167 | 0.09 | 0.03 | 0.65 | —, —, — |

Violations: 

- screen `far`: the floor plane `Terrain` is painted 25 px above the collision under the hero
- screen `mid`: the floor plane `Terrain` is painted 27 px above the collision under the hero
- screen `stand`: the floor plane `Terrain` is painted 24 px above the collision under the hero

### LizardCave

Start `Arrival`, ran +884 px and back -901 px; film frames 105–287; enemies frozen 0; hero on the floor 161 frames, feet–collision gap median 0.08 px, max 0.08 px; the hero's drawn feet vs the collision: far +12, mid +12, stand +12 (world px, + below).

| plane | kind | z | speed ×cam | scroll_scale | seen | value | contrast | sat | top at feet (px) |
|---|---|---|---|---|---|---|---|---|---|
| `Back` | room | -10 | 1.00 | — | 0.801 | 0.45 | 0.24 | 0.51 | —, —, — |
| `ExitDoor` | room | 0 | 1.00 | — | 0.001 | 0.96 | 0.01 | 0.45 | —, —, — |
| `Fight_CaveLizards` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Gate_Shrine` | room | 0 | 1.00 | — | 0.024 | 0.20 | 0.10 | 0.30 | -29, —, — |
| `ShamanMural` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Chest_Shrine` | room | 0 | 1.00 | — | 0.005 | 0.30 | 0.16 | 0.53 | —, —, — |
| `RoomInstance` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Player/Camera2D` | camera | 1 | — | — | 0.005 | 0.43 | 0.30 | 0.42 | —, —, — |
| `TopShade` | room | 19 | 0.00 | — | 0.147 | 0.03 | 0.00 | 0.55 | —, —, — |
| `FrontDark` | parallax | 20 | 1.30 | 1.30 | 0.046 | 0.13 | 0.05 | 0.51 | —, —, — |

Violations: 

- screen `far` (hero x 1204): 2 distinct speeds (×1.00, ×1.30)
- screen `mid` (hero x 762): 2 distinct speeds (×1.00, ×1.30)
- screen `stand` (hero x 301): 2 distinct speeds (×1.00, ×1.30)
- screen `far`: the floor plane `Gate_Shrine` is painted 29 px above the collision under the hero
- screen `mid`: no plane has a painted top at the hero's feet (within 80 px; what is there is solid from above, e.g. one baked backdrop)
- screen `stand`: no plane has a painted top at the hero's feet (within 80 px; what is there is solid from above, e.g. one baked backdrop)

### MayorHall

Start `Arrival`, ran +756 px and back -808 px; film frames 105–287; enemies frozen 0; hero on the floor 161 frames, feet–collision gap median 0.07 px, max 0.08 px; the hero's drawn feet vs the collision: far +12, mid +12, stand +12 (world px, + below).

| plane | kind | z | speed ×cam | scroll_scale | seen | value | contrast | sat | top at feet (px) |
|---|---|---|---|---|---|---|---|---|---|
| `Wall` | room | -10 | — | — | 0.713 | 0.49 | 0.21 | 0.44 | —, —, — |
| `CityDoorEntrance` | room | -2 | — | — | 0.033 | 0.45 | 0.27 | 0.47 | —, —, — |
| `TileMap` | room | 0 | — | — | 0.229 | 0.63 | 0.10 | 0.38 | +0, +0, +0 |
| `RoomInstance` | room | 0 | — | — | — | — | — | — | —, —, — |
| `Queue` | room | 0 | — | — | 0.031 | 0.40 | 0.35 | 0.47 | —, —, — |
| `CityDoor` | room | 0 | — | — | 0.001 | 0.96 | 0.01 | 0.45 | —, —, — |
| `Player/Camera2D` | camera | 1 | — | — | 0.005 | 0.43 | 0.30 | 0.42 | —, —, — |

Violations: 

- the camera does not pan (the room fits the view): no parallax is possible, depth only from overlap, value and scale
- no foreground piece (nothing drawn in front of the hero, D774)

### MesaClimb

Start `Arrival`, ran +732 px and back -840 px; film frames 105–285; enemies frozen 0; hero on the floor 159 frames, feet–collision gap median 0.07 px, max 0.08 px; the hero's drawn feet vs the collision: far +12, mid +12, stand +12 (world px, + below).

| plane | kind | z | speed ×cam | scroll_scale | seen | value | contrast | sat | top at feet (px) |
|---|---|---|---|---|---|---|---|---|---|
| `Back` | room | -10 | — | — | 0.605 | 0.51 | 0.24 | 0.46 | —, —, — |
| `ExitDoorEntrance` | room | -2 | — | — | 0.038 | 0.40 | 0.20 | 0.62 | —, —, — |
| `ExitDoor` | room | 0 | — | — | 0.001 | 0.96 | 0.01 | 0.45 | —, —, — |
| `Ledges` | room | 0 | — | — | 0.161 | 0.47 | 0.21 | 0.56 | —, —, — |
| `Chest_Mesa` | room | 0 | — | — | — | — | — | — | —, —, — |
| `Fight_Vultures` | room | 0 | — | — | — | — | — | — | —, —, — |
| `RoomInstance` | room | 0 | — | — | — | — | — | — | —, —, — |
| `Player/Camera2D` | camera | 1 | — | — | 0.005 | 0.43 | 0.30 | 0.42 | —, —, — |
| `TopShade` | room | 19 | — | — | 0.189 | 0.03 | 0.00 | 0.55 | —, —, — |
| `FrontDark` | parallax | 20 | — | 1.30 | 0.003 | 0.13 | 0.10 | 0.36 | —, —, — |

Violations: 

- the camera does not pan (the room fits the view): no parallax is possible, depth only from overlap, value and scale
- screen `far`: no plane has a painted top at the hero's feet (within 80 px; what is there is solid from above, e.g. one baked backdrop)
- screen `mid`: no plane has a painted top at the hero's feet (within 80 px; what is there is solid from above, e.g. one baked backdrop)
- screen `stand`: no plane has a painted top at the hero's feet (within 80 px; what is there is solid from above, e.g. one baked backdrop)

### Village

Start `Arrival`, ran +901 px and back -901 px; film frames 105–287; enemies frozen 0; hero on the floor 161 frames, feet–collision gap median 0.07 px, max 0.07 px; the hero's drawn feet vs the collision: far +12, mid +12, stand +12 (world px, + below).

| plane | kind | z | speed ×cam | scroll_scale | seen | value | contrast | sat | top at feet (px) |
|---|---|---|---|---|---|---|---|---|---|
| `Backdrop/Plan5` | parallax | -10 | 0.00 | 0.00 | 0.137 | 0.81 | 0.01 | 0.15 | —, —, — |
| `Backdrop/Plan4` | parallax | -10 | 0.10 | 0.10 | 0.158 | 0.72 | 0.13 | 0.32 | —, —, — |
| `Backdrop/DriftingClouds/Cloud1` | parallax | -10 | 0.15 | 0.15 | — | — | — | — | —, —, — |
| `Backdrop/DriftingClouds/Cloud2` | parallax | -10 | 0.12 | 0.12 | 0.001 | 0.58 | 0.02 | 0.43 | —, —, — |
| `Backdrop/DriftingClouds/Cloud3` | parallax | -10 | 0.20 | 0.20 | 0.030 | 0.75 | 0.12 | 0.27 | —, —, — |
| `Backdrop/Plan3` | parallax | -10 | 0.30 | 0.30 | 0.124 | 0.64 | 0.16 | 0.22 | —, —, — |
| `Backdrop/Walls` | parallax | -10 | 0.45 | 0.45 | 0.014 | 0.56 | 0.12 | 0.46 | —, —, — |
| `Backdrop/Plan1` | parallax | -10 | 0.75 | 0.75 | 0.000 | 0.53 | 0.05 | 0.56 | —, —, — |
| `Veil` | room | -9 | 1.00 | — | — | — | — | — | —, —, — |
| `Back` | parallax | -9 | 0.60 | 0.60 | 0.063 | 0.64 | 0.10 | 0.21 | —, —, — |
| `Houses` | parallax | -9 | 0.85 | 0.85 | 0.266 | 0.54 | 0.16 | 0.35 | —, —, — |
| `TileMap` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `GrandpaHouse` | room | 0 | 1.00 | — | 0.025 | 0.47 | 0.25 | 0.46 | —, —, — |
| `ElderHouse` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Decor` | room | 0 | 1.00 | — | 0.006 | 0.48 | 0.18 | 0.53 | —, —, — |
| `Terrain` | room | 0 | 1.00 | — | 0.188 | 0.60 | 0.11 | 0.49 | -25, -27, -25 |
| `RoomInstance` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `ElderDoor` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `EnemySpawner` | room | 0 | 1.00 | — | — | — | — | — | —, —, — |
| `Player/Camera2D` | camera | 1 | — | — | 0.005 | 0.42 | 0.29 | 0.42 | —, —, — |
| `FrontDark` | parallax | 20 | 1.30 | 1.30 | 0.167 | 0.09 | 0.03 | 0.65 | —, —, — |

Violations: 

- screen `far`: the floor plane `Terrain` is painted 25 px above the collision under the hero
- screen `mid`: the floor plane `Terrain` is painted 27 px above the collision under the hero
- screen `stand`: the floor plane `Terrain` is painted 25 px above the collision under the hero

