# Aqueduct planes (M6b-5)

**AI-generated.** Made with `design/shots/candidates/m6b5/m6b5.py` on top of `Scripts/Tools/comfy_backdrop.py`, using
**Qwen-Image** (Alibaba Qwen, Apache 2.0) with the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0). The breach in the
vault was repainted by Qwen-Image over the room's own picture (masked img2img on the Dry Riverbed's hole, turned upside
down). Brought down ×3 to the game's pixel and a few colours (octree); the far cistern, the piers and the vault are
darkened toward violet for depth. A Steam release has to disclose AI-generated content. Review:
`design/shots/m6b5_aqueduct_gate.png` (frames 1–4).

The room (`Maps/Aqueduct.tscn`): underground, 4 cells (2304 × 320 art = 3456 × 480 world), floor y 384 world (art row
256), camera x 0…1728 art, y fixed. The old aqueduct under the road that once fed the City: a cut-stone conduit with a
walkway over its channel, square piers with mooring rings, a dark cistern hall beyond them, a broken water-lifting wheel
and a dragon-head spout (dragons «like deities», as in the Old Ruins). Its passages, all painted (D747):

- **West edge** — open into the Old Ruins (MapData [15,7] → [16,7]). The ruins paint their east edge as the aqueduct's
  arch; here the **same arch seen from inside** (`OldRuins/gen_arch.png`, mirrored), its opening reaching x 0.
- **The vault breach at 576…800 world** (art 384…533) — where the Dry Riverbed's floor fell in; the hero drops in from
  there (`DryRiverbed` hole, same x). Painted in `gen_ceiling.png`: broken cut blocks around a dark hole with dim light.
- **`ApproachDoor`** (x 2891 world) — an arched side doorway with a stair climbing to daylight: the way up to the Gate
  Approach. Opening 112 art (a door, D814).
- **`CellarDoor`** (x 3291 world, gate `aqueduct_cellar`) — a low arch closed by a rusted grate into the gatehouse
  cellar; grate 128 art (a locked gate, D814). The **grate is its own sprite** (`gen_grate.png`, same size and anchor as
  the arch): hide it (or raise it like a portcullis) once `aqueduct_cellar_open` is set; behind it the arch's opening is
  plain darkness (`gen_cellar.png`), so the open passage reads open.
- **East edge** — the room's wall, painted as a rockfall that closes the tunnel (`gen_rubble.png`).

## Planes, back to front

Art px, room-local; every sprite `texture_filter = 1`, `scale = (1.5, 1.5)`, `centered = false`. A Parallax2D plane
with factor f is drawn at anchor − f × camera (camera = view left edge), so the positions below hold with the camera
at the room's left end. Tiles: `repeat_size = (864, 0)`, `repeat_times` as the placeholder (6).

| node (replaces) | file | size | factor | position (world) | what |
|---|---|---|---|---|---|
| `Back/Far` (Cellar far; ×0.4 → ×0.45, `repeat_size` 1728 → 864) | `gen_far.png` | 576×324 | 0.45 | (0, 0); tile, opaque | the far wall: round arches onto a dark cistern hall with columns in still water, thin light shafts from the vault |
| `Back/Mid` (Cellar mid) → `Back/Piers` (×0.8 → ×0.75) | `gen_arcade.png` | 576×240 | 0.75 | (0, 36); tile | square piers of fitted blocks with carved bands and iron rings, green water lines, a strip of standing water at their feet just above the walk line (as the Old Ruins' arcade) |
| `Back/Wheel` (new Parallax2D ×0.85, one Sprite2D) | `gen_wheel.png` | 113×122 | 0.85 | (1302, 207) | a broken water-lifting wheel with clay pots on a stone base; one storey (144) × 0.85 = 122 (D814); mid-screen at camera 700 art (1050 world) |
| `Back/Spout` (new Parallax2D ×0.9) | `gen_spout.png` | 70×86 | 0.9 | (2085, 195) | a dragon-head water spout in a block panel over a dry basin, hung 40 art above the walk line; a man's height (96) × 0.9 = 86; mid-screen at camera 1250 art (1875 world) |
| `Rubble` (new Sprite2D, `z_index = -2`) | `gen_rubble.png` | 102×258 | 1.0 | (3348, 0) | fallen vault blocks heaped from the floor to the vault, closing the tunnel at the east wall; runs 45 world past the edge |
| `Ceiling` (new Sprite2D, `z_index = -2`; **no repeat**) | `gen_ceiling.png` | 2304×110 | 1.0 | (0, 0) | the vault's band of fitted blocks with roots and water stains, the whole room in one strip; the **breach** at art 378…539 (world 567…809): broken blocks round a dark hole, dim light at its top; transparent below row 96 |
| `RuinsArch` (new Sprite2D, `z_index = -2`, `flip_h = true`) | `OldRuins/gen_arch.png` | 215×144 | 1.0 | (−99, 171) | the Old Ruins' aqueduct arch from inside: dragon keystone, pitch-dark opening reaching x 0; the left pier runs past the west edge |
| `ApproachDoorEntrance` → `Stair` (Sprite2D, `z_index = -2`) | `gen_stair.png` | 77×126 | 1.0 | (2833.5, 198) | the side doorway with the stair up to daylight; opening 112 art centred on x 2891 world, threshold on the walk line |
| `CellarDoorEntrance` → `CellarArch` (Sprite2D, `z_index = -2`) | `gen_cellar.png` | 181×163 | 1.0 | (3156, 142.5) | the cellar arch, opening empty and dark; centred on x 3291 world, threshold on the walk line |
| `CellarGrate` (Sprite2D, `z_index = -2`, after `CellarArch`) | `gen_grate.png` | 181×163 | 1.0 | (3156, 142.5) | the rusted grate alone (transparent between the bars), 128 art tall; visible while `aqueduct_cellar_open` is unset |
| `Ground/Floor1` (Cellar floor) | `gen_floor.png` | 576×64 | 1.0 | (0, 384), `region_rect = Rect2(0, 0, 2304, 64)`, `texture_repeat = 2` | the walkway of worn slabs with green stains over the conduit (its square channels with a trickle of green water in cross-section); row 0 = the walk line; opaque to the room's bottom (`Fill1` may go) |
| `FrontDark` = `foreground_dark.tscn` (new) + Sprite2Ds `Pier1`, `Pier2` | `gen_front.png` | 135×340 | 1.3 | (2085, −21) and (3060, −21) | a square vault pier with a rusted ring and broken chain, darkened by `FrontDark`'s modulate (D750); top and foot outside the view; crosses mid-screen at camera 900 and 1400 art; with the camera on the breach (~170), the Arrival or either door it is off screen or at the edge |

**The doors are painted openings.** Delete `ApproachDoorEntrance` and `CellarDoorEntrance` (the cave mouths), add the
sprites above, keep `ApproachDoor` (2891, 330) and `CellarDoor` (3291, 330), and add to `PAINTED` in
`verify_room_entrances.gd`: `"Aqueduct/ApproachDoor": "the side doorway with the stair up"`,
`"Aqueduct/CellarDoor": "the barred cellar arch"`. The grate's flag is the gate's own (`gates.json` →
`aqueduct_cellar` → `aqueduct_cellar_open`).

**The scene is generated.** `Scripts/Tools/build_world_rooms.py` rewrites the new rooms (D833): wire these planes in the
generator, or take `Aqueduct` out of its list once the scene is wired by hand.

Atmosphere for the room routine: a pale light shaft with dust falling from the breach to the floor (where the hero
lands), drips glinting into the green water at the piers' feet, a draught of daylight from the stair door, a bat on
the vault (`critter_bat`, D774).
