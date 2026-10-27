---
type: report
tags: [cloud, routines, hero, animation]
---

# hero-death (cloud routine, 2026-10-27) — H1

**Summary.**
- Done: the Death animation is wired into the game (D138, H1). When the hero dies he plays Death 1–4 once (0.15 s per frame), then holds frame 4 for 0.3 s, so the whole pose takes 0.75 s. His controls are off for it, the weapon is hidden (both the Pivot and the in-frame weapon libraries) and the body falls to the floor if he died in the air. After that comes the existing Game Over / respawn flow, unchanged. A respawn (`kill()`) puts him back on his feet and gives him control again.
- Not done: nothing from the task. A story defeat (`defeat_handler`, D301/D302: Lab Boss, Mayor Hall) deliberately plays no Death pose (see the D-ID below).
- **D-ID text (new, orchestrator to number):** «**The hero's death pose (H1, answers D138's Death row).** A death plays `Sprites/Player/Death/1–4` once, 0.15 s each, and holds frame 4 for 0.3 s (0.75 s in all). For that time the controls are off, any action that was running is broken (`PlayerCombat.stop_all`), the weapon is not drawn, he lets go of a ladder and the body falls to the floor. The blob shadow (D788) stays under the body. Every death frame keeps its feet on the collision bottom (D787, offset 0). Game Over (or the old respawn) comes only after the pose. A lost story fight (`defeat_handler`, D301/D302) is not a death: the room's cutscene runs at once, as before. `verify_hero_death` checks it; `design/shots/hero_death.png` shows it.»
- B rows: **B184** (Death frames 1 and 3 redrawn) can now be seen in the game in `design/shots/hero_death.png`. The row stays open until Sapega has looked at it.
- Full suite: **`SUITE: 3 FAIL`, 136 PASS**. None of the three comes from this change: `verify_masher` hung (it hangs in every suite); `verify_camera_rooms` passed when run alone; `verify_combat_feel` [2] is flaky on the base too (details below).

## Code
- `SampleProject/Player.tscn`: four `ext_resource`s (`death1..4`), `Animation_death` (length 0.75, keys 0 / 0.15 / 0.3 / 0.45, `Sprite2D:offset` (0, 0)), and `&"Death"` in the base library. The weapon libraries have no Death clip, so `body_animation` falls back to the base frames and no weapon is drawn in the frame.
- `SampleProject/Scripts/Player.gd`: `death_left`. `die()` now sets `event`, calls `combat.stop_all()`, lets go of the ladder, ends a roll and plays Death. `_dying()` runs in `_physics_process` before the `event` return: the mover is locked, gravity still applies and `kill_cooldown` keeps ticking. `_after_death()` holds the old tail of `die()` (Game Over, else `kill()`). `kill()` resets `death_left` and `event` and plays Idle.
- `PlayerCombat.stop_all()`: `_break_action()` + `cancel_attack()`, and clears held_by, block/shot held and the input buffer.
- `WeaponView._process`: `pivot.visible` is false while `player.is_dead`.

## Tests (RESULT lines)
- `verify_hero_death` (new): **ALL PASS**. Checks: frames [1, 2, 3, 4] once; frame 4 held under the Game Over screen; move_right held during the pose → 0.0 px; weapon hidden for the whole pose (it was drawn before, with an iron sword in hand); shadow on the floor under the body; Game Over at about 0.9 s (0.75 s of pose plus frames), not before; Death lasts 0.75 s with no loop; after `kill()` the hero is alive and in control with full HP, stands up again, shows the weapon and can walk; a death 80 px in the air → he lies on the floor in frame 4, with the shadow under him.
- `verify_hero_feet`: **ALL PASS** (Death keys 0–3: feet +0.0 px from the collision bottom).
- `verify_hero_shadow`, `verify_scripts_compile`, `verify_game_over`, `verify_tips_once` (the hero dies, then Resume): **ALL PASS**.
- `verify_combat_flow` has no hero-death checks (only enemy deaths), so the new script covers them.
- Full suite (`Scripts/Tools/run_verify.sh`, 139 scripts, once at the end): `SUITE: 3 FAIL`.
  - `verify_masher`: HUNG at 180 s, as in every suite (integrate-29: the same; B170).
  - `verify_camera_rooms`: 1 FAIL in the suite («City inside: the camera moves at most 31.7 px more than the hero in a frame»). **ALL PASS** when run alone, so it is a timing flake in the suite.
  - `verify_combat_feel` [2] «a bandit dropped on the hero slides off to the floor (y 327.9 vs 368.0)» is a flake that was there before this change. On this head it failed 2 of 5 runs. On the base `159dd122` (integrate-29 + feature/backlog, without the H1 files) it failed 2 of 4 runs, with the identical line. integrate-29's suite had the same line too. It is not fixed by `8f5660c8`; it needs its own B row (the bandit sometimes stays on top of the hero).

## Capture
- `SampleProject/UI/capture_hero_death.gd` → `design/shots/hero_death.png` (1×5, DesertRoad: before with the sword drawn, then Death 1–4). The software renderer under xvfb is too slow for 0.15 s frames, so the capture slows time to ×0.01 and seeks to each key. Body, shadow and weapon state are the game's own. Seen once: the weapon is gone from frame 1 on, frame 4 lies flat on the road with the shadow under him, and the feet stay on the walk line. The red streak and «99999» in frames 1–2 are the normal hit effect and damage number from the killing blow.

## Branch
`cloud/hero-death` = `origin/cloud/integrate-29` + `origin/feature/backlog`. The merge conflicted only in `design/HANDOFF.md` and `design/MASTER_PLAN.md`, both resolved to feature/backlog's new versions. Then three H1 commits. No room scenes were touched.
