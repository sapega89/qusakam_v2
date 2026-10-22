# Fire djinn — the Laboratory boss (D302, D309)

**AI-generated** (a Steam release has to disclose it): the local ComfyUI with **Qwen-Image-Edit-2511** (Alibaba
Qwen, licence **Apache 2.0**; GGUF Q5_K_M by unsloth) and its Lightning 4-step LoRA (lightx2v, Apache 2.0).
Made by `Scripts/Tools/comfy_sprite.py fire_djinn` from the hero's `Sprites/Player/Walk/1.png`; see `../README.md`.
Cells 96×112, lowest pixel (the flame tail) on row 108, facing right.

- `sheet.png` — **fix (remaining_work Art 4):** death frame 0 (cell 12) read like idle; redrawn by
  `Scripts/Tools/comfy_art_fixes.py djinn_death0` (seed 33, from idle 0): thrown back by the fatal blow, head flung
  back, arms flung wide (x 7–87 of the cell), mouth open, dark cracks across the chest, flame hair shrunk. Death 13
  (crumbling) unchanged.
- `stagger.png` — **new**, 192×112: two 96×112 cells, `comfy_art_fixes.py stagger_fire_djinn` (seed 33, from idle 0),
  colours from `sheet.png`. 0 = reeling, twisted away with a forearm raised before his face; 1 = dazed, hunched
  forward, head down, arms folded low. Tail on row 108 like every frame. A first frame 0 (arms flung wide) was a twin
  of the new death 0 and was redrawn. Wired: animation `stagger` of the scene, played for the whole stagger (D264, `EnemyView.play_stagger`).

Rerunning `comfy_sprite.py fire_djinn` would bring the old death 0 back — run `comfy_art_fixes.py djinn_death0` after it.
