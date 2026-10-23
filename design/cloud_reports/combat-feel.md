---
type: report
tags: [cloud, combat]
---

# Cloud report: combat-feel (playtest 2026-10-23)

**Done:** B128, D443, D456, B125, D444, all five. Hit areas come from the drawn frames. Bodies block and only the roll passes through. A roll or a block cancels an attack. The boss slides off the hero. The jackal has no red line. **Not done:** none of the five; no capture was taken (headless only). A visual check with F9 on is left to Sapega.
**D-ID text:** D519 (B128 as built), D520 (D443 as built, B125), D521 (D456 as built), D522 (the boss charge keeps its line). Text below. D484 was left alone: it is a gap before D485 that another routine may hold.
**B rows fixed:** B128, B125.
**New tests:** `verify_hit_areas` ALL PASS, `verify_combat_feel` ALL PASS.
**Full suite:** SUITE_LINE

## D-ID text (for the register)

| ID | Type | Text |
|---|---|---|
| D519 | GAP | **What you see is what hits, as built (B128; agent calls, Sapega to confirm).** Every enemy kind has two shapes of its own (`resource_local_to_scene`, nothing shared), measured from its frames by `Scripts/Combat/HitAreas.gd` and mirrored with its facing (`DefaultEnemy._face_shapes`). **Hurtbox** (new `Hurtbox` Area2D, group `hurtbox`) = the opaque bounds of the `idle` + `walk` frames, weapon and cape included: bandit 70.5×75, jackal 67.5×42, scorpion 74×52, archer 66×75, Brass Collector 120×153, Fire Djinn 51×163.5. The hero's swings and arrows hit it (`DamageApplier` / `Arrow` take `area_entered` on a hurtbox as a hit on its enemy; `hit_targets` still allows one hit per swing), and skills hit it too (`SkillTargeting.enemies_in_front`). The **blocking body** stays the old torso (32×32; bosses 56×100 and 40×100). If the body were the whole drawn bounds, the bandit's own scimitar (34.5 px) could never reach past its 36-px half-width. **Attack hitbox** = the frames shown while it is live (`attack` from `attack_strike_time` for `attack_active_time`), from the enemy's centre forward: bandit 34.5 px, jackal 34.5 (+ its 60-px lunge), scorpion 40.5, Brass Collector 63 (union with `charge_strike`), Djinn 60. **`attack_range` only starts the strike** and is set where the strike lands on a hero standing still: melee 100 → **40**, tank 100 → **46**, fast stays 80. Boss `melee_reach` = the hitbox front (130 → 63, 120 → 60), combo `max_range` 130 → **69**, 120 → **66**. **Hero:** the hitbox is the part of the drawn slash trail in front of the hero's centre, as tall as the trail (`WeaponView.drawn_swing_rect` of the regular first swing; `PlayerCombat.hitbox_center`; the part of an arc that curls behind the hero does not hit, so a swing facing away misses; the finisher's bigger arc stays emphasis). From the hero's centre: bare hands 13–67 px × 10 tall, sword 0–78 × 140, mace 0–66.5 × 117, halberd 34–134 × 17, dagger 32–77 × 8. Thrusts and the punch streak are thin, so they hit a narrow band at chest height. If that feels too strict in play, it is a Sapega call (widen the drawn streaks, not the hitbox). `items.json` `weapon_profile` loses `reach` / `height` (cooldown and knockback stay). **Debug:** F9 in a debug build draws bodies (white), hurtboxes (yellow) and hitboxes (red, filled while live): `Scripts/Combat/HitAreaDebug.gd`, node `Game.tscn → HitAreaDebug`. Tests: `verify_hit_areas` [1] scenes, [2] each weapon against the actually drawn trail, hit at 3 px inside and miss at 6 px past, [3] the same for the bandit, jackal and scorpion strikes. |
| D520 | GAP | **Bodies block, as built (D443, B125; agent calls).** The D197 exception (`add_collision_exception_with(player)` in `DefaultEnemy._ready`) is gone: walking or jumping into an enemy stops the hero at its torso. **The roll** adds an exception with every enemy at its start (`PlayerMover._pass_through_enemies`). After the roll each exception is removed only once the two bodies no longer overlap (`_release_passed`), so physics never has to push them apart, which could throw one on top. **Nobody stands on anyone's head:** `CombatBody2D.slide_off_bodies(delta)` runs after every `move_and_slide()` of the hero (`PlayerMover`) and of every enemy (`DefaultEnemy`, so the bosses too). A body standing on another `CombatBody2D` (a 2-px probe below the feet, normal pointing up) moves sideways away from that body's centre at **240 px/s** until it falls off. If the sideways step is blocked (a wall, or a third body such as the hero next to a stack of enemies), it pushes the body below the other way. **Fighters are not platforms** (`platform_floor_layers = 0` in `Player.tscn` and `default_enemy.tscn`; the game has no moving platforms). Whoever stands on another fighter does not ride it, and does not inherit its velocity when it moves away. Found by `verify_kusakam_skills`: a teleported enemy launched the hero at −23 500 px/s. **B125:** the Brass Collector dropped on Kusakam slides to the floor. Its **charge** (the boss's only lunge) runs 210 px and stops at the hero's body, never through it or onto it, and it stays on the floor (rose 0.1 px). `BossLogic` has **no jump** move (combo, charge, slam, fireball, pillar), so no jump needed checking. Enemy bodies still collide with each other as before. Tests: `verify_combat_feel` [1]–[3]; `verify_combat_flow` [0b] (an enemy dropped on the hero slides off, over its neighbours, to the floor). `verify_souls_combat` [0] (the 12-s melee) no longer counts walking into an enemy's body as "stuck". |
| D521 | GAP | **Attack cancel, as built (D456; agent calls).** Cancellable: a combo swing, the heavy (wind-up and strike), a bow shot (`PlayerCombat.can_cancel_attack`). Not cancellable: a skill's wind-up and release, the stagger, the bow draw (the roll already drops the draw, D382). Roll or block pressed during a cancellable attack ends it at once (`cancel_attack`). The hitbox and damage go off, so a hit that has not landed deals nothing, and an unloosed arrow never flies. The combo starts over, and the finisher's recovery (`attack_cooldown`) is kept. The roll starts in the same physics frame (test: within 2); the block starts on the next one. **Buffer:** a roll pressed while it cannot start (stagger, skill wind-up, no dash charge, the second dash too early) waits **0.1 s = 6 physics frames** (`Player.ROLL_BUFFER`) and starts as soon as it can. The block is held, so it is buffered by holding it. I-frames, parry window and guard rules are unchanged. Tests: `verify_combat_feel` [4]. |
| D522 | GAP | **The boss charge keeps its red ground line** (agent call). D444 removes the line only from the jackal's lunge (`DefaultEnemy._on_logic_attack_telegraphed` now passes no lunge; the glint and wind-up pose stay, `verify_combat_feel` [5]). The Brass Collector's charge (`BossEnemy._on_logic_attack_telegraphed`) still draws it over `distance + melee_reach`, now 320 + 63 px. If Sapega wants it gone there too, it is one line. |

## B rows fixed

- **B128** — Hit areas do not match what is drawn → fixed (D519).
- **B125** — The boss ends up hanging above Kusakam → fixed by the shared D443 rule (D520).

## Details

- `SampleProject/Scripts/Combat/HitAreas.gd` — opaque bounds of frames (`frame_rect`, `body_rect`, `strike_rect`, `shape_rect`).
- `SampleProject/Scripts/Gameplay/DefaultEnemy.gd` — the `attack_range` sizing of the hitbox is gone; `_face_shapes`, `hurt_rect`, `slide_off_bodies` after `move_and_slide`, no D197 exception, D444 tell.
- `SampleProject/Scripts/Gameplay/Characters/Bosses/BossEnemy.gd` — no `melee_reach` sizing; `start_attack` mirrors the scene shape.
- `SampleProject/Scripts/Player/Components/WeaponView.gd` — `drawn_swing_rect`, `_smear_at`, `_smear_scale`, `_trail_rect`; `drawn_reach` removed.
- `SampleProject/Scripts/Player/Components/PlayerCombat.gd` — hitbox from `drawn_swing_rect` (with its height offset `_hitbox_y`); `can_cancel_attack`, `cancel_attack`.
- `SampleProject/Scripts/Player.gd` — `_try_roll`, `ROLL_BUFFER`; block cancels the attack.
- `SampleProject/Scripts/Player/Components/PlayerMover.gd` — `can_roll`, roll pass-through and release.
- `SampleProject/Scripts/Combat/CombatBody2D.gd` — `slide_off_bodies`, `body_rect`.
- Scenes: `default_enemy.tscn` (Hurtbox node, shapes), `enemy_fast/tank/archer.tscn`, `brass_collector.tscn`, `fire_djinn.tscn`; `Game.tscn` (HitAreaDebug).
- Data: `enemy_stats_melee.tres`, `enemy_stats_tank.tres`, `items.json`.

### Existing tests changed (placements, not expectations)

- `verify_combat_flow`: the hero 30 px from a target (bodies touch at 28), not 26; neighbours parked from [1] on (their drawn hurtboxes caught the hero's swings) and in [2c]; the tank-stats bandit test at 40 px (its strike is drawn to 34.5); the lunge from 100 px (34.5 + 60 + 12 = 106.5; it was 110), placed after the AI's 0.6-s wait.
- `verify_souls_combat`: `_dummy` parks the other enemies; the hero 30 px from the dummy; the miss at 40 px (outside the bandit's drawn cape); [3] moves the enemy off the hero's path before "control comes back"; [9] places the hero 200 px from an enemy, not inside it; [12a] compares with `drawn_swing_rect`; [0] skips frames blocked by an enemy body.
- `verify_bosses`: the combo at 55 px (it now starts at 69 / 66 px).

### RESULT lines

TEST_LINES
