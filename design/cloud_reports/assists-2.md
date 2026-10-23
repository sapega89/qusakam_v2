---
type: report
status: done
tags: [cloud, companions, assists, vfx, hud, d515]
---

# Cloud report: `cloud/assists-2` (2026-10-23)

**Summary.** All of D515 is built. Every assist is now a full sequence of about 2.7–3.4 s: entrance (run in or drop in), wind-up glow, the signature action, a held pose, then the exit. The old version was a quick strike.
- Only one companion can be on the field. While one is out, or during the shared cooldown, the button calls nobody: it plays a short denied sound and the HUD slot shakes. The shared **8 s** cooldown starts when the companion leaves.
- The HUD assist slot has three states: **ready**, **active** (pulsing gold frame) and **cooldown** (dimmed, seconds left).
- The D-ID text is **D523–D525** (§5). No B rows were fixed. All timings are provisional (§2).
- Full suite: `SUITE: ALL PASS` (98 verify scripts), one run at the end.

Branch `cloud/assists-2` from `origin/feature/backlog` @ `80dc1640`. Before/after shot: `design/shots/companions_seqbefore_seqafter.png`.

## 1. What changed

- **`CompanionAssist.gd`:**
  - `start()` (l. 108) now runs five phases and emits `phase_changed` for each: `enter` → `windup` → `strike` → `hold` → `exit`.
  - `_enter()` (l. 159), RUN: the companion runs in from the edge of the view and eases to a stop, with `landing_dust` at the feet. DROP: the companion falls 260 px onto the spot while fading in, then lands with a squash (1.18 × 0.82, back-eased) and `landing_dust`.
  - Wind-up: strike frame 0 holds while the sprite flares to the companion's `tint` and a tinted `charge_glow` (glow and rising motes) plays on the companion.
  - The strike plays at `strike_speed` (0.8–0.85), so it reads heavier. The hit logic (`_strike`, `_hit`, the chain, the arrow) is unchanged from D512–D514.
  - `_leave()` (l. 186), RUN: the companion turns, runs 320 px back and fades (Alisia's cat goes with her). RISE (Urizen): he floats up 200 px in a gold glow and fades.
  - Timing and look are `@export`s in each `companion_<id>.tscn` (group "Sequence (D515)"): `entrance`, `entrance_time`, `windup_time`, `strike_speed`, `hold_time`, `exit`, `exit_time`, `tint`.
  - The coin and the arrow are slower so they read better: coin fall 0.25 → 0.3 s, coin hop 0.22 → 0.3 s, arrow 1400 → 1100 px/s.
- **New FX** in `Scenes/FX/Companions/`: `landing_dust.tscn` (a flat ring and dust both ways) and `charge_glow.tscn` (glow and motes, tinted by the companion). Both run on `AssistFX.gd`.
- **`CompanionManager.gd`:**
  - The per-companion `_cooldowns` dictionary is gone. It is replaced by `_cooldown` (shared) and `_active` / `_active_actor` (the companion on the field).
  - `call_next()` (l. 137): if the queue is empty it stays silent, as before. If someone is on the field or the cooldown is running, it emits `EventBus.assist_denied(id)` and returns `""`.
  - `_send()` connects the actor's `tree_exiting` to `_on_actor_left()` (l. 194), which frees the field and starts `COOLDOWN = 8.0`. So the cooldown also starts when a room change frees the companion mid-assist. An actor left over from a previous session (freed after `reset()`) is ignored.
  - New: `get_state()` returns NONE / READY / ACTIVE / COOLDOWN, plus `get_active()` and `get_next_in_queue()`. `get_remaining_cooldown()` no longer takes an id. `get_soonest_on_cooldown()` is removed (the HUD was its only caller).
  - The guard follows the same rule: one at a time, and the cooldown starts after he leaves.
- **EventBus:** new `assist_left()` and `assist_denied(companion_id)`.
- **SoundHooks:** `assist_denied` → the new `assist_denied` event in `sound_events.json`. It reuses Kenney `error_001` (`SFX/cast_interrupt.ogg`) at −9 dB and pitch 1.5, so no new asset was needed.
- **`skill_hotbar.gd`:**
  - `_update_assist()` (l. 180) draws the three states.
  - **Ready:** the portrait of whoever comes next, a gold frame and a gold badge (as before).
  - **Active:** the portrait of the companion on the field, the gold frame's glow pulsing (`shadow_size` 0 ↔ 6 over 0.8 s), and a neutral badge.
  - **Cooldown:** the next in the queue, dimmed to 0.55, with the seconds overlay.
  - `_on_assist_denied()` (l. 218) shakes the portrait and overlay (±4 px, 0.24 s). The constants are new in `UITokens.gd` (`ASSIST_*`). The theme does not use them, so it needs no regeneration.
- **Capture:** `capture_companion_assists.gd` now takes four frames: call +0.3 s (entrance), first hit +0.08 s and +0.4 s, and hit +1.6 s (exit). `companion_shots.py` counts frames per tag.

## 2. Timings (provisional)

Measured in `verify_companions` (headless, ms from the press):

| Companion | Entrance | Wind-up | Action (strike → hold) | Hold | Exit | Total | Tint |
|---|---|---|---|---|---|---|---|
| Alisia | run in 0.70 s | 0.45 s | 0.70 s (arrow 1100 px/s) | 0.50 s | run off 0.65 s | **3.02 s** | green-white |
| Astrit | drop in 0.60 s + squash 0.14 | 0.35 s | 0.85 s | 0.50 s | run off 0.60 s | **3.07 s** | orange |
| Urizen | drop in 0.60 s + squash 0.14 | 0.35 s | 1.24 s (coin fall 0.3 + 2 hops × 0.3) | 0.35 s | rise 0.60 s | **3.37 s** | gold |
| Guard | run in 0.60 s | 0.35 s | 0.78 s | 0.40 s | run off 0.60 s | **2.75 s** | pale blue |

Shared cooldown: **8 s** after the companion leaves. The old cooldown was 15 s per companion, which allowed three assists back to back. With three in the party you now get one assist about every 11 s at most.

## 3. Shots

`design/shots/companions_seqbefore_seqafter.png`: one row per assist, BEFORE (4 frames) | AFTER (4 frames). The frames are entrance, hit, +0.4 s, and +1.6 s.
- **Before:** the companion is already at the hero at +0.3 s and gone by +1.6 s.
- **After:** at +0.3 s, Astrit and Urizen are visibly dropping in from above and Alisia is running in from the edge. Alisia and the guard are still on the field at +0.4 s. The hit effects (D514) are unchanged.
- **Not caught:** the +1.6 s frame catches most companions already faded or outside the crop. The wind-up glow falls between frames. Both show in play; the capture moments could be tuned if a frame of the glow is wanted.

## 4. Tests

- `verify_companions`: **RESULT: ALL PASS**. Sections [1]–[3] and [9]–[10] are unchanged; [3] also checks the HUD "ready" state. New and rewritten checks:
  - [4]: Alisia runs in from more than 200 px away, and the HUD shows **active** with a pulse.
  - [4b], one at a time: a second press while she is out calls nobody and emits `assist_denied("alisia")`, the `assist_denied` sound plays, the portrait shakes and settles, and no cooldown runs while she is on the field. Landing dust and the charge glow appear.
  - Phase order, an entrance of 0.5–0.85 s and a total of 2.5–3.6 s, checked for each of the four companions.
  - [4c], shared cooldown: it starts when she leaves (≈ 8 s), and the HUD shows **cooldown** with Astrit next, dimmed, and the seconds left. A press is refused during the cooldown, and `assist_ready("astrit")` fires when it ends.
  - [5]: Astrit drops from above (more than 100 px over the feet), with the hit, stun and stars at the hold.
  - [6]: Urizen's chain hits three enemies and he rises on exit.
  - [8]: the guard also blocks a second call.
- Related tests run alone: `verify_scripts_compile`, `verify_hotbar`, `verify_lab_cells`, `verify_lab_boss`, `verify_lab_route`, `verify_city_gates_raid`, `verify_gamepad_parity`, `verify_gamepad`, `verify_onboarding`, `verify_party_panel`: all **ALL PASS**.
  - `verify_laboratory` failed once, as expected: the three corridor fights come faster than the shared cooldown, so the third F press is refused (`["alisia", "astrit"]`). Its check now counts every press as either sent or refused (`assists + denied == 3`, at least one sent) and passes (`["alisia", "astrit"] / denied ["astrit"]`).
  - `verify_audio` failed under load once (`hero_hurt`, the known flake in `test_baseline.md`) and passed alone.
- Full suite, once at the end: `Scripts/Tools/run_verify.sh` → **SUITE: ALL PASS** (98 of 98).

## 5. D-ID text (proposed; the register ends at D522)

| ID | Kind | Text |
|---|---|---|
| D523 | ROUTINE CALL | **Assist sequence as built for D515** (`cloud/assists-2`). Every assist runs entrance → wind-up → action → hold → exit (`CompanionAssist.phase_changed`). Alisia and the guard run in from the edge of the view; Astrit and Urizen drop in from 260 px above and land with a squash. Each lands or stops with a dust ring (`landing_dust`). The wind-up holds the first strike frame while the companion flares to their colour with a `charge_glow`: Astrit orange, Alisia green-white, Urizen gold, the guard pale blue. The strike plays at 0.8× (guard 0.85×), then the pose holds. Alisia, Astrit and the guard run 320 px back and fade (the cat goes with Alisia); Urizen rises 200 px and fades. Totals (provisional): Alisia 3.0 s, Astrit 3.1 s, Urizen 3.4 s, guard 2.75 s. Damage, stun, reach and targets are unchanged from D512. The coin and the arrow are slower (coin hop 0.3 s, arrow 1100 px/s). |
| D524 | ROUTINE CALL | **One on the field, one shared cooldown** (`cloud/assists-2`). D515 replaces D209's 15 s per companion with one shared **8 s** cooldown (provisional), which starts when the companion leaves the field, including when a room change frees him. While one is on the field, or while the cooldown runs, the button calls nobody (`EventBus.assist_denied`). The guard follows the same rule. The queue still rotates through the party in picking order. |
| D525 | ROUTINE CALL | **HUD assist slot: three states and the denied feedback** (`cloud/assists-2`). **Ready:** the portrait of whoever comes next, a gold frame and a gold badge. **Active:** the portrait of the companion on the field, the gold frame glowing in a 0.8 s pulse, and a neutral badge. **Cooldown:** the next in the queue, dimmed to 0.55, with the seconds left. A refused press shakes the portrait ±4 px for 0.24 s and plays `assist_denied`, which reuses Kenney `error_001` at pitch 1.5 and −9 dB. The values are the `UITokens.ASSIST_*` constants. |
