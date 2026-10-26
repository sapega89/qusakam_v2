---
type: report
tags: [cloud, routines, bow]
---

# cloud/bow-wire — B110 wiring

**Summary**
- Done: `AnimationLibrary_bow` in `SampleProject/Player.tscn` now has Jump / Apex / Fall / Land / Block / Hurt, with the same names, lengths and loop modes as the base library and the sword set. Frames: Air/1–3, Block/1, Hurt/1. Land uses the bow stance frame (`Shoot/2`, the frame `bow/Idle` uses), the way `sword/Land` uses `CombatIdle/1`.
- Done: `verify_bow.gd` `_frames()` checks that with the bow in hand each of the six goes through `body_animation()`/`play_body()` to `bow/<name>`, shows a 96×96 frame from `Weapons/bow/`, and keeps the base timing.
- **Not done: nothing has been run.** This session could not download Godot 4.6.2: the auto-mode classifier denied the download. So there are **no `.png.import` sidecars** for the five new frames, and no test results: no verify_bow, no weapon verifies, no full suite.
- B110: **not marked fixed yet.** Per ROUTINE_RULES this routine does not edit `BUGS.md`. Mark it fixed once the orchestrator has run `--import` and the tests below pass. Proposed row text: «Fixed `cloud/bow-wire`: the bow library plays Air 1–3 / Block / Hurt, Land on the stance frame; `verify_bow` [1]».
- No D-ID.
- MASTER_PLAN A2 → 🔄 (wired, not checked).
- Full suite: not run (no Godot).

## Details
- `SampleProject/Player.tscn`: 5 ext_resources `bw_air1..3`, `bw_block1`, `bw_hurt1` after `bw_run6`; 6 sub_resources `Animation_bow_{jump,apex,fall,land,block,hurt}` right before `AnimationLibrary_bow`; 6 entries in that library. Nothing else in the scene changed.
- Timings (from the base and sword sets): Jump 0.2, Apex 0.18, Fall 0.1 with loop, Land 0.1, Block 0.1, Hurt 0.25. Offset is `(0, -16)`, the same as every bow frame.
- Roll and dash: none needed. WeaponView hides the weapon while dashing.

## To finish (needs Godot)
1. `$G --headless --path . --import`, then commit the five new `bow/{Air,Block,Hurt}/*.png.import` files.
2. `verify_bow`, `verify_weapon_animations` and the other weapon verifies, then `Scripts/Tools/run_verify.sh | grep -v '^PASS'`.
3. Mark B110 fixed and set A2 to ✅.
