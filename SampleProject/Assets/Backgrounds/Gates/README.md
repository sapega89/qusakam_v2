# City gates art (D237, D314)

**AI-generated** by `Scripts/Tools/comfy_backdrop.py` (layers `Gates/*`): the local ComfyUI with **Qwen-Image**
(Alibaba Qwen, Apache 2.0) and the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0), brought down to the game's
pixel (576×324, ×1.5 in the game) and a few colours. A Steam release has to disclose AI-generated content.

| File | Use |
|---|---|
| `gen_mid.png` | CityGates: Parallax2D ×0.7 — the city wall, two gate towers, red banners with a plain golden disc (coat of arms: Q57); near blur. Its two painted gates are walled up by `patch` (plain wall copied over them, D315) |
| `gen_passage_front.png` | `Scenes/Backgrounds/gate_passage.tscn` → `Front` (×1.5, z 20 — over the hero, D314): two towers with banners joined by a stone bridge; the opening under the bridge keyed transparent down to the ground (`open`), the side walls cut off (`cut`). The same scene stands in CityGates and at the City's west end |
| `gen_passage_back.png` | `gate_passage.tscn` → `Back` (×1.5, z −1, darkened by modulate, cropped to the opening): the passage wall with both gate leaves standing open and a torch (`crop` — a 576×220 strip) |

Behind them: `desert_backdrop_open.tscn` — the pack's sky, the Canyon's generated clouds and mesas (D235),
the pack's ground strip.
