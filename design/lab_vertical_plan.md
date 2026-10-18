---
type: plan
status: in-progress  # slices 1–2 built 2026-10-18 (D225)
---

# Vertical rooms — Laboratory first (Tails of Iron style) — plan

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

### Later (not now)
- **Parallax behind the Laboratory** (Sapega, 2026-10-18, «на майбутнє»): today the background is a flat brick tile layer + `BackColumns`; add parallax layers behind it (distant halls, arches, machinery, blurred per D233) — a candidate for ComfyUI backgrounds (D234).
Other rooms vertical (Canyon, Village, Road), ability-locked ledges (double jump), secrets — after Sapega's call.
