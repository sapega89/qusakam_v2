# Gate Approach planes (M6b-5)

**AI-generated.** Made with `design/shots/candidates/m6b5/m6b5.py` on top of `Scripts/Tools/comfy_backdrop.py`, using
**Qwen-Image** (Alibaba Qwen, Apache 2.0) with the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0). The City is the
Chasm's generation (`m6b4_chasm_city_raw.png`) brought nearer. Brought down ×3 to the game's pixel and a few colours
(octree). A Steam release has to disclose AI-generated content. Review: `design/shots/m6b5_aqueduct_gate.png`
(frames 5–7).

The room (`Maps/GateApproach.tscn`): main road, 2 cells (1152 × 320 art = 1728 × 480 world), open both ways: west the
Chasm, east the City Gates; floor y 384 world (art row 256), flat (D830), camera x 0…576 art, y fixed. The last stretch
of the road: old paving under drifted sand, the ruins of the aqueduct that fed the City, the City itself nearer and
bigger than from the Chasm. Two things of its own:

- **The bridge lever** (`BridgeLever`, x 110 world, sets `chasm_bridge_down`): the chain from the Chasm's winch comes in
  along the road from the west edge to an iron-banded stone housing with a ratchet wheel (`gen_lever.png`). The moving
  handle stays `lever.tscn`'s own (its `Handle` Polygon2Ds); the housing replaces its `Base` trapezoid.
- **The aqueduct well house** (`AqueductDoor`, x 1291 world): a small facade of cut blocks with an arched doorway at
  ground level and a stair inside going down — the way into the Aqueduct. Door 112 art (D814).

## The road stays anchored to the world

As in the Dunes and the Chasm: the Gate Approach's left edge is X = 13 × 864 = 11232 world px right of the Desert
Road's (cells [4,5] → [17,5]) and 5 × 864 = 4320 right of the Dunes' ([12,5]), so a shared plane with factor f is
shifted by −f × X (mod its 864 repeat). Clouds autoscroll and need nothing.

| plane | factor | `scroll_offset.x` |
|---|---|---|
| `desert_backdrop_open.tscn` → Plan3 (`Canyon/gen_far.png`, far mesas) | 0.3 | 86.4 |
| `desert_backdrop_open.tscn` → Plan1 (pack ground strip; hidden under the floor) | 0.75 | 0 |
| `Back/Dunes` (`Dunes/gen_dunes.png`) | 0.5 | 432 |
| `Back/Near` (`Dunes/gen_near.png`) | 0.8 | 0 |

## Planes, back to front

Art px, room-local; every sprite `texture_filter = 1`, `scale = (1.5, 1.5)`, `centered = false`. A Parallax2D plane
with factor f is drawn at anchor − f × camera (camera = view left edge), so the positions below hold with the camera
at the room's left end. Tiles: `repeat_size = (864, 0)`, `repeat_times` as the placeholder (4).

| node (replaces) | file | size | factor | position (world) | what |
|---|---|---|---|---|---|
| `Backdrop` = `desert_backdrop_open.tscn` (replaces `Back/Far`), offsets above | — | — | 0–0.75 | (0, −3) | the road's sky, clouds and far mesas, continuing |
| `Back/Mid` (Road mid) → `Back/Dunes` (×0.8 → ×0.5) | `Dunes/gen_dunes.png` | 576×240 | 0.5 | (0, 105); tile | the Dunes' dune sea, continuing |
| `Back/City` (new Parallax2D ×0.55, one Sprite2D) | `gen_city.png` | 359×158 | 0.55 | (805.5, 57) | the City's walls, gatehouse, domes and palace tower with red banners — the Chasm's City nearer: walls two storeys (288) × 0.55 = 158 (D814; ×0.4 = 115 in the Chasm), hazed 0.25; its foot sinks behind the near dunes; centred at screen 400 art with the camera at the east end |
| `Back/Ruins` (new Parallax2D ×0.75) | `gen_ruins.png` | 346×135 | 0.75 | (325.5, 121.5) | three arches of the old aqueduct standing in the sand, broken off at both ends; 1.25 storeys (180) × 0.75 = 135, hazed 0.2; mid-screen at camera 120 art (180 world) |
| `Back/Near` (new Parallax2D ×0.8) | `Dunes/gen_near.png` | 576×120 | 0.8 | (0, 225); tile | the Dunes' low crests, continuing |
| `AqueductDoorEntrance` → `WellHouse` (Sprite2D, `z_index = -2`) | `gen_pump.png` | 251×211 | 1.0 | (1102.5, 70.5) | the well house facade; doorway 112 art centred on x 1291 world, threshold on the walk line (the steps and sand in front are under the floor plane) |
| `LeverHousing` (new Sprite2D, `z_index = -2`, **before** `BridgeLever` in the tree) | `gen_lever.png` | 88×24 | 1.0 | (−4.5, 351) | the chain from the west edge and the lever's stone-and-iron housing with a ratchet wheel; the wheel's axle at x 110.4 world, 16.4 world above the floor |
| `Ground/Floor1` (BanditCamp floor; `Fill1` may go) | `gen_ground.png` | 576×64 | 1.0 | (0, 384), `region_rect = Rect2(0, 0, 1152, 64)`, `texture_repeat = 2` | old paving stones half under drifted sand over orange sandstone strata; row 0 = the walk line; opaque to the room's bottom |
| `FrontDark` = `foreground_dark.tscn` (new) + Sprite2D `Pillar` | `gen_front.png` | 242×220 | 1.3 | (835.5, 174) | a broken leaning aqueduct pillar with the spring of its arch and a thorny bush, darkened by `FrontDark`'s modulate (D750); foot below the view; mid-screen at camera 300 art; with the camera at the lever only its edge shows at the right (557…576 art), with it on the well-house door only at the left (0…54 art) |

**The lever.** In the `BridgeLever` instance (editable children): `Base.visible = false` (the housing replaces it) and
`Handle.position = Vector2(0, -16)` (default −10), so the handle turns on the ratchet wheel's axle. Nothing changes in
`lever.tscn` or `Lever.gd`.

**The door is a painted opening.** Delete `AqueductDoorEntrance` (the cave mouth), add `WellHouse`, keep `AqueductDoor`
(1291, 330), and add `"GateApproach/AqueductDoor": "the well house's doorway with the stair down"` to `PAINTED` in
`verify_room_entrances.gd`.

**The scene is generated.** `Scripts/Tools/build_world_rooms.py` rewrites the new rooms (D833): wire these planes in the
generator, or take `GateApproach` out of its list once the scene is wired by hand.

Atmosphere for the room routine: sand blown along the paving, dust in the light, a bird on the aqueduct ruins
(`critter_bird`), a faint cool draught from the well-house door.
