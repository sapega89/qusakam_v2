# The hero's shield — a sprite drawn over his existing frames

S19 (Sapega 2026-10-27: «Просто щит поверх намалювати»): the equipped shield is **not** in the hero's frames. It is
one sprite drawn over the frames that already exist, and only in the three shield uses below; every other animation
stays shieldless.

`iron_shield/shield.png` (12×27) — the iron shield (`items.json` → `iron_shield`), seen from the side at an angle,
facing right, in the artist's 28 colours with his outline. **AI-generated** by `Scripts/Tools/hero_shield.py`
(Qwen-Image-Edit-2511, Apache 2.0, the artist's `Walk/1` as the style reference, seed 24; the 54-px shield the model
drew is halved by 32×32 blocks). A Steam release has to disclose AI-generated content.

## Where it sits

Position = the shield's **top-left** in the hero's 64×64 texture (feet on row 56). On the node, as `WeaponMount`
places blades: a `Sprite2D` with `centered = false`, `scale = 1.5`, at **world = (x − 32, y − 32) × 1.5** from the
hero's origin. **z: in front of the body** (after `Sprite2D` in the tree, or `z_index = 1`). Facing left: x → −x − 18
(the shield's width ×1.5) and `flip_h`.

| Use | Hero frame (existing) | Texture px (x, y) | World offset |
|---|---|---|---|
| Block (held) | `Block/1` | (42, 23) | (15, −13.5) |
| Shield Bash 1, wind-up | `Block/1` | (39, 23) | (10.5, −13.5) |
| Shield Bash 2, impact | `CastStorm/2` (arm thrust forward) | (49, 22) | (25.5, −15) |
| Shield Bash 3, recover | `Block/1` | (42, 23) | (15, −13.5) |
| Shield Charge, Run 1–8 (the Run loop) | `Run/1` … `Run/8` | (43, head top + 14): y = 24, 25, 22, 22, 24, 24, 23, 22 | (16.5, (y − 32) × 1.5): −12, −10.5, −15, −15, −12, −12, −13.5, −15 |

The charge rows follow the run's bob: y = the frame's first opaque row + 14, as `Block/1` (head top 9 → 23).
Review sheet: `design/shots/hero_death_shield.png`.
