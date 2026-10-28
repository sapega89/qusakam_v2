# Craft Quarter planes (M6c-1)

**AI-generated.** Made with `design/shots/candidates/m6c1/m6c1.py` on top of `Scripts/Tools/comfy_backdrop.py`, using
**Qwen-Image** (Alibaba Qwen, Apache 2.0) with the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0). Brought down ×3 to
the game's pixel and a few colours (octree). A Steam release has to disclose AI-generated content. Review:
`design/shots/m6c1_craft_palace.png` (frames 1–4).

The room (`Maps/CraftQuarter.tscn`): main street, 3 cells (1728 × 320 art = 2592 × 480 world), open both ways: west the
market (`City`), east the Palace Square; floor y 384 world (art row 256), flat, camera x 0…1152 art, y fixed. The City's
crafts, from what the game already trades and shows: **clay jars** (every house, the smugglers' amphorae, the
aqueduct wheel's pots), **carpets** (the grandfather's rug, the dervish's rug), **copper** (copper ore, ingots and the
copper sword at the merchant) and **leather** (the smith's helmet needs it). So: a potter, a carpet weaver and a
coppersmith on the street; the dyers' and tanners' row behind them, with cloth and hides drying on the roofs.
The look is the market's (D237): sandstone, striped awnings, lanterns.

## The street continues the market

The Craft Quarter's left edge is X = 3 × 864 = 2592 world px right of the market's (cells [21,5] → [24,5]), so a plane the
market shares, with factor f, is shifted by −f × X (mod its 864 repeat). Clouds autoscroll and need nothing.

| plane | factor | `scroll_offset.x` |
|---|---|---|
| `desert_backdrop_open.tscn` → Plan3 (`Canyon/gen_far.png`, far mesas) | 0.3 | 86.4 |
| `Back/Far` = the market's `CityFar` (`City/gen_far.png`, the skyline) | 0.4 | 691.2 |

## Planes, back to front

Art px, room-local; every sprite `texture_filter = 1`, `scale = (1.5, 1.5)`, `centered = false`. A Parallax2D plane
with factor f is drawn at anchor − f × camera (camera = view left edge), so the positions below hold with the camera
at the room's left end. Tiles: `repeat_size = (864, 0)`, `repeat_times` as the placeholder (5). Everything at ×1.0 or
behind goes under `Back` (z −10), so the floor strip covers the feet sunk below the walk line.

| node (replaces) | file | size | factor | position (world) | what |
|---|---|---|---|---|---|
| `Backdrop` = `desert_backdrop_open.tscn` (replaces `Back/Sky`), offset above | — | — | 0–0.75 | (0, 0) | the market's sky, clouds and far mesas, continuing |
| `Back/Far` (keep `City/gen_far.png`; as the market's `CityFar`: `region_rect = Rect2(0, 48, 576, 276)`, `offset = (0, 48)`, `depth_blur_mid`), offset above | `City/gen_far.png` | 576×324 | 0.4 | (0, 0); tile | the City's towers, domes and minarets, continuing |
| `Back/Mid` (×0.8 → **×0.5**) | `gen_mid.png` | 576×220 | 0.5 | (0, 63); tile | the dyers' and tanners' row: one- and two-storey workshop houses wall to wall, cloth in red, indigo and saffron drying on ropes between the roofs, a hide stretched on a frame, carpets over balcony rails, copper pots by the doors; hazed 0.25. Its doors measure 50 art, its storeys 85: 112 × 0.45 and 144 × 0.6, so ×0.5 (D814) |
| `Back/Potter` (new Parallax2D ×0.9, one Sprite2D) | `gen_potter.png` | 302×175 | 0.9 | (354, 124.5) | the potter's open workshop under a striped awning (its open front 101 art = 112 × 0.9): a potter's wheel, shelves of jars and bowls, a domed kiln with a glowing mouth and a chimney, amphorae in front; mid-screen at camera 110 art (165 world) |
| `Back/Weaver` (new Parallax2D ×0.9) | `gen_weaver.png` | 325×212 | 0.9 | (1053, 69) | the carpet weaver's house: an upright loom with a half-woven carpet under a plank awning, carpets on a rail, rolled carpets, a basket of wool; door 101 art; mid-screen at camera 640 art (960 world) |
| `Back/Copper` (new Parallax2D ×0.9) | `gen_copper.png` | 208×164 | 0.9 | (1572, 141) | the coppersmith's shop: an arched doorway (101 art with its fanlight), the wall hung with copper pans, trays and two lanterns, a bench with a small anvil, a big copper cauldron; mid-screen at camera 960 art (1440 world) |
| `Back/Forge` — **moved from `City.tscn`** with the Blacksmith (D773: the forge and chapel fronts stand in the craft quarter) | `City/gen_forge.png` | 356×206 | 1.0 | (813, 137) | the forge as in the market (A12 regenerates it at one storey); its sand slab under the floor strip. Move with it: `Anvil` and `Blacksmith` → x 979, `ForgeDoor` marker → (1109, 396) |
| `Back/Chapel` — **moved from `City.tscn`** with the oath priest (D773) | `City/gen_chapel.png` | 219×194 | 1.0 | (2235, 136) | Sister Ilvane's sky chapel; `OathPriest` → x 2395 |
| `Ground/Floor1` (keep) | `Terrain/City_Terrain.png` | — | 1.0 | (0, 384), `region_rect = Rect2(0, 256, 1728, 43)` | the market's cobbles, continuing |
| `FrontDark` = `foreground_dark.tscn` (new) + Sprite2Ds `Pole1`, `Pole2` (`flip_h = true`) | `gen_front.png` | 127×340 | 1.3 | (921, 36) and (2013, 36) | a rough pole with a rope of dyed cloth strips, a copper lantern and jars at its foot, darkened by `FrontDark`'s modulate (D750); its foot below the view; mid-screen at camera 300 and 860 art (between the potter and the forge, between the weaver and the coppersmith), never over the Arrival |

**If the forge and the chapel stay in the market** (the move takes their NPCs; `ForgeDoor` is a teleport target in
`verify_city_life.gd` and four `capture_*.gd`, so keep a `ForgeDoor` marker in `City.tscn` or retarget them): leave
`Back/Forge` and `Back/Chapel` out; the street still reads, the gaps show the dyers' row.

**The scene is generated.** `Scripts/Tools/build_world_rooms.py` rewrites the new rooms (D833): wire these planes in the
generator, or take `CraftQuarter` out of its list once the scene is wired by hand. `python -B
design/shots/candidates/m6c1/m6c1.py wiring` prints these positions again.

Atmosphere for the room routine: thin smoke from the potter's kiln chimney and the forge (the mid row's chimneys too —
the painted smoke was taken out of the plane for particles), dust drifting in the light under the awnings (light from
the sky, no sunbeams: D196), pigeons on the cobbles (`critter_pigeon`, as in the market), the cloth strips on the ropes
swaying, a faint glow flicker in the kiln mouth and the forge doorway; sound: the coppersmith's hammer, a loom's knock.
