---
type: reference
tags: [handoff, orchestrator]
---

# Handoff — 2026-10-28, night

The plan with statuses is [[MASTER_PLAN]] (§5 playtest P1–P9, §6 the art queue). Deferred items are in [[BACKLOG]] →
«Moved out of MASTER_PLAN 2026-10-27». Reply to Sapega in Ukrainian.

**Registers:** next free **D840**, **B200**, **Q115**. Do not file IDs on `feature/backlog` while an integrator runs.
**Exe:** `build/windows/Qusakam.exe` 2026-10-27 23:35 (menu effects, B195 fix, starting skills). Rebuild after each merge.

## 1. Running now
| What | Where | Task | When it reports |
|---|---|---|---|
| `fewer-road-enemies` | ☁ `trig_01YMTKTqVyu8aFA3CYpNLRp5` | D817: DesertRoad groups ≤ bandit + jackal or two bandits + jackal | it may not have run Godot (the cloud classifier blocks the download now and then): merge, then run its tests locally in a worktree |
| `world-rooms` | ☁ `trig_0199FwJ19fwAHb4RcSm3FjMo` | M7 **Canyon** on placeholder backdrops (its prompt also covers City and Lab — merge only its Canyon slice; City/Lab come from the two routines below, Sapega: «розбити на регіони») | merge the Canyon push |
| `rooms-city` | ☁ `trig_01Eqok3DZCxs6TVcwtYQGn8Q` | M7 City region only (M3) | merge |
| `rooms-lab` | ☁ `trig_01EWiH9f4dELT3EzAsQb2zt1` | M7 Laboratory region only (M4), no platforms/ladders | merge after `flat-road-lab` |
| `wire-art` | ☁ `trig_01FEuvNNspn9Qr36pPxSNUby` | wire shields, status icons, mouse; leftovers | merge |
| `playtest-tuning` | 🖥 worktree agent (godot-dev) | B197 the jackal flies; D825 shorter micro-stun; D826 slower enemies; D827 free Shield Block = 1 point toward the D497 gate; then D828 skills hit hard, D829 bigger elites, B198 enemies jump up to a step | merge its branch, file its D-IDs, rebuild, send Sapega the verify_difficulty table |

## 2. Next, in order
0. **Wire the art that lies unused** (Sapega: «чому не всі арти підключені?»; the catalog's unused list): the shield spells
   (H2: magic + glass phases on block, glass shards hurt the attacker), the status icons (bleeding, burning, cursed, stunned),
   the mouse with its hole (ambient_critters_plan), and the road planes onto `world-rooms`' new rooms; then either wire or
   delete the leftovers (old front planes, plank_posts, stone_balcony, Sprites/MC.png, kit icons, old Roll). From now on
   every art batch ends with its wiring. The 8 cloud branches with unmerged commits hold only report tails — nothing lost.
1. **P6 / D824 enemy stamina** — a new system: `plan-missing-system` → `design/enemy_stamina_plan.md` (mirror the hero's
   PlayerStamina D776), then build it (worktree agent) after `playtest-tuning` (both touch EnemyLogic).
2. **P5 / D830** — the Desert Road floor flat, no steps (Sapega: «на дорозі не має бути сходинок»); after `fewer-road-enemies` merges (same scene).
3. **P8 / B196** — «Hold Tab to skip» over the «Your Skills» window.
4. **Art queue** [[asset_verdicts_2026-10-27]] on the PC, one ComfyUI agent at a time: A5 (road planes + the Rock Ledges
   redo) → A6 (shield phases) → A7 (Brass Collector, dust, hit flash, tiles, tutorial pics) → A8/A9 → A10–A13 (scale) →
   A14, A4. Each with a before | after sheet sent to Sapega.
5. **M6a-3** burnt village (D796: the Village's own houses, scorched, not ruined) after A5.

**Burnt village (M6a-3, `785e7f49`)** is made, not wired: after `world-rooms`' Canyon slice merges (it may touch Village.tscn), swap the four Village textures for `_burnt`, open the regions (Back 0,0,576,324; Houses 0,0,576,276; offsets 0), darken the Backdrop modulate ~(0.72,0.66,0.68), green palms/banners/butterflies/larks/pollen → charred/embers. The village is burnt in every state the game uses.

## 3. Rules learned today
- **Tests:** the full suite runs 4 at a time with its own user:// per test, `## SERIAL` real-time tests last, `## MANUAL`
  (`verify_masher`) skipped (D806). Tests run in the cloud by preference (memory: tests-in-cloud), but cloud routines
  sometimes cannot download Godot — then finish them in a local worktree. At most two Godot lanes on the PC with ComfyUI.
- **Chibi** only Kusakam and his companions (D816, like Skul); NPCs and enemies keep normal proportions; the bandit's
  look is a BACKLOG item.
- **Scale chart approved** (D814): hero 64 art, adults 96, elites more than ×1.25 (D829), doors 112, palm 256.
- **Asset catalog** https://claude.ai/artifact/Qxty8beDtyy71ULkuvmocf — verdicts in db `verdicts`; generator
  `Scripts/Tools/asset_catalog.py`.

## 4. Waiting on Sapega
- Death frames 1 and 3 (B184, `design/shots/hero_death.png`).
- Check B195 in the exe: die next to an enemy mid-swing, Resume, repeat.
- The main menu art (candidate C2) and its effects — he liked the art; any notes on the effects.
- Where the steps are (D830).
- The 3 red SKILLS rows (P9) — re-judge after `playtest-tuning`.
