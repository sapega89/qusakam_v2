---
type: report
tags: [cloud, routines, combat, balance]
---

# enemy-scaling — D840: enemies and bosses scale with the hero's level

**⚠ UNTESTED: running the downloaded Godot 4.6.2 binary was refused by the permission classifier, so no test was run.** Nothing below was measured: not the new test, not `verify_difficulty`, not the full suite.
- **Done:** one formula, `EnemyScaling.scaled_level(floor, hero, kind)` = max(floor, hero + offset), capped at 20. Offsets: ordinary 0, elite +1, boss +2. Every DefaultEnemy and every BossEnemy runs it when it spawns, so a D492 respawn rescales. HP and damage come from the existing `levels` tables; XP does not scale (see §2). There are no per-room hacks and `Maps/` is untouched.
- **Bosses:** each one's floor is the level its numbers were made for (`scaling.boss_levels`: Brass Collector 5, Scorpicore 5, Fire Djinn 12, Mercenary 16). From that floor it grows by the ratio of the `levels` tables. Patterns and moves are untouched.
- **verify_difficulty:** it now judges every row at the scaled level (new column `e.lv`, new check [0c]). No assertion was loosened. The before/after rows below are **computed from the tables, not run**.
- **D-ID text (for the orchestrator, D840 "as built"):** see §1. **B rows fixed:** none.
- **Not done:** the measured before/after table, the full suite, and `.uid` files for the two new scripts (Godot writes them on first import).
- **Full suite:** not run (Godot refused).
- **For the merge:** HANDOFF says to change the formula to the partial one (room + zone offset + ⌊(hero − room) × 0.5⌋). That means editing only `EnemyScaling.scaled_level`, the `scaling` block in `enemy_variety.json`, the `expect` table in `verify_enemy_scaling` [1] and the [0c] formula in `verify_difficulty`.

## 1. D-ID text

> **D840 as built** (`cloud/enemy-scaling`). `Scripts/Gameplay/EnemyScaling.gd` (preloaded, no class_name) computes an enemy's level as **max(floor, hero level + offset)**, capped at `XPManager.MAX_LEVEL` (20). The offsets are in `enemy_variety.json` → `scaling.offsets`: **ordinary 0, elite +1, boss +2**. For an ordinary enemy or an elite, the floor is its fight's `RoomEnemySpawner.enemy_level` (D670). It stays in `DefaultEnemy.level`, and the scaled level is the new `DefaultEnemy.scaled_level`. `DefaultEnemy._apply_variety` sets `scaled_level` from the hero's level when the enemy spawns, and HP and damage then follow `levels.health / levels.damage[scaled_level − 1]` as before. A D492 respawn is a new instance, so it takes the hero's level at that moment. Saved mid-fight HP is restored as an absolute number. **Bosses** (`BossEnemy._apply_variety`): the floor is `scaling.boss_levels[enemy_type]`, the level the boss's numbers were made for: Brass Collector 5 (D671), Scorpicore 5 (D678), Fire Djinn 12 (D671), Mercenary 16 (D661). HP and damage are multiplied by `levels[scaled] / levels[floor]`. Moves, pattern, wind-ups and tells are unchanged. **XP does not follow the level**: since D670 the tables carry no XP factor, so kill XP and `win_xp` stay as they were and the route levels up exactly as `verify_xp_curve` expects. Respawned enemies give the same XP at any hero level. On the straight route (hero = fight level) ordinary enemies are unchanged, elites stand one level above and bosses two above their floor.

## 2. The XP choice

The prompt asks that "XP follows the level through the existing formulas". The existing formula has no level factor: `levels` has only `health` and `damage`, and D670 says "XP does not grow, so D297 holds". So XP is computed exactly as before, from `EnemyStats.xp_reward` × size × elite. In effect this is XP at the room level. The reason: if XP grew with the scaled level, an over-levelled hero farming D492 respawns would earn more per kill the higher he got. The D544 curve to 20 (straight Lab at 16, two corridor rounds to 20) would then compress, and `verify_xp_curve` would fail. Keeping XP flat means the scaling changes only how hard a fight is, never how fast the route levels up. `verify_enemy_scaling` [2]/[3] check that the XP is unchanged at hero levels 1, 5, 10 and 20.

## 3. Files

- `SampleProject/Scripts/Gameplay/EnemyScaling.gd`: new. `scaled_level`, `hero_level`, `boss_growth`, `boss_level`.
- `SampleProject/Resources/Data/enemy_variety.json`: new `scaling` block (`offsets`, `boss_levels`, `_note`).
- `SampleProject/Scripts/Gameplay/DefaultEnemy.gd`: `scaled_level` var. `_apply_variety` uses it instead of `level`.
- `SampleProject/Scripts/Gameplay/Characters/Bosses/BossEnemy.gd`: `_apply_variety` was `pass`; it now sets the floor, the scaled level and HP/damage growth.
- `RoomEnemySpawner.gd` is unchanged: it still sets `enemy.level = enemy_level`, which is now the floor. `EnemyLogic` (attack flow, `cloud/enemy-stamina`) is untouched.
- `SampleProject/UI/verify_enemy_scaling.gd`: new. [1] formula at hero 1/5/10/20 on floors 1 and 9. [2] ordinary bandit level/HP/damage/XP. [3] elite bandit brute. [4] the level-9 floor (scorpion). [5] all four bosses at hero 1/5/10/20 (level, HP, damage, XP, moves unchanged). [6] Fight_Dunes respawn after `Game.meditate()` at hero 1 and then 10.
- `SampleProject/UI/verify_difficulty.gd`: rows carry `scaled`/`floor`. The table prints `e.lv`. New [0c] checks every row's level against max(floor, hero + offset). The [1]–[5] assertions are unchanged.
- `SampleProject/UI/verify_enemy_variety.gd`: three checks spawned elites at a level-1 floor with a level-1 hero and expected bare ×2.5. An elite there now stands at level 2, so the checks multiply by `levels[scaled_level]` and assert `scaled_level == 2`. This is not a loosening: the HP/damage equalities stay exact. They are the Cthulhu fly, the heavy archer and the cursed jackal.

## 4. verify_difficulty, row by row (computed, not run)

On the straight route the sim builds the hero at the fight's level, so the floor equals the hero's level. Ordinary rows therefore cannot change. Elite rows gain one level and boss rows two over their floor. The multipliers come from `levels`:

| Row (red before) | Class | Level before → after | HP × | Damage × | Expected effect |
|---|---|---|---|---|---|
| scorpion L9 | ordinary | 9 → 9 | 1 | 1 | unchanged, stays red (not a scaling problem; Q114's "late enemies" half) |
| shield-bearer L11 | ordinary | 11 → 11 | 1 | 1 | unchanged, stays red (as above) |
| armoured scorpion L11 | elite | 11 → 12 | 1.049 | 1.061 | slightly harder; if it failed on SKILLS "loses", it gets slightly worse |
| Scorpicore L5 | boss | 5 → 7 | 1.237 (3900 → 4824) | 1.545 (120 → 185; slam 156 → 241) | **Q114:** 27–30 SKILLS hits → about 33–37 against the 34–46 band. **Risk:** 3–4 blows to kill the hero may drop to 2–3 (the table's L5–L7 damage jump is the City-gear step, D670) |
| Mercenary L12 | boss | floor 16 → 16 | 1 | 1 | unchanged: its numbers were made for level 16 (D661), above 12 + 2. Stays red if it was red |

Other rows: every elite row moves one level up. The steepest steps are L2→3 (HP ×1.09, damage ×1.17) and L4→5 (HP ×1.41, damage ×1.375, the City-gear step). Mid-Lab steps are about ×1.05 / ×1.10. Every [3] elite row (SKILLS wins, STRENGTH loses from the oath on) needs re-reading on the first real run. A road elite before the oath must still fall to the STRENGTH hero, and +1 makes that harder. No row became meaningless: at hero = floor the sim still tests the route as played. The new [0c] states the scaled situation, and `verify_enemy_scaling` covers the over-levelled hero.

**Before the merge, re-run `verify_difficulty`** (the `scaling-partial` and `hero-points-only` merges re-run it anyway). If Scorpicore's "taken" falls below 3, the cleanest lever is a lower `base_damage` in `scorpicore_warrior.tscn` (made for L7 instead of L5), not a different formula.

## 5. Tests to run (none were run)

`verify_enemy_scaling` (new), `verify_difficulty`, `verify_xp_curve`, `verify_progression`, `verify_bosses`, `verify_combat_enemies`, `verify_enemy_variety`, `verify_road_sections`, `verify_scripts_compile`, plus the boss tests that read live boss numbers: `verify_lab_boss` (Mercenary floor 16, hero ≤ 16 → unchanged) and `verify_mayor_boss` (hero at L5 → Scorpicore at L7; its checks read `boss.base_damage` live). Then the full suite once: `Scripts/Tools/run_verify.sh | grep -v '^PASS'`.
