# Village art (D236)

**AI-generated** by `Scripts/Tools/comfy_backdrop.py` (layers `Village/*`): the local ComfyUI with **Qwen-Image**
(Alibaba Qwen, Apache 2.0) and the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0), brought down to the game's
pixel (576×324, ×1.5 in the game) and a few colours. A Steam release has to disclose AI-generated content.

| File | Use |
|---|---|
| `gen_back.png` | Parallax2D ×0.6, near blur — the back row of rooftops, a watchtower, a dome, palms (D238) |
| `gen_houses.png` | Parallax2D ×0.85 behind the hero — adobe houses, awnings, jars, date palms; thresholds on row ~231, a painted pavement down to the floor line (row 258 = y 384) |

The backdrop behind them is the Canyon's (`desert_backdrop_canyon.tscn`: the pack's sky, generated clouds, mesas and
canyon walls — D235).
| `gen_grandpa_house.png` | Village: behind the grandfather (x 1398, he stands at 1572 left of the door; BACKLOG 29): the grandfather's house — bench, staff, peppers; 328×181, doorway x 141–175 down to row 164, sand to row 180 |
| `gen_elder_house.png` | Village: at the east end (x 1890, y 150 — the threshold row 167 on y ≈ 400, the right edge on the room edge 2592), its door is `ElderDoor` (x 2163) into `Maps/ElderHouse.tscn` (BACKLOG 38): the village elder's house — a wide one-storey house with a crenellated roof terrace, a porch under a red and blue awning, banners and jars (two storeys at the grandfather's-house scale do not fit the one-cell Village, Q58); 468×191, same scale as `gen_grandpa_house` and `Road/gen_shop`: closed arched double door x 163–201, rows 76–167 (threshold row 167 on the steps), windows ~30 px plus shutters; sand to row 190; inside = `../ElderHouse/gen_wall.png` |
