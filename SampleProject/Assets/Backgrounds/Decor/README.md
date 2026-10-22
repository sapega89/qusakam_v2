# Decor idle loops (BACKLOG 19, A5b)

Made by `Scripts/Tools/comfy_decor.py`: one generation per prop in the backdrop style (`STYLE` of
`comfy_backdrop.py`), the loop frames are derived from that single image by the script (sway = pixel shift growing
from the anchor; flicker = brightness of the hot pixels), so the shape never drifts between frames. Each
`<name>_sheet.png` is a horizontal strip of equal frames, one shared palette; empty rows are trimmed, so row 0 is
the hanging line and the last row the foot line. Not wired into scenes yet.

AI-generated: drawn by the local ComfyUI with **Qwen-Image** (Alibaba Qwen, Apache 2.0) + the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0), then keyed, downscaled to the game pixel and quantised by a script. A Steam release has to disclose AI-generated content.

| folder | frames | frame px | loop | anchor |
|---|---|---|---|---|
| `banner/` | 4 | 24×30 | sway 0,+,0,− | hangs from row 0 (rod, x 4–19) |
| `palm/` | 4 | 56×70 | sway 0,+,0,− | trunk foot: last row, x 23–28 |
| `lamp/` | 3 | 28×20 | flame flicker 1.0/0.72/1.18 | stands on the last row |
| `crystal/` | 3 | 24×26 | glow flicker | stands on the last row |
| `dust/` | 6 | 64×64 | motes drift on closed loops | none — tileable overlay; **procedural** (no model) |
