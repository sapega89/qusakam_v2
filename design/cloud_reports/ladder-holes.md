---
type: cloud-report
branch: cloud/ladder-holes
date: 2026-10-27
tags: [cloud, rooms, art, bug]
---

# Cloud report: ladder-holes (B201, whole floors where a ladder or hatch passes)

**Summary.** B201 is fixed. The only floor in the game that was actually cut for a ladder or hatch is the ElderHouse attic (Sapega's screenshot): 4 floor tiles were missing over the ladder, which left a black slot with a stray lid fragment in it. That art is whole now. Collision and routes are unchanged.
Every other spot on the list is already whole and needed no change: TavernAttic, Rooftops, City, CollapsedDrain and LabCells use doors, not floor holes; the Laboratory Ladder1/Ladder2 floors are whole sprite art (the gap is only in the invisible collision layer); the DesertRoad Shop/Tower ladders lean on walls.
All ladders now show a few rungs above their top, so the rails are no longer cut flush with the floor. This only changes how they are drawn.
**D-ID text** (number to assign): «B201 / Sapega 2026-10-28 «обрізаної підлоги не має бути»: where a ladder or hatch passes through a floor, the floor art stays whole. No hole, no black slot, no lid sprite. The ladder is drawn behind the floor and shows a few rungs above its top (wood 3, iron 1). Climbing through still uses the one-way ledge, the gate Body and the ladder strip, unchanged. A locked hatch has no art; it is read through its «Open» prompt and the locked line.»
**B rows fixed:** B201.
**Tests:** verify_ladders, room_entrances, map_geometry, laboratory, lab_route, village_house, scripts_compile, gates: all `RESULT: ALL PASS`. Full suite: `SUITE: 14 FAIL in 15 min 48 s, J=4`. 13 of them fail the same way on the base commit (`feature/backlog` before this branch). The 14th, verify_repeat_load, failed once by one node (635 → 636) and then passed 2 of 2 re-runs. None of the 14 comes from this change.
The `room-content` skill named in the prompt (`.claude/skills/room-content/SKILL.md`) does not exist on `feature/backlog`; there is no `.claude/skills/` folder at all, so I worked without it.

## What changed
- `SampleProject/Maps/ElderHouse.tscn`: new `Attic/FloorOverHatch` TileMapLayer with `collision_enabled = false`. It holds the same floor tile (source 1, atlas 8,6) in cells (10..13, 14), the gap in `Attic/Floor`. `Attic/Floor` keeps its gap, so the collision stays the same: `Ledge_Hatch` (one-way), `Hatch_Attic/Body` (locked gate) and `Ladder_Attic` are untouched.
- Same file: `Attic/Hatch_Attic/Sprite` now has `visible = false`. That sprite was the lid, a rotated piece of `gen_wall` sitting in the slot, the «обрізаний кусок». `LockedDoor` still works: Body, Area, «Open», the locked dialogue and `open()`. The tween on an invisible sprite does no harm. `verify_gates` passes.
- `SampleProject/Scripts/Gameplay/Ladder.gd`: a new `rise` entry in `ART` (wood 3 rungs ≈ 40 px, iron 1 rung = 30 px); `_draw()` starts at `-step * rise`. `contains()`, `WIDTH` and `TOP_REACH` are unchanged, so climbing works as before.
- `SampleProject/UI/capture_ladder_holes.gd`: new windowed capture of all 13 spots.

## Check, spot by spot
| Spot | Before | Action |
|---|---|---|
| ElderHouse attic hatch | black slot, lid fragment, rails cut at the floor | floor filled, lid hidden, rails rise above |
| ElderHouse ground floor (under the hatch) | ladder against the wall | unchanged |
| Laboratory Ladder1 / Ladder2 | floor art whole (gap only in the invisible `Foreground` collision layer) | none; the ladder art gets its 1 rung of rise |
| DesertRoad Ladder_Shop / Ladder_Tower | ladders lean on walls; no floor | none; the rails now rise above the roof edge |
| City (Rooftops / TavernAttic doors), TavernAttic, Rooftops, CollapsedDrain hatch | door entrances on a single whole `Floor1` sprite | none |

Shots: `design/shots/ladder_holes.png` (before | after, all 13 spots, 960×540 crops at game scale).

Seen on the way, not changed: in my Laboratory crops neither iron ladder can be seen, before or after. Ladder1/Ladder2 are drawn at z −1 inside the room's art. That belongs to Q113 (the Laboratory ladders), so I left it alone. Maps/MapData.txt was not touched.

## Full suite
`SUITE: 14 FAIL in 15 min 48 s, J=4`. To check, I re-ran each failing test on the base commit `0fbb86a4^` in a separate worktree:
- **The same failure on the base (13), so not from this branch:** ambient_critters (2 FAIL), camera_rooms (HUNG 180 s), combat_player (1 FAIL: refusal flash), difficulty (5 FAIL), cutscene (2 FAIL: descent), flying_enemies (ALL PASS + 2 SCRIPT ERROR, `spawn_points` on null at verify_flying_enemies.gd:398), camera_transitions (1 FAIL), memory (no RESULT), progression (no RESULT), quiet_transitions (1 FAIL), room_preload (3 FAIL), road_sections (1 FAIL), secrets (1 FAIL: laboratory 1).
- **Flaky:** verify_repeat_load, `node count does not grow (635 → 636)` once in the J=4 run; then `PASS` 2 of 2 on this branch alone.
