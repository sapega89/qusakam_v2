---
type: report
tags: [cloud, routines, combat, bosses]
---

# boss-fix — «боси не б'ють» (B154)

**Summary.** Done: the root cause is found and fixed in `BossLogic.gd`. Both bosses (the LabBoss mercenary and the MayorHall Scorpicore axe-warrior) now swing their weapons and land hits, and the new `verify_boss_hits` covers it. Only the slam's shockwave ever hit before.
The cause: between moves the boss rested up to 90 px from the hero, outside its own combo reach (72 / 69 px). So the pattern always replaced combo with a slam or drink that reaches farther. The Scorpicore charge fired from up to 600 px, but its line is only about 387 px, so it stopped 4 px short.
B row fixed: **B154** (text below, for the orchestrator to put in `BUGS.md`; per ROUTINE_RULES this routine does not edit it). No new D-ID: the fix follows D504/D522 as written.
Not done: no balance tuning, no `Maps/*` edits. Brass collector and fire djinn are not used by any room; `verify_bosses` still passes for them.
Full suite: **114 / 124 PASS, 10 FAIL**. None of the 10 is in boss code: 2 pass on a rerun (`audio`, `camera_transitions`), 2 fail the same way on the base code (`enemy_fx`, `npc_arrival`), and 6 fail in UI and dialogue areas this routine did not touch (see the end).

## B154 (for `design/BUGS.md`)

> **Fixed 2026-10-26 (`cloud/boss-fix`):** **B154** — Sapega's playtest of the round-13 build: «боси не б'ють». In both boss fights, started through the room, the boss never used its weapon. The LabBoss mercenary did slam → drink → slam, and the MayorHall axe-warrior did a charge that stopped short, then slams. Only the floor shockwave hit a hero who stood still, and a hero in the air or out of its radius was never hit. Root cause in `BossLogic.handle_attack_state`: between moves the boss rested at `preferred_range` ± `PREFERRED_BAND` (60 ± 30 px). That is outside its combo `max_range` (72 / 69 px). When ready, `_fits_any` accepted the far-reaching slam/drink, so `pick_move` skipped the combo every time. The charge `max_range` was 600 px, but its line (D522) is `distance` + `melee_reach` ≈ 387 px. Fix: the rest band ends at the reach of the move the boss rests for (`_rest_reach`). When the next pattern move is out of reach, the boss walks in (`_must_close`); only a charge may stand in, because it closes the gap itself. A charge fits only within its line (`_reach`). `verify_boss_hits` (new), `verify_combat_enemies` [10] (Brass «only charge» distance 400 → 360, plus 420 px = no move).

## How it was found

`verify_boss_hits` drives each fight the way a player does: new game → `teleport_to_room(hall, Arrival)` → real `move_right` → the cutscene to `FIGHT` (dialogue accepted). Then the hero stands still. A 20 s trace on the old code, with hitbox monitoring, hitbox rect, hero x and overlaps logged on every attack frame, showed:

- LabBoss: `slam` at dx 198, `drink` 156, `slam` 114, `drink` 90, `slam` 90 — no combo in 20 s. It parks at dx 90 (err = 30, not > PREFERRED_BAND).
- MayorHall: `charge` from dx 415, hitbox live and travelling 320 px, ending at dx 83. The hitbox front was at x 383 − 67 = 316 and the hero's body edge at 312, so it missed by 4 px. Then `slam`, `slam`, `slam`, parked at dx 83.

Ruled out along the path: the attack token (`BossLogic.token_free` is always true), the post-cutscene state (both reach ATTACK: LabBoss via `on_player_detected`, MayorHall via IDLE → CHASE), move names (all in the `match`), damage scale (180 / 120 base, `_apply_variety` skipped for bosses), collision layers (the hitbox's monitoring and `DamageApplier` are live, target group `player`, the slam's damage arrived), and hero i-frames (the slam hits arrived every 3–5 s). B128 shapes are fine: at the combo `max_range` the hitbox front (67.5 px) covers the hero's body edge (dx − 12).

## Change

`SampleProject/Scripts/Gameplay/Characters/Bosses/BossLogic.gd`
- `handle_attack_state`: the rest band's far edge is `min(preferred_range + PREFERRED_BAND, _rest_reach())`.
- `_rest_reach()`: the shortest reach among this phase's moves that still reaches from `preferred_range`: the combo for the mercenary and the axe-warrior, the fireball for the djinn, which keeps its 300 px.
- `_fits_any(dx)`: if `_must_close(dx)` (the next pattern move, skipping an immediate repeat, reaches from `preferred_range` but not from here, and there is ground to step on), only a charge may start. Otherwise the boss walks in at full speed.
- `_reach(move)`: a charge reaches `distance + melee_reach` (the danger line its tell draws, D522), capped by `max_range`.
- `pick_move` is unchanged: the pattern is still a pure function of distance, phase and the last move. `verify_combat_enemies` [10] keeps its sequences.

## Results

New verify, old code vs new (same verify file):

| | old code | fix |
|---|---|---|
| LabBoss | `slam, drink, slam`; hits only from the shockwave; **FAIL** weapon | engaged 6.3 s → `combo` hits at 9.3 s ✅ |
| MayorHall | `charge` (short), `slam` ×3; **FAIL** hit within 4 s of engaging, **FAIL** weapon | engaged 2.0 s → `charge` hits at 3.8 s ✅ |

- `verify_boss_hits` RESULT: ALL PASS (old code: 3 FAIL)
- `verify_bosses`, `verify_lab_boss`, `verify_mayor_boss`, `verify_mayor_hall`, `verify_combat_enemies` RESULT: ALL PASS

LabBoss engages at 6.3 s because the hall is wide: the mercenary walks about 450 px at 70 px/s. That walking speed belongs to B-pace (`hard-fights-2`), not to this bug.

## Full suite (`Scripts/Tools/run_verify.sh`, 2026-10-26/27)

`SUITE: 10 FAIL` — 114 / 124 PASS. Each failure was re-run on its own:

| verify | on its own | on base `origin/feature/backlog` (BossLogic reverted) | note |
|---|---|---|---|
| `audio` | ALL PASS | — | flaky in the suite |
| `camera_transitions` | ALL PASS | — | timed out in the suite (180 s) |
| `enemy_fx` | 2 FAIL (archer: no `enemy_struck`, no smear; `Arrow.gd:131` EventBus compile error) | same 2 FAIL | round-15 `enemy-fx`, built without Godot |
| `npc_arrival` | 10 FAIL (D454 / D735 menus, barks) | same 10 FAIL | round-15 `ui-critic` |
| `gamepad_parity` | 1 FAIL (footer key A (ENTER)) | not run | UI, not touched here |
| `onboarding` | 4 FAIL (banner, arrow) | not run | UI, not touched here |
| `tasks` | 1 FAIL (list opens with both tasks) | not run | UI, not touched here |
| `dialogue_speaker` | 3+ FAIL (name not shown) | not run | dialogue UI, not touched here |
| `tutorial_hints` | FAIL (banner text "Tutorial hint goes here...") | not run | UI, not touched here |
| `save_load_room` | no RESULT line | not run | no output in 240 s |

The boss change touches only `BossLogic.gd`, which none of these load as a boss. The boss and combat verifies all pass (above).
