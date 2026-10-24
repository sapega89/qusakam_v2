---
type: cloud-report
branch: cloud/lab-curse
date: 2026-10-24
tags: [cloud, combat, enemies, laboratory]
---

# Cloud report: lab-curse (the cursed jackals in the Laboratory)

**Summary.** Done: `jackal_cursed` is a live elite kind. It has its own scene (the D675 sheet, hit shapes measured from its frames, D519) and its own stats (the jackal's `enemy_fast` behaviour and base numbers; elite ×2.5/×1.5 and the fight level give HP 1134 / hit 148 at L9 and 1258 / 169 at L11). The foam sits at its own jaws (D653), and it has a bestiary entry in en/uk. Placement (D582): one alone in a new `Fight_Cursed` on the middle storey, then a pair as the second wave of `Fight_Lower` before the boss. The fly is unchanged. The Upper/Middle cursed slots are now ordinary jackals. `Fight_Lower` `enemy_level` goes 10 → 11 (the lone jackal's XP). D-IDs: **D693–D694** (text below). B rows fixed: none.
Full suite: `SUITE: ALL PASS` (117 verify scripts).

## D-ID text (for the register; the next free numbers after D692, other routines run beside, renumber as needed)

| D693 | ROUTINE CALL | **The cursed jackal, as built** (D589, D649, D652, D653, D675; `cloud/lab-curse`). `Scenes/Characters/Enemies/enemy_jackal_cursed.tscn` (on `default_enemy`, like the jackal) + `Resources/Enemies/enemy_stats_jackal_cursed.tres` (the jackal's `enemy_fast` numbers and behaviour: speed 120, lunge 60, windup 0.55, three-hit combo with the parry finisher, 165 HP / 23 damage, 25 XP, `enemy_type = jackal_cursed`). Sheet 4×5 cells of 96×72: idle 0–1, walk 4–7, attack 8–10 (crouch, leap, bite; strike at 0.225 s on the leap, as the jackal), stagger 12 (the hurt frame), death 16–18. **Drawn at sprite scale ×1.0** (the jackal is ×1.5): the beast fills its cell (81×58 px against the hyena's 35×28), so on screen it stands about 1.4× the jackal, a wolf beside a jackal, and still shorter than the hero (agent call). Feet on the jackal's line (+29 px). Shapes (D519): hurtbox 83×58 at (−0.5, 0), hitbox 40×59 at (20, −0.5), attack_range stays 80. Foam (D683) moves from the jackal's frames to its own jaws, `kinds.jackal_cursed.foam = [31, 0]`. Glint `tell_at` (25, −10) at the eye. Elite through `kinds.jackal_cursed.elite` (D681): L9 1134 HP / 148 hit, L11 1258 / 169; `verify_difficulty`: STRENGTH loses and SKILLS wins at both (D642 [3]). Coins 1–3 (the jackal's), voice pitch 0.95 (bigger than the jackal's 1.15, agent call). Bestiary «Cursed Jackal» / «Проклятий шакал», en + uk. |
| D694 | ROUTINE CALL | **Cursed jackals in the Laboratory: alone first, then a pair** (D582; amends D682's Laboratory slots). Route order, every placement: **1.** `Fight_Fly` (top storey, zone x 600, L8): the Cthulhu fly alone. Unchanged (D655), and no jackal beside it. **2.** `Fight_Upper` (top, zone x 1000, L8): bandit-brute slot, an **ordinary jackal** (was `BigSlot_JackalCursed_2`, now `EnemySpawnPoint2`, same spawn_id), bandit-brute slot. **3.** **`Fight_Cursed`** (new, middle storey, zone x 1330 where the hero steps off the ladder block, L9, `enemies_cursed`, respawns): **one cursed jackal alone**, `BigSlot_JackalCursed_1` at (1120, 848), on the flat floor between the block and the bridge. It is not one of the three fights `lab_corridors_complete` waits for (like the fly). **4.** `Fight_Middle` (middle, zone moved x 1250 → 900, L9): bandit 700, jackal 640, scorpion 560, jackal 480. Both of its cursed slots become ordinary jackals, keeping their spawn_ids, so the lone one has 430 px of corridor before the next zone. **5.** `Fight_Lower` (bottom, zone x 700, **L10 → 11**: the lone jackal's XP brings the hero there at 11, D642 [0]): armoured-scorpion slot, shield-bearer, then **a pair of cursed jackals** as the second wave (the old scorpion `EnemySpawnPoint4` becomes `BigSlot_JackalCursed_4`, spawn_id kept). Never two cursed kinds in one fight. Laboratory big slots 7 → 6 (11 in all). `verify_enemy_variety` [6] checks this; shot `design/shots/lab_curse/cursed_jackal_corridor.png`. |

## Details

### Files
- `SampleProject/Scenes/Characters/Enemies/enemy_jackal_cursed.tscn` (new): sprite scale 1, `hframes 4 / vframes 5`, animations as above, shapes measured by `HitAreas` (`verify_hit_areas` [1] OK: hurtbox `(-42,-29) 83×58` = the drawn body; hitbox `(0,-30) 40×59` = the drawn strike; [3] hit at 3 px inside, missed at 6 px past).
- `SampleProject/Resources/Enemies/enemy_stats_jackal_cursed.tres` (new): a copy of `enemy_stats_fast.tres` with `enemy_type = "jackal_cursed"`.
- `SampleProject/Resources/Data/enemy_variety.json`: `jackal_cursed.foam` `[15, 16]` → `[31, 0]`, plus its note.
- `SampleProject/Scripts/Gameplay/DefaultEnemy.gd` `_calculate_coin_drop`: `jackal_cursed` 1–3.
- `SampleProject/Resources/Data/sound_events.json` `enemy_voice_pitch.jackal_cursed = 0.95`.
- `SampleProject/Resources/Data/bestiary.json` + `en.po` / `uk.po`: the entry.
- `SampleProject/Maps/Laboratory.tscn` + `Scripts/Tools/build_laboratory.gd` `places`: the D694 placement.
- Tests: `verify_enemy_variety` (new [6] the kind, its rows and frames, the bestiary in en/uk, the placement: the first alone in `Fight_Cursed`, 400+ px to the next zone, the pair as `Fight_Lower`'s second wave, nowhere else, the fly still alone and first; [5] the foam now on the real scene; [3] 11 big slots); `verify_difficulty` (KIND_NAMES plus [3b]: the cursed jackal is a live elite, STRENGTH loses and SKILLS wins); `verify_hit_areas` (the scene in [1] and [3]); `verify_laboratory` and `verify_lab_route` (the new fight in their FIGHTS: the route kills it and counts its assist press).
- `capture_enemy_variety.gd` now uses the real cursed scene and stats. New `capture_lab_curse.gd` → `design/shots/lab_curse/cursed_jackal_corridor.png`: the hero steps off the ladder block, the jackal runs at him with foam trailing (top), then the leap-bite (bottom).

### RESULT lines (touched tests)
`verify_enemy_variety`, `verify_difficulty`, `verify_hit_areas`, `verify_laboratory`, `verify_lab_route`, `verify_flying_enemies`,
`verify_progression`, `verify_journal_notes`, `verify_journal_sections`, `verify_locale`, `verify_bosses`, `verify_archer`: `RESULT: ALL PASS`.

### verify_difficulty rows (cursed jackal)
```
elite cursed jackal L9    9 STRENGTH  248 HP  hit 148  e.HP 1134  N 13  no
elite cursed jackal L9    9 SKILLS    322 HP  hit 148  e.HP 1134  N 11  yes
elite cursed jackal L11  11 STRENGTH  268 HP  hit 169  e.HP 1258  N 14  no
elite cursed jackal L11  11 SKILLS    358 HP  hit 169  e.HP 1258  N  9  yes
```

### Notes for the orchestrator
- Its size on screen (scale ×1.0) is an agent call. If Sapega wants it to loom like the fly (about 1.5× the hero), raise `Sprite2D.scale` and re-measure the two shapes (`verify_hit_areas` [1] prints the drawn rects).
- The foam is small at 1:1 (2–3 px drops, D683). In the shot it reads as blue specks at the jaws and behind the running beast.
