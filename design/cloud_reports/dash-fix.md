---
type: report
status: partial
tags: [cloud, combat, movement, dash]
---

# Cloud report — `cloud/dash-fix` (2026-10-26)

- **Done:** a dash started on the floor now falls under normal gravity once it leaves a ledge or a step (keeps its
  horizontal speed); a dash started in the air (D264) stays level. New `verify_dash.gd` covers (a) step, (b) air, (c) flat.
- **Not done: no test was run.** The sandbox refused to execute the downloaded Godot 4.6.2 binary (ROUTINE_RULES setup 2),
  so `verify_dash`, the touched verifies and the full suite are **unrun**. Run before merging:
  `Scripts/Tools/run_verify.sh dash`, `souls_combat`, `combat_flow`, `combat_player`, then the full suite.
- **D-ID (next free, D713):** *D713 — A dash keeps the state it started in: started in the air it flies level (D264); started
  on the floor, it falls under normal gravity once it leaves the floor, at full dash speed. Sapega 2026-10-24 playtest:
  «коли я роблю деш на ступеньці, то я парю в повітрі».* B row (next free, B149): "Ground dash off a ledge/step hovers
  level instead of falling" — fixed here.
- **Full suite:** not run (see above).

## Fix

`SampleProject/Scripts/Player/Components/PlayerMover.gd` (branch from `origin/feature/backlog` @ `65e13520`):
- new `var air_dash: bool` next to `roll_direction`;
- `start_roll()` sets `air_dash = not player.is_on_floor()` after `roll_time_left` is set;
- `physics_move()`, `is_rolling()` branch: `velocity.y = 0` only when `air_dash and not player.is_on_floor()`.
  Otherwise `_apply_gravity_and_track_fall()` (which already runs every frame before this branch) adds gravity, so the hero
  falls; `velocity.x` is still `roll_direction * roll_distance / roll_duration`. A chained second dash started in the air is
  an air dash and stays level, as D264 designs it.

Callers of `start_roll` / `is_rolling` checked — none depend on vertical motion, nothing else changes:
- `Player.gd:138` (Roll animation not interrupted), `:206` `_try_roll()` (combat cancel, roll buffer) — unchanged.
- `Player.gd:257` no attack while rolling; `WeaponView.gd:124` weapon hidden while rolling; `CombatTraining.gd:113` lesson 1.
- Invulnerability `player.set_invulnerable(true, roll_length)` and `_pass_through_enemies()` — untouched.
- `roll_factor()`: Light Feet `passive_value("roll_length")` (D535), `Charms.effect(&"roll_length")`,
  `ArmourWeight.roll_length_of()` (D592) — only change duration, untouched.
- Existing verifies that touch the dash: `verify_souls_combat.gd:537` ("an air dash is level") still holds since that dash
  starts in the air; `verify_combat_flow`, `verify_combat_player`, `verify_equipment:167`, `verify_skill_rules:343`,
  `verify_ladders:91`, `verify_bow:358`, `verify_archer`, `verify_combat_feel` check timing/state only.

## verify_dash.gd

`SampleProject/UI/verify_dash.gd`, DesertRoad `Arrival_Start`, enemies and section fights off:
- **[c]** ground dash on flat floor: distance within 12 px of `roll_distance × roll_length / roll_duration`, y unchanged.
- **[a]** a 200×16 px StaticBody2D step whose right edge is 2 px ahead of the hero's body; ground dash right: leaves the
  floor, y grows every airborne frame, `velocity.x` stays the dash speed, lands on the real floor while still dashing
  (16 px fall ≈ 11 frames + ~1 to clear the edge, dash = 18 frames).
- **[b]** jump, dash in the air: `air_dash`, y within 0.5 px for the whole dash.

Unrun — tolerances (12 px distance, 1.5 px landing) are estimates; adjust if the first run disagrees.

## Dash art — where to swap the frames

The `Roll` animation exists in **one place**: `SampleProject/Player.tscn`
- textures `ext_resource` ids `roll1`–`roll6` → `res://SampleProject/Sprites/Player/Roll/1..6.png` (lines 27–32);
- `[sub_resource type="Animation" id="Animation_roll"]` (line 280, length 0.3, 6 keys every 0.05 s, plus a
  `Sprite2D:offset` track) in the default library `AnimationLibrary_player` (`&"Roll"` at line 1422).

No weapon library has a Roll: `AnimationLibrary_sword` (1381) and `AnimationLibrary_bow` (1371) in Player.tscn and
`Resources/Player/WeaponAnimations/{dagger,mace,polearm,dual_sword_dagger}.tres` all have 0 matches, so
`Player.body_animation()` (Player.gd:283) falls back to the base `Roll` for every weapon. Swapping the new
`Sprites/Player/Dash/` frames into those six ext_resources (and the key times if the count differs) changes the dash
for every weapon. The call sites play `&"Roll"` (Player.gd:207–208); renaming the animation would also mean those
and the capture scripts that reference `Roll`. Note the animation is 0.3 s while Light Feet/charms/armour stretch the
dash; it is not looped, so the last frame holds.
