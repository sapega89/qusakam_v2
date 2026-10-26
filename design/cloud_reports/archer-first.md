---
type: report
tags: [cloud, routine, enemies, placement]
---

# Cloud report — archer-first (2026-10-26)

**Summary**
- Done: D719 is built in the data and the tests. The Mesa's archer point is the ordinary bandit archer again, at the fight's L3. The Bandit Camp's archer point is `BigSlot_HeavyArcher_4`, the heavy archer's first place. The camp's waves are reordered so the brute is in wave 1 and the heavy archer in wave 2, behind a shield-bearer. `verify_enemy_variety`, `verify_difficulty` and `capture_heavy_archer` are updated, and MASTER_PLAN has a D719 row (Q94 → ✅ D719).
- **Not done: no test was run.** This session's permission classifier refused to run the Godot binary (`curl` + `unzip` of 4.6.2 worked; running it for `--import` was denied as "Code from External"). So there are no RESULT lines, and nothing was run or captured. The integrator must run the tests listed below.
- **Order problem (asked for):** the camp can be entered before the Mesa fight. `BanditCampDoor` is at Desert Road x 2050 and has no gate. That is before `Fight_Dunes` (x 2170), `Fight_Mesa` (x 2700) and even `Fight_LoneElite` (x 4300). On that route the hero meets the heavy archer before any ordinary archer, and the brute in a group before its lone fight (Q96 is the same problem). The proposed order is below as **Q-new**.
- D-ID text: **D719** (below). B rows fixed: none.
- Full suite: not run (Godot blocked).
- `verify_masher` is not on this branch. It exists only on `cloud/hard-fights`, which is not merged into `rooms-look`. Its fight list has no Mesa or Camp entry, so the moved slots need no change there (see below).

## D-ID row (for `figma_decision_register.md`)

| D719 | OVERRIDE | **The first archer on the road is the ordinary one; the heavy archer first appears in the Bandit Camp** (Sapega 2026-10-26, Q94: «це дивно, елітний має потім з'явитись, може в лагері»; amends D682's Mesa slot and D706's placement; D582). **1.** `DesertRoad Fight_Mesa`: point 4 is `EnemySpawnPoint4` again, `enemy_type = archer`, `big_kind` none, at the fight's `enemy_level` 3. Its `spawn_id = "Fight_Mesa_EnemySpawnPoint4"` is kept for saves and seeded size rolls. Wave 2 is still a shield-bearer in front and an archer behind, the archer's lesson. The road has no other archer and no heavy archer. **2.** `BanditCamp Fight_Camp` (L4, waves of 3, D698): the old archer point (x 1120) is `BigSlot_HeavyArcher_4` (`enemy_type = archer`, `big_kind = heavy_archer`, `spawn_id = "Fight_Camp_EnemySpawnPoint4"`), the one heavy archer among the camp's bandits. The points are reordered so the two elites are never in one wave. Wave 1: jackal (700), bandit (820), `BigSlot_BanditBrute_1` (1040). Wave 2: shield-bearer (940), heavy archer (1120), bandit (760), so the heavy archer is behind a shield-bearer, as on the Mesa. The heavy archer is the archer's lesson with heavier numbers (D706), so it can be learned after the Mesa (D582). Big slots stay at 11: 3 on DesertRoad, 2 in the camp and 6 in the Laboratory. |

## Q-new (for `questions_for_sapega.md`): the camp opens before the Mesa

The Bandit Camp's door (Desert Road x 2050) comes before `Fight_Dunes` (2170), `Fight_Mesa` (2700) and `Fight_LoneElite` (4300). A hero who goes in at once meets, at L4 and in one fight, the brute (before its lone L2 fight) and the heavy archer (before any ordinary archer). The ordinary archer is already met only on the Mesa. Options:
- **(a) Swap the camp's two doors** (proposed default). The road's way in is `CampShortcutDoor` (x 4820, after the Mesa, the Caravan and the lone brute, the camp's L4 matching the end of the road). The dune-top door (x 2050) becomes the shortcut that is barred from inside (`gate_id`), opened after the camp is won. Then the order is: Mesa ordinary archer, then lone brute, then the camp with both elites. That fixes Q96 as well. It is a map/rooms change (the door `arrival`s, `gate_id` and `verify_rooms_batch1`), so it belongs to the map routine.
- (b) Keep the doors and lock the 2050 door until `enemies_mesa` is cleared (a story flag; fixes the archer order, not the brute's).
- (c) Leave it: the camp is a hard, optional detour at L4 for a player who goes early.

## Details

Changed files:
- `SampleProject/Maps/DesertRoad.tscn:363` — `BigSlot_HeavyArcher_4` → `EnemySpawnPoint4` (ordinary archer, spawn_id kept, same unique_id).
- `SampleProject/Maps/BanditCamp.tscn:87-122` — `EnemySpawnPoint4` → `BigSlot_HeavyArcher_4` (heavy_archer, `spawn_id = Fight_Camp_EnemySpawnPoint4`). `BigSlot_BanditBrute_1` moved to the third child so the waves are [fast, melee, brute] / [shield, heavy archer, melee].
- `SampleProject/UI/verify_enemy_variety.gd` [3] placements:
  - The Mesa point 4 is the ordinary archer, with its spawn_id kept.
  - DesertRoad's only archer point is the Mesa's ordinary one.
  - The camp has exactly one heavy archer on the old archer point.
  - The brute is in wave 1, the heavy archer in wave 2 behind a shield-bearer, never side by side.
  - The slot-count label is now 3 road + 2 camp + 6 lab = 11.
- `SampleProject/UI/verify_difficulty.gd` — new `_side_room("heavy_archer", "BanditCamp", ^"Fight_Camp")` meeting. The heavy archer is no longer in any ROUTE fight, so this keeps its numbers under check [3] at the camp's level (L4, before the oath: both builds must win). It also checks that its one slot is in `Fight_Camp`. **Risk:** D706 balanced it at L3 (STRENGTH 8 hits / SKILLS 9). At L4 both sides scale, but this has not been run. If [3] fails, tune `enemy_stats_heavy_archer.tres` or put the camp at the hero's level there.
- `SampleProject/UI/capture_heavy_archer.gd` — captures in BanditCamp `Fight_Camp` wave 2 (shield-bearer + `BigSlot_HeavyArcher_4`) into `design/shots/big_archer/camp.png` (was `mesa.png`; the Mesa slot no longer exists).
- `design/MASTER_PLAN.md` §5 — Q94 → ✅ D719, plus a D719 row (👀, untested).

Unchanged on purpose:
- `verify_road_sections` (`Fight_Mesa` still has 4 enemies).
- `verify_archer` (it builds its own heavy-archer point).
- `verify_rooms_batch1` (it checks the brute slot by name, and that node still exists).
- `verify_masher` (on `cloud/hard-fights` only). Its fights are CityGates, LoneElite, Lab Middle, Caravan and Cursed, with no Mesa and no Camp. If the integrator wants the heavy archer in it, the entry is `{"name": "Bandit Camp: brute, heavy archer and 4", "room": "BanditCamp", "fight": "Fight_Camp", "cls": "group"}`.

Tests to run (none were run here):
`verify_enemy_variety`, `verify_difficulty`, `verify_archer`, `verify_road_sections`, `verify_rooms_batch1`, `verify_room_entrances`, `verify_map_geometry`, then `Scripts/Tools/run_verify.sh | grep -v '^PASS'` once. Capture: `capture_heavy_archer.gd`.
