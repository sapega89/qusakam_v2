---
type: cloud-report
branch: cloud/big-guard
date: 2026-10-24
tags: [cloud, combat, enemies]
---

# Cloud report: big-guard (the tower shield guard goes live, D652 / D693)

**Summary.** Done: `tower_shield_guard` is a live big kind. It has its own scene on the shield-bearer's behaviour, the D693 sheet `Enemies/shield_tower/sheet.png`, hit shapes measured from its frames (D519, the shield is the front block), its own stats, and a bestiary entry in en and uk. A hit from the front lands in the shield, a hit from behind lands on the body, and a heavy hit breaks the guard. The shield is drawn in the frames, so it does not fly off: after the guard-break stagger he raises it again. It is an elite by kind (D681): 550 HP / 47 per hit at level 2, 600 / 55 at level 3, 1450 / 179 at level 10.
**Not placed:** no map has a `BigSlot_TowerShieldGuard_*` slot (D682 made none), so nothing spawns it yet. I did not add one, because every shield-bearer place would break D582 (table below). The placement is a non-blocking **Q** for Sapega (below).
Tests: `verify_enemy_variety` [8], `verify_hit_areas` [1] + [3], and `verify_difficulty` (an "unplaced" meeting at the Caravan's L3 and the Laboratory Lower's L10) all pass. Capture: `design/shots/big_guard/tower_guard_lone_shield.png`.
D-IDs: **D694** (text below; the orchestrator renumbers). B rows fixed: none. Full suite: SUITE_LINE

## D-ID text (for the register; the register ends at D693, sibling routines take numbers in parallel, renumber as needed)

| D694 | ROUTINE CALL | **The tower shield guard, as built** (D652, D681, D682, D693; `cloud/big-guard`). The scene is `Scenes/Characters/Enemies/enemy_tower_shield_guard.tscn`, built on `default_enemy`, with the script `Scripts/Gameplay/Characters/Enemies/TowerShieldGuard.gd` (it extends `ShieldBearer.gd`) and `Resources/Enemies/enemy_stats_tower_shield_guard.tres`. The stats copy the shield-bearer's `enemy_stats_shield` numbers and behaviour: 200 HP, 26 damage, speed 55, a 0.8 s wind-up, a yellow (parry) tell, poise 4, 30 XP, back-off 40, `enemy_type = tower_shield_guard`. Only `attack_range` differs, 40 → **42**, because the body is wider (below). `kinds.tower_shield_guard.sheet` is now `Assets/Characters/Enemies/shield_tower/sheet.png` (it was the placeholder path `tower_shield_guard/`). The sheet is 4×5 cells of 96×96, facing right, drawn at sprite scale ×1.0 with offset (0, −13), so the feet stand at y 28 like the other big kinds: idle 0–1, walk 4–7, attack 8–10 (sword raised over the shield; the thrust past its edge from 0.5 s on frame 9; back to guard), hurt 12 (the shield knocked aside, used as the stagger pose), death 16–18. **Shapes (D519):** the hurtbox is 49×81 at (3.5, −12.5) (the idle and walk frames, x −21…28; the shield is its front part, x 2…28). The hitbox is 31×78 at (15.5, −11) (frame 9: the sword reaches 31 px, 3 px past the shield). The **blocking body is 56×32**, so its front edge is the shield's front edge (28 px). The hero bumps into the shield, not into the man behind it. The body stays centred, so 7 px of it sit behind his back. `attack_range` 42 lies between body contact (40) and the strike's reach (43). The shield point `Sprite2D/Shield` is at (16, 0), mirrored with facing. Block sparks come off it. The tell glint `tell_at` (−14, −46) is on the raised blade. **Behaviour:** as the shield-bearer (D495, D560): a hit from the front is blocked (no damage, no poise loss, sparks and a clang), and a hit in the back lands. A heavy hit from the front (`VFXHooks.hit_strength` ≥ 2) breaks the guard: `enemy_shield_broken`, a stagger of `shield.guard_break_stagger` (1.2 s) on the hurt frame, and front hits land while it lasts. **Unlike the shield-bearer, the tower shield does not fly off.** It is drawn in every frame, so when the stagger ends (and any stagger stacked on top of it) he raises it again and blocks as before. It is an elite by kind (D681): at level 2 it has 550 HP and hits for 47, at level 3 600 / 55, at level 10 1450 / 179. XP stays 30. Coins are 3–5 (the shield-bearer's), and the voice pitch is 0.8 (lower than the shield-bearer's 0.92; agent call). Bestiary: «Tower Shield Guard» / «Вартовий з баштовим щитом», en + uk. **Placement:** none. D682 made no tower-guard slot, and each shield-bearer place breaks D582 if it becomes one (see the report). The kind is live and waits for its slot. `verify_difficulty` simulates it as an "unplaced" elite at the Caravan (L3: both builds win, as D668 asks of road elites) and at the Laboratory Lower (L10: SKILLS wins, STRENGTH loses). The simulation counts raw HP and ignores the shield, so in play he is harder than the table says. |

## Question for Sapega (non-blocking, for `questions_for_sapega.md`)

**Where does the tower shield guard first stand?** D582 wants a new elite alone, somewhere safe enough to learn it. It
also wants the ordinary shield-bearer taught before him (the guard is "the shield-bearer, but the shield comes back").
Options:
(a) A new optional lone fight in the Laboratory, before Fight_Lower, guarding a reward. The hero already knows the
shield-bearer from the road by then, and the guard is the Laboratory's "learn the heavy hit and the roll" lesson. This
fits D582 best, but it needs a new spawner, a trigger and a reward (level design).
(b) Turn the Laboratory's shield-bearer (`Fight_Lower/EnemySpawnPoint2`) into `BigSlot_TowerShieldGuard_2`. This is
cheap, but Fight_Lower then holds three big kinds (armoured scorpion, cursed jackal, tower guard), and D582 rules that out.
(c) Leave it out of the demo until there is a city or fortress room with guards after the Laboratory.
Default until answered: (c), so the kind is live but has no slot.

## Placements (D582 check)

`BigSlot_*` points with `big_kind = tower_shield_guard`: **none** (all maps checked by `verify_enemy_variety` [8]).
Every place that has a shield-bearer today, and why it does not become a slot:

| Room / fight (level) | Point | Why not a slot |
|---|---|---|
| DesertRoad `Fight_LoneShield` (2) | `EnemySpawnPoint1`, alone | The road's first shield-bearer. D582 says it teaches the ordinary kind alone, so it stays ordinary. |
| DesertRoad `Fight_Mesa` (3) | `EnemySpawnPoint3` | The Mesa already holds `BigSlot_HeavyCrossbowman_4`. Two big kinds in a fight, both new, go against D582. |
| DesertRoad `Fight_Caravan` (3) | `EnemySpawnPoint4` | The Caravan already holds `BigSlot_ArmouredScorpion_1` (and big-scorpion's `verify_difficulty` [0b]). |
| Laboratory `Fight_Lower` (10) | `EnemySpawnPoint2` | It already holds `BigSlot_ArmouredScorpion_1` and `BigSlot_JackalCursed_3`. |

## What changed (files)

- `Scenes/Characters/Enemies/enemy_tower_shield_guard.tscn`: new (animations, shapes, `Sprite2D/Shield` point).
- `Scripts/Gameplay/Characters/Enemies/TowerShieldGuard.gd`: new. `break_shield` staggers him without removing the
  shield, `_raise_shield` brings the guard back after the stagger, and `_face_shapes` mirrors the shield point.
  `ShieldBearer.gd` itself is unchanged.
- `Resources/Enemies/enemy_stats_tower_shield_guard.tres`: new.
- `Resources/Data/enemy_variety.json`: `kinds.tower_shield_guard.sheet` → `shield_tower/sheet.png` (one line).
- `Resources/Data/sound_events.json`: `enemy_voice_pitch.tower_shield_guard` 0.8.
- `Scripts/Gameplay/DefaultEnemy.gd` `_calculate_coin_drop`: `tower_shield_guard` 3–5.
- `Resources/Data/bestiary.json`, `Translations/en.po`, `uk.po`: the entry.
- `Assets/Characters/Enemies/shield_tower/sheet.png.import`: the import file.
- Tests: `verify_enemy_variety` [8] (new `_tower_guard`), `verify_hit_areas` (KINDS + [3]), `verify_difficulty`
  (`KIND_NAMES`, `_tower_guard_at`, two unplaced meetings).
  **Merge note:** big-vulture adds a similar `_unplaced` helper to `verify_difficulty`, and the brute, leader and
  vulture branches also edit `KIND_NAMES` and the `[3]` area. Keep both sides. The two helpers do the same job and can
  be folded into one when merging.
- `UI/capture_tower_guard.gd`: new capture.

## Results

- `verify_hit_areas`: RESULT: ALL PASS. `enemy_tower_shield_guard: hurtbox (-21, -53) 49×81 = drawn body`, `hitbox (0, -50) 31×78 = drawn strike`, `attack_range 42 starts a strike that reaches (body contact 40, reach 43)`, `[3]` hit at 3 px inside (39 damage), not hit at 6 px past.
- `verify_enemy_variety`: RESULT: ALL PASS. [8]: blocked from the front (sparks 16 px in front), the back lands, heavy → guard broken (frame 12, 1.2 s), a front hit lands while staggered, the shield comes back up and blocks again, no slot on any map, elite at L3 600 HP / 54.6 and L10 1450 / 179.4, bestiary en/uk.
- `verify_difficulty`: RESULT: ALL PASS. The rows `tower shield guard (unplaced) L3`: STRENGTH wins (10 hits needed, survives 5), SKILLS wins (12, survives 6); `L10`: STRENGTH loses (16, survives 3), SKILLS wins (12, survives 5).
- Full suite: SUITE_DETAIL
- Shot `design/shots/big_guard/tower_guard_lone_shield.png`: (1) he walks at the hero with the shield in front, (2) the thrust over the shield's edge into the hero, (3) the guard broken: the shield knocked aside (hurt frame, staggered). He stands at `Fight_LoneShield`'s point, level 2, because he has no slot. His feet are on the same ground line as the hero's. The hero's drawn body overlaps the shield a little at contact. This is true of every enemy (the hero's 24-px body is narrower than his sprite) and is not this kind's issue.
