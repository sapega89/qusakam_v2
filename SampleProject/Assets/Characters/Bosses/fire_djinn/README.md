# Fire djinn — the Laboratory boss (D302, D309)

**AI-generated** (a Steam release has to disclose it): the local ComfyUI with **Qwen-Image-Edit-2511** (Alibaba
Qwen, licence **Apache 2.0**; GGUF Q5_K_M by unsloth) and its Lightning 4-step LoRA (lightx2v, Apache 2.0).
Made by `Scripts/Tools/comfy_sprite.py fire_djinn` from the hero's `Sprites/Player/Walk/1.png`; see `../README.md`.
Cells 96×112, lowest pixel (the flame tail) on row 108, facing right.

- `sheet.png` — **fix (remaining_work Art 4):** the death frames (cells 12 and 13, played 12 → 13) read like idle.
  Cell 12 redrawn by `Scripts/Tools/comfy_art_fixes.py djinn_death0` (seed 33, from idle 0): thrown back by the
  fatal blow, head flung back, arms flung wide (x 7–87 of the cell), mouth open, dark cracks across the chest, flame
  hair shrunk. Cell 13 was still the old upright pose with the arms crossed, so he seemed to recover before
  crumbling; `djinn_death1` (seed 33) redraws it from the new cell 12: the head still thrown back, the arms dropped,
  the body cracking into dark smoke and embers, the flame hair guttering out (x 19–66). 12 → 13 reads as one
  collapse; the arms never cross again.
- `stagger.png` — 192×112: two 96×112 cells, `python Scripts/Tools/comfy_art_fixes.py "stagger_fire_djinn*"`
  (seed 33, from idle 0), colours from `sheet.png`, facing right like the whole sheet, the flame-tail ball on row 108
  at x 37–58 like idle. 0 = reeling, twisted away with a forearm raised before his face, hair blown back — the model
  drew it facing left, so the job mirrors the cell (`post`). 1 = dazed, head bowed, both arms hanging limp. Redrawn
  earlier: a frame 0 with the arms flung wide (a twin of the new death 12) and a frame 1 that faced left with the
  arms folded low like a raised knee. Wired: animation `stagger` of the scene, played for the whole stagger (D264, `EnemyView.play_stagger`).

Rerunning `comfy_sprite.py fire_djinn` would bring the old death frames back — run
`comfy_art_fixes.py djinn_death0 djinn_death1` after it (in that order: death 1 is drawn from the new death 0).
