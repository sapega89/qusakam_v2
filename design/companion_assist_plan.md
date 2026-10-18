---
type: plan
status: blocked
blocked-by: [Ludo login (art), Астрит strike]
---

# Companion assists — plan

**Decided, not built.** D201 (assists exist), D209 (who, strikes, one button). 2026-10-18.
Figma: no design exists (HUD readiness indicator has no frame — Sapega's call, D209).

## What exists today
| Thing | Where | State |
|---|---|---|
| Companion manager | `SampleProject/Scripts/Managers/Gameplay/CompanionManager.gd` (27 lines) | ❌ stub: an array with add/remove, limit 3 |
| Working January manager | `raw_assets/qusakam_v2-main/.../CompanionManager.gd` (206 lines) | ⚠️ summon, per-type cooldowns, HUD wiring — not in the project |
| Assist scripts | `Scripts/Gameplay/Characters/Companions/Companion{Fire,Healer,Shield,Utility}.gd` | ⚠️ referenced by nothing; no `.tscn` |
| `CompanionFire` flow | same, `_start_attack()` | ⚠️ the right shape (enter → `DamageApplier` → leave), but offset always `+50` right, and enemies already inside the hitbox are missed (monitoring never toggled) |
| Lab beats | `Scripts/Gameplay/Scenes/Laboratory.gd:79-96`, `Maps/Laboratory.tscn:84+` (`StateChangeTrigger_Companion01–03`) | ✅ fire `Lab_Companion_0N` dialogues |
| Lab dialogues | `dialogue_quest/Lab_Companion_0{1,2,3}.dqd`, `Lab_LimitTest.dqd` | ⚠️ one placeholder line each, speaker `[Lab]` |
| City Gates fight | `Scripts/Gameplay/Scenes/CityGates.gd:33,160-163` | ✅ ends on `all_enemies_defeated`; the guard assist (D209) is not in it |
| Canvas | `game.twee:70-106` (gate: "fight goes on until Kusakam uses the companion — the guard"), `:211-252` (lab, limit 3) | design source |
| Shared combat | `DamageApplier` (`target_group`), `EnemyLogic.stun()` / `start_knockback()` (D207, D208) | ✅ reusable as is |

## Missing entirely
- Companion art: sprites + enter / strike / leave animations for the guard, Алісия, Астрит, Уризен.
  Checked `assets/`: the licensed craftpix packs (wizard, ninja, raider) are slim realistic figures —
  they do not match Kusakam's chibi style, and none fits "warrior-thaumaturge with shield and book" (2026-10-18 sheet).
- Input action `assist` (F / pad LT) — `grep assist project.godot` → 0.
- `EventBus` signals for assist used / ready — none.
- Assist scenes (one per companion) and the HUD readiness indicator.
- Real lab dialogue lines naming the three (Sapega writes texts, D159 style).

## Decisions required
1. **Астрит's strike** — Sapega (2026-10-18): Астрит is a **warrior-thaumaturge with a shield and a book**.
   D209's "leap + heavy blow" was proposed before that. Proposal: he charges in behind his shield, bashes the
   nearest enemy (knockback, breaks a wind-up) and his book **marks** it — the mark makes the next hits on it
   deal +25 % for 4 s (PF2e Thaumaturge *Exploit Vulnerability*). **GAME DESIGN DECISION REQUIRED**; blocks slice 3.
2. **Art source** — D196: generate with Ludo in Kusakam's style (his sprite as the reference). Blocks slices 2–4
   until `ludo login`.
3. Lab beat order (Алісия 01, Астрит 02, Уризен 03) — taken from Sapega's answer; non-blocking.

## Slices
### Slice 1 — assist core (no art needed to test)
- `CompanionManager.gd`: roster (unlocked ids, saved in `player_state`), per-companion 15 s cooldown, `call_next()`.
- `project.godot`: `assist` action (F / pad LT); `Player._unhandled_input` → `call_next()`.
- `EventBus.assist_called(id)`, `assist_ready(id)`.
- `verify_companions.gd`: unlock, rotation, cooldown, save round trip.
### Slice 2 — the guard at City Gates (tutorial)
- `Scenes/Characters/Companions/guard_assist.tscn` + script from `CompanionFire.gd`'s flow, fixed (facing,
  monitoring toggle); spear thrust, knockback via `start_knockback`.
- `CityGates.gd`: the fight ends when the player calls the guard (canvas), hint on screen.
- `verify_city_gates_assist.gd`.
### Slice 3 — Алісия, Астрит, Уризен in the Laboratory
- three assist scenes; strikes per D209 (+ decision 1); unlock on `lab_companion_0N_complete`.
- lab dialogues named (Sapega's lines).
### Slice 4 — HUD readiness
- beside the hotbar, same shared slot style as the weapon bind (D202); portrait = the companion sprite.

## Order and dependencies
`1 → 2 → 3 → 4`. Slice 1 needs nothing; 2–4 need the art (Ludo) — slice 3 also decision 1.

## Out of scope for this pass
Retributive Strike (D207 — after the companions exist); companions that follow the hero around (not asked).
