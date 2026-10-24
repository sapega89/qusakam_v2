---
type: cloud-report
branch: cloud/big-brute
date: 2026-10-24
tags: [cloud, combat, enemies]
---

# Cloud report: big-brute (the bandit brute goes live, D652 / D693)

**Summary.** Done: `bandit_brute` is a live elite kind. It has its own scene on the bandit's behaviour (`default_enemy`) and the D693 sheet. Its attack is a slow, heavy smash: a 1.0 s windup with the club over his shoulder, then one blow into the ground behind a red glint (dodge only). Its hit shapes are measured from its frames (D519), and the hitbox front is the club on the ground. Its elite numbers come from the kind and the slot's level (D642): L2 523 HP / 43 per hit, L8 1235 / 140. It has a bestiary entry in en/uk.
Placements: `DesertRoad Fight_LoneElite` (alone, the road's first elite, D582) and `Laboratory Fight_Upper` ×2 (a pair at L8). **The `Fight_Dunes` slot is an ordinary bandit again**, so the pack leader's fight keeps one big kind (D582; the big-leader routine asked for this call).
Tests: `verify_enemy_variety` [3]/[9], `verify_difficulty` [3c], `verify_hit_areas` [1]/[3]. Capture: `design/shots/big_brute/bandit_brute_lone_elite.png`.
D-IDs: **D694, D695** (text below; the orchestrator renumbers). B rows fixed: none. Full suite: SUITE_LINE

## D-ID text (for the register; the next free numbers after D693, renumber as needed)

| D694 | ROUTINE CALL | **The bandit brute, as built** (D652, D681, D692, D693; `cloud/big-brute`). `Scenes/Characters/Enemies/enemy_bandit_brute.tscn` (inherits `default_enemy`, the bandit's melee behaviour) + `Resources/Enemies/enemy_stats_bandit_brute.tres`. **Body and blow are the bandit's** (190 HP, 24 damage, 30 XP, detection 300 / chase 400), so the elite and level multipliers make him heavy. **The smash is his own** (agent call, «a slow heavy smash»): windup 1.0 s (bandit 0.7), one blow (`combo_hits` 1, bandit 2), red glint `tell = dodge` (the club comes down into the ground, so you step out of it; you cannot block or parry it), cooldown 2.0 s, recovery 0.7 s (the opening while he drags the club back), poise 5 / stagger 0.4 s, speed 55 (bandit 70, he drags the club), no back-off. Sheet `Assets/Characters/Enemies/bandit_brute/sheet.png`, 4×5 cells of 96×96, facing right: idle 0–1 (0.9 s), walk 4–7 (0.8 s, dragging the club), attack 8 → 9 → 10 (club over the shoulder for the whole windup, the smash at `attack_strike_time` 0.6 → he lowers it back 0.25 s later), stagger 12 (the hurt frame), death 16–18. **Drawn at ×1.0**, as the pack leader and the cursed jackal: 81×86 px against the bandit's 70.5×73.5. Offset (0, −16) puts his feet on the bandit's line (+28 vs +28.5). Shapes (D519): body 40×32, hurtbox 81×86 at (−0.5, −15) (idle + walk, club included), hitbox 45×86 at (22.5, −15) = frame 9, whose front edge is the club head on the ground, `attack_range` 50 (body contact 32, reach 57). Glint `tell_at` (−25, −29) is at the club head over his shoulder. Elite from the kind (D681): L2 523 HP / 43 per hit, L8 1235 / 140. `verify_difficulty` [3]: at L2 both builds win (STRENGTH 10 hits, SKILLS 11; he needs 4 blows); at L8 SKILLS wins and STRENGTH loses, as D668 asks. Coins 2–4 (the bandit's). Voice pitch 0.8 (deeper than the bandit's 1.0). Bestiary «Bandit Brute» / «Бандит-громило», en + uk. No cursed foam. |
| D695 | ROUTINE CALL | **The bandit brute's placements** (D582, D682; amends D682's Dunes slot). **1.** `DesertRoad Fight_LoneElite/BigSlot_BanditBrute_1` (L2, spawn_id `Fight_LoneElite_EnemySpawnPoint1`): the brute **alone**, the road's first elite and the place to learn the red smash. **2.** `DesertRoad Fight_Dunes`: its point 1 is an ordinary bandit again, `EnemySpawnPoint1` (spawn_id `Fight_Dunes_EnemySpawnPoint1` kept, `big_kind` none). That fight is where the pack leader first appears (big-leader's report). With a brute in wave 1 and the leader in wave 2, it would be two elites at L2, right after the lone one, and D582 keeps big elite groups rare. **3.** `Laboratory Fight_Upper/BigSlot_BanditBrute_1` and `_3` (L8): **a pair** of brutes. This is the "pairs after the lone one" step of D582. After lab-curse's D694 the middle point is an ordinary jackal, so the pair is the fight's only elites. Big slots: 11 (4 on DesertRoad, 7 in the Laboratory, before the other routines' changes). |

## Merge notes (for the orchestrator)

- **Merge-time conflicts with the sibling branches are expected in these places:** the `enemy_voice_pitch` line in `sound_events.json`, `KIND_NAMES` in `verify_difficulty.gd`, the strike-case list and `KINDS` in `verify_hit_areas.gd`, and the `_coin_drop` match in `DefaultEnemy.gd` (another kind's line beside mine). In `verify_enemy_variety.gd`, both big-leader and lab-curse also append `func _translated` at the end, with the same body. Keep **one** copy. Two copies are a parse error.
- The bestiary and `.po` entries sit after «Shield Bandit», not after «Cthulhu Fly» where the siblings put theirs, so these merge cleanly.
- `verify_enemy_variety` [3] slot count: I made it 11. Recount after merging big-archer (it renames the Mesa slot, and the count stays the same) and lab-curse (it turns two cursed slots into ordinary points and adds its own).
- big-leader's [6] (`Fight_Dunes` kinds `["melee", "fast", "jackal_pack_leader"]`) and big-scorpion's [0b] (a live big kind's first fight holds no other big kind) both **need** the Dunes demotion above. Without it, Dunes would hold `bandit_brute` too.
- I did not touch `Laboratory.tscn` or `build_laboratory.gd`. lab-curse edits those lines, and both Upper brute slots stay as they are.

## Details

### Files
- `SampleProject/Scenes/Characters/Enemies/enemy_bandit_brute.tscn`: new, inherits `default_enemy.tscn`, its own animation library (it replaces the bandit's stagger, which swaps in `bandit/stagger.png`).
- `SampleProject/Resources/Enemies/enemy_stats_bandit_brute.tres`: new.
- `SampleProject/Assets/Characters/Enemies/bandit_brute/sheet.png.import`: the import file only. The sheet came from feature/backlog.
- `SampleProject/Maps/DesertRoad.tscn`: `Fight_Dunes/BigSlot_BanditBrute_1` → `EnemySpawnPoint1`.
- `SampleProject/Scripts/Gameplay/DefaultEnemy.gd` `_calculate_coin_drop`: `bandit_brute` 2–4.
- `SampleProject/Resources/Data/bestiary.json`, `Translations/en.po`, `uk.po`, `sound_events.json` (`enemy_voice_pitch.bandit_brute` 0.8).
- Tests: `verify_enemy_variety.gd` ([3] the lone elite is the brute, 11 slots; new [9]), `verify_difficulty.gd` (KIND_NAMES, new [3c]), `verify_hit_areas.gd` ([1] scene shapes, [3] strike edge).
- `SampleProject/UI/capture_big_brute.gd`: new.

### Measured from the frames (96×96 cells, cell centre = origin)
| frames | opaque bounds (cell px) | note |
|---|---|---|
| idle 0–1, walk 4–7 | x 7–88, y 6–92 | club head in front at x 65–88, low |
| attack 8 | x 6–89, y 3–92 | club over the shoulder, head up at the back (−25, −29) |
| attack 9 | x 7–93, y 6–92 | the smash: club head on the ground at x 60–93 with dust |
| attack 10, hurt 12 | x 7–88 | back to the drag pose |
| death 16–18 | down to y 30–92 at 18 | lying |

### Test results
- `verify_enemy_variety`: `RESULT: ALL PASS`. [9]: «Fight_LoneElite/BigSlot_BanditBrute_1, Fight_Upper/BigSlot_BanditBrute_1, Fight_Upper/BigSlot_BanditBrute_3 spawn the bandit brute»; «in the game it is the bandit brute, an elite at the fight's level 2: HP 523, damage 43.2»; feet on the bandit's line.
- `verify_hit_areas`: `RESULT: ALL PASS`. Hurtbox (−41, −58) 81×86 = drawn body; hitbox (0, −58) 45×86 = drawn strike; «attack_range 50 starts a strike that reaches (body contact 32, reach 57)»; the hero is hit 3 px inside the strike edge and not hit 6 px past it.
- `verify_difficulty`: `RESULT: ALL PASS`. Its table:
  ```
  elite bandit brute L2   2 STRENGTH  130   43  39  4  8   523  47  10 yes
  elite bandit brute L2   2 SKILLS    148   43  39  4  8   523  44  11 yes
  elite bandit brute L8   8 STRENGTH  238  140 104  3  4  1235  77  15 no
  elite bandit brute L8   8 SKILLS    304  140  84  4  6  1235  74  11 yes
  ```
- Full suite: SUITE_DETAIL

### Capture
`design/shots/big_brute/bandit_brute_lone_elite.png` (`capture_big_brute.gd`, log: «spawned bandit_brute elite=true level 2 HP 523 damage 43»). Panel 1: he drags the club toward the hero along the road. Panel 2: the windup, club over his shoulder. Panel 3: the smash, club head on the ground at the hero's feet. On screen he stands about 1.5× the hero's height, and his feet are on the floor line. Nothing here differs from Figma: enemies have no Figma frame.
