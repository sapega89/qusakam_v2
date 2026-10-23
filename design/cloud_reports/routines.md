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

rows-3 merged 2026-10-22: D432 (#50 order 6, the last screen of D117 "Slices 2+"). Cloud suite: 92 PASS + the known `verify_audio` flake. Local suite after the merge: 93/93.

## Round 9 (2026-10-23): Sapega's playtest

Sapega played the demo and reported as he went. Each item is a B-ID or D-ID in the registers. playtest-1 and ui-kit
merged (D477–D482 renumbered from the branches' D443–D446, B119 / B122 / B123 fixed). The local suite runs after the
merge.

| UTC | Routine | Branch | Task |
|---|---|---|---|
| 01:28 | playtest-1 (`trig_016Dw9H1DX9R8UrqhGzDYg1M`) | cloud/playtest-1 | B122, B123, D437, D439 — merged |
| 01:28 | ui-kit (`trig_0133mr7NRgLcPALNDCBRMbhc`) | cloud/ui-kit | B119, D433 — merged |
| 02:13 | perf-1 (`trig_01QdvohWAPwpHQ3sFeRkiiq2`) | cloud/perf-1 | performance_plan slices 1–3 and 6, D434 fade |
| 02:20 | combat-feel (`trig_01SsSus3e2Lb7hNha4Cxym7h`) | cloud/combat-feel | B128, D443, D456, B125, D444 |
| 02:20 | npc-flow (`trig_01N1yoFKhEuXs3wq5dFKoVNa`) | cloud/npc-flow | D442, D452, D454 |
| 02:20 | story-text (`trig_015CA5q64kigmy5dtqzfhvi3`) | cloud/story-text | D437 rest, D457, D462, B126, D460 |
| 02:20 | ui-text (`trig_014xkVFFPggLwdiAWnEHFBGr`) | cloud/ui-text | D474, D475 |
| 02:20 | companions (`trig_017aeA6bXGhs2gsGoj12FFaB`) | cloud/companions | D463, D464, D465 |

Round 9 merged 2026-10-23: perf-1 (D505–D508), ui-text (D509–D511), companions (D512–D514), npc-flow (D516–D518),
combat-feel (D519–D522), story-text (D499–D501). Local suite: 97/98, and the one flake (`verify_combat_flow` [0b]) was
fixed (`362a0178`).

## Round 10 (2026-10-23): souls-like combat, skills, menu QA, progression, assists, world

| UTC | Routine | Branch | Task |
|---|---|---|---|
| 06:20 | combat-player (`trig_01Mc6YD9yJTo1X3RDpZuPPma`) | cloud/combat-player | D504 hero side: commitment, stamina, potion slot; B136; D502; D503 |
| 06:20 | combat-enemies (`trig_019GiYqT9bFVXXBz2pXcNbha`) | cloud/combat-enemies | D504 enemy side: colour tells, parry/riposte, B133–B135, B139, B140, D494 |
| 06:20 | skills-data (`trig_017U1vDMnuv2xPJaffHnJABQ`) | cloud/skills-data | B137, the flask, D491, D496, D497, D490 API |
| 06:20 | menu-qa (`trig_01D3omsQbPTaGHoqdjADdEPy`) | cloud/menu-qa | B129–B132, D493 |
| 06:20 | progression (`trig_01SviDye8epyKH2yPHA1ZZDu`) | cloud/progression | D488, D447 behaviour, D492 |
| 06:20 | assists-2 (`trig_01DR6RMPV4decwg8ChB9TDci`) | cloud/assists-2 | D515 |
| 06:20 | world-fixes (`trig_01SneiTQdYeENaYg2Jgb1PoQ`) | cloud/world-fixes | D446, D448, D451, D483 |

## Round 11 — 2026-10-23, launched 10:49 UTC (the four pillars, D585)

| Time (UTC) | Routine | Branch | Task |
|---|---|---|---|
| 10:49 | combat-polish (`trig_01WY4yVPjQGHs4BZCEtxYhC7`) | cloud/combat-polish | D551 stamina out, D581 hit feel |
| 10:49 | enemy-variety (`trig_01GdxdDbm3CpEih96hMJ77rA`) | cloud/enemy-variety | D495/D560 sizes, elites, shield-bearer; D582 pacing |
| 10:49 | world-1 (`trig_01J2f6CV6DXH1um3rZkJgkZs`) | cloud/world-1 | D565 locations data, D562 gates, D583 pickups into branches, the attic |
| 10:49 | skills-v2 (`trig_011hxei4kv9MxLHDkazQUTGp`) | cloud/skills-v2 | D535 33 draft skills, JP caps, D592 paid respec |
| 10:49 | hud-v2 (`trig_01TGsbpruzDTVYxLzPMvAWVX`) | cloud/hud-v2 | D453/D549/D552 hero panel, 8-slot hotbar, XP bar |
| 10:52 | ui-moments (`trig_017dMJtshPnHtL6ghLk6VCgX`) | cloud/ui-moments | D436 level-up, D486 journal card, D473 finale (quiet, D587) |
| 10:52 | perf-gfx (`trig_01GC4dKDbSKmTuoYtKyoTCzZ`) | cloud/perf-gfx | performance slices 4, 5, 7: High/Low for the HD 3000 (D553, D554) |
| 10:52 | text-1 (`trig_01FTn4tGdUakz5ok2iGPN5gf`) | cloud/text-1 | D566 «бандит», D571 NPC chatter drafts |
