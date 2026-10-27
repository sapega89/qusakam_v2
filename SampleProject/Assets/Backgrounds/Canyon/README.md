# Canyon art (D227)

Drawn by `Scripts/Tools/draw_canyon.py` (original work), placed by `Scripts/Tools/build_canyon.gd`:
`pride_rock.png` — the Pride Rock promontory (Sapega: «з утьосом як в лайон кінг»), its shelf and ledges match the
hidden `RockCollision` tile layer.

D228 (critics' pass): `gorge.png` — the gorge drawn from `Scripts/Tools/canyon_gorge.txt` (same layout as its hidden
collision), `plateau_body.png` — the plateau's body as the same rock, `canyon_depths.png` — the lower canyon walls
under the plateau (since D249 painted by `paint_terrain.py` from the generated sandstone, see `../Terrain/README.md`); the Canyon's backdrop is `desert_backdrop_canyon.tscn` (desert_backdrop_4 without the oasis layer).

D235 (first use of D234): the backdrop planes `gen_clouds.png` (Parallax2D ×0.1), `gen_far.png` — distant
mesas (×0.3) — and `gen_walls.png` — the canyon walls (×0.45, replaced the procedural `canyon_walls.png`) are
**AI-generated**: `Scripts/Tools/comfy_backdrop.py` asks the local ComfyUI for them with **Qwen-Image**
(Alibaba Qwen, Apache 2.0) and the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0), then brings them to the
game's pixel and palette. A Steam release has to disclose AI-generated content. The sky is the pack's `plan5`.

D256 (the descent cutscene): `gen_rock.png` — the foreground boulder Kusakam climbs down behind (`ForegroundRock`,
z 20) — and `gen_bridge.png` — the rope bridge, cut into slices by `build_canyon.gd` (replaced the procedural
`bridge_plank/post/rope.png`) — are **AI-generated** the same way (`comfy_backdrop.py`, Qwen-Image, Apache 2.0).

D257 (meditation on the summit): `gen_shrine.png` — the meditation stone with a cairn and a glowing rune on top of
the Pride Rock (`Meditation/Shrine`) — **AI-generated** the same way (`comfy_backdrop.py`, Qwen-Image, Apache 2.0;
`small=2`: game pixels from 6×6 blocks, the model painted the stone too big).
| `gen_front.png` | Canyon: foreground plane (BACKLOG 7, A5a; not wired yet) — red sandstone boulders, dry grass tufts, thorny dead bushes, a fallen log; 576×324, transparent above row ~225, a dark ground strip from row 300 to the bottom; made like `Village/gen_front`: Parallax2D ×1.25, z 20, darkened (shade 0.6), `depth_blur_front` |
