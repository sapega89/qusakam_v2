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
| 10:02 | skill-fx (`trig_015CZMZqVbfC796bgZx9nmni`) | cloud/skill-fx | own charge + release effect for the 9 oath actives (A6 is all 9: the "18" was 9 skills × charge + release); the first short prompt on [[ROUTINE_RULES]] |
| 10:05 | art-fixes-wire (`trig_01XjApghCth8pwwaouVwVdh1`) | cloud/art-fixes-wire | wire `fe96e88a`: dagger Heavy/Attack2, dual Hurt, enemy and boss stagger animation, B105 palette pixels; check the in-place NPC/boss sheet fixes |

## Round 6 (2026-10-22): bugs and damage numbers

Sapega «оце вже можна в хмарі запустити» (the open bugs) and «треба додати цифри урону по мені і ворогу». The three run side by side, so none edits the registers: each report carries its D-ID text and the B rows it fixed, and the orchestrator applies them at merge.

| UTC | Routine | Branch | Task |
|---|---|---|---|
| 09:41 | combat-stats (`trig_012dFzq1nzQq3U3rPMcWC6qM`) | cloud/combat-stats | B84 (D393), B111 (D394), damage numbers on the hero and enemies + the Settings row (D66) |
| 09:41 | ui-bugs (`trig_01NdCwKPSAEPpPjMiwKExM6v`) | cloud/ui-bugs | B8, B10, B14, B19, B22, B90, B95, B96 |
| 09:41 | misc-bugs (`trig_016RhosmxiaoTrWqcMrsQGpi`) | cloud/misc-bugs | B91, B92, B93, B94, B107, B108 |

Not in this round: B105 (weapon palette pixels) goes with `cloud/art-fixes-wire`; B110 needs bow frames from the art lane first (Air 1–3, Block, Hurt, Roll); B106 closed by D395.

## Round 7 (2026-10-22): Settings, fight music, UI fixes

Sapega chose all four after the green suite (92/92). `cloud/settings-2` (#52, D418) waits until `cloud/settings-1` is
merged: both edit the Settings screen.

| UTC | Routine | Branch | Task |
|---|---|---|---|
| 12:40 | settings-1 (`trig_01RjsrWpydjYsaMR2JRsmqew`) | cloud/settings-1 | #100 settings_plan slice 1 (Borderless, Auto-Save row default Off, every row honest), #36 mouse off on Alt (D417) |
| 12:41 | fight-music (`trig_01GZ9nXe5t5hDTJSakSA6YP2`) | cloud/fight-music | music_plan slice 3a (D414): battle / boss / room switching, placeholder tracks until Sapega's pick |
| 12:41 | ui-fixes (`trig_01XDvEM6aPyHQF3maHM9cvRP`) | cloud/ui-fixes | B112 speaker name row; #50 row templates for stats_component and equipment_component |

Round 7 merged 2026-10-22: fight-music (D419), settings-1 (D420–D422), ui-fixes (D423, B112); B116, B118 filed, B117 fixed
by the orchestrator. Local suite after the merge: 92 PASS + `verify_lab_boss` (B117), green after its fix.

## Round 8 (2026-10-22): settings storage, row templates, combat fixes

Sapega chose all four. `cloud/settings-2` (#52, D418) starts after `cloud/settings-store` is merged: both edit
`SettingsModule.gd` and `verify_settings.gd`.

| UTC | Routine | Branch | Task |
|---|---|---|---|
| 14:04 | settings-store (`trig_013NrFUvbHqQC8rmFA1Yvbxq`) | cloud/settings-store | B118: one global settings file, slots stop carrying settings |
| 14:04 | rows-2 (`trig_014wctbx36UJsgUBWYAZPjTk`) | cloud/rows-2 | #50: skills_component, inventory_component, bottom_bar as templates (D423 way) |
| 14:04 | combat-fixes (`trig_01ME2nviFHh4JuK3PQTdzGSM`) | cloud/combat-fixes | B116 (in combat through the boss cutscene); CombatInput / SkillScreenInput into project.godot |
| 14:42 | settings-2 (`trig_01YQGg9VyujAfkkUo4fSEj3g`) | cloud/settings-2 | #52: D418 check, Text Speed, Screen Shake, Ambient, Brightness — started after settings-store merged (D424) |

Round 8 merged 2026-10-22: settings-store (D424, B118), combat-fixes (D425, B116), rows-2 (D426), settings-2 (D427–D431, renumbered from the branch's D425–D429). Local suite after the merge: 93/93. Left of #50: `options_component` (order 6), now unblocked.

| UTC | Routine | Branch | Task |
|---|---|---|---|
| 16:05 | rows-3 (`trig_01XySQVTHZfMXq8iURt7AdkY`) | cloud/rows-3 | #50 order 6: options_component as templates (the last screen) |

rows-3 merged 2026-10-22: D432 (#50 order 6, the last screen of D117 "Slices 2+"). Cloud suite: 92 PASS + the known `verify_audio` flake.
