# The Brass Collector — the Mayor Hall boss (D301, D309)

**AI-generated** (a Steam release has to disclose it): the local ComfyUI with **Qwen-Image-Edit-2511** (Alibaba
Qwen, licence **Apache 2.0**; GGUF Q5_K_M by unsloth) and its Lightning 4-step LoRA (lightx2v, Apache 2.0).
Made by `Scripts/Tools/comfy_sprite.py brass_collector` from the hero's `Sprites/Player/Walk/1.png`; see
`../README.md`. Cells 96×112, feet on row 107, facing right.

- `stagger.png` — **remaining_work Art 4**, 192×112: two 96×112 cells made by
  `python Scripts/Tools/comfy_art_fixes.py "stagger_brass_collector*"` from idle 0, colours from `sheet.png`, feet
  on row 107. 0 = knocked backwards off balance (seed 35): upper body tilted back, head thrown back behind the hips,
  both arms flung forward and up, feet close together under the hips, the cage tilted back with him and in view;
  the frame spans x 10–85 of the cell. The first frame 0 (seed 31) had the pose of walk frames 4 and 6 — a forward stride, head
  ahead of the hips — so the boss seemed to step toward the hero as his poise broke; seed 32 kicked the front leg up
  and turned the cage into grey noise. 1 = dazed, hunched forward, head down, arms hanging (seed 31). Wired: animation `stagger` of the scene, played for the whole stagger (D264, `EnemyView.play_stagger`).
