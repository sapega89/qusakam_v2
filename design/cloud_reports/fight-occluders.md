---
type: report
tags: [cloud, routines, foreground, combat]
---

# fight-occluders — B199 (front occluders hide the fight)

**Done:** `FightOccluderFade.gd` (child of Game, every room): during a fight each ×1.3 occluder over the fight area fades to 0.25 alpha in 0.2 s, and comes back after the fight. New B199 check in `verify_room_entrances`: ALL PASS, 14 occluder-over-fight cases; with the fade switched off it gives **14 FAIL**, so the check catches the bug.
**Also green:** `verify_camera_transitions`, `verify_combat_flow`, `verify_scripts_compile`, all ALL PASS. D800's limit checks and D750's "fight's middle" check are unchanged and pass.
**Capture:** `design/shots/fight_occluders.png`, DesertRoad, first road fight: before (rock and palm hide the jackal and a bandit) | after.
**Not done:** no occluder nodes moved (none needed). No `.tscn` or MapData changes.
**D-ID (next free, D835 on feature/backlog at branch time), text below.** **B rows fixed:** B199.
**Full suite:** `SUITE: 1 FAIL in 13 min 8 s, J=4` (138 PASS). The failure is `verify_difficulty` 3 FAIL (scorpion L9 hit counts, elite tower shield guard L9, elite armoured scorpion L11). It fails the same way with the fade unhooked from `Game.gd`, so it is not from this branch.
Godot 4.6.2 download worked.

## D835 (as built)
| D835 | ROUTINE CALL (`cloud/fight-occluders`, fixes B199, extends D750 / D800) | **Front occluders fade over a running fight.** `Scripts/Gameplay/FightOccluderFade.gd` (preloaded by `Game.gd`, added as child `FightOccluderFade` in `Game._ready`, no `class_name`). Each frame of every room, the occluders are the D750 set: `Occluder*` / `Pillar*` sprites in a Parallax2D with scroll > 1. **A fight runs** while a live `enemies`-group enemy of the room is aggroed (CHASE / ATTACK / RETREAT) or on screen. **The fight area** is the screen rect spanning the hero, those enemies and the on-screen spawn points of every RoomEnemySpawner that still has live enemies, each as a body box (−40, −96, 80 × 112 world px), clipped to the view. Every occluder whose drawn rect overlaps that area eases to **alpha 0.25 in 0.2 s** (`move_toward`). Once there is no fight, or the occluder leaves the area, it eases back to 1.0. Outside fights nothing changes, so D750's "sometimes covers part of the view" stands. Checked in `verify_room_entrances` (`_check_fight_fade`): in every room with fights, each fight is started and the hero stands on each spawn point with a live enemy. Every occluder over the hero or the point must be ≤ 0.30 alpha, and after despawn all are back at 1.0. |

## Why a fade, not placement
The occluders scroll at ×1.3, so they slide relative to the world as the camera moves. A fight also moves around the room (chase, knockback, dodge, flyers), and the camera follows the hero. To keep every occluder out of the fight at every camera position, each fight's whole span plus 0.3 × the camera travel across it would need to be occluder-free. On DesertRoad and BanditCamp that leaves almost no room for the D750 occluders at all. Moving nodes would also only fix today's spawn points: the next fight that drifts would bring the bug back. The fade hooks the one thing every fight has (live aggroed or on-screen enemies), so it works in every room, including future M6 rooms and boss fights, with no per-room data. D800's limit rule still governs where occluders rest.

## Details
- `SampleProject/Scripts/Gameplay/FightOccluderFade.gd`: `_process` (caches occluders and spawners on room change), `occluders_of`, `screen_rect`, `fight_area`, `_engaged`.
- `SampleProject/Scripts/Game.gd`: preload and `add_child` next to the mouse cursor.
- `SampleProject/UI/verify_room_entrances.gd`: `_check_fight_fade` runs after `_check_limits`. It uses the live node instead of a preload: a preload would compile Game before the autoloads exist in a SceneTree script.
- Cases covered (OK): Village EnemySpawner/1 (Palm1); DesertRoad EnemySpawner/1–3 (Rock1, Palm1), Fight_Mesa/2 (Palm2), Fight_Caravan/BigSlot_ArmouredScorpion_1, 3, 4 (Rock2); BanditCamp Fight_Camp/1, 2, BigSlot_BanditBrute_1 (Ropes1, Ropes2); Laboratory Fight_Fly/1 (Pillar1), Fight_Middle/1 (Pillar2). CityGates, GatehouseCellar and MesaClimb have fights, but no occluder covers them.
- Capture: `SampleProject/UI/capture_fight_occluders.gd` (xvfb, 1920×1080, two half-size frames side by side).
- Untracked `SampleProject/UI/capture_starting_skills.gd.uid` was produced by import; it is not this task's file and was not committed.
