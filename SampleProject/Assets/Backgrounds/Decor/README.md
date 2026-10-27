# Decor idle loops (BACKLOG 19, A5b)

Made by `Scripts/Tools/comfy_decor.py`: one generation per prop in the backdrop style (`STYLE` of
`comfy_backdrop.py`), the loop frames are derived from that single image by the script (sway = pixel shift growing
from the anchor — the banner shifts whole rows of one downscaled, quantised frame, so its stripes never change; flicker = brightness of the hot pixels), so the shape never drifts between frames. Each
`<name>_sheet.png` is a horizontal strip of equal frames, one shared palette; empty rows are trimmed, so row 0 is
the hanging line and the last row the foot line. Not wired into scenes yet.

AI-generated: drawn by the local ComfyUI with **Qwen-Image** (Alibaba Qwen, Apache 2.0) + the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0), then keyed, downscaled to the game pixel and quantised by a script. A Steam release has to disclose AI-generated content.

| folder | frames | frame px | loop | anchor |
|---|---|---|---|---|
| `banner/` | 4 | 24×32 | sway 0,+,0,− (whole-pixel row shifts of one frame) | row 0 empty, rod on row 1 (knobs x 2–21), tip ±2 px |
| `palm/` | 4 | 56×70 | sway 0,+,0,− | trunk foot: last row, x 23–28 |
| `lamp/` | 3 | 28×20 | flame flicker 1.0/0.72/1.18 | stands on the last row |
| `crystal/` | 3 | 24×26 | glow flicker | stands on the last row |
| `dust/` | 6 | 64×64 | motes drift on closed loops | none — tileable overlay; **procedural** (no model) |

## Foreground pieces (D774, Batch 0)

Single frames for the dark foreground layer `Scenes/Backgrounds/foreground_dark.tscn` (`FrontDark`, ×1.3, modulate
0.3/0.26/0.34 — they read as dark silhouettes). Made by `Scripts/Tools/comfy_backdrop.py` (layers `Decor/fg_hall/*`,
`Decor/fg_camp/*`): one generation per piece on the green key, keyed, downscaled to the game pixel, quantised.
AI-generated: **Qwen-Image** (Alibaba Qwen, Apache 2.0) + Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0).

| file | px | where |
|---|---|---|
| `fg_hall/chandelier.png` | 97×96 | Mayor Hall, hangs from the top |
| `fg_hall/banner.png` | 97×110 | Mayor Hall, hangs from the top (rod + cloth) |
| `fg_hall/column.png` | 131×352 | Mayor Hall, the screen's sides (taller than the screen) |
| `fg_camp/rope_stake.png` | 129×119 | Bandit Camp, a stake with two guy ropes |
| `fg_camp/crate.png` | 103×55 | Bandit Camp, low at an edge, below the walk line |
