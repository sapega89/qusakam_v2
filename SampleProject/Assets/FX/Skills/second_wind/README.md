# second_wind — skill effect (A6)

Neutral (Warden) tree active. **AI-generated** with **Qwen-Image** (`qwen_image_fp8_e4m3fn` + `Qwen-Image-Lightning-4steps`
LoRA, **Apache 2.0**) by `Scripts/Tools/comfy_fx.py` (`second_wind_charge`, `second_wind_release`), anime style of D273.
Steam needs the AI-content disclosure. Wired: `Scenes/FX/Skills/OathSkill.tscn` (`OathSkillFX.gd`, D279).

- `charge_1–4.png` (32×32) — mint wind spiral round a white core, two leaves, gathered in the hand during the cast pose: grows from the centre (1–2) →
  full (3) → thinner pulse (4); loop 3–4 while charging. Anchor: canvas centre on the casting hand.
- `release_1–3.png` (48×80) — two mint healing-wind ribbons twisting up round a white core, leaves and sparkles, bottom on the canvas bottom.
**A9 redraw** (2026-10-28, D813 «поправити», D828): the cream wind vanished on sand and its golden top read as a torch flame; now mint (a heal, not the beige of Balanced Strike / Dervish Whirl). The model put the swirl on a dark ground strip — the bottom 10 % of the generation is cut (`crop`). Release frames: 1 the full shape white-hot (impact flash), 2 full in colour, 3 one pixel thinner; 1-px outline `(18, 96, 96)` (`A9_OUTLINE` in `comfy_fx.py`).

