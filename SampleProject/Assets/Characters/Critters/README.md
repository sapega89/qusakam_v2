# Ambient critters — birds (A21 slice 2, [[ambient_critters_plan]], D774)

`bird.png` (a desert lark: outdoors, the Village) and `pigeon.png` (the City) — **AI-generated** (a Steam release has
to disclose it) by `python -I -B Scripts/Tools/comfy_sprite.py critter_bird` / `critter_pigeon` with the local
ComfyUI, **Qwen-Image-Edit-2511** (Alibaba Qwen, licence **Apache 2.0**; GGUF Q5_K_M by unsloth) + Lightning LoRA.
Reference: the hero's artist frame (`Sprites/Player/Walk/1.png`), for the style and the pixel size (not the vulture
sheet: it is drawn at enemy size). Seeds 111 / 112, no picks by Sapega yet.

Facing right, the feet (lowest pixel) on the bottom row of the cell; scenes flip for the left.

| File | Cell | Row 0 | Row 1 |
|---|---|---|---|
| `bird.png` | 48×48 | `perch` 2 (frame 2: head and body 1 px lower, `BOB`) | `fly` 4: wings up, level, downstroke, level |
| `pigeon.png` | 56×56 (bigger bird, wings up are 50 px) | `perch` 2 (`BOB`) | `fly` 4: wings up, level, downstroke, level (feet down — a take-off) |

The bat critter uses the enemy sheet `Enemies/bat/sheet.png` (`critter_bat.tscn`). Sound: `critter_flap`.
