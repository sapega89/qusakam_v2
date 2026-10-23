---
type: cloud-report
branch: cloud/big-mobs
date: 2026-10-23
tags: [cloud, combat, enemies]
---

# Cloud report: big-mobs (D652: a bigger enemy is its own kind)

**Summary.** Done: the scaled `large` size and the elite outline are gone. Elite is now a property of a kind in
`enemy_variety.json` `kinds`, and only elite kinds get D560's HP ×2.5 / damage ×1.5. A kind spawns only once its sheet
exists. Six planned big kinds plus the horror jackal are data slots with no art. The humanoid fly (its sheet exists, D654)
is the one elite that is live today. The 12 D582 places that wanted an elite or a large enemy are now `BigSlot_<Kind>_n`
points. Each spawns the ordinary kind until its big kind's art lands (list below). The cursed foam (D653) is a reusable
VFX in the hit-VFX layer. **Not done:** big-kind art, scenes, stats and bestiary names (art batch). D-IDs: **D681–D683**
(text below). B rows fixed: none. Full suite: 110 PASS, 3 FAIL (`verify_difficulty`, `verify_lab_boss`,
`verify_mayor_boss`: all three fail the same way on `origin/feature/backlog`, the boss numbers of D671 vs the mayor-boss branch)

## D-ID text (for the register; the next free numbers after D674, bugfix-1 runs beside, renumber as needed)

| D681 | ROUTINE CALL | **Big kinds and elites, as built** (D652; amends D614, D615; `cloud/big-mobs`). `enemy_variety.json` `sizes` keeps only small (×0.8 scale, HP ×0.7, damage ×0.8, speed ×1.15) and medium. `large`, `size_weights`, the elite roll (`chance` 1/8), `elite.scale` ×1.1 and the outline (`Shaders/elite_outline.gdshader`, deleted) are removed. A new `kinds` table gives each kind `sheet`, `elite` and its own size weights (`sizes`: ordinary kinds small 1 : medium 2, elite kinds medium only). `EnemyVariety.available(kind)` is "its sheet exists". `DefaultEnemy._apply_variety` reads `elite` from `kinds.<enemy_type>` and applies `elite` HP ×2.5, damage ×1.5, XP ×1 (no growth, no glow). `RoomEnemySpawner.elite_rolls` and `EnemySpawnPoint.elite` are gone. Bosses skip the variety (`BossEnemy._apply_variety`, their numbers are their own, D671). Elite kinds: `fly` (the humanoid Cthulhu fly, D651/D654, live), and, disabled until their sheet exists: `bandit_brute` (base `melee`), `jackal_pack_leader` (`fast`), `armoured_scorpion` (`tank`), `heavy_crossbowman` (`archer`), `tower_shield_guard` (`shield`), `old_vulture` (`vulture`), `jackal_cursed` (`fast`, the horror jackal D649). A big kind's entry also names its planned `scene` (`Scenes/Characters/Enemies/enemy_<kind>.tscn`) and the stats go in `Resources/Enemies/enemy_stats_<kind>.tres`. `verify_enemy_variety` fails if a kind has a sheet but not both of these. |
| D682 | ROUTINE CALL | **Big slots keep the D582 placements** (D652, D617). Where a placement asked for an elite (D617's pinned lone elite, the Laboratory's seeded elite rolls) or rolled a large enemy, the spawn point is now `BigSlot_<Kind>_<n>` with `big_kind = <kind>`. `EnemySpawnPoint.kind()` spawns the big kind once `available`, otherwise the ordinary `enemy_type` (the kind's `base`). The old `spawn_id` is pinned, so saves and seeded size rolls keep their keys. In the Laboratory a big jackal is the cursed one (D589), and on the road it is the pack leader. 12 slots: DesertRoad Fight_LoneElite 1 bandit brute, Dunes 1 bandit brute + 4 pack leader, Mesa 4 heavy crossbowman, Caravan 1 armoured scorpion; Laboratory Upper 1 + 3 bandit brute, 2 cursed jackal; Middle 2 + 4 cursed jackal; Lower 1 armoured scorpion, 3 cursed jackal. Until art lands, the road has no elite at all, and the Laboratory's only elite is the fly (Fight_Fly). `verify_difficulty` simulates every slot as "planned" (the base kind with the elite multipliers). All of them already meet D668 [3]: SKILLS wins everywhere, STRENGTH wins before the oath and loses from level 8 on. |
| D683 | ROUTINE CALL | **The cursed foam, as built** (D653). `Scenes/FX/CursedFoam.tscn` + `Scripts/FX/CursedFoam.gd`: a `CPUParticles2D` of 10 drops (lifetime 0.7 s, gravity 220, 2–3 px), a near-white core that turns blue and fades, in world space (`local_coords` off) so the drops trail behind a running beast. It is drawn in the hit-VFX layer (absolute z 250, as `HitImpact`). It is a child of the enemy's `Sprite2D`, so it grows with the size, and it sits at `kinds.<id>.foam` (frame pixels from the frame centre, facing right) and mirrors with `flip_h`. Any kind with a `foam` entry gets it (`DefaultEnemy._add_foam`); today only `jackal_cursed` has one, `[15, 16]`, set on the ordinary jackal's 96×72 frames. Move it when the `jackal_cursed` sheet lands. Normal blend, not additive: additive washed out on the desert sand. |

## Big slots: which big kinds the art batch needs first

| Big kind | Slots | Fights (level) |
|---|---|---|
| `jackal_cursed` (horror jackal, D649) | 4 | Laboratory Upper (8), Middle ×2 (9), Lower (10) |
| `bandit_brute` | 4 | DesertRoad Fight_LoneElite (2) and Dunes (2); Laboratory Upper ×2 (8) |
| `armoured_scorpion` | 2 | DesertRoad Caravan (3); Laboratory Lower (10) |
| `jackal_pack_leader` | 1 | DesertRoad Dunes (2) |
| `heavy_crossbowman` | 1 | DesertRoad Mesa (3) |
| `tower_shield_guard`, `old_vulture` | 0 | data slot only, not placed yet |

Suggested order: the horror jackal (the Laboratory's cursed beast and the foam's owner), then the bandit brute (the
road's first elite lesson, D582), then the armoured scorpion. When the kinds land, review the Laboratory Upper fight:
all three of its points are slots, so it would become three elites at once. D582 keeps big elite groups rare.

Slot point names (node → kept `spawn_id`):
- DesertRoad: `Fight_LoneElite/BigSlot_BanditBrute_1`, `Fight_Dunes/BigSlot_BanditBrute_1`,
  `Fight_Dunes/BigSlot_JackalPackLeader_4`, `Fight_Mesa/BigSlot_HeavyCrossbowman_4`,
  `Fight_Caravan/BigSlot_ArmouredScorpion_1`.
- Laboratory: `Fight_Upper/BigSlot_BanditBrute_1`, `Fight_Upper/BigSlot_JackalCursed_2`,
  `Fight_Upper/BigSlot_BanditBrute_3`, `Fight_Middle/BigSlot_JackalCursed_2`, `Fight_Middle/BigSlot_JackalCursed_4`,
  `Fight_Lower/BigSlot_ArmouredScorpion_1`, `Fight_Lower/BigSlot_JackalCursed_3`.
- Each `spawn_id` is the old `<Fight>_EnemySpawnPoint<n>`. `Scripts/Tools/build_laboratory.gd` `places` uses the new
  node names.

## What changed (files)

- `Resources/Data/enemy_variety.json`: `sizes` small/medium, `elite` multipliers only, new `kinds`.
- `Scripts/Gameplay/EnemyVariety.gd`: `kind`, `kind_ids`, `big_kinds`, `is_elite`, `available`,
  `roll_size(kind, key)`. `roll_elite` is removed.
- `Scripts/Gameplay/EnemySpawnPoint.gd`: `size` is auto/small/medium; `big_kind`, `kind()`, `scene_path()`. `elite` is
  removed.
- `Scripts/Gameplay/RoomEnemySpawner.gd`: no `elite_rolls` / `variant_elite`, and the size roll uses the kind's weights.
- `Scripts/Gameplay/DefaultEnemy.gd`: elite from the kind, `_add_foam`. The outline is removed.
- `Scripts/Gameplay/Characters/Bosses/BossEnemy.gd`: `_apply_variety` is a no-op.
- `Scenes/FX/CursedFoam.tscn`, `Scripts/FX/CursedFoam.gd`: new.
- `Maps/DesertRoad.tscn`, `Maps/Laboratory.tscn`: the `elite` / `elite_rolls` lines are removed, and 12 points are
  renamed to BigSlot.
- Tests: `verify_enemy_variety` (rewritten [1]–[3], new [5] foam), `verify_difficulty` (elite by kind, planned slots),
  `verify_flying_enemies` (the fly is elite by kind), `capture_enemy_variety` (sizes lineup + foam zoom).

## Results

- `verify_enemy_variety`: RESULT: ALL PASS.
- `verify_difficulty`: RESULT: 2 FAIL, both **pre-existing on the base branch** (the same 2 FAIL with this branch
  stashed): `Brass Collector at level 5: 9 hits kill the hero ([3, 4]), 27 hits kill it ([34, 46])` and
  `Brass Collector at level 5, STRENGTH: wins`. The boss here has HP 2600 and damage 48, not D671's 3900 / 120, so the
  D671 boss numbers have not reached `feature/backlog` yet (mayor-boss vs difficulty merge). Not this task's.
- Full suite (`Scripts/Tools/run_verify.sh`): `SUITE: 3 FAIL`, 110 PASS. The three FAILs were re-run on
  `origin/feature/backlog` with the same result, so they are **pre-existing**: `verify_difficulty` (2, above),
  `verify_lab_boss` (2: «balanced build: he dies in 2.6 of the mercenary's blows (406 HP; mace 129, club 206)»,
  «the mercenary takes 60 light hits (6800 HP, Phys. Atk. 100)»), `verify_mayor_boss` (1: «the boss (2600 HP) takes 50
  light hits of 53 (D642: about 40)»). They are boss balance after D642/D671 and outside this task.
- Shot: `design/shots/enemy_variety/shield_fight.png`. Panel 1 is small and medium bandit, jackal, and a jackal with
  `jackal_cursed` stats (elite numbers and the foam, on the ordinary jackal frames). Panel 2 zooms ×4 on its foam: glowing
  blue drops fall from the jaw. Panels 3–5 are the shield-bearer fight, unchanged.

## Notes

- Fight_LoneElite keeps its name and `state_key` for saves. For now it is a lone medium bandit (XP unchanged, 30).
- XP is unchanged everywhere (elite XP ×1, slots spawn the base kind).
- `design/enemy_variety_plan.md` still describes the D560 large size and the outline. Superseded by D681, and the
  orchestrator should mark it there.
