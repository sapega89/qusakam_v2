# Dry Riverbed planes (M6b-4)

**AI-generated.** Made with `design/shots/candidates/m6b4/m6b4.py` on top of `Scripts/Tools/comfy_backdrop.py`, using
**Qwen-Image** (Alibaba Qwen, Apache 2.0) with the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0); the boat was
cleaned with **Qwen-Image-Edit-2511** (Apache 2.0: the sand mound under it removed), the far wall's end of the gorge
and the hole in the floor were repainted by Qwen-Image over the room's own picture (masked img2img). Brought down ×3
to the game's pixel and a few colours (octree); the far wall is darkened toward violet for depth. A Steam release has
to disclose AI-generated content. Review: `design/shots/m6b4_chasm_riverbed.png` (frames 3–4).

The room (`Maps/DryRiverbed.tscn`): underground, **one cell** in the scene and MapData ([16,6], 576 × 320 art = 864 ×
480 world; the m6 table said 1×2). The camera never moves, so every plane is one fixed composition (no seam). Walls at
both screen edges; the top is open where the hero falls in from the Chasm above (160…704 world), painted as the crack
of pale sky high in the gorge; floor y 384 world (art row 256) with a **hole 576…800 world** (art 384…533) — the drop
on into the Aqueduct ([16,7]). The bed of a river long gone: water-carved walls with old water lines, rounded
boulders, a bleached driftwood log, dead reeds, cracked mud, a stranded boat; the river's way on is choked by a
rockfall, and its water once drained through the floor into the old aqueduct vault, whose cut blocks show in the
hole's edges.

## Planes, back to front

Art px, room-local; every sprite `texture_filter = 1`, `scale = (1.5, 1.5)`, `centered = false`. The camera stays at
x 0, so a plane is drawn exactly at its position; no plane needs a repeat (`repeat_size` 0).

| node (replaces) | file | size | factor | position (world) | what |
|---|---|---|---|---|---|
| `Back/Far` (LizardCave far; ×0.4 → ×0.45, no repeat) | `gen_far.png` | 576×324 | 0.45 | (0, 0); opaque | the gorge bottom: layered water-worn walls leaning together, the crack of pale sky at the top (the Chasm above), the gorge's end choked by fallen boulders |
| `Back/Mid` (LizardCave wall) → `Back/Banks` (×0.8 → ×0.75) | `gen_banks.png` | 576×120 | 0.75 | (0, 237) | the old bank: big rounded boulders, the driftwood log, dead reeds, cracked mud; its bottom rows sit under the floor |
| `Back/Boat` (new Parallax2D ×0.85, one Sprite2D) | `gen_boat.png` | 84×54 | 0.85 | (162, 307.5) | a wrecked river boat with a snapped mast and a rope; 1 H (64) × 0.85 = 54 (D814); west of the Arrival (x 300) |
| `Ground/Riverbed` (replaces `Fill1`, `Floor1`, `Fill2`, `Floor2`) | `gen_ground.png` | 576×64 | 1.0 | (0, 384), no region | cracked dry mud with pebbles and shells over river sediment; at art 384…533 the floor is broken open into a dark hole framed by the aqueduct vault's cut blocks; row 0 = the walk line, opaque to the room's bottom; no ground line crosses the hole |
| `FrontDark` = `foreground_dark.tscn` (new) + Sprite2D `Boulders` | `gen_front.png` | 210×150 | 1.3 | (−97.5, 375) | dark round boulders with a bleached branch in the lower left corner, darkened by `FrontDark`'s modulate (D750); clear of the Arrival, the fall from above and the hole |

`Arrival`, `ObjectiveTargets`, `RoomInstance`, `Music` and the `Foreground` tiles stay as they are.

**The scene is generated.** `Scripts/Tools/build_world_rooms.py` rewrites the new rooms (D833): wire these planes in
the generator, or take `DryRiverbed` out of its list once the scene is wired by hand. If the room becomes 1×2 (the m6
table), only `gen_far.png` needs a taller version; the rest stands on the floor.

Atmosphere for the room routine: dust motes in the pale light from the crack, a thin sand trickle from above, a bat
under the rocks (`critter_bat`, D774), a dry draught from the hole.
