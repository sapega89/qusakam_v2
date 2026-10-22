# The Brass Collector — the Mayor Hall boss (D301, D309)

**AI-generated** (a Steam release has to disclose it): the local ComfyUI with **Qwen-Image-Edit-2511** (Alibaba
Qwen, licence **Apache 2.0**; GGUF Q5_K_M by unsloth) and its Lightning 4-step LoRA (lightx2v, Apache 2.0).
Made by `Scripts/Tools/comfy_sprite.py brass_collector` from the hero's `Sprites/Player/Walk/1.png`; see
`../README.md`. Cells 96×112, feet on row 107, facing right.

- `stagger.png` — **new (remaining_work Art 4)**, 192×112: two 96×112 cells made by
  `Scripts/Tools/comfy_art_fixes.py stagger_brass_collector` (seed 31) from idle 0, colours from `sheet.png`.
  0 = knocked off balance, leaning far back, arms thrown forward (wide: x 6–89 of the cell; the cage mostly behind
  it); 1 = dazed, hunched forward, head down, arms hanging. Feet on row 107. Wired: animation `stagger` of the scene, played for the whole stagger (D264, `EnemyView.play_stagger`).
