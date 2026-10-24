---
type: cloud-report
branch: cloud/big-vulture
date: 2026-10-24
tags: [cloud, combat, enemies]
---

# Cloud report: big-vulture (the old vulture goes live, D652 / D692)

**Summary.** Done: `old_vulture` is a live big kind. It has its own scene on the vulture's behaviour (it flies and dives, with the vulture's numbers), the D692 sheet `Enemies/vulture_old/sheet.png`, hit shapes measured from its frames (D519), and its own stats file. It is an elite through its kind (D681): 454 HP / 41 per hit at level 2, and 495 / 48 at level 3. It has a bestiary entry in en and uk.
**Not placed:** no map has a `BigSlot_OldVulture_*` slot (D682 made none), so nothing spawns it yet. I did not add a slot. D582 rules out both vulture places on the road (details below). The placement is a Sapega call: **Q (non-blocking)** below.
Tests: `verify_enemy_variety` [7], `verify_flying_enemies` [1], `verify_hit_areas` [1] (fliers), and `verify_difficulty` (an "unplaced" meeting at the Caravan's level) all pass. Capture: `design/shots/big_vulture/old_vulture_dive.png`.
D-IDs: **D696** (text below; the orchestrator renumbers). B rows fixed: none. Full suite: `SUITE: ALL PASS` (117 PASS).

## D-ID text (for the register; big-leader took D695, lab-curse D693–D694, renumber as needed)

| D696 | ROUTINE CALL | **The old vulture, as built** (D652, D681, D682, D692; `cloud/big-vulture`). The scene is `Scenes/Characters/Enemies/enemy_old_vulture.tscn`, built on `default_enemy` like the vulture, with `Resources/Enemies/enemy_stats_old_vulture.tres`. The stats copy the vulture's `enemy_stats_vulture` numbers and behaviour: flying, `flight_attack = dive`, hover 150, dive speed 450, a 0.6 s wind-up, a red (dodge) tell, 165 HP, 23 damage, speed 120, 7 XP, `enemy_type = old_vulture`. `kinds.old_vulture.sheet` is the D692 pick `Assets/Characters/Enemies/vulture_old/sheet.png`. The sheet is 4×4 cells of 96×96 with the vulture's layout: fly 0–3 (idle and walk), dive 4–6 (the strike from 0.6 s on frame 6), hurt 8 (stagger), death 12–14. It is **drawn at sprite scale ×1.0**, so it is 1.5× the vulture's 64-px cell, and the bird fills its cell. Shapes (D519): the hurtbox is 96×93 at (0, −1.5) (the fly frames), the hitbox is 88×91 at (−4, −0.5) (the dive frame, the whole bird, as for the vulture), and the blocking body stays 32×32. The tell `tell_at` (24, −10) is at the head. It is an elite by kind (D681): at level 2 it has 454 HP and hits for 41, and at level 3 it has 495 HP and hits for 48. XP stays 7. Coins are 1–3 (the vulture's), and the voice pitch is 0.7 (lower than the vulture's 0.85; agent call). Bestiary: «Old Vulture» / «Старий гриф», en + uk. **Placement:** none. D682 made no old-vulture slot. The road's first vulture (`Fight_LoneVulture`) must stay an ordinary vulture alone (D582). The other road vulture flies in `Fight_Caravan`, which already holds `BigSlot_ArmouredScorpion_1`, so a second big kind there would break D582's "a new kind first comes alone" (and big-scorpion's `verify_difficulty` [0b]). The kind is live and waits for its slot. `verify_difficulty` simulates it as an "unplaced" elite at the Caravan's level 3: both builds win there before the oath (STRENGTH in 9 hits, survives 6 blows; SKILLS in 10, survives 7), as D668 asks of road elites. |

## Question for Sapega (non-blocking, for `questions_for_sapega.md`)

**Where does the old vulture first fly?** D582 wants a new elite alone, in a place that is safe enough to learn it. Options:
(a) A new lone optional fight on DesertRoad after the Caravan, over open sand, guarding a reward (a nest with loot). This is the cleanest fit for D582, and it needs a new spawner, a trigger and a reward (level design).
(b) Turn the Caravan's vulture (`Fight_Caravan/EnemySpawnPoint6`) into `BigSlot_OldVulture_6`. This is cheap, but then the Caravan holds two big kinds (the armoured scorpion and the old vulture), against D582.
(c) Leave it out of the demo until there is a cliffs/canyon room after the city.
Default until answered: (c), so the kind is live but has no slot.

## Placements (D582 check)

| Room / fight (level) | Slot | Spawns |
|---|---|---|
| none | no `BigSlot_OldVulture_*` on any map (`verify_enemy_variety` [7] walks every `Maps/*.tscn`) | none |

Vultures in the demo today: `DesertRoad Fight_LoneVulture/EnemySpawnPoint1` (L2, the lone first vulture, stays ordinary)
and `DesertRoad Fight_Caravan/EnemySpawnPoint6` (L3, last in the chest guard group, beside the armoured scorpion slot).

## What changed (files)

- `Resources/Data/enemy_variety.json`: `kinds.old_vulture.sheet` → `Enemies/vulture_old/sheet.png` (D692's folder).
- `Scenes/Characters/Enemies/enemy_old_vulture.tscn` and `Resources/Enemies/enemy_stats_old_vulture.tres` (new),
  `Assets/Characters/Enemies/vulture_old/sheet.png.import` (new).
- `Scripts/Gameplay/DefaultEnemy.gd` `_calculate_coin_drop`: `old_vulture` 1–3.
- `Resources/Data/sound_events.json` `enemy_voice_pitch.old_vulture` 0.7.
- `Resources/Data/bestiary.json` + `Translations/en.po`, `uk.po`: the Old Vulture entry.
- Tests: `verify_enemy_variety` [7] `_old_vulture`; `verify_flying_enemies` [1] (old vulture stats + shapes);
  `verify_hit_areas` [1] `FLIERS` (hurtbox = drawn body, own shapes); `verify_difficulty` `_unplaced` meeting and a
  `KIND_NAMES` entry. New capture `UI/capture_old_vulture.gd`.

Merge notes: `enemy_variety.json`, `sound_events.json` (`enemy_voice_pitch`), `DefaultEnemy._calculate_coin_drop`,
`verify_difficulty.KIND_NAMES` and `verify_enemy_variety._initialize` are one-line edits that the sibling big-* branches
make too, on the same lines or right next to them. Keep both sides.

## Results

- `verify_enemy_variety`: RESULT: ALL PASS ([7]: «level 2: a flying elite, HP 454, damage 41.4, XP 7», «level 3: … HP 495, damage 48.3»).
- `verify_flying_enemies`: RESULT: ALL PASS («old_vulture: hurtbox = the fly frames (-48, -48) 96×93», «hitbox = the dive frames (-48, -46) 88×91»).
- `verify_hit_areas`: RESULT: ALL PASS.
- `verify_difficulty`: RESULT: ALL PASS (old vulture (unplaced) L3: STRENGTH wins in 9 hits, survives 6 blows; SKILLS wins in 10, survives 7).
- Full suite (`Scripts/Tools/run_verify.sh`): `SUITE: ALL PASS`, 117 PASS, 0 FAIL.
- Shot `design/shots/big_vulture/old_vulture_dive.png`: panel 1 shows the old vulture circling beside an ordinary vulture (it is clearly the bigger bird). Panel 2 shows the red tell at its head. Panel 3 shows the dive at the hero, and panel 4 shows it skimming low past him. It was taken on the road's flat arena (x 560), not in a slot, because it has none.
