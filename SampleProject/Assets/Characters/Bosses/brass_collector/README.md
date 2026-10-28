# The Brass Collector — the Mayor Hall boss (D301, D309)

**AI-generated** (a Steam release has to disclose it): the local ComfyUI with **Qwen-Image-Edit-2511** (Alibaba
Qwen, licence **Apache 2.0**; GGUF Q5_K_M by unsloth) and its Lightning 4-step LoRA (lightx2v, Apache 2.0).
Made by `Scripts/Tools/comfy_sprite.py brass_collector` from the hero's `Sprites/Player/Walk/1.png`; see
`../README.md`. Cells 96×112, feet on row 107 (`floor=107`), facing right; 24 colours.

**A7 redraw** (2026-10-28, D813 «прибрати»; before | after `design/shots/a7_ingame_redraw.png`). The first sheet was
one flat yellow brass with no sandstone, the eye slits did not show, the cage was a thin grey ladder finer than the
16-px block (it fell into grey noise or vanished in several frames) and the body was narrow. Now D309's look as
written: a golem of pale cracked sandstone blocks bound with dark riveted brass plates and bands, two amber eye slits,
huge brass fists, a big boxy cage of thick dark iron bars on its back, normal heavy proportions (D816). First frame:
3 candidates (seeds 41, 42, 43, `design/shots/candidates/brass_collector_a7.png`), seed 43 kept — the darkest,
thickest cage and the clearest brass. Same rows, frame order and feet line as before; `specks=12` drops the dust the
model laid under the feet; idle 1 breathes above row 70 (below the belt). The scene's shapes follow the new drawing
(B128): hurtbox 114×153, hitbox 61.5×148.5, `melee_reach` 61.5, glints on the new fists (`tell_at` (−1, −46),
charge (33, 10), slam (2, −46)); `portrait.tres` moved to the head, Rect2(40, 4, 48, 48).

- `stagger.png` — 192×112: two 96×112 cells made by
  `python -I -B Scripts/Tools/comfy_art_fixes.py stagger_brass_collector0 stagger_brass_collector1` from the new idle 0
  (working tree), colours from the new `sheet.png`, feet on row 107, seed 43. 0 = knocked backwards off balance: upper
  body tilted back, head thrown back, both arms flung forward and up, feet together under the hips, the cage tilted
  back with him and in view. 1 = dazed, hunched forward, head down, arms hanging. Wired: animation `stagger` of the
  scene, played for the whole stagger (D264, `EnemyView.play_stagger`). (The first sheet's stagger rejects — a
  forward stride, a kick — are in git history.)
