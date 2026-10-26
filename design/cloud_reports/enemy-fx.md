---
type: report
tags: [cloud, routine, combat, fx]
---

# enemy-fx: hit effects for every enemy and boss (A17)

- **Done (code):** every enemy kind and both bosses (lab mercenary, Scorpicore axe-warrior) get the hero's effects, reusing the same components with parameters. `SlashTrail` (arc, thrust, punch) is tinted and sized per kind: arc, club plus dust, bite (jaw snap), sting, dive, and speed lines with a dust kick for lunges and charges. `LandingDust` is the ground dust, `ParrySpark` the arrow burst. Archer arrows trail a streak in their tell colour. A hit on the hero now counts as heavy for elites and for blows of ≥ 20 % of max HP.
- **New signals:** `EventBus.enemy_struck(enemy, move, direction)` (strike frame) and `EventBus.arrow_landed(at, tell)`.
- **NOT RUN:** in this cloud run the auto-mode classifier refused to execute the downloaded Godot binary ("Code from External"), so **no test, import or capture ran**. `verify_enemy_fx.gd`, the combat verifies (`verify_hit_feel`, `verify_souls_combat`, `verify_hit_areas`, `verify_bow`, `verify_enemy_variety`, `verify_lab_boss`, `verify_hero_motion`), the full suite and `capture_enemy_fx.gd` must run on the PC. A parse error is possible: the new scripts were written without being compiled.
- **D-ID:** D717 (D716 is taken by `elder-home`), text below. **B rows fixed:** none.
- **Full suite:** not run (see above).
- MASTER_PLAN A17 is set to built but not run.

## D717 (row for `figma_decision_register.md`)

| D717 | OVERRIDE | **Every enemy and boss gets anime-style hit effects, like the hero's. Poses are not redrawn** (Sapega, 2026-10-26: «анімації у всіх мають бути анімешними, не тільки у мене», then «перемальовувати не треба — анімації удару я мав на увазі, а не анімації персонажів»; `cloud/enemy-fx`, A17). There is one FX system: `Scripts/FX/EnemyStrikeFX.gd`, a child of `VFXHooks`, reuses `SlashTrail`, `LandingDust` and `ParrySpark` from a fixed pool (16 trails, 6 dust, 6 sparks, round-robin, nothing allocated on a strike). It listens to the new `EventBus.enemy_struck(enemy, move, direction)`, which fires on the strike frame from `DefaultEnemy.start_attack`, `BossEnemy.start_attack`, `BossEnemy.strike` (slam) and `ArcherEnemy.start_attack`. `move` comes from `DefaultEnemy.strike_move()`: swing / lunge / bite / dive / charge / slam / shot. The weapon comes from `enemy_type` (`EnemyStrikeFX.WEAPONS`). The smear covers the strike zone, from the body centre to the far edge of the hitbox. **Bandit, shield bandit, tower-shield guard:** arc, steel blue. **Brute:** club arc ×1.15 plus dust ×1.4 where the club lands, dust tan. **Scorpions (tank, armoured):** a sting thrust, venom green. **Jackals (fast, cursed, pack leader):** a jaw snap (two arcs closing and a punch flash), pale violet; the cursed one is purple. **Bat, fly:** jaw snap, purple. **Vultures:** a dive streak along the dive, feather tan. **Lab mercenary:** mace and club arcs, green, and the slam is a heavy arc ×1.3 plus dust ×2.2 both ways. **Scorpicore:** axe arc ×1.3, venom green. A **lunge, charge or bat bite** adds 3 speed lines behind and a dust kick-off. **Archers:** a streak behind the arrow (`arrow.tscn → Streak`) in its tell colour (D504), and small sparks ×0.35 where it lands (`EventBus.arrow_landed`). Smear colours are `UITokens.ENEMY_SMEAR_*`, alpha 0.9. None of them is the tell white, yellow or red. **Landed hit on the hero:** the existing cut, hitstop, shake, vignette and white flash (D204, D581). It now counts as heavy (`HURT_FEEL[1]`) for an elite and for a blow of ≥ 20 % of the hero's max HP (`VFXHooks.HEAVY_HURT_SHARE`, `hurt_tier_for`); bosses stay at tier 2. **Block:** the existing block spark; **parry:** the parry spark. **Low quality** (D554): smears stay, with 1 speed line, no dust and no arrow sparks. Movement, moves, sizes and balance are unchanged. Test: `verify_enemy_fx` [1]–[4]; capture: `capture_enemy_fx.gd` → `design/shots/enemy_fx.png`. |

## Details

### Files
- `SampleProject/Scripts/Core/EventBus.gd`: `enemy_struck`, `arrow_landed`.
- `SampleProject/Scripts/Gameplay/DefaultEnemy.gd`: `start_attack` emits `enemy_struck`; new `strike_move()`.
- `SampleProject/Scripts/Gameplay/Characters/Bosses/BossEnemy.gd`: `start_attack` emits; `strike()` emits `slam`; `strike_move()` returns `charge` while the charge move runs.
- `SampleProject/Scripts/Gameplay/Characters/Enemies/ArcherEnemy.gd`: emits `shot` after loosing the arrow.
- `SampleProject/Scripts/Combat/Arrow.gd` + `Scenes/Combat/arrow.tscn`: the `Streak` child, shown only on an enemy arrow and hidden once a parry turns it into a hero arrow. `arrow_landed` fires on a stick and on a hit or block against the hero.
- `SampleProject/Scripts/FX/SlashTrail.gd`: `pooled` mode, which hides the node on its last frame instead of freeing it; `play()` restarts at frame 0.
- `SampleProject/Scripts/FX/EnemyStrikeFX.gd` (new): the table, the pool and the effects.
- `SampleProject/Scripts/Systems/VFXHooks.gd`: creates `EnemyStrikeFX`; `hurt_tier_for` (elite, damage share); test signals `hurt_shown(tier)` and `guard_shown(parry)`.
- `SampleProject/UI/Tokens/UITokens.gd`: `ENEMY_SMEAR_*` colours. They are not theme tokens, so the theme needs no rebuild.
- `SampleProject/UI/verify_enemy_fx.gd` (new): [1] each of the 15 kinds, the strike-frame smear parts, plus the archers' arrow streak and its stick sparks; [1b] both bosses: combo, slam, charge; [2] a landed hit gives the impact and hitstop with the expected tier, plus the 20 %-HP rule; [3] parry, then block, gives the sparks; [4] on Low, no dust.
- `SampleProject/UI/capture_enemy_fx.gd` (new): a sheet of smear and impact frames for every kind and boss move → `design/shots/enemy_fx.png`.

### Known risks for the PC run
- No `.uid` files were generated for the new scripts. Godot writes them on the first import.
- `verify_hit_feel` [3] still expects tier 0 for a 5-damage bandit hit. That holds: the bandit is not elite, and 5 < 20 % of 99999.
- If the bosses' `_ready` needs nodes DesertRoad lacks, `verify_enemy_fx` [1b] will show it. `capture_bosses.gd` places them elsewhere.
