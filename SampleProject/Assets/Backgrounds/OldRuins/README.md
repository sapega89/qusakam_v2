# Old Ruins planes (M6b-3)

**AI-generated.** Made with `design/shots/candidates/m6b3/m6b3.py` on top of `Scripts/Tools/comfy_backdrop.py`, using
**Qwen-Image** (Alibaba Qwen, Apache 2.0) with the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0). Brought down ×3 to
the game's pixel and a few colours (octree); the far hall is darkened toward violet for depth. A Steam release has to
disclose AI-generated content. Review: `design/shots/m6b3_dunes_ruins.png` (frames 5–8).

The room (`Maps/OldRuins.tscn`): underground, optional, 5 cells (2880 × 320 art = 4320 × 480 world; the graph and the
task said 4, the scene and MapData have 5 — every plane but the props is a seamless 576 tile, so either fits), floor
y 384 world (art row 256), camera x 0…2304 art, y fixed. West end: a wall and the **well** from Zahra's Rest
(`WellDoor`, x 151 world; gate `ruins_well`, the chief's key «green with old water»). East end: an open edge into the
**Aqueduct** (MapData [15,7] → [16,7]), painted as the aqueduct's arch. The hall of an ancient civilisation under the
dunes: colonnades, broken vaults with pale light through cracks (the sky is bright, no sun — D196), old water standing
in the channels (the green stains), and its gods: a dragon relief and a statue with an offering bowl.

## Planes, back to front

Art px, room-local; every sprite `texture_filter = 1`, `scale = (1.5, 1.5)`, `centered = false`. A Parallax2D plane
with factor f is drawn at anchor − f × camera (camera = view left edge), so the positions below hold with the camera
at the room's left end. Tiles: `repeat_size = (864, 0)`, `repeat_times` as the placeholder (7).

| node (replaces) | file | size | factor | position (world) | what |
|---|---|---|---|---|---|
| `Back/Far` (Cellar far; ×0.4 → ×0.45, `repeat_size` 1728 → 864) | `gen_far.png` | 576×324 | 0.45 | (0, 0); tile, opaque | the dim hall: rows of colossal columns into the dark, broken arches, light shafts from cracks onto sand heaps, dark pools |
| `Back/Mid` (Cellar mid) → `Back/Arcade` (×0.8 → ×0.75) | `gen_arcade.png` | 576×240 | 0.75 | (0, 24); tile | broken carved columns at different heights, a fallen lintel with a scale pattern, a strip of green standing water along their feet just above the walk line |
| `Back/Statue` (new Parallax2D ×0.85, one Sprite2D) | `gen_statue.png` | 81×136 | 0.85 | (1326, 183) | a robed statue on a plinth holding a stone bowl of water; plinth + 1.5 people = 160 art × 0.85 = 136 (D814); mid-screen at camera 560 |
| `Back/Relief` (new Parallax2D ×0.9) | `gen_relief.png` | 160×130 | 0.9 | (1867.5, 192) | the story prop: an upright slab with a winged dragon coiled in a circle and robed figures kneeling under it; one storey (144) × 0.9 = 130; mid-screen at camera 1152 |
| `Well` (new Sprite2D, `z_index = -2`, **before** `Ceiling`; replaces `WellDoorEntrance`) | `gen_well.png` | 105×262 | 1.0 | (72, −6) | the well shaft: a narrow chimney of carved blocks coming down through the ceiling to the floor, broken open at the bottom, the rope inside and the bucket standing in the opening; centre x 151 world = `WellDoor`; feet 2 art under the walk line, top above the view, hidden by the ceiling |
| `Ceiling` (new Parallax2D ×1.0, tile) | `gen_ceiling.png` | 576×110 | 1.0 | (0, 0); tile | rough rock and vault blocks along the top, a sandy lip, sand drips and dry roots hanging; transparent below |
| `Arch` (new Sprite2D, `z_index = -2`) | `gen_arch.png` | 215×144 | 1.0 | (4095, 171) | the aqueduct's arch: fitted blocks, a dragon-head keystone, a pitch-dark opening, a channel at its foot; one storey (144); its opening reaches the room's east edge, so walking on east is walking into it (D747); the right pier runs past the edge |
| `Ground/Floor1` (Cellar floor) | `gen_floor.png` | 576×64 | 1.0 | (0, 384), `region_rect = Rect2(0, 0, 2880, 64)`, `texture_repeat = 2` | worn flagstones with green water stains over fitted blocks; row 0 = the walk line; covers to the room's bottom (`Fill1` may go) |
| `FrontDark` = `foreground_dark.tscn` (new) + Sprite2Ds `Column1`, `Column2` | `gen_front.png` | 128×340 | 1.3 | (1213.5, −21) and (4138.5, −21) | a broken column wrapped in dry roots, darkened by `FrontDark`'s modulate (D750, like the cellar's pillars); top and foot outside the view; crosses mid-screen at camera 450 and 1950 art (675 / 2925 world), never over the well, the statue, the relief or the arch |

**The well is a painted opening.** As at Zahra's Rest: delete `WellDoorEntrance` (the cave mouth), add the `Well`
sprite, keep `WellDoor` at (151, 330), and add `"OldRuins/WellDoor": "the well shaft with its rope"` to `PAINTED` in
`verify_room_entrances.gd`. Its action reads best as «Climb up».

Atmosphere for the room routine: dust in the light shafts, thin sand trickles from the ceiling cracks, drips glinting
into the green water, a bat on the ceiling (`critter_bat`, D774).
