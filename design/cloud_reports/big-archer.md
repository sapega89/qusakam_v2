---
type: cloud-report
branch: cloud/big-archer
date: 2026-10-24
tags: [cloud, combat, enemies]
---

# Cloud report: big-archer (the heavy archer goes live, D652, D692)

**Summary.** Done: the big archer kind is live as **`heavy_archer`** (renamed from `heavy_crossbowman`, because D692 made it
a bow). It has its own scene on the archer behaviour, its arrow leaves the drawn bow, its hit shapes come from its frames,
it has elite numbers checked at its slot's level (L3), and a bestiary entry in en/uk ("Heavy Archer" / "Важкий лучник").
Its one slot, DesertRoad `Fight_Mesa/BigSlot_HeavyArcher_4`, now spawns it. Its bow is drawn above the hero's head, so its
arrow is aimed down into the hero's body (new `ArcherEnemy.max_tilt`, `Arrow.fall`). Ordinary archers still shoot level.
**Not done / flagged:** two art defects (the hurt frame's background scrap shows while it is staggered; frame 9 is drawn
facing left, so it is skipped). Also a D582 concern: the road's only archer is now an elite (below). D-IDs: **D693–D694**
(text below). B rows fixed: none (two new B rows proposed). Full suite: SUITE_LINE

## D-ID text (for the register; next free after D692, siblings big-leader / big-scorpion run beside, renumber as needed)

| D693 | ROUTINE CALL | **The heavy archer, as built** (D652, D681, D682, D692; `cloud/big-archer`). The big archer kind is `heavy_archer` (was the `heavy_crossbowman` slot; D692: a bow). The slot is now `DesertRoad Fight_Mesa/BigSlot_HeavyArcher_4`, and its `spawn_id` stays `Fight_Mesa_EnemySpawnPoint4`. `enemy_variety.json` `kinds.heavy_archer`: sheet `Enemies/archer_heavy/sheet.png` (96×96 cells, 4×5: idle 0–1, walk 4–7, attack 8 draw / 9 loose / 10 recover, hurt 12, death 16–18), elite, base `archer`, scene `enemy_heavy_archer.tscn`. The scene inherits `default_enemy.tscn` with `ArcherEnemy.gd`, like `enemy_archer.tscn`. The sprite is ×1.2 with offset y −19, so its drawn feet sit on the archer's floor line (28.8 vs 28.5 px below the centre). Its drawn body is 79×102 px against the archer's 66×75. Animations: attack = 8 (the full draw, held through the wind-up) then 10 at `attack_strike_time` 0.8; frame 9 is not used (drawn facing left). Death is 16–18, and `stagger` = 12 (hurt). Its `tell_at` is (36, −14), the arrowhead on the drawn frame: the yellow glint and the arrow start there. Hurtbox (D519) = the idle+walk bounds, 79.2×102 at (4.8, −22.2). The unused archer hitbox = frame 8 forward of the centre. The blocking body stays the 32×32 torso. `enemy_stats_heavy_archer.tres`: the archer's HP 150, damage 24, ranges and XP 25 (XP ×1 for elites, D681, so the XP curve is unchanged). It is heavier in tempo: speed 45 (60), wind-up 1.1 s (0.9), cooldown 2.6 s (2.2), recovery 0.4 (0.3), poise 3 (2), and its arrow staggers the hero 0.35 s (0.25). The elite ×2.5 / ×1.5 on top gives L3 (Mesa) HP 450 and a 50-damage hit: 4 arrows kill either build's hero, and the hero needs 8 (STRENGTH) / 9 (SKILLS) hits; both builds win (D668 [3], before the oath). Bestiary "Heavy Archer" / "Важкий лучник" after the Desert Archer; voice pitch 0.9. |
| D694 | ROUTINE CALL | **A big archer aims down from its drawn bow** (D652, D386). A big archer's bow is drawn above the head of a standing hero (the heavy archer's arrowhead is 16 px above the hero's 40-px body), so a level arrow from the bow would never hit. `ArcherEnemy.max_tilt` (0 = level, as every ordinary archer still shoots): above 0, the arrow is aimed from the arrowhead at the centre of the hero's body, clamped to ±max_tilt px per px of flight. The heavy archer has 0.25; at 170–380 px that is 0.09–0.21. `Arrow.fall` carries it: the arrow moves along (direction, fall), its sprite and tip are rotated to the line, and a parried arrow flies back along the same line (`fall = -fall`), so it hits the archer's tall hurtbox. Block, parry, roll and jump work as against the level arrow (`verify_archer` [10]). The archer still shoots only when the hero is within `same_height` (48 px) of its height. |

## Proposed rows (for the orchestrator)

- **B (art), heavy archer hurt frame:** frame 12 of `Enemies/archer_heavy/sheet.png` keeps a brown scrap of background in
  its top-right corner (around x 72–96, y 0–40 of the cell). It is used as the `stagger` pose, so the scrap shows for the
  length of every stagger. The PNG is left alone as briefed. The hurtbox is measured from idle+walk, so the scrap does not
  touch any hit shape. Fix: clean the corner (or regenerate that frame) in comfy_sprite.
- **B (art), heavy archer frame 9:** the "arrow just loosed" frame is drawn facing **left** (the archer turned round, bow
  pointing left). The attack goes 8 → 10 and skips it. Fix: regenerate or mirror frame 9 and put it back between 8 and 10.
- **Q (D582), non-blocking:** DesertRoad has one archer place, the Mesa second wave (shield-bearer in front, archer
  behind). That place is the D682 big slot, so the road now has **no ordinary archer**: the hero meets archers first as
  the elite heavy archer, at level 3, in a pair. The ordinary desert archer first appears at CityGates. D582 wants each
  new kind, the elite included, to come alone first. Today the road's lone-elite fight (`Fight_LoneElite`, the bandit
  brute's slot) waits for the brute's art, and it stands at x 4480, after the Mesa (x 3070). Default kept: the D682
  placement as is. Options for Sapega: (a) keep it, since the heavy archer is the archer's lesson with heavier numbers
  and the D668 check says both builds win at L3; (b) turn the Mesa slot back into an ordinary archer and put the heavy
  archer in a later, optional fight; (c) add a lone ordinary archer before the Mesa.

## Placements (task 2) and D582

| Slot (big_kind = heavy_archer) | Fight, level | Spawns now | D582 |
|---|---|---|---|
| `DesertRoad/Fight_Mesa/BigSlot_HeavyArcher_4` (spawn_id `Fight_Mesa_EnemySpawnPoint4`, x 3070) | Mesa, enemy_level 3, waves of 2: tank+jackal, then shield-bearer + heavy archer | `heavy_archer` (medium, elite) | The pair matches "shield-bearer in front, archer behind". The elite does not come alone first, see the Q above |

That is the only slot (`verify_enemy_variety` [3] lists 12 slots, and this is the one heavy archer). The Laboratory has
no archer slot.

## What changed (files)

- `Resources/Data/enemy_variety.json`: `kinds.heavy_archer` replaces `heavy_crossbowman` (sheet `archer_heavy`, scene).
- `Scripts/Gameplay/EnemySpawnPoint.gd`: the `big_kind` enum value `heavy_archer`.
- `Maps/DesertRoad.tscn`: `BigSlot_HeavyCrossbowman_4` → `BigSlot_HeavyArcher_4`, `big_kind = "heavy_archer"`.
- New: `Scenes/Characters/Enemies/enemy_heavy_archer.tscn`, `Resources/Enemies/enemy_stats_heavy_archer.tres`,
  `Assets/Characters/Enemies/archer_heavy/sheet.png.import`.
- `Scripts/Gameplay/Characters/Enemies/ArcherEnemy.gd`: `max_tilt`, `_tilt_to`. `Scripts/Combat/Arrow.gd`: `fall`.
- `Resources/Data/bestiary.json`, `Translations/en.po`, `uk.po` (after the Desert Archer), `sound_events.json` (pitch).
- Tests: `verify_enemy_variety` (PLANNED renamed; new heavy-archer block in [2]; the Mesa slot in [3]), `verify_hit_areas`
  ([1] the new scene; it shoots arrows, so it has no strike check), `verify_difficulty` (`KIND_NAMES`), `verify_archer`
  ([8] spawn from a BigSlot point, elite, bestiary, journal, pitch; [9] the drawn frame, arrow from the arrowhead, above
  the hero's head, aimed into his body, flies down nose first; [10] hit, parry, jump against it).
- New capture `UI/capture_heavy_archer.gd` → `design/shots/big_archer/mesa.png`.

Merge notes for the siblings: the touched shared lines are the `heavy_*` line of `enemy_variety.json`, the `big_kind`
enum line, `PLANNED`/`bases` in `verify_enemy_variety`, the voice-pitch line and `KIND_NAMES` (a new line).

## Results

- `verify_enemy_variety`: RESULT: ALL PASS.
- `verify_hit_areas`: RESULT: ALL PASS (`enemy_heavy_archer: hurtbox [P: (-34.8, -73.2), S: (79.2, 102.0)] = drawn body`).
- `verify_difficulty`: RESULT: ALL PASS. Rows `elite heavy archer L3`: STRENGTH hero HP 140, hit 50 (45 taken), H 4,
  e.HP 450, N 8, wins. SKILLS hero HP 166, H 4, N 9, wins.
- `verify_archer`: RESULT: ALL PASS. The arrow starts at (681, 328) for a bow at (680, 328), tilt 0.12, and reaches the
  hero at y 364 = his body centre. The hero loses 36 HP (elite damage at level 1 in the test room), and the parried
  arrow hits the heavy archer (375 → 339).
- Full suite: SUITE_DETAIL
- Shot `design/shots/big_archer/mesa.png`, four panels: (1) the Mesa second wave, with the hero, the shield-bearer in
  front and the heavy archer behind, visibly a head taller; (2) the draw (frame 8) with the yellow glint on the
  arrowhead; (3) ×3 zoom on the drawn bow and glint; (4) the arrow in flight, tilted down past the shield-bearer toward
  the hero, and the archer in his recovery frame.
