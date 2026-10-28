# withering_grasp — skill effect (A6)

Dark (Dark Knight) tree active. **AI-generated** with **Qwen-Image** (`qwen_image_fp8_e4m3fn` + `Qwen-Image-Lightning-4steps`
LoRA, **Apache 2.0**) by `Scripts/Tools/comfy_fx.py` (`withering_grasp_charge`, `withering_grasp_release`), anime style of D273.
Steam needs the AI-content disclosure. Wired: `Scenes/FX/Skills/OathSkill.tscn` (`OathSkillFX.gd`, D279).

- `charge_1–4.png` (32×32) — knot of black-violet shadow tendrils with sickly green tips, gathered in the hand during the cast pose: grows from the centre (1–2) →
  full (3) → thinner pulse (4); loop 3–4 while charging. Anchor: canvas centre on the casting hand.
- `release_1–3.png` (64×40) — a huge black-violet shadow claw with sickly yellow-green claws and a pale green rim, reaching right, arm from the left edge.
**A9 redraw** (2026-10-28, D813 «поправити», D828): was dark violet on dark (invisible in dark rooms) with crimson tips like the other Dark skills; now the green rim reads in the dark and the black body on sand. Release frames: 1 the full shape white-hot, flashing violet `(210, 170, 255)` instead of white (a white flash turned the black hand grey) (impact flash), 2 full in colour, 3 one pixel thinner; 1-px outline `(150, 214, 92)` (`A9_OUTLINE` in `comfy_fx.py`).

