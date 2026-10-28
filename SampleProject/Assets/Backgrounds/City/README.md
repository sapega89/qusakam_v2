# City art (D237)

**AI-generated** by `Scripts/Tools/comfy_backdrop.py` (layers `City/*`): the local ComfyUI with **Qwen-Image**
(Alibaba Qwen, Apache 2.0) and the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0), brought down to the game's
pixel (576×324, ×1.5 in the game) and a few colours. A Steam release has to disclose AI-generated content.

| File | Use |
|---|---|
| `gen_far.png` | City: Parallax2D ×0.4 — the skyline: towers, domes, minarets behind the wall; mid blur |
| `gen_near.png` | City: Parallax2D ×0.85 — tall houses with balconies, awnings, carpets, lanterns, market stalls |

Behind them: `desert_backdrop_open.tscn` — the pack's sky, the Canyon's generated clouds and mesas (D235),
the pack's ground strip.
| `gen_forge.png` | City: the Blacksmith's forge behind his station, door at x 1230 (BACKLOG 14, D292) |
| `gen_chapel.png` | City: Sister Ilvane's sky chapel behind the oath priest (x 1450, priest at 1610; BACKLOG 29): the priest's small sky chapel, 219×194, doorway x 126–147 down to row 176, sand slab to row 193 |
| `gen_witch_hut.png` | City: Morrow's hut behind the oath witch (x 1765, witch at 1915; BACKLOG 29): the witch's thatched hut with herbs and a cauldron, 255×203, doorway x 117–151 down to row 193 |
| `gen_dervish_tent.png` | City: Kesh's tent behind the oath dervish (x 2136, dervish at 2330; BACKLOG 29): the dervish's striped tent, flaps open, 304×201, opening x 144–201 down to row 179, rug to row 200 |

## Passage ends of the side rooms (M6c-3)

Made with `design/shots/candidates/m6c3/m6c3.py` (same model and licence as above; AI-generated). Review:
`design/shots/m6c3_archive_cistern.png` (frames 9–10). Both replace the `door_elder` placeholder of a market door
(D836). Sprite2D, `texture_filter = 1`, `scale = (1.5, 1.5)`, `centered = false`, placed in the tree **before
`Terrain`** like `Forge` (the cobbles cover their foot); their foot stands on the cobbles' back edge (art row 242 =
world 363), so the bottom of the ladder and the stall's baskets read. The ladders stand against whole walls (B201).

| node (replaces) | file | size | position (world) | what |
|---|---|---|---|---|
| `RooftopsDoorEntrance` → `RooftopsLadder` | `gen_rooftops_ladder.png` | 133×258 | (733.5, −24) | a narrow plastered tower house with beam ends and a shuttered window, a long wooden ladder against it up to its parapet (out of the view top) — the way up to the Rooftops; the **ladder centred on x 880 world** (`RooftopsDoor` → (880, 322.5)). Its right edge meets `Forge` (x 934) until m6c1 moves the forge to the Craft Quarter |
| `TavernAtticDoorEntrance` → `AtticStall` | `gen_attic_stall.png` | 256×258 | (2136, −24) | a fruit-and-spice stall (dates, oranges, red spice; a red-and-cream awning) against a plastered wall, the long ladder right of it up the wall — «the ladder behind the stall» to the Tavern Attic; the **ladder centred on x 2450 world** (`TavernAtticDoor` → (2450, 322.5)). **Conflict:** today `DervishTent` covers 2076…2532 world — the stall stands inside Kesh's tent. Move the tent (with the oath dervish) or the door before wiring |

Add to `PAINTED` in `verify_room_entrances.gd`: `"City/RooftopsDoor": "the ladder up the house wall"`,
`"City/TavernAtticDoor": "the ladder behind the stall"`. `City/CisternDoor` (x 2540, the hatch) keeps its placeholder:
not in this slice.
