# skyfall_blessing — skill effect (A6)

Light (Paladin) tree active. **AI-generated** with **Qwen-Image** (`qwen_image_fp8_e4m3fn` + `Qwen-Image-Lightning-4steps`
LoRA, **Apache 2.0**) by `Scripts/Tools/comfy_fx.py` (`skyfall_blessing_charge`, `skyfall_blessing_release`), anime style of D273.
Steam needs the AI-content disclosure. Wired: `Scenes/FX/Skills/OathSkill.tscn` (`OathSkillFX.gd`, D279).

- `charge_1–4.png` (32×32) — golden light feather, gathered in the hand during the cast pose: grows from the centre (1–2) →
  full (3) → thinner pulse (4); loop 3–4 while charging. Anchor: canvas centre on the casting hand.
- `release_1–3.png` (40×104) — a pillar of gold light slamming down from the sky into the ground in front of him, bursting sideways along the ground at the bottom (bottom on the canvas bottom, top tapered to a point by `taper`).
**A9 redraw** (2026-10-28, D813 «поправити», D828): was a thin pale pole with a star at each end, like a sceptre, vanishing on sand. The model drew ground under the burst — the bottom 14 % of the generation is cut (`crop`). Only the release changed; the feather charge stays. Release frames: 1 the full shape white-hot (impact flash), 2 full in colour, 3 one pixel thinner; 1-px outline `(92, 52, 12)` (`A9_OUTLINE` in `comfy_fx.py`).

