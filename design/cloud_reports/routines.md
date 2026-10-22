---
type: plan
status: active
tags: [cloud, schedule]
---

# Cloud routines — the overnight schedule (2026-10-21)

Sapega: «підготуй в хмарі всі інші хвилі одразу». Every task runs in its own branch `cloud/<name>` on GitHub;
integrators merge finished branches (those with `design/cloud_reports/<name>.md`) into `cloud/integration`,
register their D-/B-IDs and keep the suite green. The laptop only runs ComfyUI art (pushed to `feature/backlog`
every 15 min) and pulls `cloud/integration` back into `feature/backlog` every hour while the session is open.
Routines: https://claude.ai/code/routines

| Kyiv time | UTC | Routine | Branch | Items |
|---|---|---|---|---|
| 21:27 | 18:27 | B82 position on load + B10 Auto button | cloud/b82-b10 | B82, B10 |
| 21:29 | 18:29 | Onboarding | cloud/onboarding | 28 |
| 21:30 | 18:30 | Skills screen + attributes | cloud/skills-screen | 43, 44 |
| 21:30 | 18:30 | Lab 9.5 cells cutscene, Malik, assists | cloud/lab-9-5 | 9.5 |
| 21:31 | 18:31 | Speaker name + portrait, objective plaque, gift/loot popups | cloud/dialogue-ui | 36, 37, 33 (non-art) |
| 21:31 | 18:31 | Graphics settings, one selection look, cleanup, NPC chatter | cloud/settings-cleanup | 41, 39, 35 |
| 21:37 | 18:37 | Lab 9.7 boss hall — the fire djinn fight, the cloak | cloud/lab-9-7 | 9.7, B83 |
| 22:24 | 19:24 | **INTEGRATOR 1** (moved up: 6 of 7 wave-1 branches were done by 22:20) | cloud/integration | merge wave 1 |
| 23:45 | 20:45 | Lab 9.6 mob corridors | cloud/lab-9-6 | 9.6, B83 |
| 23:45 | 20:45 | Two languages part 1 | cloud/localization-1 | 31 (UI) |
| 22:08 | 19:08 | Chests wired (art A1 landed early; started at once) | cloud/chests | 33 |
| 22:55 | 19:55 | Buildings + village-centre house + lore stubs (art A2 landed early; started at once) | cloud/buildings | 29, 38, 34 |
| 05:15 | 02:15 | **INTEGRATOR 2** | cloud/integration | merge wave 2 |
| 06:15 | 03:15 | Lab 9.8 demo end + full route + boss voices | cloud/lab-9-8 | 9.8 |
| 06:15 | 03:15 | Two languages part 2 (data, dialogue, Piper) | cloud/localization-2 | 31 (data, voices) |
| 06:30 | 03:30 | Sword animations (needs art A3) + gamepad audit | cloud/weapon-gamepad | 42 (sword), 24 |
| 09:30 | 06:30 | **INTEGRATOR 3 FINAL** + `FINAL.md` in Ukrainian | cloud/integration | merge wave 3 |

Not in the cloud (needs the laptop): art batches A4 (bow, archers), A5 (foreground parallax, living world),
A6 (effects polish), the other weapon types for 42; the bow (40) and 7 + 19 wiring after that art; Figma pages for
the journal lore/flags (34); Sapega's own texts (hints D159, lore, oath ideas 27, effect notes 30).

## Round 5 (2026-10-22)

| UTC | Routine | Branch | Task |
|---|---|---|---|
| 07:xx | code-fixes (`trig_01AKEmtZhgFsxCs72ueui65A`) | cloud/code-fixes | boss telegraph, game-time enemy cooldowns, souls_combat flake, B42, B4, #29, Journal portraits |
| 08:09 | living-world (`trig_01MyFTRZ4Rone1Aiik6fc6ze`) | cloud/living-world | BACKLOG 7 + 19: foreground planes, decor idle loops, drifting clouds |
