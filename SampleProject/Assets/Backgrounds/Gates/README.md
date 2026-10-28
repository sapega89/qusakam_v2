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

## The Rooftops rope's landing (M6c-3)

Made with `design/shots/candidates/m6c3/m6c3.py` (same model and licence as above; AI-generated). Review:
`design/shots/m6c3_archive_cistern.png` (frame 11).

| node (replaces) | file | size | position (world) | what |
|---|---|---|---|---|
| `RooftopsDoorEntrance` → `RooftopsRope` (Sprite2D, `texture_filter = 1`, `scale = (1.5, 1.5)`, `centered = false`, in the tree before `Terrain`) | `gen_rooftops_rope.png` | 121×230 | (547.5, 18) | a square buttress of the city wall with battlements, nearer than the wall plane (×0.7), the rope from the Rooftops tied round a merlon and hanging down its face to a coil at the foot — where the drop from `Rooftops/SlideDoor` lands; the **rope centred on x 638 world** (the scene's `RooftopsDoor`; the previous README said 300); foot on the cobbles' back edge (world 363) so the coil reads. `RooftopsDoor` → (638, 322.5) |

Add `"CityGates/RooftopsDoor": "the rope down the wall buttress"` to `PAINTED` in `verify_room_entrances.gd`.
