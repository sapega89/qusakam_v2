---
type: report
tags: [cloud, routines, progression, balance]
---

# hero-points-only — D841: a level gives only the points the hero spends

- **Done:** `XPManager` no longer adds hp_per_level / damage_per_level (D642). A level gives only 5 attribute points (D335) and JP (D497). To keep the sensible build where it was, **Strength 1 → 2 Phys. Atk. a point (diminishing factor 0.5 → 0.75)** and **Vitality 4 → 9 Max HP a point**. With these, the SKILLS hero (2 Str / 2 Vit / 1 Wis a level) has the same HP and Atk as before on every row, through level 11. At level 12 he is 1 Atk lower (86 → 85).
- **UI:** the level-up notification (D436) drops its Max HP and Damage rows and keeps Attribute Points and Job Points. Two tutorial texts no longer promise automatic HP and damage (en + uk).
- **verify_difficulty: 11 FAIL → 14 FAIL.** No assertion was loosened. All 11 earlier FAILs come from D840 (pre-D840 base: 5 FAIL) and stay the same. The **3 new FAILs are all in the STRENGTH build.** That build puts every point into Strength, so its HP now comes only from gear (120 at levels 3–4, 168 from level 5 to level 12): **[3]** it now loses the armoured scorpion at L3 before the oath, and **[4]** Scorpicore's and the Mercenary's heaviest moves now kill it at full HP in one hit. This is the cost of D841, not a bug in the change. See Q below.
- **D-ID text:** §1. **B rows fixed:** none.
- **Full suite:** running (this line is updated when it finishes)
- **Godot ran** (4.6.2). Tests: verify_attributes, verify_level_up, verify_xp_curve, verify_status, verify_progression, verify_combat_stats, verify_starting_skills, verify_save_load, verify_scripts_compile — ALL PASS; verify_difficulty 14 FAIL (above). `Maps/` is untouched.

## 1. D-ID text

> **D841 as built** (`cloud/hero-points-only`, after `cloud/enemy-scaling`). `XPManager` keeps the curve and the level but drops `stat_bonuses`, `get_hp_bonus()` and `get_damage_bonus()`. `xp_curve.json` loses `hp_per_level` / `damage_per_level`. `GameManager.level_and_passive_health/attack` are renamed `passive_and_attribute_health/attack` (passives plus attributes, no level term); Equipment's "without items" numbers use them as before. A level now gives the hero only what he spends: 5 attribute points (`attributes.json → points_per_level`) and `SkillManager.JP_PER_LEVEL` JP. To make up for the removed automatic +10 Max HP / +2 Phys. Atk. a level, `attributes.json` now gives **Strength +2 Phys. Atk. a point** (was 1), with diminishing every 10 points **×0.75** (was ×0.5), and **Vitality +9 Max HP a point** (was 4). Agility and Wisdom are unchanged. The numbers: a level spent 2 Str / 2 Vit / 1 Wis used to give 2 + 2 Atk and 8 + 10 HP. It now gives 2 × 2 = 4 Atk and 2 × 9 = 18 HP, the same. The old +2 Atk never diminished, so ×0.5 would have left that hero 2–7 Atk short from level 8 on (14+ Strength). ×0.75 gives exactly the old Atk through 20 Strength (level 11) and 1 less at 22. An all-Strength hero gets more Atk than before (+10 a level, diminishing) but no HP from levels; an all-Vitality hero gets +45 HP a level (was 30). The level-up notification shows only Attribute Points and Job Points. The tutorial texts `experience` and `level_up` say a level gives points to spend.

## 2. Numbers per level (SKILLS build, Strength points → Phys. Atk. from Strength + level)

| level | Str pts | before (×0.5, 1/pt + 2/lv) | ×0.5, 2/pt | **built (×0.75, 2/pt)** |
|---|---|---|---|---|
| 2 | 2 | 2 + 2 = 4 | 4 | **4** |
| 6 | 10 | 10 + 10 = 20 | 20 | **20** |
| 8 | 14 | 12 + 14 = 26 | 24 | **26** |
| 11 | 20 | 15 + 20 = 35 | 30 | **35** |
| 12 | 22 | 15.5 + 22 = 37.5 | 31 | **37** |

HP: 2 Vit × 9 = 18 a level = 2 × 4 + 10. The two runs of the sim show the same thing: the first try (×0.5) cost SKILLS 2–7 Atk on 12 rows, and one row turned worse (tower shield guard N 9 → 10). The built ×0.75 leaves only Mercenary 86 → 85.

## 3. verify_difficulty, every row: before (`cloud/enemy-scaling`, D840 only) → after (D840 + D841)

Both builds spend their points as the sim does (STRENGTH: everything in Strength, no JP; SKILLS: 2/2/1 and JP on the tree).
`H` = enemy hits that kill the hero, `N` = hero hits that kill it, `H+F` = with the flask. Changed cells in **bold**.

| enemy | lvl | e.lv | build | HP | hit | got | H | H+F | e.HP | atk | N | wins |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| bandit L1 | 1 | 1 | STRENGTH | 120 | 24 | 22 | 6 | 13 | 190 | 40 | 5 | yes |
| bandit L1 | 1 | 1 | SKILLS | 120 | 24 | 22 | 6 | 13 | 190 | 40 | 5 | yes |
| jackal L1 | 1 | 1 | STRENGTH | 120 | 23 | 21 | 6 | 13 | 165 | 40 | 4 | yes |
| jackal L1 | 1 | 1 | SKILLS | 120 | 23 | 21 | 6 | 13 | 165 | 40 | 4 | yes |
| shield-bearer L2 | 2 | 2 | STRENGTH | 130 → **120** | 31 | 28 | 5 | 10 | 220 | 47 → **50** | 5 → **4** | yes |
| shield-bearer L2 | 2 | 2 | SKILLS | 148 | 31 | 28 | 6 | 11 | 220 | 44 | 5 | yes |
| vulture L2 | 2 | 2 | STRENGTH | 130 → **120** | 28 | 25 | 6 → **5** | 12 → **11** | 182 | 47 → **50** | 4 | yes |
| vulture L2 | 2 | 2 | SKILLS | 148 | 28 | 25 | 6 | 13 | 182 | 44 | 4 | yes |
| elite bandit brute L2 | 2 | 3 | STRENGTH | 130 → **120** | 77 | 70 | 2 | 4 | 570 | 47 → **50** | 11 | yes |
| elite bandit brute L2 | 2 | 3 | SKILLS | 148 | 77 | 70 | 3 | 5 | 570 | 44 | 12 | yes |
| bandit L2 | 2 | 2 | STRENGTH | 130 → **120** | 29 | 26 | 5 | 11 | 209 | 47 → **50** | 5 → **4** | yes |
| bandit L2 | 2 | 2 | SKILLS | 148 | 29 | 26 | 6 | 12 | 209 | 44 | 5 | yes |
| elite jackal pack leader L2 | 2 | 3 | STRENGTH | 130 → **120** | 74 | 67 | 2 | 5 | 495 | 47 → **50** | 10 → **9** | yes |
| elite jackal pack leader L2 | 2 | 3 | SKILLS | 148 | 74 | 67 | 3 | 5 | 495 | 44 | 11 | yes |
| shield-bearer L3 | 3 | 3 | STRENGTH | 140 → **120** | 36 | 33 | 5 → **4** | 9 | 240 | 54 → **60** | 5 → **4** | yes |
| shield-bearer L3 | 3 | 3 | SKILLS | 166 | 36 | 33 | 6 | 10 | 240 | 48 | 5 | yes |
| archer L3 | 3 | 3 | STRENGTH | 140 → **120** | 34 | 31 | 5 → **4** | 10 → **9** | 180 | 54 → **60** | 3 | yes |
| archer L3 | 3 | 3 | SKILLS | 166 | 34 | 31 | 6 | 11 | 180 | 48 | 4 | yes |
| jackal L3 | 3 | 3 | STRENGTH | 140 → **120** | 32 | 29 | 5 | 10 | 198 | 54 → **60** | 4 → **3** | yes |
| jackal L3 | 3 | 3 | SKILLS | 166 | 32 | 29 | 6 | 12 | 198 | 48 | 4 | yes |
| elite armoured scorpion L3 | 3 | 4 | STRENGTH | 140 → **120** | 103 | 94 | 2 | 4 → **3** | 726 | 54 → **60** | 12 → **11** | yes → **no** |
| elite armoured scorpion L3 | 3 | 4 | SKILLS | 166 | 103 | 94 | 2 | 4 | 726 | 48 | 14 | no |
| bandit L3 | 3 | 3 | STRENGTH | 140 → **120** | 34 | 31 | 5 → **4** | 10 → **9** | 228 | 54 → **60** | 4 | yes |
| bandit L3 | 3 | 3 | SKILLS | 166 | 34 | 31 | 6 | 11 | 228 | 48 | 5 | yes |
| elite old vulture L4 | 4 | 5 | STRENGTH | 150 → **120** | 116 | 105 | 2 | 3 | 784 | 59 → **68** | 12 → **11** | no |
| elite old vulture L4 | 4 | 5 | SKILLS | 184 | 116 | 105 | 2 | 4 | 784 | 55 | 13 | no |
| bandit L4 | 4 | 4 | STRENGTH | 150 → **120** | 38 | 35 | 5 → **4** | 9 → **8** | 257 | 59 → **68** | 4 | yes |
| bandit L4 | 4 | 4 | SKILLS | 184 | 38 | 35 | 6 | 10 | 257 | 55 | 5 | yes |
| archer L4 | 4 | 4 | STRENGTH | 150 → **120** | 38 | 35 | 5 → **4** | 9 → **8** | 203 | 59 → **68** | 4 → **3** | yes |
| archer L4 | 4 | 4 | SKILLS | 184 | 38 | 35 | 6 | 10 | 203 | 55 | 4 | yes |
| Scorpicore Axe-Warrior | 5 | 7 | STRENGTH | 208 → **168** | 185 | 138 | 2 | 3 | 4824 | 68 → **80** | 63 → **54** | no |
| Scorpicore Axe-Warrior | 5 | 7 | SKILLS | 250 | 185 | 138 | 2 | 4 | 4824 | 64 | 34 | no |
| elite Cthulhu fly L8 | 8 | 9 | STRENGTH | 238 → **168** | 227 | 169 | 2 → **1** | 3 → **2** | 1134 | 77 → **95** | 14 → **11** | no |
| elite Cthulhu fly L8 | 8 | 9 | SKILLS | 304 | 227 | 156 | 2 | 4 | 1134 | 74 | 8 | yes |
| elite bandit brute L8 | 8 | 9 | STRENGTH | 238 → **168** | 237 | 177 | 2 → **1** | 3 → **2** | 1306 | 77 → **95** | 15 → **13** | no |
| elite bandit brute L8 | 8 | 9 | SKILLS | 304 | 237 | 163 | 2 | 3 | 1306 | 74 | 8 | yes |
| jackal L8 | 8 | 8 | STRENGTH | 238 → **168** | 90 | 67 | 4 → **3** | 6 → **5** | 429 | 77 → **95** | 6 → **5** | yes |
| jackal L8 | 8 | 8 | SKILLS | 304 | 90 | 62 | 5 | 8 | 429 | 74 | 4 | yes |
| elite tower shield guard L9 | 9 | 10 | STRENGTH | 248 → **168** | 275 | 205 | 2 → **1** | 2 | 1450 | 80 → **100** | 17 → **13** | no |
| elite tower shield guard L9 | 9 | 10 | SKILLS | 322 | 275 | 189 | 2 | 3 | 1450 | 77 | 9 | no |
| elite cursed jackal L9 | 9 | 10 | STRENGTH | 248 → **168** | 243 | 181 | 2 → **1** | 3 → **2** | 1196 | 80 → **100** | 14 → **11** | no |
| elite cursed jackal L9 | 9 | 10 | SKILLS | 322 | 243 | 167 | 2 | 4 | 1196 | 77 | 7 | yes |
| bandit L9 | 9 | 9 | STRENGTH | 248 → **168** | 103 | 77 | 4 → **3** | 6 → **5** | 523 | 80 → **100** | 6 → **5** | yes |
| bandit L9 | 9 | 9 | SKILLS | 322 | 103 | 71 | 5 | 8 | 523 | 77 | 4 | yes |
| jackal L9 | 9 | 9 | STRENGTH | 248 → **168** | 99 | 74 | 4 → **3** | 6 → **5** | 454 | 80 → **100** | 6 → **5** | yes |
| jackal L9 | 9 | 9 | SKILLS | 322 | 99 | 68 | 5 | 8 | 454 | 77 | 4 | yes |
| scorpion L9 | 9 | 9 | STRENGTH | 248 → **168** | 120 | 90 | 3 → **2** | 5 → **4** | 591 | 80 → **100** | 7 → **6** | yes |
| scorpion L9 | 9 | 9 | SKILLS | 322 | 120 | 82 | 4 | 7 | 591 | 77 | 4 | yes |
| elite armoured scorpion L11 | 11 | 12 | STRENGTH | 268 → **168** | 335 | 250 | 2 → **1** | 2 | 1720 | 84 → **106** | 19 → **15** | no |
| elite armoured scorpion L11 | 11 | 12 | SKILLS | 358 | 335 | 230 | 2 | 3 | 1720 | 83 | 9 | no |
| shield-bearer L11 | 11 | 11 | STRENGTH | 268 → **168** | 127 | 95 | 3 → **2** | 5 → **4** | 610 | 84 → **106** | 7 → **6** | yes |
| shield-bearer L11 | 11 | 11 | SKILLS | 358 | 127 | 87 | 5 | 7 | 610 | 83 | 3 | yes |
| elite cursed jackal L11 | 11 | 12 | STRENGTH | 268 → **168** | 275 | 205 | 2 → **1** | 3 → **2** | 1320 | 84 → **106** | 15 → **12** | no |
| elite cursed jackal L11 | 11 | 12 | SKILLS | 358 | 275 | 189 | 2 | 4 | 1320 | 83 | 6 | yes |
| Mercenary [DRAFT] | 12 | 16 | STRENGTH | 278 → **168** | 180 | 134 | 3 → **2** | 4 → **3** | 6800 | 87 → **108** | 69 → **56** | no |
| Mercenary [DRAFT] | 12 | 16 | SKILLS | 376 | 180 | 124 | 4 | 5 | 6800 | 86 → **85** | 30 | yes |
| heavy archer (BanditCamp) L4 | 4 | 5 | STRENGTH | 150 → **120** | 121 | 110 | 2 | 3 | 713 | 59 → **68** | 11 → **10** | no |
| heavy archer (BanditCamp) L4 | 4 | 5 | SKILLS | 184 | 121 | 110 | 2 | 4 | 713 | 55 | 12 | yes |

FAIL lines after the change (14). The 11 not marked NEW also failed before; a few of their numbers moved, see the table. **NEW** = caused by D841.
```
     FAIL scorpion L9 at level 9: 4 hits kill the hero ([5, 6]), 4 hits kill it ([4, 6])
     FAIL shield-bearer L11 at level 11: 5 hits kill the hero ([5, 6]), 3 hits kill it ([4, 6])
     FAIL Scorpicore Axe-Warrior at level 5: 2 hits kill the hero ([3, 4]), 34 hits kill it ([34, 46])
     FAIL Mercenary [DRAFT] at level 12: 4 hits kill the hero ([3, 4]), 30 hits kill it ([34, 46])
NEW  FAIL elite armoured scorpion L3 at level 3, STRENGTH: loses (11 hits needed, 3 blows taken, survives 2)
     FAIL elite armoured scorpion L3 at level 3, SKILLS: loses (14 hits needed, 4 blows taken, survives 3)
     FAIL elite old vulture L4 at level 4, STRENGTH: loses (11 hits needed, 3 blows taken, survives 2)
     FAIL elite old vulture L4 at level 4, SKILLS: loses (13 hits needed, 4 blows taken, survives 3)
     FAIL Scorpicore Axe-Warrior at level 5, SKILLS: loses (34 hits needed, 4 blows taken, survives 3)
     FAIL elite tower shield guard L9 at level 9, SKILLS: loses (9 hits needed, 3 blows taken, survives 2)
     FAIL elite armoured scorpion L11 at level 11, SKILLS: loses (9 hits needed, 3 blows taken, survives 2)
     FAIL heavy archer (BanditCamp) L4 at level 4, STRENGTH: loses (10 hits needed, 3 blows taken, survives 2)
NEW  FAIL Scorpicore Axe-Warrior, STRENGTH: its heaviest move (278) kills in 1 hits
NEW  FAIL Mercenary [DRAFT], STRENGTH: its heaviest move (288) kills in 1 hits
```
`[5]` (diminishing): `OK the first 10 points of Strength give their full 2 each, every next 10 less ([20, 15, 11, 9])`. The check used to say `steps[0] == 10`. It now reads `10 × per_point` from the data, so it still asks for exactly full value from the first 10 points. It was not loosened.

Pre-D840 base (merge-base with feature/backlog) for reference: 5 FAIL (scorpion L9 [1], shield-bearer L11 [1], Scorpicore [2], Mercenary [2], armoured scorpion L11 SKILLS [3]).

## 4. Proposed Q (for the orchestrator to file and ask)

**Q: the all-Strength hero with D841.** He now gets no HP from levels (gear only: 168 HP at level 12). He is one-shot by Scorpicore's and the Mercenary's heaviest move ([4]), and he loses the pre-oath armoured scorpion ([3]). Options: (a) accept: a glass-cannon build is meant to die to a boss's big move, so [4] should be judged on the SKILLS hero only (a product call; I did not change the check); (b) give Strength a little HP per point (e.g. +2), which blurs the attributes; (c) raise base HP / armour HP. My default if nobody answers: (a). The point of D841 and the pillars («a build through profession and skills») is that a build has a cost.

## 5. Files

- `SampleProject/Scripts/Managers/XPManager.gd` — stat_bonuses / get_hp_bonus / get_damage_bonus removed.
- `SampleProject/Resources/Data/xp_curve.json` — hp_per_level / damage_per_level removed; `_growth` says D841.
- `SampleProject/Resources/Data/attributes.json` — Strength 2 (×0.75), Vitality 9; `_comment` explains.
- `SampleProject/Scripts/Managers/Core/GameManager.gd`, `Scripts/Menus/Game/equipment_component.gd`, `Scripts/Player/Components/PlayerCombat.gd` — rename and comments.
- `SampleProject/Scenes/UI/level_up_notification.tscn`, `Scripts/UI/LevelUpNotification.gd` — MaxHp / Damage rows removed.
- `SampleProject/Resources/Data/tutorial.json`, `Resources/Translations/en.po`, `uk.po` — two texts.
- Tests: `verify_level_up` (rows are exactly AttributePoints + JobPoints), `verify_attributes` / `verify_status` (new per-point values), `verify_difficulty` [5] (from the data).
- Also committed: the three `.uid` files that Godot wrote for `cloud/enemy-scaling`'s new scripts (its report listed them as missing).
