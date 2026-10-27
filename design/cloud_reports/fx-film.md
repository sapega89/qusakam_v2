---
type: report
tags: [cloud, fx, film]
---

# fx-film — combat effects filmed for Sapega's notes (BACKLOG 30 / MASTER_PLAN A9)

**Summary.** Done: `SampleProject/UI/film_fx.gd` films 41 effects in one Movie Maker run (DesertRoad, 1920x1080, 30 fps,
xvfb + opengl3, real InputMap bindings), `Scripts/Tools/fx_pack.py` packs them into 41 GIFs + 41 six-frame sheets
in `design/shots/fx/` with an [[index]] table. Every hero-side effect of `Assets/FX/README.md` and every `vfx` skill of
`skills.json` (12) is filmed, plus enemy strikes, bosses, companions, level-up, landing, block/parry, death.
Not filmed: the story effects that are not wired yet (explosion, wall_burst, sleep_gas, wall_hole), and the oath charge/
release frames only through the casts (all 9 are filmed). Film run 502 s, pack 744 s. No game code changed.
No D-ID, no B rows. `verify_scripts_compile`: RESULT: ALL PASS (no full suite: no game code changed).

## How to re-run

```bash
export G=/tmp/godot/Godot_v4.6.2-stable_linux.x86_64
xvfb-run -a -s "-screen 0 1920x1080x24" $G --path . --resolution 1920x1080 --rendering-driver opengl3 \
  --write-movie /tmp/fxfilm/fx.avi --fixed-fps 30 --script res://SampleProject/UI/film_fx.gd -- out=/tmp/fxfilm
python3 -I Scripts/Tools/fx_pack.py /tmp/fxfilm design/shots/fx
```

The .avi (~0.8 GB) stays out of git; `fx.marks.json` beside it holds each clip's video frames and screen rectangle.

## Setup of the film (film-only, nothing in the game changes)

- DesertRoad, `Arrival_Start` + 700 px (flat floor, daylight); room enemies freed, section-fight spawners off, hints off,
  `CombatRolls.calm()` (no crit/dodge rolls, every take is the same).
- **`FrontDark` hidden**: the room's foreground parallax boulder covered the hero and dummy at this spot (first run
  filmed only the rock). This is the only room layer touched.
- HUD and every UI CanvasLayer hidden; the `VFXHooks` layer (HurtVignette) stays.
- Dummy = a `melee` bandit with AI stopped, HP 99999, poise 99. Each new enemy settles on the floor 1600 px away and is
  then moved next to the hero: its AI runs through the body's physics while it falls, and a djinn spawned next to the
  hero threw an unrequested fireball in the second take.
- The hero: Max_Health 99999 and full HP before every clip (level-ups and equips recompute Max_Health — in the first
  take the hero died at the bosses and the last 6 clips showed Game Over). Damage numbers over the hero are real
  `take_damage` calls, healed back.
- Inputs through the real bindings (`_press` duplicates the InputMap key / mouse event): attack, heavy_attack, block,
  jump, skill_slot_1 (the hidden hotbar still casts), assist. Enemy and boss strikes are called directly
  (`start_attack`, `strike` + `BossLogic._fireballs/_pillars/_slam`), as in `verify_enemy_fx.gd`.
- Skills: the hero is raised to level 20, each skill is unlocked, put in slot 1 and cast with key 1; a skill that needs
  a weapon gets it first (Fire Strike: sword, Electric Strike: halberd — the second take showed nothing for Electric
  Strike because the hero held a sword). Refused casts are logged into `skipped`: none.

## The effects

| `level_up` | `Scenes/FX/LevelUpFlash.tscn`, `LevelUpParticles.tscn` | [level_up.gif](../shots/fx/level_up.gif) | Level-up flash and golden particles (Player._spawn_level_up_vfx) |
| `landing_dust` | `Scenes/FX/LandingDust.tscn` | [landing_dust.gif](../shots/fx/landing_dust.gif) | Landing dust after a jump (VFXHooks._on_player_landed, LandingDust.tscn) |
| `punch_combo` | `Assets/FX/Smear/punch_1-3`, `Hit/cut_1-4`, `SlashTrail.tscn`, `HitImpact.tscn` | [punch_combo.gif](../shots/fx/punch_combo.gif) | Bare-hand combo: punch streaks (Smear/punch_1-3) and the hit cut (Hit/cut_1-4) |
| `sword_combo` | `Assets/FX/Smear/arc_1-3`, `Hit/cut_1-4` | [sword_combo.gif](../shots/fx/sword_combo.gif) | Sword combo: swing crescents (Smear/arc_1-3), the finisher bigger |
| `mace_combo` | `Assets/FX/Smear/arc_1-3`, `Hit/cut_1-4` | [mace_combo.gif](../shots/fx/mace_combo.gif) | Mace combo: swing crescents (Smear/arc_1-3) |
| `dagger_combo` | `Assets/FX/Smear/thrust_1-3`, `Hit/cut_1-4` | [dagger_combo.gif](../shots/fx/dagger_combo.gif) | Dagger combo: thrust streaks (Smear/thrust_1-3) |
| `halberd_combo` | `Assets/FX/Smear/thrust_1-3`, `arc_1-3` | [halberd_combo.gif](../shots/fx/halberd_combo.gif) | Halberd combo: thrusts and a sweep (Smear/thrust, arc) |
| `dual_combo` | `Assets/FX/Smear/arc_1-3`, `thrust_1-3` | [dual_combo.gif](../shots/fx/dual_combo.gif) | Sword + dagger dual-wield: four fast swings |
| `heavy_attack` | `Assets/FX/Smear/arc_1-3` (x1.4), `Hit/cut_1-4` | [heavy_attack.gif](../shots/fx/heavy_attack.gif) | Sword heavy attack: the big crescent, heavy hit feel |
| `bow_quick_shot` | `Assets/FX/Projectiles/arrow.png` | [bow_quick_shot.gif](../shots/fx/bow_quick_shot.gif) | Bow quick shots: the arrow (Projectiles/arrow.png) and its hit |
| `bow_charged_shot` | `Assets/FX/Projectiles/arrow_charged.png` | [bow_charged_shot.gif](../shots/fx/bow_charged_shot.gif) | Bow held: draw, charged glow, the piercing charged arrow (arrow_charged.png) |
| `skill_fire_strike` | `fire_strike` - `Skills/fire_arc.png`, `Scenes/FX/Skills/FireStrike.tscn` | [skill_fire_strike.gif](../shots/fx/skill_fire_strike.gif) | Fire Strike: wind-up, then the fire crescent (Skills/fire_arc.png) |
| `skill_electric_strike` | `electric_strike` - `Skills/bolt.png`, `ElectricStrike.tscn` | [skill_electric_strike.gif](../shots/fx/skill_electric_strike.gif) | Electric Strike: the bolt in the wind-up and from the sky at the release (Skills/bolt.png) |
| `skill_healing_palm` | `healing_palm` - `Skills/heal_aura.png`, `HealingPalm.tscn` | [skill_healing_palm.gif](../shots/fx/skill_healing_palm.gif) | Healing Palm: the healing ring (Skills/heal_aura.png) |
| `skill_radiant_smite` | `radiant_smite` - `Assets/FX/Skills/radiant_smite/charge_*, release_*`, `OathSkill.tscn` | [skill_radiant_smite.gif](../shots/fx/skill_radiant_smite.gif) | radiant_smite (oath paladin): own charge and release frames (Skills/radiant_smite/) |
| `skill_skyfall_blessing` | `skyfall_blessing` - `Assets/FX/Skills/skyfall_blessing/charge_*, release_*`, `OathSkill.tscn` | [skill_skyfall_blessing.gif](../shots/fx/skill_skyfall_blessing.gif) | skyfall_blessing (oath paladin): own charge and release frames (Skills/skyfall_blessing/) |
| `skill_judgement_of_the_sky` | `judgement_of_the_sky` - `Assets/FX/Skills/judgement_of_the_sky/charge_*, release_*`, `OathSkill.tscn` | [skill_judgement_of_the_sky.gif](../shots/fx/skill_judgement_of_the_sky.gif) | judgement_of_the_sky (oath paladin): own charge and release frames (Skills/judgement_of_the_sky/) |
| `skill_searing_hex` | `searing_hex` - `Assets/FX/Skills/searing_hex/charge_*, release_*`, `OathSkill.tscn` | [skill_searing_hex.gif](../shots/fx/skill_searing_hex.gif) | searing_hex (oath dark_knight): own charge and release frames (Skills/searing_hex/) |
| `skill_withering_grasp` | `withering_grasp` - `Assets/FX/Skills/withering_grasp/charge_*, release_*`, `OathSkill.tscn` | [skill_withering_grasp.gif](../shots/fx/skill_withering_grasp.gif) | withering_grasp (oath dark_knight): own charge and release frames (Skills/withering_grasp/) |
| `skill_eclipse_cleave` | `eclipse_cleave` - `Assets/FX/Skills/eclipse_cleave/charge_*, release_*`, `OathSkill.tscn` | [skill_eclipse_cleave.gif](../shots/fx/skill_eclipse_cleave.gif) | eclipse_cleave (oath dark_knight): own charge and release frames (Skills/eclipse_cleave/) |
| `skill_balanced_strike` | `balanced_strike` - `Assets/FX/Skills/balanced_strike/charge_*, release_*`, `OathSkill.tscn` | [skill_balanced_strike.gif](../shots/fx/skill_balanced_strike.gif) | balanced_strike (oath warden): own charge and release frames (Skills/balanced_strike/) |
| `skill_dervish_whirl` | `dervish_whirl` - `Assets/FX/Skills/dervish_whirl/charge_*, release_*`, `OathSkill.tscn` | [skill_dervish_whirl.gif](../shots/fx/skill_dervish_whirl.gif) | dervish_whirl (oath warden): own charge and release frames (Skills/dervish_whirl/) |
| `skill_second_wind` | `second_wind` - `Assets/FX/Skills/second_wind/charge_*, release_*`, `OathSkill.tscn` | [skill_second_wind.gif](../shots/fx/skill_second_wind.gif) | second_wind (oath warden): own charge and release frames (Skills/second_wind/) |
| `parry_spark` | `Scenes/FX/ParrySpark.tscn` (VFXHooks._on_guard) | [parry_spark.gif](../shots/fx/parry_spark.gif) | Parry: the hero blocks just as the bandit strikes - parry sparks (ParrySpark.tscn) |
| `block_spark` | `Scenes/FX/ParrySpark.tscn` x0.5 | [block_spark.gif](../shots/fx/block_spark.gif) | Block: the hero holds block through the strike - smaller block sparks |
| `enemy_shield_sparks` | `ParrySpark.tscn` (VFXHooks._on_shield) | [enemy_shield_sparks.gif](../shots/fx/enemy_shield_sparks.gif) | Hits on a shield bandit's shield: shield sparks, a heavy hit breaks it |
| `enemy_melee` | `Scripts/FX/EnemyStrikeFX.gd` (melee); hurt: `HitImpact.tscn`, `HurtVignette.tscn` | [enemy_melee.gif](../shots/fx/enemy_melee.gif) | Enemy strike (melee): its smear from EnemyStrikeFX.WEAPONS, then the hit on the hero (red cut, vignette) |
| `enemy_bandit_brute` | `Scripts/FX/EnemyStrikeFX.gd` (bandit_brute); hurt: `HitImpact.tscn`, `HurtVignette.tscn` | [enemy_bandit_brute.gif](../shots/fx/enemy_bandit_brute.gif) | Enemy strike (bandit_brute): its smear from EnemyStrikeFX.WEAPONS, then the hit on the hero (red cut, vignette) |
| `enemy_armoured_scorpion` | `Scripts/FX/EnemyStrikeFX.gd` (armoured_scorpion); hurt: `HitImpact.tscn`, `HurtVignette.tscn` | [enemy_armoured_scorpion.gif](../shots/fx/enemy_armoured_scorpion.gif) | Enemy strike (armoured_scorpion): its smear from EnemyStrikeFX.WEAPONS, then the hit on the hero (red cut, vignette) |
| `enemy_fast` | `Scripts/FX/EnemyStrikeFX.gd` (fast); hurt: `HitImpact.tscn`, `HurtVignette.tscn` | [enemy_fast.gif](../shots/fx/enemy_fast.gif) | Enemy strike (fast): its smear from EnemyStrikeFX.WEAPONS, then the hit on the hero (red cut, vignette) |
| `enemy_jackal_cursed` | `Scripts/FX/EnemyStrikeFX.gd` (jackal_cursed), `CursedFoam.tscn`; hurt: `HitImpact.tscn`, `HurtVignette.tscn` | [enemy_jackal_cursed.gif](../shots/fx/enemy_jackal_cursed.gif) | Enemy strike (jackal_cursed): its smear from EnemyStrikeFX.WEAPONS, then the hit on the hero (red cut, vignette) |
| `enemy_vulture` | `Scripts/FX/EnemyStrikeFX.gd` (vulture); hurt: `HitImpact.tscn`, `HurtVignette.tscn` | [enemy_vulture.gif](../shots/fx/enemy_vulture.gif) | Enemy strike (vulture): its smear from EnemyStrikeFX.WEAPONS, then the hit on the hero (red cut, vignette) |
| `enemy_archer` | `Scripts/FX/EnemyStrikeFX.gd` (archer); hurt: `HitImpact.tscn`, `HurtVignette.tscn` | [enemy_archer.gif](../shots/fx/enemy_archer.gif) | Enemy strike (archer): its smear from EnemyStrikeFX.WEAPONS, then the hit on the hero (red cut, vignette) |
| `boss_fire_djinn_fireball` | `Assets/FX/Bosses/fireball.png`, `Scenes/FX/Bosses/boss_fireball.tscn` | [boss_fire_djinn_fireball.gif](../shots/fx/boss_fire_djinn_fireball.gif) | Fire djinn: the fireball (Bosses/fireball.png, boss_fireball.tscn) |
| `boss_fire_djinn_pillar` | `Assets/FX/Bosses/mark.png`, `pillar.png`, `boss_pillar.tscn` | [boss_fire_djinn_pillar.gif](../shots/fx/boss_fire_djinn_pillar.gif) | Fire djinn: the floor mark, then the fire pillar (Bosses/mark.png, pillar.png) |
| `boss_brass_collector_slam` | `Assets/FX/Bosses/shockwave.png`, `boss_shockwave.tscn`; EnemyStrikeFX slam | [boss_brass_collector_slam.gif](../shots/fx/boss_brass_collector_slam.gif) | Brass Collector: the slam, its shockwave and dust (Bosses/shockwave.png) |
| `companion_alisia` | `Scenes/FX/Companions/charge_glow`, `arrow_streak`, `hit_spark` | [companion_alisia.gif](../shots/fx/companion_alisia.gif) | Alisia: green draw glow, the arrow streak, hit sparks (Companions/charge_glow, arrow_streak, hit_spark) |
| `companion_astrit` | `Scenes/FX/Companions/landing_dust`, `charge_glow`, `shield_slam`, `stun_stars` | [companion_astrit.gif](../shots/fx/companion_astrit.gif) | Astrit: drops in - landing dust, charge glow, shield slam, stun stars |
| `companion_urizen` | `Scenes/FX/Companions/charge_glow`, `gold_burst` | [companion_urizen.gif](../shots/fx/companion_urizen.gif) | Urizen: gold glow, the coin chaining to three enemies - gold bursts |
| `companion_guard` | `Scenes/FX/Companions/wind_arc`, `knockback_puff` | [companion_guard.gif](../shots/fx/companion_guard.gif) | City Gates guard: runs in, the thrust ends with a wind arc, knockback puff |
| `enemy_death` | `Scenes/FX/DeathParticles.tscn`, `DamageNumber.tscn` | [enemy_death.gif](../shots/fx/enemy_death.gif) | Enemy death: the last hit, damage number, death particles (DeathParticles.tscn) |

GIF details: game pixels x2 (nearest), 15 fps (every 2nd video frame), palette 256→48 colours until ≤ 1.5 MB. Too wide
clips are shrunk: archer, djinn fireball and pillar to 75 %, the four companions to 50 % (they run in from the edge of
the view, 1200 px wide). `companion_urizen.gif` is 1.57 MB even at 50 % / 32 colours — kept, slightly over.

## Not filmed, and why

- `Bosses/explosion.png`, `wall_burst.png`, `sleep_gas.png`, `wall_hole.png`: story effects, README says not wired.
- `Projectiles/` README said "not wired", but the bow is wired (D383) — filmed as `bow_quick_shot` / `bow_charged_shot`.
- Enemy kinds of an already filmed smear family: shield and tower_shield_guard (arc, = melee), tank (sting),
  jackal_pack_leader / bat / fly (bite), old_vulture (dive), heavy_archer (shot). One per family is filmed.
- Bosses lab_boss, scorpicore_warrior, giant_scorpion: their strikes are the same EnemyStrikeFX arc / slam / charge
  family (`verify_enemy_fx`); brass_collector's slam is filmed. Boss combo and charge not filmed separately.
- No axe or staff item exists in `items.json` (slots only), so no axe swing.
- HurtVignette (red screen edges) plays on the enemy-strike clips, but the GIF crop around hero and enemy cuts most of
  it away; the full frame is in the .avi.
- Emote, CursedFoam outside a strike: not combat effects (the cursed jackal's foam is visible in `enemy_jackal_cursed`).

## Notes for whoever looks at the GIFs

- The dummy stands 36 px in front of the hero (the reach of the light combo), so the hero and dummy sprites overlap;
  the smear and cut are still on top.
- `skill_healing_palm`: the hero is at Max − 70 HP before the cast so the heal has something to restore.

## Run times

| Take | Film | Why another take |
|---|---|---|
| 1 | 905 s | foreground rock hid everything; hero died after the level-ups (Game Over in the last clips) |
| 2 | 478 s | Electric Strike refused (needs halberd/mace); djinn's stray fireball |
| 3 | 531 s | stray fireball still there (AI runs through the body's physics) |
| 4 | 502 s | final; pack 744 s (cv2 + Pillow, 41 GIFs, 61 MB in `design/shots/fx/`) |
