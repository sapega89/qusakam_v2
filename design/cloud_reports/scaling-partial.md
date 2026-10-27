---
type: report
tags: [cloud, routines, combat, balance]
---

# scaling-partial — D840: partial scaling with zone offsets

- **Done:** `EnemyScaling.scaled_level(room, zone, hero, kind)` = room level + zone offset + kind offset + ⌊max(0, hero − room) × `HERO_LEAD_SHARE` 0.5⌋, capped at 20. Zones live in `enemy_variety.json` → `scaling.zone_offsets` (by room scene name): **Laboratory +1, Bandit Camp +1**, every other room 0. Bosses have no zone (their authored floor is their edge). Everything else that enemy-scaling built is unchanged. Godot ran in this session, so everything below was measured.
- **D-ID text (D840 "as built", replaces enemy-scaling's):** see §1. **B rows fixed:** none.
- **Tests:** `verify_enemy_scaling` ALL PASS (rewritten to the partial rule, plus [7] zone; also fixes enemy-scaling's own [6] failure). `verify_xp_curve`, `verify_progression`, `verify_bosses`, `verify_combat_enemies`, `verify_scripts_compile`, `verify_enemy_variety` ALL PASS.
- **verify_difficulty: 14 FAIL.** It was 5 before D840 and 11 on `cloud/enemy-scaling`. No assertion was loosened. The new reds come from the elite +1 (already in enemy-scaling) and the zone +1 (3 rows). §3 has every row.
- **Full suite:** SUITE_LINE
- **Open for the orchestrator:** D840's offsets (elite +1, boss +2, zones +1) collide with D642's bands in `verify_difficulty`. Either retune the elite/boss numbers or soften the offsets. That is a balance call, not a scaling bug (§4).

## 1. D-ID text

> **D840 as built** (`cloud/enemy-scaling` + `cloud/scaling-partial`). `Scripts/Gameplay/EnemyScaling.gd` (preloaded, no class_name) computes an enemy's level as **room level + zone offset + kind offset + ⌊max(0, hero level − room level) × 0.5⌋**, capped at `XPManager.MAX_LEVEL` (20). The 0.5 is the named constant `EnemyScaling.HERO_LEAD_SHARE`. Kind offsets are `enemy_variety.json` → `scaling.offsets`: **ordinary 0, elite +1, boss +2**. Zone offsets are `scaling.zone_offsets`, keyed by the room's scene name as in `locations.json`: **Laboratory +1** (the late zone Sapega named) and **Bandit Camp +1** (an optional side path with a hard group fight and the elite heavy archer, D582/D719). Every other room is 0. **The old ruins** are planned at +2 once they are built (world_structure_plan: an optional loop behind the bandit leader's key; no room exists yet). The room level of an ordinary enemy or an elite is its fight's `RoomEnemySpawner.enemy_level` (D670). `RoomEnemySpawner` sets `DefaultEnemy.zone_offset` from its room, and `DefaultEnemy.scaled_level` is set on every spawn, so a D492 respawn rescales. A **boss**'s room level is `scaling.boss_levels` (Brass Collector 5, Scorpicore 5, Fire Djinn 12, Mercenary 16), the level its numbers were made for. It has no zone offset, and HP and damage grow by `levels[scaled] / levels[floor]`. A hard zone is therefore hard on arrival and stays a step above the hero. An over-levelled hero gains on old areas at half speed and never trivialises them: a level-1 fight against a level-20 hero stands at 10, and a level-9 fight at 14. **XP does not follow the level** (D670), so the route levels up as `verify_xp_curve` expects. Consequence: the Mercenary now always stands at 18 or above (floor 16 + 2) instead of enemy-scaling's 16 at a level-12 hero.

## 2. Files

- `SampleProject/Scripts/Gameplay/EnemyScaling.gd`: `HERO_LEAD_SHARE`, the partial `scaled_level(room_level, zone_offset, hero_level, kind)`, and the new `zone_offset(room)`.
- `SampleProject/Resources/Data/enemy_variety.json`: `scaling._note` is rewritten to the partial rule, and `scaling.zone_offsets` is new.
- `SampleProject/Scripts/Gameplay/DefaultEnemy.gd`: `var zone_offset := 0` passes into `scaled_level`.
- `SampleProject/Scripts/Gameplay/RoomEnemySpawner.gd:212`: `enemy.zone_offset = EnemyScaling.zone_offset(<room scene name>)`, next to `enemy.level = enemy_level`.
- `SampleProject/Scripts/Gameplay/Characters/Bosses/BossEnemy.gd`: passes zone 0 to `scaled_level`.
- `SampleProject/UI/verify_enemy_scaling.gd`: [1] covers hero 1/5/10/20 × floors 1, 4 (+1), 9, 9 (+1), 19 (+1, the cap) × ordinary/elite/boss, plus the zone data and `HERO_LEAD_SHARE`. [2]–[4] use the hard-coded partial levels (bandit 1/3/5/10, brute 2/4/6/11, level-9 scorpion 9/9/9/14). [5] covers bosses at floor + 2 + half the lead. [6] is a respawn fix: the test reused `spawn_once` points after the meditation, so hero 10 got no enemies. It now re-arms them, as a room reload does. New [7]: a live Laboratory `Fight_Fly` spawns at zone +1, one step above the same fight with no zone. That check failed before the spawner fix ([0, 9, 0]).
- `SampleProject/UI/verify_difficulty.gd`: meetings carry `zone`, `_enemy` sets `zone_offset`, and [0c] checks the partial formula through `Scaling.HERO_LEAD_SHARE`. [1]–[5] are untouched.
- `SampleProject/UI/verify_enemy_variety.gd`: 5 checks (8 asserts) expected an elite at its fight's level. Under full scaling that held by accident (max(level, hero 1 + 1) = level for level ≥ 2). They now read `levels[scaled_level]` and assert `scaled_level == fight level + 1`, still exact equalities. The checks are the pack leader, the bandit brute, the armoured scorpion ×2, the old vulture ×2 and the tower shield guard ×2.
- The `.uid` files for `EnemyScaling.gd` and `verify_enemy_scaling.gd` are committed (enemy-scaling lacked them).

## 3. verify_difficulty, every row: before D840 / full (enemy-scaling) / partial (this)

Each cell: enemy level / hit / H (hits that kill the hero) / enemy HP / N (hero hits to kill) / wins. The pre-D840 Mercenary level shows its fight (12); its numbers were made for 16.

| Row | Build | pre-D840 e.lv / hit / H / e.HP / N / wins | full (enemy-scaling) | partial (this) |
|---|---|---|---|---|
| bandit L1 | STRENGTH | 1 / 24 / 6 / 190 / 5 / yes | 1 / 24 / 6 / 190 / 5 / yes | 1 / 24 / 6 / 190 / 5 / yes |
| bandit L1 | SKILLS | 1 / 24 / 6 / 190 / 5 / yes | 1 / 24 / 6 / 190 / 5 / yes | 1 / 24 / 6 / 190 / 5 / yes |
| jackal L1 | STRENGTH | 1 / 23 / 6 / 165 / 4 / yes | 1 / 23 / 6 / 165 / 4 / yes | 1 / 23 / 6 / 165 / 4 / yes |
| jackal L1 | SKILLS | 1 / 23 / 6 / 165 / 4 / yes | 1 / 23 / 6 / 165 / 4 / yes | 1 / 23 / 6 / 165 / 4 / yes |
| shield-bearer L2 | STRENGTH | 2 / 31 / 5 / 220 / 5 / yes | 2 / 31 / 5 / 220 / 5 / yes | 2 / 31 / 5 / 220 / 5 / yes |
| shield-bearer L2 | SKILLS | 2 / 31 / 6 / 220 / 5 / yes | 2 / 31 / 6 / 220 / 5 / yes | 2 / 31 / 6 / 220 / 5 / yes |
| vulture L2 | STRENGTH | 2 / 28 / 6 / 182 / 4 / yes | 2 / 28 / 6 / 182 / 4 / yes | 2 / 28 / 6 / 182 / 4 / yes |
| vulture L2 | SKILLS | 2 / 28 / 6 / 182 / 4 / yes | 2 / 28 / 6 / 182 / 4 / yes | 2 / 28 / 6 / 182 / 4 / yes |
| elite bandit brute L2 | STRENGTH | 2 / 66 / 3 / 523 / 10 / yes | 3 / 77 / 2 / 570 / 11 / yes | 3 / 77 / 2 / 570 / 11 / yes |
| elite bandit brute L2 | SKILLS | 2 / 66 / 3 / 523 / 11 / yes | 3 / 77 / 3 / 570 / 12 / yes | 3 / 77 / 3 / 570 / 12 / yes |
| bandit L2 | STRENGTH | 2 / 29 / 5 / 209 / 5 / yes | 2 / 29 / 5 / 209 / 5 / yes | 2 / 29 / 5 / 209 / 5 / yes |
| bandit L2 | SKILLS | 2 / 29 / 6 / 209 / 5 / yes | 2 / 29 / 6 / 209 / 5 / yes | 2 / 29 / 6 / 209 / 5 / yes |
| elite jackal pack leader L2 | STRENGTH | 2 / 63 / 3 / 454 / 9 / yes | 3 / 74 / 2 / 495 / 10 / yes | 3 / 74 / 2 / 495 / 10 / yes |
| elite jackal pack leader L2 | SKILLS | 2 / 63 / 3 / 454 / 10 / yes | 3 / 74 / 3 / 495 / 11 / yes | 3 / 74 / 3 / 495 / 11 / yes |
| shield-bearer L3 | STRENGTH | 3 / 36 / 5 / 240 / 5 / yes | 3 / 36 / 5 / 240 / 5 / yes | 3 / 36 / 5 / 240 / 5 / yes |
| shield-bearer L3 | SKILLS | 3 / 36 / 6 / 240 / 5 / yes | 3 / 36 / 6 / 240 / 5 / yes | 3 / 36 / 6 / 240 / 5 / yes |
| archer L3 | STRENGTH | 3 / 34 / 5 / 180 / 3 / yes | 3 / 34 / 5 / 180 / 3 / yes | 3 / 34 / 5 / 180 / 3 / yes |
| archer L3 | SKILLS | 3 / 34 / 6 / 180 / 4 / yes | 3 / 34 / 6 / 180 / 4 / yes | 3 / 34 / 6 / 180 / 4 / yes |
| jackal L3 | STRENGTH | 3 / 32 / 5 / 198 / 4 / yes | 3 / 32 / 5 / 198 / 4 / yes | 3 / 32 / 5 / 198 / 4 / yes |
| jackal L3 | SKILLS | 3 / 32 / 6 / 198 / 4 / yes | 3 / 32 / 6 / 198 / 4 / yes | 3 / 32 / 6 / 198 / 4 / yes |
| elite armoured scorpion L3 | STRENGTH | 3 / 90 / 2 / 645 / 11 / yes | 4 / 103 / 2 / 726 / 12 / yes | 4 / 103 / 2 / 726 / 12 / yes |
| elite armoured scorpion L3 | SKILLS | 3 / 90 / 3 / 645 / 12 / yes | 4 / 103 / 2 / 726 / 14 / no | 4 / 103 / 2 / 726 / 14 / no |
| bandit L3 | STRENGTH | 3 / 34 / 5 / 228 / 4 / yes | 3 / 34 / 5 / 228 / 4 / yes | 3 / 34 / 5 / 228 / 4 / yes |
| bandit L3 | SKILLS | 3 / 34 / 6 / 228 / 5 / yes | 3 / 34 / 6 / 228 / 5 / yes | 3 / 34 / 6 / 228 / 5 / yes |
| elite old vulture L4 | STRENGTH | 4 / 85 / 2 / 557 / 9 / yes | 5 / 116 / 2 / 784 / 12 / no | 5 / 116 / 2 / 784 / 12 / no |
| elite old vulture L4 | SKILLS | 4 / 85 / 3 / 557 / 9 / yes | 5 / 116 / 2 / 784 / 13 / no | 5 / 116 / 2 / 784 / 13 / no |
| bandit L4 | STRENGTH | 4 / 38 / 5 / 257 / 4 / yes | 4 / 38 / 5 / 257 / 4 / yes | 4 / 38 / 5 / 257 / 4 / yes |
| bandit L4 | SKILLS | 4 / 38 / 6 / 257 / 5 / yes | 4 / 38 / 6 / 257 / 5 / yes | 4 / 38 / 6 / 257 / 5 / yes |
| archer L4 | STRENGTH | 4 / 38 / 5 / 203 / 4 / yes | 4 / 38 / 5 / 203 / 4 / yes | 4 / 38 / 5 / 203 / 4 / yes |
| archer L4 | SKILLS | 4 / 38 / 6 / 203 / 4 / yes | 4 / 38 / 6 / 203 / 4 / yes | 4 / 38 / 6 / 203 / 4 / yes |
| Scorpicore Axe-Warrior | STRENGTH | 5 / 120 / 3 / 3900 / 51 / no | 7 / 185 / 2 / 4824 / 63 / no | 7 / 185 / 2 / 4824 / 63 / no |
| Scorpicore Axe-Warrior | SKILLS | 5 / 120 / 3 / 3900 / 27 / yes | 7 / 185 / 2 / 4824 / 34 / no | 7 / 185 / 2 / 4824 / 34 / no |
| elite Cthulhu fly L8 | STRENGTH | 8 / 206 / 2 / 1073 / 13 / no | 9 / 227 / 2 / 1134 / 14 / no | 10 / 243 / 2 / 1196 / 14 / no |
| elite Cthulhu fly L8 | SKILLS | 8 / 206 / 3 / 1073 / 8 / yes | 9 / 227 / 2 / 1134 / 8 / yes | 10 / 243 / 2 / 1196 / 8 / yes |
| elite bandit brute L8 | STRENGTH | 8 / 215 / 2 / 1235 / 15 / no | 9 / 237 / 2 / 1306 / 15 / no | 10 / 254 / 2 / 1378 / 16 / no |
| elite bandit brute L8 | SKILLS | 8 / 215 / 3 / 1235 / 8 / yes | 9 / 237 / 2 / 1306 / 8 / yes | 10 / 254 / 2 / 1378 / 9 / no |
| jackal L8 | STRENGTH | 8 / 90 / 4 / 429 / 6 / yes | 8 / 90 / 4 / 429 / 6 / yes | 9 / 99 / 4 / 454 / 6 / yes |
| jackal L8 | SKILLS | 8 / 90 / 5 / 429 / 4 / yes | 8 / 90 / 5 / 429 / 4 / yes | 9 / 99 / 5 / 454 / 4 / yes |
| elite tower shield guard L9 | STRENGTH | 9 / 257 / 2 / 1375 / 16 / no | 10 / 275 / 2 / 1450 / 17 / no | 11 / 293 / 2 / 1525 / 18 / no |
| elite tower shield guard L9 | SKILLS | 9 / 257 / 2 / 1375 / 8 / yes | 10 / 275 / 2 / 1450 / 9 / no | 11 / 293 / 2 / 1525 / 10 / no |
| elite cursed jackal L9 | STRENGTH | 9 / 227 / 2 / 1134 / 13 / no | 10 / 243 / 2 / 1196 / 14 / no | 11 / 259 / 2 / 1258 / 15 / no |
| elite cursed jackal L9 | SKILLS | 9 / 227 / 3 / 1134 / 7 / yes | 10 / 243 / 2 / 1196 / 7 / yes | 11 / 259 / 2 / 1258 / 7 / yes |
| bandit L9 | STRENGTH | 9 / 103 / 4 / 523 / 6 / yes | 9 / 103 / 4 / 523 / 6 / yes | 10 / 110 / 4 / 551 / 7 / yes |
| bandit L9 | SKILLS | 9 / 103 / 5 / 523 / 4 / yes | 9 / 103 / 5 / 523 / 4 / yes | 10 / 110 / 5 / 551 / 4 / yes |
| jackal L9 | STRENGTH | 9 / 99 / 4 / 454 / 6 / yes | 9 / 99 / 4 / 454 / 6 / yes | 10 / 106 / 4 / 479 / 6 / yes |
| jackal L9 | SKILLS | 9 / 99 / 5 / 454 / 4 / yes | 9 / 99 / 5 / 454 / 4 / yes | 10 / 106 / 5 / 479 / 4 / yes |
| scorpion L9 | STRENGTH | 9 / 120 / 3 / 591 / 7 / yes | 9 / 120 / 3 / 591 / 7 / yes | 10 / 129 / 3 / 624 / 7 / yes |
| scorpion L9 | SKILLS | 9 / 120 / 4 / 591 / 4 / yes | 9 / 120 / 4 / 591 / 4 / yes | 10 / 129 / 4 / 624 / 4 / yes |
| elite armoured scorpion L11 | STRENGTH | 11 / 316 / 2 / 1639 / 18 / no | 12 / 335 / 2 / 1720 / 19 / no | 13 / 354 / 2 / 1801 / 20 / no |
| elite armoured scorpion L11 | SKILLS | 11 / 316 / 2 / 1639 / 9 / no | 12 / 335 / 2 / 1720 / 9 / no | 13 / 354 / 2 / 1801 / 9 / no |
| shield-bearer L11 | STRENGTH | 11 / 127 / 3 / 610 / 7 / yes | 11 / 127 / 3 / 610 / 7 / yes | 12 / 135 / 3 / 640 / 7 / yes |
| shield-bearer L11 | SKILLS | 11 / 127 / 5 / 610 / 3 / yes | 11 / 127 / 5 / 610 / 3 / yes | 12 / 135 / 5 / 640 / 3 / yes |
| elite cursed jackal L11 | STRENGTH | 11 / 259 / 2 / 1258 / 14 / no | 12 / 275 / 2 / 1320 / 15 / no | 13 / 291 / 2 / 1382 / 15 / no |
| elite cursed jackal L11 | SKILLS | 11 / 259 / 3 / 1258 / 6 / yes | 12 / 275 / 2 / 1320 / 6 / yes | 13 / 291 / 2 / 1382 / 6 / yes |
| Mercenary [DRAFT] | STRENGTH | 12 / 180 / 3 / 6800 / 69 / no | 16 / 180 / 3 / 6800 / 69 / no | 18 / 197 / 2 / 7337 / 75 / no |
| Mercenary [DRAFT] | SKILLS | 12 / 180 / 4 / 6800 / 30 / yes | 16 / 180 / 4 / 6800 / 30 / yes | 18 / 197 / 3 / 7337 / 31 / yes |
| heavy archer (BanditCamp) L4 | STRENGTH | 4 / 88 / 2 / 506 / 8 / yes | 5 / 121 / 2 / 713 / 11 / no | 6 / 155 / 2 / 788 / 12 / no |
| heavy archer (BanditCamp) L4 | SKILLS | 4 / 88 / 3 / 506 / 9 / yes | 5 / 121 / 2 / 713 / 12 / yes | 6 / 155 / 2 / 788 / 13 / no |

FAILs, before D840 (5): scorpion L9 [1], shield-bearer L11 [1], Scorpicore [2] (H 3, N 27), Mercenary [2] (N 30), armoured scorpion L11 SKILLS [3].
Full (11): those, with Scorpicore at H 2 / N 34, plus armoured scorpion L3 SKILLS, old vulture L4 ×2, Scorpicore SKILLS loses, tower guard L9 SKILLS and heavy archer STRENGTH [3].
**Partial (14):** the same 11, the Mercenary [2] still fails on N only (31, was 30; H 3, was 4). New: **elite bandit brute L8 SKILLS loses** (Laboratory zone: L10, N 9 vs 2 blows), **heavy archer SKILLS loses** (Bandit Camp zone: L6), and [3d] **brute rows** (the same Laboratory brute).

## 4. The call left open

On the straight route (hero = fight level) the half-lead term is 0. Partial scaling therefore changes nothing on the route itself, and the route rows differ from enemy-scaling's only by the zone offsets. The 3 new reds are the zone +1 meeting [3] "SKILLS beats elites": a Laboratory elite now stands two above the hero, and the Bandit Camp's elite heavy archer stands at 6 against a level-4 hero. Two levers, both Sapega's call:
(a) keep the zones and lower those elites' numbers (`enemy_stats_bandit_brute.tres` / `enemy_stats_heavy_archer.tres`);
(b) zone +1 on ordinary enemies only, or set the zone values to 0. Setting the Laboratory and Bandit Camp to 0 in `zone_offsets` brings back exactly enemy-scaling's 11.
The other 11 reds predate this branch: 5 are from before D840 and 6 come from enemy-scaling's elite +1 and boss +2 (its report flagged the Scorpicore risk). As enemy-scaling suggested, the cleanest Scorpicore lever is a lower `base_damage` in `scorpicore_warrior.tscn`.

## 5. RESULT lines

- verify_enemy_scaling: ALL PASS (61 OK)
- verify_difficulty: 14 FAIL (enemy-scaling HEAD: 11; feature/backlog before D840: 5)
- verify_xp_curve, verify_progression, verify_bosses, verify_combat_enemies, verify_scripts_compile, verify_enemy_variety: ALL PASS
- Full suite: SUITE_LINE
