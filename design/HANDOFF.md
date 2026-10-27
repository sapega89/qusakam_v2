---
type: reference
tags: [handoff, orchestrator]
---

# Handoff — 2026-10-27, afternoon

Fresh session on purpose (Sapega: «ти дуже багато тримаєш в контексті»). The plan is the new, short [[MASTER_PLAN]]
(the old one: [[archive/MASTER_PLAN_2026-10-24]]); what waits on Sapega or was deferred is in [[BACKLOG]] → «Moved out of
MASTER_PLAN 2026-10-27». Reply to Sapega in Ukrainian.

**Registers:** `integrate-29` is assigning D787–D793+ and the next B rows; after it lands, the next free numbers are in
its report — write them here. Do not file IDs on `feature/backlog` while an integrator runs (they collide).

## 1. First, when you start
1. `git fetch`; read `design/cloud_reports/integrate-29.md` on `origin/cloud/integrate-29` when it exists (it already
   contains integrate-28: 11 routines, D775–D786, B163–B169, suite 3 FAIL / 132 PASS — read which and why).
2. Merge `origin/cloud/integrate-29` into `feature/backlog`. **MASTER_PLAN.md will conflict**: keep the new plan (ours)
   and mark I29 ✅; the old rows it touched live in the archive. Then push and rebuild the exe (X1).
3. Then start R2+R3 (`rooms-dressing`, one room routine) and H1 (Death wiring) in the cloud — briefs in the plan rows.

## 2. Running now
| Routine / agent | Trigger | Waits for | Task |
|---|---|---|---|
| integrate-29 | `trig_013BwjzmMBKhfMPaMMvX65Vy` | — | I29 (see the plan) |
| fx-film | `trig_012PS9H1zFeGbai2EpsuCitj` | — | every effect filmed → `design/shots/fx/` GIFs for Sapega's notes (BACKLOG A9) |
| scale-probe | `trig_01QzZV3gTqsGcK5c9taCodyV` | — | **reported**; it may use the old draft (≈70 px, ranges): set `world_scale.json` to the exact table (H = 64 art px) and re-run the probe + `scale_chart.py`, then send Sapega the chart (R4) |
| skills-v2-data | `trig_01Pq52MBQ8GTvV5YddP6xi1J` | — | H3 slice 1 |
| skills-v2-screen | `trig_01EarsZ2Bq1ztEWDEcvumshx` | skills-v2-data | H3 slice 2 |
| skills-v2-move | `trig_01S8vAyhUS4sr9wgVj1AQ1eX` | skills-v2-screen | H3 slice 3; then create ranged → stance (+ H2 shields) → control |
| hero-shadow | `trig_01HbdpMkejiuyv4BN1jvoqCX` | — | **reported**, merged by integrate-29 |
| art agent (local, ComfyUI) | — | — | §3 items 1–2 running (started 2026-10-27 afternoon): the magic and glass shield effects over Block/1 (`FX/Shield/`), the iron-shield sprite removed, the mouse critter. When it reports: push, send Sapega `design/shots/shield_spells.png` and `critters_mouse.png`, start §3 item 3 → 4 (M6a) |

## 3. Art lane next (ComfyUI, one agent at a time; commit with `-- <paths>`)
1. **H2 shields** — Sapega's final word: the shield is a spell (Pathfinder): a magic shield drops from the sky over the
   existing Block art and fades; a glass shield cracks and shatters (its shards hurt the attacker). Over `Block/1`;
   the iron-shield sprite `Sprites/Player/Shields/iron_shield` (`e5cb5681`) is superseded — remove it then.
2. **Mouse critter** (idle 2, run 4, side view; it runs into a hole) — for R2.
3. **H4**: `Raise/2`, the faint mark under a column (A8).
4. **M6a → M6b → M6c → M6d** backdrops ([[m6_backdrops]]: several planes, props on their own plane, foreground,
   atmosphere, exact sizes from [[world_scale_plan]]). M7 starts once M6a is in.
5. **H3 art**: the hero poses and VFX the skills-v2 routines list as missing (icons already exist, Figma sheets 10–15).

## 4. Sapega's pages
- P1 (done): https://claude.ai/artifact/TTw9d4LafTG574jTXRKGkk — all 112 agent calls confirmed.
- S1: https://claude.ai/artifact/C19YzVs1KYFu9GuKBfwJuv — the draft was accepted as is; the page stays for later fixes
  (db `verdicts`).
- Next page when integrate-29 and side-stories are merged: the dialogue review ([[dialogue_review_plan]]).

## 5. Decisions today still to get D-IDs (if integrate-29 did not file them)
Critter placements (moth — attic, bat — cellar, mouse — cellar and houses, pigeon — City); the shield is a spell with a
glass-shield variant (S19, [[skills_audit]]); the 33 skills accepted as drafted; Q66 closed (names, D260 marked);
shortcuts = blocked where seen, opened from the far side with a lever ([[world_structure_plan]]); M14 folded into M7;
world scale: H = 64 art px, exact sizes ([[world_scale_plan]]).
