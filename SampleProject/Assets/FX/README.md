# Combat effects (D204, D224, D268, D271)

All files here are **AI-generated** with **Qwen-Image** (`qwen_image_fp8_e4m3fn` + `Qwen-Image-Lightning-4steps`
LoRA, **Apache 2.0**) by `Scripts/Tools/comfy_fx.py`: one generated picture per effect on a chroma key,
keyed out, fitted into the texture at the game's pixel scale (1 texture px = 1.5 world px, like the hero), quantised;
the animation frames are cut from that one picture (appear → full → thinning). Steam needs the AI-content disclosure.

| File | Effect | Made from |
|---|---|---|
| `Smear/arc_1–3.png` | swing crescent (sword / axe / mace / heavy), `SlashTrail.tscn` | `slash_arc` |
| `Smear/thrust_1–3.png` | thrust streak (dagger, halberd) | `thrust` |
| `Smear/punch_1–3.png` | bare-hand punch streak | `thrust` |
| `Hit/cut_1–4.png` | hit cut across the target, `HitImpact.tscn` | `thrust`, turned 35° |
| `Skills/fire_arc.png` | Fire Strike crescent | `fire_arc` |
| `Skills/bolt.png` | Electric Strike bolt (forward and from the sky) | `bolt` |
| `Skills/heal_aura.png` | Healing Palm ring | `heal_aura` |
| `Bosses/fireball.png` | the fire djinn's fireball, `Scenes/FX/Bosses/boss_fireball.tscn` (D302) | `boss_fireball` |
| `Bosses/pillar.png`, `Bosses/mark.png` | the djinn's fire pillar and its floor mark, `boss_pillar.tscn` | `boss_pillar`, `boss_mark` |
| `Bosses/shockwave.png` | the Brass Collector's slam shockwave, `boss_shockwave.tscn` (D301) | `boss_shockwave` |
| `Bosses/explosion.png`, `wall_burst.png`, `sleep_gas.png`, `wall_hole.png` | story effects for the Mayor Hall / cells (queue rows 9.3, 9.5), not wired yet | same names |
| `Projectiles/arrow.png`, `arrow_charged.png` | the hero's bow arrow and charged arrow (BACKLOG 40), not wired yet, see `Projectiles/README.md` | `arrow`, `arrow_charged` |

Replaced 2026-10-21 (Sapega: hack'n'slash, anime, generated): the drawn smears of `draw_hero_attack.py` and the
round hit spark `HitSpark/` (unknown licence).
