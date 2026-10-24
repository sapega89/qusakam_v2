# Armoured scorpion — the big elite scorpion (D652, D692)

`sheet.png` — **AI-generated** (a Steam release has to disclose it) by `python -I -B Scripts/Tools/comfy_sprite.py
big_armoured_scorpion` with the local ComfyUI, **Qwen-Image-Edit-2511** (Alibaba Qwen, licence **Apache 2.0**; GGUF
Q5_K_M by unsloth) + Lightning LoRA, the hero's artist frame (`Sprites/Player/Walk/1.png`) as the style reference.
Sapega's pick (D692): candidate 3 (seed 134, three-quarter view).

128×80 cells, 3 columns, facing right (the idle, attack and death cells came out facing left — the base candidate faces left — and were mirrored in place, D-ID in `design/cloud_reports/big-scorpion.md`), rows: `idle` 2, `walk` 2, `attack` 3 (tail back, sting, pincers), `hurt` 1,
`death` 3. Scene: `Scenes/Characters/Enemies/enemy_armoured_scorpion.tscn` (×1.25).
