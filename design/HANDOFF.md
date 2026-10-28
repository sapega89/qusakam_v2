---
type: reference
tags: [handoff, orchestrator]
---

# Handoff — 2026-10-28, 14:45

The plan with statuses is [[MASTER_PLAN]]. Deferred items are in [[BACKLOG]]. Reply to Sapega in Ukrainian.

**Registers:** next free **D874**, **B210**, **Q126** — `integrate-33` takes them first; do not file IDs on `feature/backlog`
while an integrator runs. The room chain's reports use placeholder/colliding numbers (rooms-finish D871–D875): the
integrator after the chain renumbers them.
**Exe:** `build/windows/Qusakam.exe` rebuilt 28.10 ~14:45 after `integrate-32` was merged (`768d25ca`). Rebuild after each merge (X1).

## 1. Cloud now
`integrate-32` ✅ merged into `feature/backlog`. All parallel branch routines reported: skills-v2-ranged, -stance,
-control-a, -control-b, small-fixes, wire-leftovers (all four weapon variants wired), lab-v3-now.

| Routine | Trigger | Task | On report |
|---|---|---|---|
| `integrate-33` | `trig_01XtXrAxaVP6qYhFE1gsSJrt` (12:50 UTC) | merge the 4 skills branches one at a time, small-fixes, wire-leftovers; fix verify_camera_transitions (BanditCamp) | merge into `feature/backlog`, rebuild exe |

**Room chain** (one room routine at a time): `wire-backdrops` ✅ → `wire-backdrops-2` ✅ → `rooms-finish` ✅ (done by
the original or `-r`; fights + life in the new rooms, camp off the Dunes; built nothing in the Laboratory — that is
lab-v3-now's) → **`wire-backdrops-3-r`** 🔄 running (`trig_01TGj1QNGEtXZNTtShBMyvtf`; the original gave up at 10:47) →
`wire-backdrops-4-r` (`trig_019qjvbMDSdG2DBeyjYqRk6A`, waiting; also merges `lab-v3-now`) → `prop-sizes` / `-r`
(`trig_015U2tbMG9yLHwpLrRMGBCSg` / `trig_01GUwKqL7gmdvPmyoVwmg45Z`) → `wire-props` / `-r` (`trig_01B4nHuyADwieMains6tHt2J` /
`trig_01UrXytkDsfE7YLbMquXK5r4`). The originals of prop-sizes/wire-props give up at 15:15/15:31 UTC, the `-r`
replacements take over with their own 8 h. If a replacement dies too, re-run it with RemoteTrigger `run`.
- After `wire-props`: **`integrate-34`** merges the chain's last branch (contains lab-v3-now) and renumbers its IDs.
- rooms-finish's Q-a (redraw the Lab M4 graph, D863) is covered by lab-v3-now (built from Figma 564:6590); Q-b East Gate
  is non-blocking (default: with the location after the demo, D861).
- lab-v3-now left: the hall's cave look at ground level (D865) has no art; LabBoss stays 2×1 (the graph draws 3×2).
- Never merge `cloud/lab-v3`, `cloud/lab-main-path`, `cloud/rooms-city`, `cloud/rooms-lab`.

## 2. Art lane — stopped
Sapega 28.10: «комфі більше не запускай». Do not start any ComfyUI agent or offer one. Everything that needed it is in
[[BACKLOG]] → «ComfyUI art — stopped 2026-10-28». The PC only builds the exe.

## 3. Rules learned
- **Code and tests in the cloud**, the PC only for ComfyUI (memory: tests-in-cloud). The cloud sometimes cannot
  download Godot — then the routine commits and lists its tests.
- **Tests:** 4 at a time with own user:// per test, `## SERIAL` last, `## MANUAL` (`verify_masher`) skipped (D806).
  `verify_difficulty` (17) and `verify_lab_boss` (2) are red on balance until Q114/Q116–Q118.
- **Chibi** only Kusakam and his companions (D816); NPCs and enemies normal proportions.
- **Scale chart approved** (D814): hero 64 art, adults 96, elites ×1.5 (D859), doors 112, palm 256.
- **Sky** yellow until the hero leaves the Laboratory, then blue (D864, [[lore]] 28.10).
- **Asset catalog** https://claude.ai/artifact/Qxty8beDtyy71ULkuvmocf — generator `Scripts/Tools/asset_catalog.py`
  (lists unused art).

## 4. Waiting on Sapega
- Balance: Q114, Q116–Q118 (P9).
- The glass shield's skill: Q115.
- Death frames 1 and 3 (B184, Q110); B195 check in the exe (die next to an enemy mid-swing, Resume, repeat).
- Looks at the art sheets A1, A5–A9, A13, A14 ([[asset_verdicts_2026-10-27]]).
- Q107–Q111, Q119–Q122, Q124 (defaults applied).
