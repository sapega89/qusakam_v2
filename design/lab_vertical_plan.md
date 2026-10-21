---
type: plan
status: done
---

# Vertical rooms — Laboratory first (Tails of Iron style) — plan

> **Superseded by [[lab_story_plan]]** (D303): slices 1–2 built (D225, ladders, one-way platforms); the Laboratory's storeys and rooms are now planned there.

Critics 2026-10-18: rooms are flat, one floor, no verticality. Sapega: «Кімнати пласкі… оце я б виправив,
референс — Tails of Iron»; first room — **the Laboratory**; floors joined by **ladders + one-way platforms**;
no ability-locked ledges yet. Decision: D225.

## What exists
| Thing | Where | State |
|---|---|---|
| One-way platform tiles | `Resources/Tileset.tres` atlas `(0..2, 0)` (all three sources) | ✅ |
| Drop through a one-way platform | `PlayerMover._handle_jump` (↓ + jump → `position.y += 8`) | ✅ |
| Ladders / climbing | — (`grep -i ladder\|climb` → 0) | ❌ |
| Laboratory | 2 MetSys cells in one row (`MapData.txt` `[14..15,3,2]`), floor strip rows 12–14 | flat |

## Slices
### Slice 1 — ladders
`Scenes/Gameplay/Objects/Ladder.tscn` + `Scripts/Gameplay/Ladder.gd` (group `ladders`, height in px, art from
`Scripts/Tools/draw_ladder.py`); climbing in `PlayerMover` (↑/↓ on a ladder, jump without ↑ leaves it,
↓ at the top climbs down through the one-way platform); `Climb` animation in `Player.tscn`.
Check: `verify_ladders.gd`.

### Slice 2 — the Laboratory on three floors
`Scripts/Tools/build_laboratory.gd` paints the room from an ASCII layout (54 × 45 tiles = 2 × 3 cells) and
places triggers, save points, spawn points and ladders: top floor — entrance, Companion 01; middle — Companion
02 and 03; bottom — pre-boss save, limit test, arena, exit to LaboratoryOutside (moved down to row 5 of the
map). `MapData.txt` cells and borders updated. Checks: `verify_laboratory` (walks to the trigger nodes),
`verify_map_geometry`.

### 2026-10-21 — the storeys become the mob corridors ([[lab_story_plan]], D303)
The companion talks and the limit test leave the three storeys (BACKLOG 17); the room keeps its geometry, gains three
trigger-zone fights and a west door to the new `LabCells`; the boss moves to `LabBoss`.

### Later (not now)
- ~~**Parallax behind the Laboratory**~~ — done (D246: generated far/mid/front planes per storey and generated walkable surfaces). Was (Sapega, 2026-10-18, «на майбутнє»):  the background is a flat brick tile layer + `BackColumns`; add parallax layers behind it (distant halls, arches, machinery, blurred per D233) — a candidate for ComfyUI backgrounds (D234).
Other rooms vertical (Canyon, Village, Road), ability-locked ledges (double jump), secrets — after Sapega's call.
