# Bosses (BACKLOG 16 + 17 + 6, D301, D302, D309)

**AI-generated** by `Scripts/Tools/comfy_sprite.py brass_collector` / `fire_djinn`: the local ComfyUI with
**Qwen-Image-Edit-2511** (Alibaba Qwen, Apache 2.0; GGUF Q5_K_M by unsloth) and its Lightning LoRA (lightx2v, Apache 2.0).
The first frame is made from the hero's own sprite (`SampleProject/Sprites/Player/Walk/1.png`, the artist's frame) as
the style reference; every other frame from that first frame. Cells 96×112 at the hero's pixel (≈2× his height), one
palette per boss, the lowest pixel on row 107/108, facing right. A Steam release has to disclose AI-generated content.

| Sheet | Rows (4 columns, 96×112) | Who |
|---|---|---|
| `brass_collector/sheet.png` | idle 0–1 · walk 4–7 · attack (sweep) 8–11 · charge 12–13 · slam 16–17 · death 20–22 | the Mayor Hall boss: a brass-and-sandstone golem with a prisoner cage on its back (D301) |
| `fire_djinn/sheet.png` (3 columns) | idle 0–1 · attack (claws) 3–5 · cast 6–7 · fly 9 · death 12–13 | the Laboratory boss: a fire djinn on a smoke-and-flame tail (D302) |

Wired into `Scenes/Characters/Bosses/brass_collector.tscn` and `fire_djinn.tscn` (queue row 9.2, D316). `fire_djinn` death 12
was redrawn (it read like idle) and both bosses got a 2-frame `stagger.png` (remaining_work Art 4, not wired yet) —
see `brass_collector/README.md`, `fire_djinn/README.md`.
