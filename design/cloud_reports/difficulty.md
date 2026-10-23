---
type: cloud-report
tags: [cloud, combat, difficulty]
branch: cloud/difficulty
---

# Cloud report: difficulty (D642)

**Summary.**
- Done: `verify_difficulty.gd` measures each fight of the route (6 kinds, elites, both bosses) for a STRENGTH and a SKILLS build, from the real formulas. It asserts D642 and passes after the retune (before: 14 FAIL).
- Changed: hero growth per level, Strength's diminishing returns, enemy level per fight, base stats, bosses, the 8 damaging non-ultimate actives (×1.5), faster enemy tempo and a 3-enemy attack token. All numbers are in data; the flask is unchanged.
- Not done: no real-fight capture (D580), so this is numbers only, and Sapega should play it. The Laboratory boss is still the djinn (D564's manticore is not built).
- D-IDs: D654–D659 below. B rows fixed: none.
- Full suite: `SUITE: ALL PASS` (112 verify scripts, final run after all changes).

## D-ID text (for the orchestrator)

| ID | Kind | Text |
|---|---|---|
| D654 | ROUTINE CALL | **The difficulty simulation** (D642; `cloud/difficulty`). `verify_difficulty.gd` walks the story route (Canyon → Village → Desert Road → City Gates → City → Mayor Hall → Lab cells → Laboratory → LabBoss). For each fight it takes the hero's level at the fight's start (XP from the spawn points' EnemyStats, as `verify_xp_curve`) and builds a real hero at that level with the route's gear: before the City the grandfather's copper sword and leather armour, from the City the shops' iron sword, iron armour and iron shield. It then spawns the real enemy scene (medium size, elite where the fight has `elite = always` or `elite_rolls`) or the boss scene. **H** is how many of the enemy's ordinary hits (for a boss, a combo swing) kill the hero through `Player.mitigated_damage`, with no block and no dodge (the evasion roll is calmed). **N** is how many hero actions kill it: the light combo via `PlayerCombat.hit_damage` with no crit, from behind (tank shell, shield), plus the best affordable active (`SkillManager.skill_damage` + burn) whenever SP allows. The fight starts at **0 SP**, and SP comes from hits (D504). Two builds: **STRENGTH** puts every attribute point in Strength and spends no JP. **SKILLS** puts 2 Strength / 2 Vitality / 1 Wisdom per level and learns in order Toughness, Shield Block, Weapon Training, Radiant Smite, Devotion, Fire Strike, Riposte Instinct, Aura of Resolve, Mending Hands, Sky's Grace, Skyfall, Fortitude, Last Stand (Paladin oath from level 5), with leftover JP into active ranks. **Wins:** a fight of N hero hits costs ceil(N / OPENINGS) blows taken (OPENINGS = hits a good player lands per blow he eats: boss 10, elite 4), and the hero must survive them with the full flask (Healing Palm, all charges). Asserts: [0] each fight's `enemy_level` = hero level there; [1] ordinary, SKILLS: H 5–6, N 4–6; [2] boss, SKILLS: H 3–4, N 34–46; [3] from the oath (level 5) on, SKILLS wins every elite and boss fight and STRENGTH loses. Before the oath both builds hold ≤ 4 JP and no active skill, so the road's lone elite (level 2) must be won by either. [4] A boss's heaviest move never kills a full-HP hero in one hit. [5] each 10 Strength adds less Phys. Atk. |
| D655 | ROUTINE CALL | **A level is worth less; Strength has diminishing returns** (D642). `xp_curve.json` gets `hp_per_level` **10** (was 20) and `damage_per_level` **2** (was 5), which used to be hardcoded in `XPManager.stat_bonuses`. `attributes.json` Strength: `"diminishing": {"step": 10, "factor": 0.5}`: points 1–10 give +1 Phys. Atk. each, 11–20 +0.5, 21–30 +0.25, and so on (`AttributeManager.effective_points`). The skills screen's "+1 gives" preview shows the next point's real gain. At level 12 a Strength-only hero gets +19 from 55 points (was +55). |
| D656 | ROUTINE CALL | **Enemies have the level of their fight** (D642). `RoomEnemySpawner.enemy_level` is the hero's level when he reaches that fight: Desert Road lone fights and Dunes 2, Mesa and Caravan 3, City Gates 4, Laboratory Upper / Middle / Lower 8 / 9 / 10. Fights with no setting are level 1. `enemy_variety.json` `levels.health[level − 1]` and `levels.damage[level − 1]` multiply HP and damage, on top of size and elite. XP does not grow, so D297 holds. The tables follow the SKILLS hero: HP 1.0, 1.1, 1.2, 1.35, 1.9 … 2.6 (L8), 2.75, 2.9 (L10); damage 1.0, 1.2, 1.4, 1.6, 2.2 … 3.9 (L8), 4.3, 4.6 (L10). Damage jumps after level 4 because of the City gear. New level-1 base stats (HP / damage): bandit 190 / 24, jackal 165 / 23, shield-bearer 200 / 26, scorpion 215 / 28, archer 150 / 24. The vulture keeps D639's "the jackal's stats", 165 / 23, and the bat keeps D640's "half the jackal", rounded to 83 / 12 (none placed). This amends D297's "fixed enemy stats" and the D616/D639 numbers. |
| D657 | ROUTINE CALL | **Bosses for D642.** Brass Collector (met at level 5): damage 36 → **120**, HP 1400 → **3900**, pause between moves 1.8 → **1.3** s. Fire Djinn (met at level 12): damage 30 → **185**, HP 1100 → **6000**, pause 1.5 → **1.1** s. Moves, patterns, wind-ups and tells are unchanged (D574, D577). His heaviest moves (slam ×1.5, pillar ×1.6) take 2–3 hits to kill. |
| D658 | ROUTINE CALL | **Skills are the damage** (D642: «гра має заставляти героя качати вміння»). The eight non-ultimate damaging actives get ×1.5 on `damage` and on `damage_scaling.phys`: Fire Strike 30 / 1.95, Electric Strike 38 / 1.8, Radiant Smite 36 / 2.1, Skyfall Blessing 42 / 2.4, Searing Hex 27 / 1.95, Withering Grasp 51 / 2.7, Balanced Strike 39 / 2.1, Dervish Whirl 45 / 2.7. Burns, SP costs and ultimates are unchanged. |
| D659 | ROUTINE CALL | **Enemies press harder, tells as before** (D642, D573). `attack_cooldown` goes back to the pre-D494 tempo (bandit 1.5, jackal 1.0, scorpion 2.0, archer 2.2 s; shield-bearer 2.5 → 1.7, vulture and bat 1.5 → 1.0). This reverses D494's ×1.5. Recovery after a series is about ×0.75 (bandit 0.45, jackal 0.35, scorpion 0.7, shield 0.6, archer 0.3, vulture 0.35, bat 0.25). The attack token allows **3** enemies to wind up at once (was 2, D576), from `enemy_variety.json` `pressure.max_attackers` (`EnemyLogic.max_attackers()`). Wind-ups, `TELL_LEAD` and the parry window are untouched, so every blow is still telegraphed. |

## The measured table

H = enemy hits that kill the hero (H+F with the full flask), N = hero hits that kill it, medium size, no block or dodge.

**Before** (`origin/feature/backlog`, the first meeting of each kind):

| enemy | lvl | build | hero HP | hit | H | H+F | enemy HP | N | wins |
|---|---|---|---|---|---|---|---|---|---|
| bandit | 1 | either | 120 | 20 | 7 | 7 | 100 | 3 | yes |
| jackal | 1 | either | 120 | 14 | 10 | 10 | 60 | 2 | yes |
| shield-bearer | 2 | STR / SKL | 140 / 158 | 22 | 7 / 8 | 15 / 16 | 110 | 3 / 3 | yes |
| vulture | 2 | STR / SKL | 140 / 158 | 14 | 11 / 13 | 23 / 24 | 60 | 2 / 2 | yes |
| scorpion | 3 | STR / SKL | 160 / 186 | 28 | 7 / 8 | 13 / 14 | 200 | 3 / 4 | yes |
| archer | 3 | STR / SKL | 160 / 186 | 17 | 11 / 13 | 21 / 24 | 60 | 1 / 2 | yes |
| Brass Collector | 5 | STR / SKL | 244 / 286 | 36 | 10 / 11 | 15 / 17 | 1400 | 15 / 11 | yes / yes |
| elite bandit | 8 | STR / SKL | 304 / 370 | 30 | 14 / 21 | 20 / 31 | 250 | 3 / 2 | yes / yes |
| elite scorpion | 8 | STR / SKL | 304 / 370 | 42 | 10 / 15 | 15 / 22 | 500 | 4 / 3 | yes / yes |
| Fire Djinn | 12 | STR / SKL | 384 / 482 | 30 | 17 / 31 | 24 / 44 | 1100 | 7 / 5 | yes / yes |

Sapega's report holds: a Strength-only hero took 7–17 hits to die and killed the djinn in 7 swings. `RESULT: 14 FAIL` against D642.

**After:**

From the final `verify_difficulty` run (`RESULT: ALL PASS`). "Lx" is the fight's `enemy_level`, "lvl" is the hero's level there, and "hit → got" is the raw hit and what the hero takes.

| enemy | lvl | build | hero HP | hit | got | H | H+F | enemy HP | N | wins |
|---|---|---|---|---|---|---|---|---|---|---|
| bandit L1 | 1 | STRENGTH | 120 | 24 | 22 | 6 | 6 | 190 | 5 | yes |
| bandit L1 | 1 | SKILLS | 120 | 24 | 22 | 6 | 6 | 190 | 5 | yes |
| jackal L1 | 1 | STRENGTH | 120 | 23 | 21 | 6 | 6 | 165 | 4 | yes |
| jackal L1 | 1 | SKILLS | 120 | 23 | 21 | 6 | 6 | 165 | 4 | yes |
| shield-bearer L2 | 2 | STRENGTH | 130 | 31 | 28 | 5 | 10 | 220 | 5 | yes |
| shield-bearer L2 | 2 | SKILLS | 148 | 31 | 28 | 6 | 11 | 220 | 5 | yes |
| vulture L2 | 2 | STRENGTH | 130 | 28 | 25 | 6 | 12 | 182 | 4 | yes |
| vulture L2 | 2 | SKILLS | 148 | 28 | 25 | 6 | 13 | 182 | 4 | yes |
| elite bandit L2 | 2 | STRENGTH | 130 | 43 | 39 | 4 | 8 | 523 | 10 | yes |
| elite bandit L2 | 2 | SKILLS | 148 | 43 | 39 | 4 | 8 | 523 | 11 | yes |
| bandit L2 | 2 | STRENGTH | 130 | 29 | 26 | 5 | 11 | 209 | 5 | yes |
| bandit L2 | 2 | SKILLS | 148 | 29 | 26 | 6 | 12 | 209 | 5 | yes |
| jackal L2 | 2 | STRENGTH | 130 | 28 | 25 | 6 | 12 | 182 | 4 | yes |
| jackal L2 | 2 | SKILLS | 148 | 28 | 25 | 6 | 13 | 182 | 4 | yes |
| scorpion L3 | 3 | STRENGTH | 140 | 39 | 35 | 4 | 9 | 258 | 5 | yes |
| scorpion L3 | 3 | SKILLS | 166 | 39 | 35 | 5 | 10 | 258 | 5 | yes |
| jackal L3 | 3 | STRENGTH | 140 | 32 | 29 | 5 | 10 | 198 | 4 | yes |
| jackal L3 | 3 | SKILLS | 166 | 32 | 29 | 6 | 11 | 198 | 4 | yes |
| shield-bearer L3 | 3 | STRENGTH | 140 | 36 | 33 | 5 | 9 | 240 | 5 | yes |
| shield-bearer L3 | 3 | SKILLS | 166 | 36 | 33 | 6 | 10 | 240 | 5 | yes |
| archer L3 | 3 | STRENGTH | 140 | 34 | 31 | 5 | 10 | 180 | 3 | yes |
| archer L3 | 3 | SKILLS | 166 | 34 | 31 | 6 | 11 | 180 | 4 | yes |
| vulture L3 | 3 | STRENGTH | 140 | 32 | 29 | 5 | 10 | 198 | 4 | yes |
| vulture L3 | 3 | SKILLS | 166 | 32 | 29 | 6 | 11 | 198 | 4 | yes |
| bandit L4 | 4 | STRENGTH | 150 | 38 | 35 | 5 | 9 | 257 | 4 | yes |
| bandit L4 | 4 | SKILLS | 184 | 38 | 35 | 6 | 10 | 257 | 5 | yes |
| archer L4 | 4 | STRENGTH | 150 | 38 | 35 | 5 | 9 | 203 | 4 | yes |
| archer L4 | 4 | SKILLS | 184 | 38 | 35 | 6 | 10 | 203 | 4 | yes |
| Brass Collector | 5 | STRENGTH | 204 | 120 | 91 | 3 | 4 | 3900 | 51 | no |
| Brass Collector | 5 | SKILLS | 246 | 120 | 73 | 4 | 6 | 3900 | 38 | yes |
| bandit L8 | 8 | STRENGTH | 234 | 94 | 71 | 4 | 6 | 494 | 6 | yes |
| bandit L8 | 8 | SKILLS | 300 | 94 | 57 | 6 | 9 | 494 | 5 | yes |
| elite bandit L8 | 8 | STRENGTH | 234 | 140 | 106 | 3 | 4 | 1235 | 15 | no |
| elite bandit L8 | 8 | SKILLS | 300 | 140 | 85 | 4 | 6 | 1235 | 11 | yes |
| jackal L8 | 8 | STRENGTH | 234 | 90 | 68 | 4 | 6 | 429 | 6 | yes |
| jackal L8 | 8 | SKILLS | 300 | 90 | 55 | 6 | 9 | 429 | 4 | yes |
| elite jackal L8 | 8 | STRENGTH | 234 | 135 | 102 | 3 | 4 | 1073 | 13 | no |
| elite jackal L8 | 8 | SKILLS | 300 | 135 | 82 | 4 | 6 | 1073 | 10 | yes |
| bandit L9 | 9 | STRENGTH | 244 | 103 | 78 | 4 | 6 | 523 | 6 | yes |
| bandit L9 | 9 | SKILLS | 318 | 103 | 57 | 6 | 9 | 523 | 5 | yes |
| elite bandit L9 | 9 | STRENGTH | 244 | 155 | 117 | 3 | 4 | 1306 | 15 | no |
| elite bandit L9 | 9 | SKILLS | 318 | 155 | 86 | 4 | 6 | 1306 | 11 | yes |
| jackal L9 | 9 | STRENGTH | 244 | 99 | 75 | 4 | 6 | 454 | 6 | yes |
| jackal L9 | 9 | SKILLS | 318 | 99 | 55 | 6 | 9 | 454 | 4 | yes |
| elite jackal L9 | 9 | STRENGTH | 244 | 148 | 112 | 3 | 4 | 1134 | 13 | no |
| elite jackal L9 | 9 | SKILLS | 318 | 148 | 83 | 4 | 6 | 1134 | 11 | yes |
| scorpion L9 | 9 | STRENGTH | 244 | 120 | 91 | 3 | 5 | 591 | 7 | yes |
| scorpion L9 | 9 | SKILLS | 318 | 120 | 67 | 5 | 8 | 591 | 6 | yes |
| elite scorpion L9 | 9 | STRENGTH | 244 | 181 | 137 | 2 | 3 | 1478 | 17 | no |
| elite scorpion L9 | 9 | SKILLS | 318 | 181 | 101 | 4 | 5 | 1478 | 13 | yes |
| scorpion L10 | 10 | STRENGTH | 254 | 129 | 98 | 3 | 5 | 624 | 7 | yes |
| scorpion L10 | 10 | SKILLS | 336 | 129 | 72 | 5 | 8 | 624 | 6 | yes |
| elite scorpion L10 | 10 | STRENGTH | 254 | 193 | 146 | 2 | 3 | 1559 | 17 | no |
| elite scorpion L10 | 10 | SKILLS | 336 | 193 | 108 | 4 | 6 | 1559 | 13 | yes |
| shield-bearer L10 | 10 | STRENGTH | 254 | 120 | 91 | 3 | 5 | 580 | 7 | yes |
| shield-bearer L10 | 10 | SKILLS | 336 | 120 | 67 | 6 | 9 | 580 | 5 | yes |
| elite shield-bearer L10 | 10 | STRENGTH | 254 | 179 | 136 | 2 | 3 | 1450 | 16 | no |
| elite shield-bearer L10 | 10 | SKILLS | 336 | 179 | 100 | 4 | 6 | 1450 | 12 | yes |
| jackal L10 | 10 | STRENGTH | 254 | 106 | 80 | 4 | 6 | 479 | 6 | yes |
| jackal L10 | 10 | SKILLS | 336 | 106 | 59 | 6 | 10 | 479 | 4 | yes |
| elite jackal L10 | 10 | STRENGTH | 254 | 159 | 120 | 3 | 4 | 1196 | 13 | no |
| elite jackal L10 | 10 | SKILLS | 336 | 159 | 89 | 4 | 7 | 1196 | 11 | yes |
| Fire Djinn | 12 | STRENGTH | 274 | 185 | 140 | 2 | 4 | 6000 | 61 | no |
| Fire Djinn | 12 | SKILLS | 372 | 185 | 103 | 4 | 6 | 6000 | 40 | yes |
| (before the oath both builds hold ≤ 4 JP and no | active | skill, | so | the | road's | lone | elite | must | to | either) |

What the table shows:
- **Ordinary enemies, SKILLS hero:** 5–6 hits kill him and 4–6 of his hits kill them, at every fight level. The STRENGTH hero dies in 3–6 hits and needs 3–7.
- **Elites from level 8:** SKILLS needs 10–13 hits and survives 4–6 blows with the flask. STRENGTH needs 13–17 and survives 2–3, so he loses.
- **Bosses:** Brass Collector takes 38 hits (SKILLS) against 51 (STRENGTH), and the djinn 40 against 61. Both bosses kill the SKILLS hero in 4 hits and the STRENGTH hero in 2–3.


## Files

- `SampleProject/UI/verify_difficulty.gd` — new, the simulation (D654).
- `Resources/Data/xp_curve.json` + `Scripts/Managers/XPManager.gd` — `hp_per_level` / `damage_per_level` moved to data (D655).
- `Resources/Data/attributes.json` + `Scripts/Managers/Gameplay/AttributeManager.gd` — `diminishing`, `effective_points()`, and `preview()` now gives the marginal gain (D655).
- `Resources/Data/enemy_variety.json` — `levels` tables and `pressure.max_attackers` (D656, D659).
- `Scripts/Gameplay/EnemyVariety.gd` (`level()`), `DefaultEnemy.gd` (`level` in `_apply_variety`), `RoomEnemySpawner.gd` (`enemy_level`), `Components/EnemyLogic.gd` (`max_attackers()` replaces `MAX_ATTACKERS`).
- `Maps/DesertRoad.tscn`, `CityGates.tscn`, `Laboratory.tscn` — `enemy_level` on 10 fights.
- `Resources/Enemies/enemy_stats_*.tres` — HP, damage, cooldown, recovery (D656, D659).
- `Scenes/Characters/Bosses/brass_collector.tscn`, `fire_djinn.tscn` — boss numbers (D657).
- `Resources/Data/skills.json` — 8 actives ×1.5 (D658).
- Tests whose pinned numbers or setups followed the old difficulty:
  - `verify_combat_enemies` [1]: the D642 tempo. [8]: the token test spawns `max_attackers() + 1` bandits.
  - `verify_combat_stats` [4]: the hero gets 9999 HP, since four D642 series killed the level-1 hero and the Game Over pause hung the test. The jackal tempo is now 1.0 s.
  - `verify_combat_flow` [2]: 9999 HP for the same reason. The hero died in [2], and the paused tree failed "dead enemy is hidden".
  - `verify_archer` [0]: HP read from the stats instead of 60.
  - `verify_flying_enemies` [1]: half the jackal is rounded.

## Tests

- `verify_difficulty`: `RESULT: ALL PASS` (before the retune: `RESULT: 14 FAIL`).
- Touched while working, all `RESULT: ALL PASS`: `verify_combat_enemies`, `verify_combat_stats`, `verify_combat_flow`, `verify_bosses`, `verify_archer`, `verify_flying_enemies`.
- `verify_onboarding` passes, so the lessons stay winnable (D-28c: `min_health` keeps the hero alive).
- Full suite, `Scripts/Tools/run_verify.sh`: `SUITE: ALL PASS` (112 PASS). The first full run had 3 FAIL (archer, combat_flow, flying_enemies), all fixed above.
