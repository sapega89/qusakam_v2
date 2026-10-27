---
type: plan
status: planned
tags: [art, rooms, scale, M6]
---

# World scale — one size chart for everything next to the hero

**Nothing implemented.** 2026-10-27. A player asked Sapega why everything is so big next to the hero; Sapega: «це
все ж таки світ, все має бути лаконічно, підходити по розмірах; може, треба розмірна сітка». No Figma: Sapega's
Figma plan may have ended («генерація у фігма може бути вже не доступна»), so the chart is a picture made from the
real sprites at their real in-game size, plus a data file the tools and a test read.

## What exists today
| Thing | Where | State |
|---|---|---|
| The hero's size | `Sprites/Player/Idle/2.png`: 47 px of art in a 64 px cell, drawn ×1.5 (`SampleProject/Player.tscn:1622`) → **≈70 world px tall** in a 480 px tall view (≈15 %) | ✅ the unit |
| Adults ×1.5 the hero | D172 (NPC sprites ×1.5, feet on the hero's foot line) | ✅ rule |
| Chibi proportions, the hero the smallest | D598 (MapleStory) | ✅ rule |
| Enemy size classes | D560 (small ×0.8, medium ×1.0, large ×1.3), D766 (elites ×1.25) | ✅ rule |
| Props and backdrop objects | generated per room (`comfy_backdrop.py` props, backdrop planes) with no size target | ❌ each sized by eye; e.g. the gates are 416 px (≈6 hero heights), Bandit Camp's barrel is about the hero's height |
| A measure of drawn size | the depth probe renders each plane solo (`film_rooms.gd`, `cloud/depth-film`) | ⚠️ planes, not objects |

## How it works
1. **The unit H = the hero's drawn height (≈70 world px).** Every category gets a target in H (a draft until Sapega
   approves the chart). Draft, MapleStory-like and compact:

   | Category | Target | ≈ world px |
   |---|---|---|
   | adult NPC / human enemy | 1.5 H (D172) | 105 |
   | ordinary door, doorway, arch passage | 1.6–1.8 H | 112–126 |
   | big gate (city, fortress) | 2.5–3 H | 175–210 |
   | locked door / shrine gate in a room | 1.8–2.2 H (floor-to-ceiling only as a wall with the door in it) | 126–154 |
   | barrel | 0.5 H | 35 |
   | crate, chest | 0.4–0.5 H | 28–35 |
   | sack, pot | 0.3–0.4 H | 21–28 |
   | table, bench, chair | 0.45–0.55 H | 32–38 |
   | lamp post, banner pole | 2–2.5 H | 140–175 |
   | tent | 2.5–3 H | 175–210 |
   | one storey of a house | 2–2.3 H | 140–160 |
   | palm, tree | 3–4.5 H | 210–315 |
   | bush, grass tuft | 0.3–0.6 H | 21–42 |
   | bat, pigeon, lark | 0.25–0.35 H | 18–25 |
   | butterfly, moth, mouse | 0.1–0.15 H | 7–11 |
   Backdrop planes shrink with distance: an object on the ×0.8 plane is drawn about 0.8× its chart size, ×0.4 about 0.4×.
2. **Data:** `design/world_scale.json` — categories, target H ranges, the keywords that put a node or texture in a
   category (`barrel`, `crate`, `door`, `gate`, `tent`, …), the plane factor.
3. **Probe** (`SampleProject/UI/probe_world_scale.gd`): every room, every drawn object that is not a full plane (props,
   decor, doors, NPCs, enemies, critters): its drawn height in world px (texture region × scale, or a solo render),
   its category, the target, and the verdict (ok / too big / too small). Out: a table per room.
4. **The chart picture** (`Scripts/Tools/scale_chart.py`): the hero on a 1 H grid, and next to him the real sprites at
   their real size — today's and, beside each offender, the size the chart wants. `design/shots/scale_chart.png`.
5. **Use it:** the art tools take the target from the data (`comfy_backdrop.py` props and `comfy_sprite.py` crops ask
   for «N world px tall»); backdrop prompts carry the scale («doors about 1.7 times the height of a small lizard
   warrior»); the room routine (M7) places props at chart size; `verify_world_scale.gd` keeps fixed rooms from drifting.

## Decisions required
1. **The chart values** — GAME/ART DECISION (Sapega): the draft above is the default until he answers the chart picture.
   Not blocking the probe.
2. **Shrink or regenerate** an offender: scaling a pixel sprite by a non-integer breaks its pixel grid. Recommendation:
   scale by ×0.5 / ×0.75 only where it still reads, otherwise regenerate at the target size (art lane).

## Slices
### Slice 1 — measure and show (☁ `scale-probe`)
- `world_scale.json` (the draft), `probe_world_scale.gd`, `scale_chart.py`; the per-room table and the chart picture;
  proposed B rows for the worst offenders. Own commit.
### Slice 2 — Sapega approves the chart (👤)
### Slice 3 — fix the offenders (☁ for placements and scales in scenes; 🖥 for regenerations)
### Slice 4 — keep it (M6 prompts, M7 placement, `verify_world_scale.gd` per fixed room)

## Order and dependencies
`1 → 2 → 3 → 4`; slice 4's prompt rule applies to M6 from now on with the draft values.

## Out of scope for this pass
The hero's own size and the chibi proportions (D598); the enemy size classes (D560, D766); the UI scale.
