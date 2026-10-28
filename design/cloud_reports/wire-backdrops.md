---
type: cloud-report
branch: cloud/wire-backdrops
date: 2026-10-28
---
# Cloud report: wire-backdrops

**Summary**
- **Done:** every finished backdrop from the brief is now in its room (Sapega 2026-10-28: «чому не всі арти підключені?»). Road: **MountainPath, ScreeSlide, StreamGorge, RockLedges**. Also **CaveUnderBridge** (`BridgeCave/`), the **attic** in `ElderHouse` (`GrandfatherAttic/`), **MesaTop**, **ZahraRest** (the well is a painted opening), and the **burnt Village** in every state. The world-rooms rooms are wired in `Scripts/Tools/build_world_rooms.py` (`PAINTED`), so re-running the generator keeps the art. Doors, triggers, spawns, NPCs and chests are kept; the attic chest and notes moved a little (below).
- **Not done:** palms (`Decor/Palm1–3`, `FrontDark/OccluderPalm1–2`), banners (`Banner1–2`) and the 35 grass tufts in the Village stay green, because there is no charred asset yet (art queue). The end-game rope ladders of the cave (`gen_ladder.png`) are not placed, because no end-game flag exists. Room atmosphere (dragonflies, glints, dust, spores, sparks) is not added.
- **D-IDs:** D870–D873 below (renumbered by integrate-32 from D864–D867).
- **B rows fixed:** none.
- **Full suite:** `run_verify.sh` (J=4): **5 FAIL**. Three passed when re-run alone: `camera_transitions`, `weapon_animations` and `repeat_load` (load timing under J=4). Two are not this branch's: `verify_difficulty` (17 FAIL; D822's open rows, also red on feature/backlog per world-rooms) and `verify_lab_boss` (2 FAIL, mercenary balance; no lab or combat file touched here).

Godot 4.6.2 downloaded and ran here. Every test named in the prompt was run (RESULT lines below), plus `verify_branches`, `verify_gates`, `verify_journal_notes` and `verify_charms`, which go through the attic. The `room-content` skill is not in this checkout (`.claude/` is gitignored), so I worked from the READMEs and D750/D814/D830/D834.

## D-ID text (for the orchestrator)

| D | Kind | Text |
|---|---|---|
| D870 | ROUTINE CALL (wire-backdrops) | **The painted planes replace the placeholder kits, wired from each folder's README table** (Sapega 28.10: «чому не всі арти підключені?»). `build_world_rooms.py` has a `PAINTED` table: node, texture, factor, position. Planes with factor 1.0 are plain sprites in `Ground` (the drawn floor, `verify_map_geometry` rule 6). Below the art, the room's bottom is filled with the art's own last row, stretched down. Occluders sit in `FrontDark`. **Road:** the planes are world-anchored as in `MountainPath/README` (−factor × the room's offset), and they scroll on both axes. Our Mountain Path is 3 cells, not the README's 2, so the extra cell counts as the west end of the path. Each room's offset is then the README's own: scree 1152, gorge (1728, 320), ledges 3456 art. Every road and cave plane is drawn **32 px higher** than its README anchor, because the art's walk line is 416 and the world-rooms floors are 384 (as the Village). The scree's `Slope` collision follows the painted surface: (96, 384) → (720, 864). **Measured (Godot 4.6.2):** `Parallax2D` takes the camera as centre − (960, 540), the 1920×1080 viewport, and ignores the camera zoom. So a plane that the README draws at anchor − f × camera gets + (1 − f) × (528, 297) (`VIEW_FIX`); without this the sky was off screen and the far planes left grey holes. |
| D871 | ROUTINE CALL (wire-backdrops, D830/D834) | **The rock ledges stay a ramp, and the art is bent to it.** The road has no steps (D830). world-rooms' ramp (96, 864) → (768, 384) is kept as it is. `Scripts/Tools/ledges_ramp.py` shifts each column of `gen_ledges.png` so its README walk line lands on the ramp; nothing is repainted. The result is `RockLedges/gen_ledges_ramp.png`, and the original stays as the source. The blocks read as a sheared stone ramp (`design/shots/wire_backdrops/ledges_*.png`). The cascade at the bottom left lifts a little with the bank. If Sapega prefers the 7 steps on this fight-free stretch, the README table is the collision to build instead. |
| D872 | ROUTINE CALL (wire-backdrops) | **The cave under the bridge takes the painted shelves' collision.** The top shelf is 0–480 at y 384 (it ends at 495 in the art). The middle shelf is 384–864 at 864 (369 in the art). The floor is at 1344, with the **pit at 96–224**, which leads down to the cave exit. Before, the holes were at 608–800, 64–256 and 320–544, which did not match the painted rock. Inner wall tiles in the outer columns cover the painted ~39 px side walls. Below the cave there is a dark backstop in the kit's fill colour, seen through the pit. The order of falls is the same: off the east end, then off the west end, then down the pit. |
| D873 | ROUTINE CALL (wire-backdrops, D621) | **The grandfather's attic is the painted one-screen attic.** The planes are placed from `GrandfatherAttic/README` with the walk line on the attic floor (y 448). The floor collision now spans the screen (walls in the outer tile columns), and its hole is under the painted hatch (tiles 14–15). The ladder, `Ledge_Hatch` and `Hatch_Attic` moved from x 384 to **480**, and the notes moved to the shrine (x 702). The charm chest moved from x 480 (the hatch) to **340**, beside the painted belongings (the painted iron-bound chest is his storage, not the charm chest). The old tile look (`Back`, `Beams`, `Rug`, `FloorOverHatch`) is gone; the dark `Dark` layer stays as the filler above the roof. The herbs hang in `FrontDark` (`OccluderHerbs`). |

Also applied, without a new D (the briefs already decided them):
- **D796 burnt Village:** the four textures were swapped for `_burnt`. `Back` region is (0, 0, 576, 324) and `Houses` region is (0, 0, 576, 276), both with offset 0. Backdrop modulate is (0.72, 0.66, 0.68). Pollen became embers (`atmo_embers`). The larks and butterflies are gone, and `verify_ambient_critters` LIVES/AIR now say so.
- **ZahraRest:** the well is a painted sprite (`Well`, z −2). `WellDoorEntrance` is deleted, `WellDoor` is at x 900 with no entrance art, and `"ZahraRest/WellDoor"` is in `PAINTED` of `verify_room_entrances.gd`. One deviation from the README: the reeds occluder is at y **275**, not 219, so its foot is below the view (D750; `verify_room_entrances` failed with 219).
- **MesaTop:** the floor strip is at y **381**, not 384. Rows 0–1 of `MesaClimb/gen_floor.png` are a ragged lip (36–71 % opaque), so at 384 seven tile tops were bare (`verify_map_geometry` rule 6).

**Open (non-blocking):** charred palms, banners and grass for the Village (art queue). Whether to keep the bent ramp art on the ledges or build the README's steps (D871).

## Tests

| Test | Result |
|---|---|
| verify_map_geometry | PASS (first run: MesaTop bare tops, fixed by y 381) |
| verify_scripts_compile | PASS |
| verify_camera_rooms | PASS |
| verify_camera_transitions | PASS |
| verify_world_rooms | PASS |
| verify_room_entrances | PASS (first run: ZahraRest reeds foot in view, fixed) |
| verify_village_fight | PASS |
| verify_village_house | PASS |
| verify_ambient_critters | PASS |
| verify_branches | PASS (the attic walk times follow the new hatch → notes → potion distances) |
| verify_gates | PASS (stands under `hatch.global_position.x` instead of a literal 384) |
| verify_journal_notes, verify_charms | PASS |

Full suite (`run_verify.sh`, J=4, nproc = 4):

```
FAIL  verify_difficulty  6 s — RESULT: 17 FAIL
FAIL  verify_camera_transitions  385 s — RESULT: 1 FAIL (biggest one-frame drop 6.75 px) → alone: PASS 386 s
FAIL  verify_lab_boss  56 s — RESULT: 2 FAIL (balanced build vs the mercenary)
FAIL  verify_repeat_load  9 s — RESULT: 1 FAIL (node count 636 → 637) → alone: PASS
FAIL  verify_weapon_animations  57 s — RESULT: 1 FAIL ([false, true, true]) → alone: PASS
SUITE: 5 FAIL in 19 min 32 s, J=4
```

## Shots
`design/shots/wire_backdrops.png` (contact sheet, 22 frames) and full frames in `design/shots/wire_backdrops/`: `path_1–3`, `scree_top/bottom`, `gorge_1–3`, `ledges_bottom/top`, `village_1–3`, `attic`, `cave_top/middle/floor`, `mesa_1–2`, `zahra_1/well/3`. Capture: `SampleProject/UI/capture_wire_backdrops.gd`.

## Files
- `Scripts/Tools/build_world_rooms.py`: `ROAD`, `DY`, `VIEW_FIX`, `at()`, `road()`, `cave()`, `PAINTED`, `PAINTED_SIZE`, `Room.painted()`; `walls_in`, `slope_line`; ZahraRest's `WellDoor` without art; new cave holes.
- `Scripts/Tools/ledges_ramp.py` → `RockLedges/gen_ledges_ramp.png` (+ README section).
- `SampleProject/Maps/{MountainPath,ScreeSlide,StreamGorge,RockLedges,CaveUnderBridge,MesaTop,ZahraRest}.tscn` (generated), `ElderHouse.tscn` and `Village.tscn` (by hand).
- Tests: `verify_ambient_critters.gd`, `verify_room_entrances.gd`, `verify_branches.gd`, `verify_gates.gd`; capture `capture_wire_backdrops.gd`.
