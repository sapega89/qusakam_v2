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
| `Bosses/pillar.png`, `Bosses/mark.png` | the djinn's fire pillar and its floor mark, `boss_pillar.tscn`. The mark redrawn in H4 (2026-10-27; the old 48×10 ember oval read faint): a top-down fire-rune circle squashed into a 48×14 floor oval (`stretch`), white-hot core, orange ring, red rim, dark 1-px outline; lit x 6–40 = 72 world px, the pillar's `width`. Mark and fire sit on the hero's feet line (y 22.5 / 29), unshaded (dark rooms' CanvasModulate no longer greys them), the mark pulses 1 ↔ 0.8 | `boss_pillar`, `boss_mark` |
| `Bosses/shockwave.png` | the Brass Collector's slam shockwave, `boss_shockwave.tscn` (D301) | Redrawn in A1 (2026-10-27, Sapega «більш виразний має бути»; the old beige dust wave melted into the dark hall floor): a sand crest with a white front edge, orange core and a dark 1-px outline on the same 56×28 canvas; unshaded (CanvasModulate no longer greys it), full strength for the first half of its run, then fades | `boss_shockwave` |
| `Bosses/explosion.png`, `wall_burst.png`, `sleep_gas.png`, `wall_hole.png` | story effects for the Mayor Hall / cells (queue rows 9.3, 9.5), not wired yet | same names |
| `Projectiles/arrow.png`, `arrow_charged.png` | the hero's bow arrow and charged arrow (BACKLOG 40), not wired yet, see `Projectiles/README.md` | `arrow`, `arrow_charged` |
| `Skills/<skill_id>/charge_1–4.png`, `release_1–3.png` | own charge + release effects of the 9 oath-tree actives (A6), not wired yet, see each folder's README | `<skill_id>_charge`, `<skill_id>_release` |
| `Shield/magic/drop_1–3.png`, `hold_1–2.png`, `fade_1–2.png` | the magic shield spell (H2, Sapega 2026-10-27: a Pathfinder spell, not gear): a shield of light drops from the sky in front of him and lands (3), holds with a shimmer (2, loop), fades (2); warm gold-white, a solid pale-blue edge. Not wired yet | `Scripts/Tools/shield_spells.py` `magic` (Qwen-Image, seed 51) |
| `Shield/glass/appear_1–2.png`, `hold_1.png`, `crack_1–2.png`, `shatter_1–3.png` | the glass shield spell: appears (2), holds (1), cracks (2 stages), shatters into shards flying forward at the attacker (3). Not wired yet | `shield_spells.py` `glass` (seed 52); the cracks and the shards are drawn by the script from that one picture |

Replaced 2026-10-21 (Sapega: hack'n'slash, anime, generated): the drawn smears of `draw_hero_attack.py` and the
round hit spark `HitSpark/` (unknown licence).

**Shield spells (H2).** Drawn over the hero's existing `Block/1` — no new hero frames. The shield is 31 art px tall: 0.65 of his drawn figure (48 px, rows 9–56; 0.65 of the 64-px cell would be 42 px and cover him from the feet to the eyes instead of standing in front of the chest), x 48–62, y 21–51 of his 64×64 texture, a front-view shield squashed to 0.7 width so it faces the enemy. Bodies are translucent (alpha 210 light, 170 glass) with a solid 1-px edge, so the hero shows through and the shield still reads on sand. To wire (as `WeaponMount` places blades): a `Sprite2D`, `centered = false`, `scale = 1.5`, in front of the hero (`z_index = 1`), at world = (x − 32, y − 32) × 1.5 from his origin, where (x, y) is the canvas's top-left in his texture: magic 32×96 at (40, −32) → (12, −96); glass 64×64 at (40, 0) → (12, −48). Facing left: x → −x − width × 1.5 (magic −60, glass −108) and `flip_h`. Sheet: `design/shots/shield_spells.png` (×4, over `Block/1`, `Idle 1` for scale, on dark and on sand).
