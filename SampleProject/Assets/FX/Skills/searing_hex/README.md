# searing_hex — skill effect (A6)

Dark (Dark Knight) tree active. **AI-generated** with **Qwen-Image** (`qwen_image_fp8_e4m3fn` + `Qwen-Image-Lightning-4steps`
LoRA, **Apache 2.0**) by `Scripts/Tools/comfy_fx.py` (`searing_hex_charge`, `searing_hex_release`), anime style of D273.
Steam needs the AI-content disclosure. Wired: `Scenes/FX/Skills/OathSkill.tscn` (`OathSkillFX.gd`, D279).

- `charge_1–4.png` (32×32) — a glowing violet hex sigil with violet flame on top, gathered in the hand during the cast pose: grows from the centre (1–2) →
  full (3) → thinner pulse (4); loop 3–4 while charging. Anchor: canvas centre on the casting hand.
- `release_1–3.png` (72×24) — a thick bolt of violet hexfire with a lilac-white core and indigo edges, tip on the right edge like `Smear/thrust`.
**A9 redraw** (2026-10-28, D813 «поправити», D828): read as dark red / pink fire, too close to Fire Strike, and the charge looked like a burning gem; now violet only, no red. Release frames: 1 the full shape white-hot (impact flash), 2 full in colour, 3 one pixel thinner; 1-px outline `(44, 14, 78)` (`A9_OUTLINE` in `comfy_fx.py`).

**A13 / Q124** (2026-10-28, Sapega: «Redraw without a star»): the model drew the charge sigil as a five-pointed star in
a circle (a pentagram), and as a six-pointed star when asked for a hexagon, so `charge_1–4.png` are **script-drawn now,
not AI-generated** (`comfy_fx.py` → `draw_hex_sigil`, run `comfy_fx.py searing_hex_charge`): a lilac ring with a
violet inner glow, a hexagon outline inside it, six short rune strokes facing its sides (not its corners — no star),
a bright dot in the centre and a small violet flame on top, A9's colours and `(44, 14, 78)` outline. Same canvas and
frames: grows from the centre (1–2) → full (3) → the ring one pixel thinner (4). The release frames are unchanged.
