---
type: report
tags: [cloud, routine, enemies, placement, playtest]
---

# Cloud report — fewer-road-enemies (2026-10-27)

**Summary**
- Done: D817. Every group fight on the Desert Road now has at most three enemies: a bandit and a jackal, or two bandits and a jackal. Lone fights and the lone elites stay lone. Each enemy's numbers (HP, damage, level) are unchanged.
- **The XP curve would have broken.** I did not add enemies. Instead, each group fight now pays a `win_xp` bonus. Without it, the road gives 424 XP instead of 616. The hero would reach the City at level 4 instead of 5, and the Mesa would start at hero level 2 against its enemy_level 3. With `win_xp`, every route level is the same as before: 646 XP after the road, level 5 at the City, and the Laboratory ends at level 16. This is my call (D819 below). If Sapega would rather have a lower curve, delete the four `win_xp` lines.
- D-ID text: **D819** (below). B rows fixed: none.
- Full suite: `SUITE: 1 FAIL in 13 min 9 s, J=4`. The one failure is `verify_difficulty` (6 FAIL). The same 6 checks fail on `origin/feature/backlog` without this change; they are all in the Laboratory or bosses at L8+.

## The groups (DesertRoad.tscn)
| Fight | Was | Now | win_xp |
|---|---|---|---|
| EnemySpawner (story, L1) | bandit, jackal, bandit, jackal (110 XP) | bandit, jackal, bandit: 2 + 1 (85) | 25 |
| Fight_Dunes (L2) | bandit, jackal, pack leader (80) | bandit, then the pack leader alone (wave_size 2 → 1): 1 + 1 (55) | 25 |
| Fight_Mesa (L3) | scorpion, jackal, shield, archer (150) | shield-bearer + archer (wave 1, D617's pair), then a jackal: 2 + 1 (80) | 70 |
| Fight_Caravan (L3, bandit_key) | armoured scorpion, jackal, shield, scorpion, vulture (202) | armoured scorpion, bandit (SP3 jackal → bandit), shield-bearer: 2 + 1 (130) | 72 |
| LoneShield, LoneVulture, LoneElite (brute), OldVulture | lone | unchanged | 0 |

The spawn_ids are kept, so saves stay valid. A removed point's id in an old mid-fight save is dropped the next time that fight starts, because `spawn_all_enemies` writes back only the points that still exist. The big slots are unchanged (13), and D705/D710's first meetings are unchanged.

## D-ID text for the orchestrator
**D819 | ROUTINE CALL** | **How D817 is built** (`cloud/fewer-road-enemies`). In a road group, a "bandit" is any of the bandit gang (bandit, shield-bearer, archer, and their big kinds). The "jackal" is the group's one beast: the jackal, the pack leader, or the Caravan's armoured scorpion, which stays as its first meeting (D705). The ordinary scorpions of the Mesa and the Caravan are gone from the road, and so is the Caravan's vulture (this amends D445; the road still has the lone vulture and the old vulture). Groups along the road: first fight 2 + 1, Dunes 1 + 1, Mesa 2 + 1, Caravan 2 + 1. The road's XP is kept with a new `RoomEnemySpawner.win_xp`. It is paid when the fight is won (all waves out, every enemy of the run dead), once per run, again after a respawn (D492), and only for the XP its cut enemies used to give: 25 / 25 / 70 / 72. So the D297 curve, every fight's enemy_level (D670) and verify_difficulty's route levels are unchanged. `verify_road_sections` [1b] enforces the shape on every group in the room and checks that a win pays win_xp.

## Code
- `Scripts/Gameplay/RoomEnemySpawner.gd`: `@export win_xp`, `_pay_win_xp()` (from `_on_enemy_died` and after the last wave).
- Tests updated: verify_xp_curve and verify_difficulty add win_xp. verify_road_sections has the new counts, [1b] and the XP check. verify_enemy_variety (Mesa/Dunes/Caravan compositions), verify_flying_enemies (no Caravan vulture), verify_combat_flow / verify_room_state / verify_desert_road (3 enemies in the first fight). For verify_combat_flow's [0b] drop, the enemy is now enemies[0]: dropping the last one (now the bandit at 1000) left the hero placed so that [2c]'s swing missed, every time. verify_masher has new labels only (manual; not run). capture_armoured_scorpion now compares against the Caravan bandit.

## Tests (RESULT lines)
- verify_scripts_compile, verify_xp_curve, verify_road_sections, verify_desert_road, verify_progression, verify_combat_flow, verify_enemy_variety, verify_flying_enemies, verify_room_state, verify_gates: ALL PASS.
- verify_xp_curve: DesertRoad 646 XP → level 4; City at 731 XP → level 5; Laboratory ends at 16; 20 after 2 farm rounds (the same as before).
- verify_difficulty: 6 FAIL, the same set as the base. The diff shows only meetings that disappeared (jackal L2, scorpion L3, vulture L3) and one new meeting (bandit L3). Failing on both:
      FAIL scorpion L9 at level 9: 4 hits kill the hero ([5, 6]), 6 hits kill it ([4, 6])
      FAIL elite bandit brute L8 at level 8, SKILLS: loses (11 hits needed, 3 blows taken, survives 2)
      FAIL elite tower shield guard L9 at level 9, SKILLS: loses (12 hits needed, 3 blows taken, survives 2)
      FAIL elite armoured scorpion L11 at level 11, SKILLS: loses (12 hits needed, 3 blows taken, survives 2)
      FAIL Mercenary [DRAFT] at level 12, SKILLS: loses (45 hits needed, 5 blows taken, survives 4)
      FAIL brute rows: ["elite bandit brute L2 at level 2 STRENGTH wins, HP 523, hit 66", "elite bandit brute L2 at level 2 SKILLS wins, HP 523, hit 66", "elite bandit brute L8 at level 8 STRENGTH loses, HP 1235, hit 215", "elite bandit brute L8 at level 8 SKILLS loses, HP 1235, hit 215"]
    RESULT: 6 FAIL
