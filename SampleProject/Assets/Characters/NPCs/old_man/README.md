# Kusakam's grandfather — Village OldMan

**AI-generated** (a Steam release has to disclose it): the local ComfyUI with **Qwen-Image-Edit-2511** (Alibaba
Qwen, licence **Apache 2.0**; GGUF Q5_K_M by unsloth) and its Lightning 4-step LoRA (lightx2v, Apache 2.0).
Made by `Scripts/Tools/comfy_sprite.py old_man` from the hero's `Sprites/Player/Walk/1.png`; see `../README.md`.
`sheet.png`: 64×96 cells, row 0 idle 0–1, row 1 pipe `work` 3–5; feet row 91; faces right (the scene flips him).

**Fix (remaining_work Art 4):** the staff swapped hands — the far hand with a hooked staff in idle, the near hand with
a knobby staff in the pipe frames. Idle 0 was redrawn by `Scripts/Tools/comfy_art_fixes.py old_man_idle` (same model,
seed 8) **from the pipe frame `work` 0**: the same staff in the same hand, no pipe, the other hand at his side, eyes
open; idle 1 is its breathing copy (`BOB:50`). Pipe frames unchanged. Rerunning `comfy_sprite.py old_man` would bring
the old idle back — run `comfy_art_fixes.py old_man_idle` after it.
