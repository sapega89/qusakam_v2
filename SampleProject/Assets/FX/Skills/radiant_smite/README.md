# radiant_smite — skill effect (A6)

Light (Paladin) tree active. **AI-generated** with **Qwen-Image** (`qwen_image_fp8_e4m3fn` + `Qwen-Image-Lightning-4steps`
LoRA, **Apache 2.0**) by `Scripts/Tools/comfy_fx.py` (`radiant_smite_charge`, `radiant_smite_release`), anime style of D273.
Steam needs the AI-content disclosure. Wired: `Scenes/FX/Skills/OathSkill.tscn` (`OathSkillFX.gd`, D279).

- `charge_1–4.png` (32×32) — saturated gold star glint with long rays, gathered in the hand during the cast pose: grows from the centre (1–2) →
  full (3) → thinner pulse (4); loop 3–4 while charging. Anchor: canvas centre on the casting hand.
- `release_1–3.png` (56×72) — a thick sunburst crescent of gold light, straight rays off its outer edge, outer edge pinned to the right edge like `Smear/arc`.
**A9 redraw** (2026-10-28, D813 «поправити», D828): was pale cream with no outline and vanished on sand; the first model try drew a sword («no sword» in the prompt). Release frames: 1 the full shape white-hot (impact flash), 2 full in colour, 3 one pixel thinner; 1-px outline `(92, 52, 12)` (`A9_OUTLINE` in `comfy_fx.py`).

