# Vulture — a flying enemy outdoors (D445)

`sheet.png` — **AI-generated** (a Steam release has to disclose it) by `python -I -B Scripts/Tools/comfy_sprite.py
enemy_vulture` with the local ComfyUI, **Qwen-Image-Edit-2511** (Alibaba Qwen, licence **Apache 2.0**; GGUF Q5_K_M
by unsloth) + Lightning LoRA, the hero's artist frame (`Sprites/Player/Walk/1.png`) as the style reference. Sapega's
pick: candidate 2 (seed 92, no reference picture).

64×64 cells, facing right, rows ([[flying_enemies_plan]] slice 0): `fly` 4, `dive` 3, `hurt` 1, `death` 3.
Kept as generated (D637): the wing beat barely moves and the dive keeps the flying pose.
