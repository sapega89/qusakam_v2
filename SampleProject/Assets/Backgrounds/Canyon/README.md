# Canyon art (D227)

Drawn by `Scripts/Tools/draw_canyon.py` (original work), placed by `Scripts/Tools/build_canyon.gd`:
`pride_rock.png` — the Pride Rock promontory (Sapega: «з утьосом як в лайон кінг»), its shelf and ledges match the
hidden `RockCollision` tile layer.

D228 (critics' pass): `gorge.png` — the gorge drawn from `Scripts/Tools/canyon_gorge.txt` (same layout as its hidden
collision), `plateau_body.png` — the plateau's body as the same rock, `canyon_depths.png` — the lower canyon walls
under the plateau; the Canyon's backdrop is `desert_backdrop_canyon.tscn` (desert_backdrop_4 without the oasis layer).

D235 (first use of D234): the backdrop planes `gen_clouds.png` (Parallax2D ×0.1), `gen_far.png` — distant
mesas (×0.3) — and `gen_walls.png` — the canyon walls (×0.45, replaced the procedural `canyon_walls.png`) are
**AI-generated**: `Scripts/Tools/comfy_backdrop.py` asks the local ComfyUI for them with **Qwen-Image**
(Alibaba Qwen, Apache 2.0) and the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0), then brings them to the
game's pixel and palette. A Steam release has to disclose AI-generated content. The sky is the pack's `plan5`.
