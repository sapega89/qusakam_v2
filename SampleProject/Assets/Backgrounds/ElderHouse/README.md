# Village elder's house, inside (BACKLOG 38, art A2)

**AI-generated** by `Scripts/Tools/comfy_backdrop.py` (layer `ElderHouse/gen_wall`): the local ComfyUI with **Qwen-Image**
(Alibaba Qwen, Apache 2.0) and the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0), brought down to the game's
pixel (576×324, ×1.5 in the game) and 16 colours. A Steam release has to disclose AI-generated content.

| File | Use |
|---|---|
| `gen_wall.png` | `Maps/ElderHouse.tscn` → Wall (y −64, so its floor row ~299 meets the tile floor at y 384; BACKLOG 38): the room's wall Sprite2D, like `Hall/gen_wall.png` in the Mayor Hall — adobe walls under dark ceiling beams, two shuttered windows, hanging carpets and a parchment, shelves with pots, a clay hearth with a fire and a tall clay jar beside it, a stone plinth and floor along the bottom; seamless left–right. x 165–268 repainted (`--repaint`) — the first version had a fabric-shade table lamp on the floor and a dark blob on the floor line |
| `gen_floor.png` | `Maps/ElderHouse.tscn` → Floor Sprite2D right after TileMap (y 864, over the tile floor, which stays as collision): worn planks, a floor beam and an adobe footing; layer `ElderHouse/gen_floor`, cut, patched and put in the wall's colours by `design/shots/candidates/floor_strips/floor_strips.py` |

The outside of the house is `../Village/gen_elder_house.png`.

## A13 (B189, D814), 2026-10-28 — floor jars out of `gen_wall`, at chart size

The tall clay jar by the hearth (68 art px, 1 H) and the two pots on the right bench were painted into the wall.
`Scripts/Tools/unbake_props.py` (Qwen-Image-Edit-2511, Apache 2.0, AI-generated) repainted those spots — plain adobe
wall and the stone bench; the model put a second arched niche where the jar was, so that spot is a copy of the bare
wall right of it (`PATCH`). The pots on the wall shelves stay. Original: `design/shots/candidates/a13/elder_orig.png`.

Props (`comfy_backdrop.py` layers `ElderHouse/prop_*`, **Qwen-Image**, Apache 2.0, AI-generated; jar / pot 24 art, the
chart's sack–pot row, on the ×1.0 wall). Wire as `Sprite2D` children of the root next to `Wall` (z_index −10 like it, or
−9 so they stand in front), `texture_filter = 1`, `scale = (1.5, 1.5)`, `centered = false`, `offset = (−width / 2,
−height)`, `position` = the feet:

| File | Size (art) | Feet `position` | Was |
|---|---|---|---|
| `prop_amphora.png` | 13×24 | (291, 864) | the tall jar beside the hearth; feet on the floor line (D916, B211; was 870.5, its bottom 6.5 px under `Floor`) |
| `prop_pot.png` | 25×24 | (580.5, 822.5) | the big pot on the right bench |
| `prop_pot.png` | 25×24 | (634.5, 822.5) | the small pot beside it (flip_h) |

**Wired 2026-10-28** (B189): `Maps/ElderHouse.tscn` → `Amphora`, `PotBig`, `PotSmall` (z −9, in front of `Wall`).
