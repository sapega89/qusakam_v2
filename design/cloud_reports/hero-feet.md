---
type: cloud-report
branch: cloud/hero-feet
date: 2026-10-27
tags: [cloud, art, hero, enemies, npcs]
---

# Cloud report: hero-feet: the drawn feet stand on the floor

**Summary**
- **Done:** the hero's drawn feet sit on his collision bottom within 1 px in every standing frame. `Sprite2D` and `WeaponMount` are at (0, −13.5), with per-key offsets for the run bob and weapon frames. Attachments move with him; he now sits on the D764 slab.
- Ground enemies were 12–13 px low too: `Sprite2D`, `hitbox` and `Hurtbox` lifted 12.5. Bosses: 5/5/3.5. NPCs: gate_scribe and oath_witch. Flyers and boxes are unchanged.
- **Proposed D-ID:** «D-new» below. **B rows fixed:** none. B candidate: a save point without `Seat` (`SavePoint.gd:62`, pre-existing).
- New check `verify_hero_feet` (211 frames). Probe `probe_character_feet` (table below). Shot `design/shots/hero_feet.png`.
- Full suite once at the end: `SUITE: 6 FAIL`. companions and weapon_animations were from this change: fixed, re-run ALL PASS.
  city_gates_raid passed on re-run (flake). progression, save_load and save_load_room fail the same way on feature/backlog.

## D-new (proposed; Sapega 2026-10-27, his answer to the depth-film Q)
| D-new | DECISION (answers depth-film «Proposed Q») | **The drawn feet stand exactly on the floor** (Sapega 2026-10-27: «підняти спрайт, щоб ноги стояли точно на підлозі»). The hero's drawn feet (the lowest row of toes or boots, an in-frame weapon excluded) meet the bottom of his collision box within 1 px in every standing frame of every body animation. The fix moves the drawing, never the box: `Player.tscn` `Sprite2D` and `WeaponMount` at (0, −13.5) (`Player.visual_base`), plus per-key `Sprite2D:offset` where a frame's feet sit off row 56 (the artist's run bob, generated weapon frames). Whatever is drawn against the hero moves with him; whatever stands on the floor (landing dust, ground markers) sits at the collision bottom. In road rooms the walk line stays the band's middle (D559). Ground enemies and bosses get the same treatment: `Sprite2D`, `hitbox` and `Hurtbox` lifted together (default_enemy 12.5; lab_boss / scorpicore 5, djinn 3.5), flyers not. `verify_hero_feet` checks the hero, and `probe_character_feet` measures enemies and NPCs. |

## Root cause
- Hero frames are 64×64 (artist) or 96×96 (weapon library, `Sprite2D:offset` (0, −16)) with the feet on row 56 of
  the 64 cell (README; comfy-sprite). The Sprite2D is centred at the body origin, ×1.5, so the bottom edge of row 56
  is at (57 − 32) × 1.5 = **+37.5 px**. The collision box `RectangleShape2D_yj7bn` 24×40 at (0, 4) ends at **+24**.
  The gap was 13.5 px of world space. depth-film measured 11–12 because it looked at rendered screens.
- Per frame, with the feet measured from the toes or boots and the weapon excluded: the artist's `Run/1–8` and
  `Walk/2` dip 1–2 rows below row 56 (his bob), and so do the punch frames that reuse them (`Attack`, `AttackThrust`)
  and every `<weapon>/Run`. Generated weapon frames stand 1–6 rows above it: halberd `CombatIdle`, `Block`, `Heavy`,
  `Attack2/3`; sword `Attack1/3`, `Attack3/3`, `Heavy/3`; dual `Attack1/3`, `Heavy/3`; mace `Attack1/3`, `Attack3/3`.
  Roll (Dash 1–3), Land, Block, Hurt, casts, Raise and Idle all sit on row 56. Jump, Apex, Fall, Climb and Meditate
  are not on the floor and are listed but not checked.
- The feet measure (`verify_hero_feet.feet_end`) is the lowest opaque row that is neither a weapon key colour
  (`weapon_palettes.json` key) nor next to one. In a weapon frame the toes (skin colours plus one outline row) win
  when they sit 1–5 rows above that row, because there the halberd shaft, mace head or sword-tip outline is lowest.
  Every outlier was checked by eye on 4× crops.

## Changes (file:line)
- `SampleProject/Player.tscn:1622,1627`: `Sprite2D` and `WeaponMount` at (0, −13.5). There are 25 offset tracks with
  per-key values in `Player.tscn` (`Attack`, `AttackThrust`, `Run`, `Walk`, `bow/Run`, `sword/Run|Attack1|Attack3|HeavyStrike`)
  and in `Resources/Player/WeaponAnimations/{dagger,dual_sword_dagger,mace,polearm}.tres`.
- `Scripts/Player.gd:43` `visual_base`; `:298` `set_visual_offset` adds it, so the D764 hop is relative to the lifted
  drawing. `SavePoint` is unchanged. `:470` level-up burst.
- `Scripts/Player/Components/WeaponView.gd:328` adds the smear at `position +` (the mount), and `:367`
  `drawn_swing_rect` does the same. The hero's hitbox (B128, built from the drawn smear) moves up with the drawing.
- `Scripts/Player/Components/PlayerCombat.gd:563` the arrow leaves from `visual_base + ARROW_FROM`.
- `Scripts/Systems/VFXHooks.gd:184` places the hit impact at the drawing's height, `+ Sprite2D.position.y`, for the
  hero and for enemies. `:251` the parry spark starts from the drawn hero.
- `Scripts/FX/DamageNumbers.gd:43` puts numbers above the lifted drawing. `Scripts/Gameplay/Characters/Companions/CompanionAssist.gd:246`
  does the same for stun stars.
- `UI/Tokens/UITokens.gd` `BUBBLE_OFFSET_Y` −56 → −70: the hero's speech bubble keeps its gap over the head.
- `Scripts/Gameplay/Characters/Companions/CompanionAssist.gd:33` sets `HERO_FEET` 36 → 24. The comment called 36 a
  workaround for feet drawn about 13 px below the box. The knockback puff now sits on the enemy's collision bottom.
- Scene markers: `Scenes/FX/LandingDust.tscn` y 37 → 24 (it was the old drawn feet; now the floor). `Scenes/FX/Skills/OathSkill.tscn`
  `CastPalm`, `CastFire`, `CastStorm`, `Hand`, `ArcEdge` and `Centre` move −13.5. `GroundFront` and `Feet` stay at
  24, on the floor. `HealingPalm`, `FireStrike` and `ElectricStrike` move their nodes −13.5, including the
  `Aura:position` and `Crescent:position` keys.
- Enemies: `Scenes/Characters/Enemies/default_enemy.tscn:161,175,188` put `Sprite2D`, `hitbox` and `Hurtbox` at
  (0, −12.5). The flyers `enemy_bat`, `enemy_fly`, `enemy_vulture` and `enemy_old_vulture`, and `brass_collector`
  (+2.0, within 2), are overridden back to 0. `fire_djinn` is at −3.5; `lab_boss` and `scorpicore_warrior` are at −5.
  `Scripts/Gameplay/DefaultEnemy.gd:255` makes `_grow` scale the areas about the feet, area offset included.
  `EnemyView.weapon_point` (archer arrows, tells, foam) already adds `sprite2d.position`.
- NPCs: `gate_scribe.tscn` `Sprite2D.offset` −43 → −41 and `oath_witch.tscn` −43 → −47.
- Tests: new `UI/verify_hero_feet.gd`. `UI/verify_bow.gd`: the bow offset may be −16 ±2 (the run keys), and the arrow
  start includes `visual_base`. `UI/verify_weapon_animations.gd`: the combat-idle offset may be −16 ±6.
- Tools: `UI/probe_character_feet.gd` (the table below) and `UI/capture_hero_feet.gd` (before/after crops).

## Enemies and NPCs: drawn feet against the collision bottom
Lowest opaque row over the idle and walk frames, against the root `CollisionShape2D` bottom. NPC areas end at the
origin. px of the node.

| scene | before | after | note |
|---|---|---|---|
| default_enemy, enemy_archer, enemy_fast, enemy_shield | +12.5 | 0.0 | lifted 12.5 |
| enemy_armoured_scorpion, enemy_heavy_archer, enemy_tank | +12.8 | +0.2…+0.3 | lifted 12.5 |
| enemy_jackal_cursed | +13.0 | +0.5 | lifted 12.5 |
| enemy_bandit_brute, enemy_jackal_pack_leader, enemy_tower_shield_guard | +12.0 | −0.5 | lifted 12.5 |
| enemy_bat / enemy_fly / enemy_vulture / enemy_old_vulture | −3.2 / +13.2 / +14.0 / +29.0 | same | flyers (`flying = true`): no floor contact, not changed |
| brass_collector | +2.0 | +2.0 | within 2 px, not changed |
| fire_djinn | +3.5 | 0.0 | lifted 3.5 |
| lab_boss, scorpicore_warrior | +5.0 | 0.0 | lifted 5 |
| giant_scorpion | (Node2D, no body) | — | decor/boss art without a collision body, not measured |
| companions (alisia, astrit, guard, urizen), assist_cat | +1.5 vs origin | same | within 2 px |
| assist_coin | −3.0 vs origin | same | a flying coin, not a standing figure |
| blacksmith, gate_guard, grandfather, lab_alchemist, lab_malik, lab_prisoner, merchant, oath_dervish, oath_priest, townsfolk_* | 0.0 | 0.0 | — |
| gate_scribe | −3.0 | 0.0 | offset −43 → −41 |
| oath_witch | +6.0 | 0.0 | offset −43 → −47 |
| townsfolk.tscn | frames set at runtime | — | its variants above are 0.0 |

Observation, not changed: `oath_witch.tscn` draws `NPCs/contract_priest/sheet.png`, while an `NPCs/witch/` folder exists.

## Tests (RESULT lines)
Run before the full suite, on this branch:
- verify_scripts_compile, hero_feet, combat_flow, souls_combat, ladders, canyon_exit (the Canyon meditation), hit_areas,
  skill_fx, combat_player, hero_motion, bow, companions, weapon_animations: **ALL PASS**. bow, companions and
  weapon_animations pass after the fixes above.
- verify_progression **4 FAIL** (`pose: Jump`, the save screen does not open: NullState) and verify_save_load_room
  **2 FAIL** (the save point does not open the save screen; B82 position). Both fail **identically on untouched
  `origin/feature/backlog`** (run with the changes stashed), so they are pre-existing, not from this change.
- Full suite (`Scripts/Tools/run_verify.sh`, 133 scripts) once, at the end: `SUITE: 6 FAIL`.
  - verify_companions «Алісия's feet on the hero's foot line (397.5 vs 384.0)»: a companion stood on the old drawn feet
    (`CompanionAssist.HERO_FEET` 36). Fixed: 24, the collision bottom the hero now stands on. The knockback puff under
    an enemy now uses that enemy's own collision bottom. Re-run: **ALL PASS**.
  - verify_weapon_animations «combat idle: polearm/Idle … 96×96 offset»: the check wanted exactly (0, −16), and the
    halberd idle is now −12 (feet planted). The check now allows −16 ±6 (the feet keys). Re-run: **ALL PASS**.
  - verify_city_gates_raid «the hero falls after the teleport (y 360.0 -> 360.0)»: passed on re-run with this change
    in place. A timing flake.
  - verify_progression (4), verify_save_load (2: «interact opens Save Slot Selection (NullState)»; `SavePoint.gd:62`
    reads `$Seat` on a save point without a `Seat` marker) and verify_save_load_room (2): **pre-existing**. They give
    the same FAIL lines on `origin/feature/backlog`: progression and save_load_room with the changes stashed,
    save_load in a clean worktree of feature/backlog. B candidate for the orchestrator: the save point these tests
    use has no `Seat` (D764), so `_meditate` stops before the save screen.

## Shots
`design/shots/hero_feet.png` shows DesertRoad (a road room, D559 band) and LabBoss (flat `Surfaces` top), before and after,
×2 around the hero. Before: the feet sink 13.5 px into the walkway. After: they stand on its top edge. Also checked
on `capture_meditation_spots` (not committed): the seated hero used to sit in front of the slab and now sits on it (D764).

## Notes and limits
- Collision boxes (hero, enemies) are unchanged. The hero's drawing now rises 32 px above his box top (head
  −48 against −16), as before only more. Hits on him still land on the box.
- The hero's attack hitbox, built from the drawn smear (B128), and the enemy hit/hurt areas move up with their
  drawings. That keeps drawing and hit area together, and it is why the bow's pierce test passes again: the lifted
  arrow would otherwise fly over the unlifted short enemies.
- The weapon overlay pivots (`HAND_*`) are not keyed per frame. In run frames the hand may sit 1–2 texture px off
  the overlay. With the weapon libraries the overlay is hidden, because the weapon is drawn in the frame.
- Rooms that place enemies with their own Sprite2D overrides were not checked one by one.
- Importer sidecars (`meditation_spot.png.import`, a few `.uid`) and `heavy_battle.mp3.import` are left uncommitted.
