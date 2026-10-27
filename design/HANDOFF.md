---
type: reference
tags: [handoff, orchestrator]
---

# Handoff — 2026-10-27, afternoon

Fresh session on purpose (Sapega: «ти дуже багато тримаєш в контексті»). The plan is the new, short [[MASTER_PLAN]]
(the old one: [[archive/MASTER_PLAN_2026-10-24]]); what waits on Sapega or was deferred is in [[BACKLOG]] → «Moved out of
MASTER_PLAN 2026-10-27». Reply to Sapega in Ukrainian.

**Registers:** next free **D794**, **B187**, **Q107** (integrate-29 filed D787–D793, B171–B184, Q101–Q106; merged into
`feature/backlog`). Do not file IDs on `feature/backlog` while an integrator runs (they collide).

## 1. First, when you start
1. `git fetch`; read `design/cloud_reports/integrate-29.md` on `origin/cloud/integrate-29` when it exists (it already
   contains integrate-28: 11 routines, D775–D786, B163–B169, suite 3 FAIL / 132 PASS — read which and why).
2. Merge `origin/cloud/integrate-29` into `feature/backlog`. **MASTER_PLAN.md will conflict**: keep the new plan (ours)
   and mark I29 ✅; the old rows it touched live in the archive. Then push and rebuild the exe (X1).
3. R2+R3 (`rooms-dressing`) and H1 (`hero-death`) are already created and wait for integrate-29 in the cloud; merge them when they report.

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
| rooms-dressing | `trig_01B18JHqmgqV3VCnxrCTiH5N` | integrate-29 | R2 + R3: critters, atmosphere, grass in every existing room; the critics' fixes. The ONE room routine while it runs |
| hero-death | `trig_01ScrX4599bqUCazXRG2Gi61` | integrate-29 | H1: the Death animation wired |
| scale-exact | `trig_014Ca3d11T1YfgLfR3yg4AQE` | — | R4: the exact table (H = 64 art px), probe re-run, the chart → send Sapega for «ок» |
| art agent (local, ComfyUI) | — | — | shields + mouse, H4, **M6a-1** (`4cca758a`, `design/shots/m6a1_path_scree.png`) done and sent; **idle until Sapega reviews M6a-1** (m6_backdrops: each batch seen before the next). Open: the fallen barrier's look (lore never says — blocks only the barrier plane), the waymarker reads as a ribboned pillar, the smoke's foot floats in the scree's top frame, the gorge-wall ledges may read walkable. Then M6a-2 (gorge + ledges, world-anchored from 1728 px), M6a-3 (burnt village) |

## 2b. Tests (Sapega 2026-10-27: «зроби»)
`run_verify.sh` now runs 4 tests at a time, each with its own empty user:// (`0e901b13`; g* subset 1:49 → 0:56), and prints
the 10 slowest; ROUTINE_RULES: after a fix re-run only the failed tests. **Next, after integrate-29 is merged:** one local
full run for the time table, then an audit agent (worktree, `godot-dev`) deletes verify scripts whose every check another
script covers and lists partial overlaps (clusters: skills ×13 — wait for skills-v2; combat ×14; lab ×6; NPC ×5; the
early «Phase 5.x» UI checks ×12; settings ×3).

**Test audit** merged (`5b9e8c21`, [[test_audit_2026-10-27]]): 2 scripts gone (lab_rooms covered, demo_end → lab_route), city_gates_raid in game time, B185 fixed, B186 open (wall-clock waits → load flakes). Wall time did not drop: it is the real-time tail (masher ~350 s) and headless frames capped at ~145/s by `low_processor_usage_mode_sleep_usec`. Follow-ups listed in the audit (one door walk instead of two after rooms-dressing; small merges; game-time speed-up of combat_enemies, audio, archer, combat_flow, bosses). Full suite at J=4: 14–20 min, sum ≈ 3400 s; `## SERIAL` for hit_feel, masher; masher TIMEOUT 480.
**Exe** rebuilt after integrate-29 (15:58). **Ask Sapega:** the local uncommitted `scorpicore_warrior.tscn` edit (slam 1.5, charge 1.3; from an agent's autostash of 24.10, not his) contradicts D678 (×1.3 / ×1.15) — revert on his word.

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
Art-lane calls (agent calls, Sapega to confirm): the shield 31 art px tall (0.65 of the drawn 48-px figure, in front of
the chest), alpha 210 light / 170 glass with a solid 1-px edge, gold +20 % warm with a sky-blue edge, navy cracks; the
mouse 12 art px sitting (16×16 cells, idle 2 / run 4); Raise 1 → 2 (0.08 s) → 3 (0.16 s, held), the potion drink
plays it too; the pillar mark 48×14 on the hero's feet line (Mark y 22.5, Fire y 29 — the old mark sat on the wall
base), Mark and Fire unshaded (one material), pulse low 0.8. Note: the djinn is not fought anywhere since D466 —
the pillar is seen only in a capture.
Critter placements (moth — attic, bat — cellar, mouse — cellar and houses, pigeon — City); the shield is a spell with a
glass-shield variant (S19, [[skills_audit]]); the 33 skills accepted as drafted; Q66 closed (names, D260 marked);
shortcuts = blocked where seen, opened from the far side with a lever ([[world_structure_plan]]); M14 folded into M7;
world scale: H = 64 art px, exact sizes ([[world_scale_plan]]).
