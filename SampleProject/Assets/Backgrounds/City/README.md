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
| `gen_front.png` | City: foreground plane (BACKLOG 7, A5a; not wired yet) — a market stall with a striped awning, a rolled carpet, fruit baskets, clay jars; 576×324, transparent above row ~218, a dark ground strip from row 301 to the bottom; made like `Village/gen_front`: Parallax2D ×1.25, z 20, darkened (shade 0.6), `depth_blur_front` |
