---
type: report
branch: cloud/elite-reach
base: feature/backlog @ 85646a41
date: 2026-10-28
---

# cloud/elite-reach: B203, a grown elite starts a strike out of reach

- **Done:** B203 fixed at the root (`DefaultEnemy._grow`), with a test for every live melee elite at its grown scale. Nothing left open.
- **B rows fixed:** B203.
- **D-ID (ROUTINE CALL, `cloud/elite-reach`, B203; D839/D859 as built):** a grown or shrunk enemy's `attack_range` changes by exactly as much as its strike's front (hitbox front + lunge) moved, not by the size factor: the hero's half-width inside it does not grow. A strike starts only where the grown hitbox reaches the hero, for every elite kind and any size (small ×0.8, elite ×1.5). This is the rule `TowerShieldGuard._drop_shield` already uses when the shield breaks.
- **Full suite:** `SUITE: 3 FAIL in 20 min 8 s, J=4`. None are from this branch: `verify_difficulty` (17 FAIL) and `verify_lab_boss` (2 FAIL, balance numbers) fail the same way on `origin/feature/backlog` 85646a41. `verify_camera_transitions` (1 FAIL) passes alone on both this branch and the base (a load flake).
- **For the orchestrator:** mark B203 fixed in [[BUGS]] and add the D-ID above to [[figma_decision_register]]. The two balance failures on the base are not filed as a B row by this routine. They belong to whoever last moved the D840 level numbers.

## Root cause

`DefaultEnemy._grow(factor)` scaled the body, hit and hurt areas and `lunge` by `factor`, then did `attack_range *= factor`.
`attack_range` is a distance between centres: the enemy's strike front plus up to the hero's half-width (12 px). Only the
first part grows. So the start distance grew by 12 × (factor − 1) more than the reach did.

The ×1.5 tower guard started a thrust at **72.0 px** while his grown hitbox reached **67.8 px** (hero half included).

How each kind was affected:
- **Ground melee:** `EnemyLogic.swing_fits` already gates the swing on the real reach. The wrong `attack_range` showed up as the guard stepping in to a spot he could not strike from (the guard was the only elite over the limit).
- **Bite flier:** for the fly, `FlyingLogic._in_reach` gates the bite on `attack_range` directly.

## Fix

`SampleProject/Scripts/Gameplay/DefaultEnemy.gd:275,286`: `_grow` reads `strike_reach()` before scaling and adds the change
after scaling (`attack_range += strike_reach() - reach`). There are no new constants and no branches.

Values before → after (×1.5 elites, fight level 1):

| kind | before | after | grown reach (+hero half) |
|---|---|---|---|
| tower_shield_guard | 72.0 ✗ | 66.6 | 67.8 |
| bandit_brute | 86.2 | 83.4 | 89.6 |
| armoured_scorpion | 117.0 | 114.2 | 120.8 |
| jackal_pack_leader | 156.0 | 169.6 | 208.9 |
| jackal_cursed | 150.0 | 162.5 | 199.5 |
| fly (bite) | 112.5 | 121.9 | 152.6 |
| old_vulture (dive) | 240.0 | 184.0 | the dive flies to the hero; still above ORBIT_X 110, so it dives anywhere on its orbit |

Small ordinaries (×0.8): melee 33.1, tank 37.9, fast 100.4. All are still past body contact.

## Tests

`SampleProject/UI/verify_enemy_variety.gd`:
- **[10] (new, `_grown_reach`, line 962):** covers every live elite except the heavy archer (it shoots), each at its grown ×1.5. It checks that:
  - the logic gets the grown `attack_range`;
  - `attack_range` ≤ the grown `strike_reach()` + the hero's real half-width (read from the hero's body), and, on the ground, > body contact;
  - just past the grown reach `swing_fits` refuses;
  - a strike started with the hero at `attack_range` lands.

  Before the fix: `FAIL tower_shield_guard: attack_range 72.0 starts a strike its grown hitbox reaches (67.8; body contact 62.4)`.
- **[1]:** the small-size check pinned the old `attack_range == stats × 0.8`, which was the bug's rule. It now checks the exact new rule: `attack_range − strike_reach()` is the same as the medium's, and the range is past body contact. This is stricter, not looser.
- **[8]:** the shield-burst watcher on `game.map.child_entered_tree` is now disconnected when its guard is freed. It used to fire on later spawns with a freed capture (`Lambda capture … was freed`).

Results (Godot 4.6.2 Linux, headless):
- `verify_hit_areas` PASS
- `verify_combat_enemies` PASS
- `verify_enemy_variety` PASS (ALL PASS)
- `verify_enemy_stamina` PASS
- `verify_scripts_compile` PASS
- Full suite: see the summary.
