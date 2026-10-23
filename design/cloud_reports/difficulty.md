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
- D-IDs: D643–D648 below. B rows fixed: none.
- Full suite: SUITE_LINE

## D-ID text (for the orchestrator)

| ID | Kind | Text |
|---|---|---|
| D643 | ROUTINE CALL | **The difficulty simulation** (D642; `cloud/difficulty`). `verify_difficulty.gd` walks the story route (Canyon → Village → Desert Road → City Gates → City → Mayor Hall → Lab cells → Laboratory → LabBoss). For each fight it takes the hero's level at the fight's start (XP from the spawn points' EnemyStats, as `verify_xp_curve`) and builds a real hero at that level with the route's gear: before the City the grandfather's copper sword and leather armour, from the City the shops' iron sword, iron armour and iron shield. It then spawns the real enemy scene (medium size, elite where the fight has `elite = always` or `elite_rolls`) or the boss scene. **H** is how many of the enemy's ordinary hits (for a boss, a combo swing) kill the hero through `Player.mitigated_damage`, with no block and no dodge (the evasion roll is calmed). **N** is how many hero actions kill it: the light combo via `PlayerCombat.hit_damage` with no crit, from behind (tank shell, shield), plus the best affordable active (`SkillManager.skill_damage` + burn) whenever SP allows. The fight starts at **0 SP**, and SP comes from hits (D504). Two builds: **STRENGTH** puts every attribute point in Strength and spends no JP. **SKILLS** puts 2 Strength / 2 Vitality / 1 Wisdom per level and learns in order Toughness, Shield Block, Weapon Training, Radiant Smite, Devotion, Fire Strike, Riposte Instinct, Aura of Resolve, Mending Hands, Sky's Grace, Skyfall, Fortitude, Last Stand (Paladin oath from level 5), with leftover JP into active ranks. **Wins:** a fight of N hero hits costs ceil(N / OPENINGS) blows taken (OPENINGS = hits a good player lands per blow he eats: boss 10, elite 4), and the hero must survive them with the full flask (Healing Palm, all charges). Asserts: [0] each fight's `enemy_level` = hero level there; [1] ordinary, SKILLS: H 5–6, N 4–6; [2] boss, SKILLS: H 3–4, N 34–46; [3] from the oath (level 5) on, SKILLS wins every elite and boss fight and STRENGTH loses. Before the oath both builds hold ≤ 4 JP and no active skill, so the road's lone elite (level 2) must be won by either. [4] A boss's heaviest move never kills a full-HP hero in one hit. [5] each 10 Strength adds less Phys. Atk. |
| D644 | ROUTINE CALL | **A level is worth less; Strength has diminishing returns** (D642). `xp_curve.json` gets `hp_per_level` **10** (was 20) and `damage_per_level` **2** (was 5), which used to be hardcoded in `XPManager.stat_bonuses`. `attributes.json` Strength: `"diminishing": {"step": 10, "factor": 0.5}`: points 1–10 give +1 Phys. Atk. each, 11–20 +0.5, 21–30 +0.25, and so on (`AttributeManager.effective_points`). The skills screen's "+1 gives" preview shows the next point's real gain. At level 12 a Strength-only hero gets +19 from 55 points (was +55). |
| D645 | ROUTINE CALL | **Enemies have the level of their fight** (D642). `RoomEnemySpawner.enemy_level` is the hero's level when he reaches that fight: Desert Road lone fights and Dunes 2, Mesa and Caravan 3, City Gates 4, Laboratory Upper / Middle / Lower 8 / 9 / 10. Fights with no setting are level 1. `enemy_variety.json` `levels.health[level − 1]` and `levels.damage[level − 1]` multiply HP and damage, on top of size and elite. XP does not grow, so D297 holds. The tables follow the SKILLS hero: HP 1.0, 1.1, 1.2, 1.35, 1.9 … 2.6 (L8), 2.75, 2.9 (L10); damage 1.0, 1.2, 1.4, 1.6, 2.2 … 3.9 (L8), 4.3, 4.6 (L10). Damage jumps after level 4 because of the City gear. New level-1 base stats (HP / damage): bandit 190 / 24, jackal 165 / 23, shield-bearer 200 / 26, scorpion 215 / 28, archer 150 / 24, vulture 140 / 24; bat unchanged (none placed). This amends D297's "fixed enemy stats" and the D616/D639 numbers. |
| D646 | ROUTINE CALL | **Bosses for D642.** Brass Collector (met at level 5): damage 36 → **120**, HP 1400 → **3900**, pause between moves 1.8 → **1.3** s. Fire Djinn (met at level 12): damage 30 → **185**, HP 1100 → **6000**, pause 1.5 → **1.1** s. Moves, patterns, wind-ups and tells are unchanged (D574, D577). His heaviest moves (slam ×1.5, pillar ×1.6) take 2–3 hits to kill. |
| D647 | ROUTINE CALL | **Skills are the damage** (D642: «гра має заставляти героя качати вміння»). The eight non-ultimate damaging actives get ×1.5 on `damage` and on `damage_scaling.phys`: Fire Strike 30 / 1.95, Electric Strike 38 / 1.8, Radiant Smite 36 / 2.1, Skyfall Blessing 42 / 2.4, Searing Hex 27 / 1.95, Withering Grasp 51 / 2.7, Balanced Strike 39 / 2.1, Dervish Whirl 45 / 2.7. Burns, SP costs and ultimates are unchanged. |
| D648 | ROUTINE CALL | **Enemies press harder, tells as before** (D642, D573). `attack_cooldown` goes back to the pre-D494 tempo (bandit 1.5, jackal 1.0, scorpion 2.0, archer 2.2 s; shield-bearer 2.5 → 1.7, vulture and bat 1.5 → 1.0). This reverses D494's ×1.5. Recovery after a series is about ×0.75 (bandit 0.45, jackal 0.35, scorpion 0.7, shield 0.6, archer 0.3, vulture 0.35, bat 0.25). The attack token allows **3** enemies to wind up at once (was 2, D576), from `enemy_variety.json` `pressure.max_attackers` (`EnemyLogic.max_attackers()`). Wind-ups, `TELL_LEAD` and the parry window are untouched, so every blow is still telegraphed. |

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

AFTER_TABLE

## Files

FILES

## Tests

TESTS
