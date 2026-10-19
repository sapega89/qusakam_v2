# Village art (D236)

**AI-generated** by `Scripts/Tools/comfy_backdrop.py` (layers `Village/*`): the local ComfyUI with **Qwen-Image**
(Alibaba Qwen, Apache 2.0) and the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0), brought down to the game's
pixel (576×324, ×1.5 in the game) and a few colours. A Steam release has to disclose AI-generated content.

| File | Use |
|---|---|
| `gen_houses.png` | Parallax2D ×0.85 behind the hero — adobe houses, awnings, jars, date palms; bases on row 258 (floor y 384) |
| `gen_front.png` | Parallax2D ×1.25 in front of everything (z 20) — shrubs, reeds, agave, jars, a fence; darkened, `depth_blur_front` |

The backdrop behind them is the Canyon's (`desert_backdrop_canyon.tscn`: the pack's sky, generated clouds, mesas and
canyon walls — D235).
