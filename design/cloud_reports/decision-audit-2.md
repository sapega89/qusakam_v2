---
type: report
tags: [cloud, audit, decisions, plans]
---

# decision-audit-2 — D179–D330 audit and active-plan tails (MASTER_PLAN S15, S16)

**Summary.** S15 is done: `decision_audit.md` Run 6 checks D179–D330 (152 D-IDs) against the code, and «Resume at» now reads D331. ✅ 138 · ❌ 1 · ↩️ 0 · ➖ 13. S16 is done: four plans are `status: done`, and four carry «Tails (2026-10-27)». This is a document-only pass: no game code changed, no D-ID text written, no B rows fixed. No Godot test was run, because every verdict cites code plus an existing `verify_*` check label, or says "untested".

**D-IDs not built or undone (the orchestrator files each as a B-ID):**
- D181: Journal quests are not grouped by city. There is no Bab ar-Rimal region bar; `journal_component.gd:176-196` groups by story stage ("PROLOGUE") and "Tasks".
- D459 (outside the range; it amends D304): the prisoner does not burst into flame. `LabCells.gd:134` still plays `collapse` and then fades the djinn in.

**Plan tails (for MASTER_PLAN):**
- ranged_plan: all built, so `status: done`.
- hero_weapon_animation_plan: 1 tail. Slice 7, the bare-hands combat stance (optional), waits on art.
- onboarding_plan: all built, so `status: done`. Slice 2 was replaced by D743's «?» glint tips, which are built.
- localization_plan: all built, so `status: done`.
- npc_recall_plan: 2 tails. Slice 1, the objective hints of D159, is not built (Claude drafts the texts, D571). Slice 3, the speech-bubble art of D160, waits on Sapega's art.
- lab_boss_plan: all built, so `status: done`.
- lab_story_plan: 1 tail. The code is built; slice 9's `fb17_*` captures were never taken.
- world_expansion_plan: 1 tail. The code is built; slice 4's `fb23_*` road captures were never taken.

## Details

- **Method.** Five read-only auditors each took 30–32 register rows (`figma_decision_register.md:350-501`), and two took four plans each. I merged their output; the table is in [[decision_audit]] Run 6. Each D-ID that a later D-ID overrides is checked against the later one, which the Kind column names (for example D281 → D725, D283 → D330/D489/D691, D298 → D340/D583/D722).
- **D181 checked by hand.** `grep -rn "Bab ar-Rimal\|region"` in Scripts and Data finds nothing for the Journal. D565 keeps the City's name provisional (Q54) but does not withdraw the grouping.
- **D261 potions in chests are not a B-ID.** Potions are in `DesertRoad.tscn:421-425` `Chest_OldVulture`, `BanditCamp.tscn:141`, `GatehouseCellar.tscn:110`, `ElderHouse.tscn:148` and the `City.tscn:219, 228` stalls. D621, D698 and D740 put potions back explicitly, and D722's chest follows them. The register's D261 row could say it was lifted.
- **Stale text** (register rows, one code comment, orphans) is listed at the end of Run 6 for the Cleanup list.

## S16 per-slice evidence


### design/ranged_plan.md
Verdict: ALL BUILT
| Slice | Verdict | Evidence |
|---|---|---|
| 1 Bow item, grip, frames | ✅ | `Resources/Data/items.json:285` `short_bow` (`category` bow :289, `grip` bow :300); `EquipmentManager.gd:47-48` → `&"bow"`; `Player.tscn:1542` `AnimationLibrary_bow`, `:1652` `libraries/bow`, bow textures `:80-87`; `WeaponView.gd:31` `DRAWN_ONLY := ["bow"]`, overlay hidden `:124`; `UI/verify_bow.gd` exists |
| 2 Shots | ✅ | `PlayerCombat.gd:13` states `SHOOT, DRAW, CHARGED`; `PlayerCombat.gd:95-101` charged arrow / ×1.8 / knockback 60; `cancel_draw` `PlayerCombat.gd:548`, called on roll `Player.gd:240` (D382); `Scenes/Combat/arrow.tscn`, `arrow_charged.tscn`, `Scripts/Combat/Arrow.gd:17` group `hero_arrows`; `VFXHooks.gd:52,201` counts hero arrows; sounds `SoundHooks.gd:13-15`, `Arrow.gd:142` `arrow_wall`, `sound_events.json:21-24` |
| 3 Archer | ✅ | `Scripts/Gameplay/Characters/Enemies/ArcherEnemy.gd`, `ArcherLogic.gd`; `Scenes/Characters/Enemies/enemy_archer.tscn`; `Resources/Enemies/enemy_stats_archer.tres`; `EnemySpawnPoint.gd:12,38` type `archer`; tell `ArcherEnemy.gd:5,47`; coins `DefaultEnemy.gd:577-578` (1–3); voice pitch `sound_events.json:158` `"archer": 1.05`; bestiary `bestiary.json:24-25` "Desert Archer"; `UI/verify_archer.gd` exists |
| 4 Placement | ✅ | `Maps/DesertRoad.tscn:353-357` `Fight_Mesa/EnemySpawnPoint4` `enemy_type = "archer"`; `Maps/CityGates.tscn:292-295` `EnemySpawner/EnemySpawnPoint3` archer, raid figure from archer sheet `:17,269`; bow sold `merchants.json:21` `city_merchant` → `:34` `short_bow` |
| 5 Translations | ✅ | `Resources/Translations/uk.po:2565` "Short Bow", `:2571-2574` "Desert Archer" + bestiary text |

Tails: none. ("Left for later" items — B110 bow frames, aiming, ammo, archer kick — are explicitly out of the slices.)
Tail summary: "ranged_plan: all built"

### design/hero_weapon_animation_plan.md
Verdict: TAILS
| Slice | Verdict | Evidence |
|---|---|---|
| 1 Sword | ✅ | `Player.tscn:1647` `libraries/sword`; `WeaponView.gd:140` `body_library()`; `Player.gd:284` `body_animation`, `:294` `play_body`; `UI/verify_souls_combat.gd:669` [12c] |
| 2 Palette swap | ✅ | `Shaders/weapon_palette.gdshader` on `Player.tscn:79,99`; `Resources/Data/weapon_palettes.json`; 7 `"palette"` entries in `items.json`; `Scripts/Tools/weapon_key_fixups.py`; `UI/verify_weapon_animations.gd`, `UI/capture_weapon_palettes.gd` |
| 3 Dagger | ✅ | `Player.tscn:1648` `libraries/dagger` → `Resources/Player/WeaponAnimations/dagger.tres`; `Scripts/Tools/weapon_libraries.py` |
| 4 Mace | ✅ | `Player.tscn:1649` `libraries/mace` → `mace.tres` |
| 5 Halberd | ✅ | `Player.tscn:1650` `libraries/polearm` → `polearm.tres` |
| 6 Dual-wield | ✅ | `Player.tscn:1651` `libraries/dual_sword_dagger` → `dual_sword_dagger.tres` |
| 7 Bare-hands combat stance (optional) | ❌ | no `bare`/fists library in `Player.tscn` (libraries `:1646-1652`), no `Sprites/Player/Weapons/bare*` folder; BACKLOG.md:278 lists it as left. Waits on art (laptop). |

Tails:
- 7 Bare-hands combat stance: no fists-up `CombatIdle` frames or library; optional, waits on art. (Also open per BACKLOG 42, not a numbered slice: other dual pairs besides `dual_sword_dagger`.)
Tail summary: "hero_weapon_animation_plan: 1 tail — slice 7 bare-hands combat stance (optional, waits on art)"

### design/onboarding_plan.md
Verdict: ALL BUILT
| Slice | Verdict | Evidence |
|---|---|---|
| 1 The plan | ✅ | the note itself |
| 2 Six lessons in the street fight | ➖ cancelled (superseded) | Superseded by D540 (4 lessons) → D733 (sparring) → **D743** (`figma_decision_register.md:895`: "No combat training; the glint colours are «?» tips", removes `CombatTraining.gd` and `lesson_*`). Checked against D743: `CombatTraining.gd` gone, no `lesson_*` in `tutorial.json`; replacement built — `tutorial.json:72,81,90` `tell_block`/`tell_parry`/`tell_dodge`, `EventBus.gd:162` `enemy_tell_shown`, emitted `DefaultEnemy.gd:332`, `BossEnemy.gd:103`, listened `TutorialManager.gd:29,51` |
| 3 Moving pictures in tutorial window | ✅ | `Scripts/Menus/Game/tutorial_menu.gd:16-17,58` `load_frames(topic.frames)`; `UI/capture_tutorial_frames.gd`; `Assets/UI/Tutorial/{move_jump,combo,dodge,block,parry,heavy,heal,assist}/` (20–28 files each, ≥6 frames) + `companion_picker`; `tutorial.json` names all sets |
| 4 Controls page | ✅ | `Scenes/Menus/Game/controls_component.tscn` + `.gd`; Misc row `misc_menu_modal.tscn:32-37`, `misc_menu_modal.gd:15,27,44`; `game_menu.tscn:16`, `game_menu.gd:148,174`. D-28i (Z for `weapon_prev`) superseded by **D475** (no weapon switching) — `verify_combat_flow.gd:183`, `verify_onboarding.gd:146` assert no weapon-switch action |
| 5 Waypoint arrow | ✅ | `Game.gd:555` `set_objective(text, target)`, `:566` `objective_marker()`; `UI/Components/combat_hud_top.tscn:82` `Direction`, `combat_hud_top.gd:21`; `ObjectiveTargets` in `Maps/{Canyon,Village,DesertRoad,CityGates,City,ElderHouse}.tscn` (D325) |

Tails: none.
Tail summary: "onboarding_plan: all built (slice 2 superseded by D743, built as «?» glint tips; D-28i superseded by D475)"

### design/localization_plan.md
Verdict: ALL BUILT
| Slice | Verdict | Evidence |
|---|---|---|
| 1 Runtime registration, Language row, UI strings, verify_locale | ✅ | `LocalizationManager.gd:29` `_register_translations`, `:37` `set_language`, `:49` `apply_language`; `Resources/Translations/{en,uk}.po`; `export_presets.cfg:9,81` `*.po`; `Scripts/Tools/po_sync.py`; `verify_locale.gd:66` [0], `:74` [1], `:100` [2] |
| 2a Data JSON → uk.po + composers | ✅ | `Resources/Translations/data_fields.json`; `verify_locale.gd:113` [4]; `name_ru`/`description_ru` 0 hits in `items.json`, `crafting_recipes.json`; `ItemDatabase.gd:169,179` no language param |
| 2b Character names → ids + English keys | ✅ | `dialogue_quest/characters/ALISIA.tres:11` `character_name = "Alisia"`, `ASTRIT.tres:11`, …; `CompanionManager.gd:23` `NAMES` English |
| 2c English .dqd twins + resolver + twin verify | ✅ | 68 `dialogue_quest/*.dqd` = 68 `dialogue_quest/en/*.dqd`, same names; `Scripts/Systems/dialogue_paths.gd:2,23` `DialoguePaths.localized`; used `DialogueManager.gd:127`, `dqd_reader.gd:13`; `verify_locale.gd:120` [5] |
| 2d DATA_DEFERRED / RUNTIME_FILLED removed, [4] + [5] | ✅ | 0 hits for `DATA_DEFERRED`/`RUNTIME_FILLED` in `verify_locale.gd`; [4] `:113`, [5] `:120` |
| 3 Greeting by locale | ✅ | `Assets/Audio/Voice/Greetings/*.ogg` (EN) + `Greetings/uk/` (12 files); `sound_events.json:91-92` `greet_*` / `greet_*_uk`; `SoundHooks.gd:242` picks `_uk` by locale; `verify_locale.gd:128` [6] |

Tails: none.
Tail summary: "localization_plan: all built"


Branch checked: working tree of /home/user/qusakam_v2 (cloud/decision-audit-2). Paths relative to `SampleProject/` unless noted.

### design/npc_recall_plan.md
Verdict: TAILS
| Slice | Verdict | Evidence |
|---|---|---|
| 1 Objective hints (D159; D571 = Claude drafts the texts) | ❌ | `Resources/Data/story.json` has no `hint`/`from` key at all (grep: 0 hits); `GameFlow.gd:94-104` `_objectives()` emits only `{text, state}`; `Scripts/Menus/Game/journal_component.gd` has no hint line under an objective (its `_set_hint` at :468 is the context-bar hint, not D159). MASTER_PLAN S6 says a `journal-hints` routine is in progress, but none of it is on this branch |
| 2a Quest at the old man (D169) | ✅ | `Scripts/Systems/dqd_reader.gd:9` `lines()`; `Scripts/Systems/DialogueManager.gd:295` `replay(path, tail)`; `Scripts/Gameplay/NPCs/StoryNpc.gd:22-28` (main row) + `:38-41` (replay of `quest_dialogue` + "Current objective"); `Scenes/Gameplay/Objects/NPCs/grandfather.tscn` placed in `Maps/ElderHouse.tscn` (moved there by D729); test `UI/verify_npc_recall.gd` |
| 2 Remind at the NPC (D158) | ✅ (superseded) | D161 turns "Remind" into the Figma `Quest` entry that replays the conversation that gave the quest. D175/D390 describe it as built: `NpcBase.gd:143-148` `menu_entries()` adds Quest, `:154-158` `quest_rows()`, `:314` `dm.replay(give_dialogue, tail)`; `StoryNpc.gd:22-28`. The original speaker_id "list every completed dialogue" design was replaced and not built (no `speaker_id` in NpcBase) |
| 3 Speech bubbles (Q48, D160, D178) | 🟡 waits on art | `UI/Components/speech_bubble.gd`; `DialogueManager.gd:94-112` (`in_cloud`), `:337` preload. "Point Remind at it" is dropped: D415 keeps Remind replays in the box. Still open: Sapega's bubble art (D160). The current `Assets/UI/Dialogue/bubble_body.png` / `bubble_tail.png` are Claude's temporary PNGs (D178) |
| 4 Side quests in story data (D162) | ✅ (superseded) | D175 replaces `story.json` with `quests.json` (`Resources/Data/quests.json`: `merchant_caravan`, `smith_helmet`, `smith_enchant`, `malik_escort`) + `Scripts/Tasks/task_service.gd`. The Journal shows them as a "Tasks" group (D180, `journal_component.gd:191-196`). `quests_from` becomes `NpcBase.quest_rows()` (D390). `Scripts/Quest/` is deleted (does not exist). `SceneQuestManager`/`quest_manager`: 0 hits |
| Blacksmith tasks (D175): Helmet + Enchant | ✅ | `quests.json:18-27` (`smith_helmet`, reward coin 88), `:30-40` (`smith_enchant`, coin 20); `Scripts/Gameplay/NPCs/Blacksmith.gd:33`; test `UI/verify_tasks.gd` |
| Gold-diamond list (D161/D390) | ✅ | `NpcBase.gd:152-158`, `StoryNpc.gd:22-28` (`main: true` first); `verify_tasks` [4][5] per D390 |

Tails:
- 1 Objective hints: no `hint`/`from` in `story.json`, no hint line in the Journal, no `verify_journal` check. The texts are Claude's drafts per D571, so this does not wait on Sapega.
- 3 Speech bubbles: waits on art. Sapega's `bubble_body.png` / `bubble_tail.png` (D160) have not replaced the temporary PNGs.

Tail summary: npc_recall_plan: 2 tails — slice 1 objective hints (not built); slice 3 bubble art (waits on art)

### design/lab_boss_plan.md
Verdict: ALL BUILT
| Slice | Verdict | Evidence |
|---|---|---|
| 1 Boss core (BossEnemy, BossLogic, hazards, boss bar, defeat_handler) | ✅ | `Scripts/Gameplay/Characters/Bosses/BossEnemy.gd:8` (BOSS_BAR = `Scenes/UI/boss_health_bar.tscn`), `:25` phase2; `BossLogic.gd:98-101` charge/slam/fireball/pillar; `Scenes/FX/Bosses/boss_fireball.tscn`; `Scripts/Player.gd:34,312` `defeat_handler`; `UI/verify_bosses.gd`; DemoBoss.gd gone |
| 2 Two bosses as scenes (generated art) | ✅ | `Scenes/Characters/Bosses/brass_collector.tscn`, `fire_djinn.tscn` (the djinn is now a puppet in `LabCells.gd:22`) |
| 3 Fights in rooms | ✅ (superseded by D466/D468) | see the two rows below |
| D466 1–2 Lab boss art candidates + frames | ✅ | D564 pick, D644 frames: `Assets/Characters/Bosses/lab_boss/` |
| D466 3 Lab boss fight | ✅ | `Scenes/Characters/Bosses/lab_boss.tscn` (D660 moveset); `Maps/LabBoss.tscn:14` instances it; `Scripts/Gameplay/Scenes/LabBoss.gd:4`; `UI/verify_lab_boss.gd:208-214` (move tells/hits) |
| D466 4 Lab boss story text | ✅ | `dialogue_quest/Lab_Boss_Talk.dqd` (`[ЧЕРНЕТКА]`, speaker LAB_BOSS), `Lab_Boss_TakesCloak.dqd`; `LabBoss.gd:98,140,156` |
| D468 1–2 Scorpicore warrior + scorpion art | ✅ | `Assets/Characters/Bosses/mayor_hall_boss/`, `giant_scorpion/` (D644) |
| D468 3 Mayor Hall duo fight (D557: the scorpion is cutscene only) | ✅ | `Scenes/Characters/Bosses/scorpicore_warrior.tscn`, `giant_scorpion.tscn`; `Maps/MayorHall.tscn:16`; `Scripts/Gameplay/Scenes/MayorHall.gd:44-46,86-87` (scorpion), `:9-10` capture (D556); `UI/verify_mayor_boss.gd` |
| D468 4 Victory text | ✅ | `dialogue_quest/MayorHall_Victory.dqd`, `MayorHall_Defeat.dqd` (`[ЧЕРНЕТКА]`); `MayorHall.gd:139,160` |

Tails: none.
Tail summary: lab_boss_plan: all built

### design/lab_story_plan.md
Verdict: TAILS (minor, non-code)
| Slice | Verdict | Evidence |
|---|---|---|
| 0 B79 XP reset at New Game | ✅ | `Scripts/Game.gd:170-171` `get_xp_manager().reset()`; `UI/verify_xp_curve.gd` |
| 1 Cutscene helper + HUD + skip | ✅ | `Scripts/Systems/Cutscenes/Cutscene.gd`, `ScreenFade.gd`; `Scenes/UI/cutscene_skip_prompt.tscn`, `Scripts/UI/cutscene_skip_prompt.gd:34` (`cutscene_skip`); used in Canyon/CityGates/MayorHall/LabCells/LabBoss .gd; `UI/verify_cutscene.gd`. `NpcArrival.gd` no longer exists (first-meeting cutscenes cut, D442) |
| 2 Bosses core | ✅ | see lab_boss_plan slice 1 |
| 3 Mayor Hall beat | ✅ (boss superseded by D468/D664) | `MayorHall.gd:105,139,160`; `UI/verify_mayor_hall.gd` |
| 4 Laboratory split (D303) | ✅ | `Maps/LabCells.tscn`, `Maps/LabBoss.tscn`; `locations.json:21` rooms; `UI/verify_lab_rooms.gd` |
| 5 Cells cutscene (D304) | ✅ | `Scripts/Gameplay/Scenes/LabCells.gd:171` sets `lab_cells_cutscene_complete`; `:22` djinn puppet; `UI/verify_lab_cells.gd` |
| 6 Wake + acquaintance + Малік + assists (D305) | ✅ | `LabCells.gd:27` `MALIK_TASK`, `:67-72` entry state from flags; `Assets/Characters/NPCs/malik/` |
| 7 Mob corridors (D306) | ✅ | `Maps/Laboratory.tscn:441` `Fight_Upper` (+Middle/Lower); `Scripts/Gameplay/Scenes/Laboratory.gd:12` `lab_corridors_complete`; `UI/verify_laboratory.gd` |
| 8 Boss hall (D307; boss is now the mercenary, D466) | ✅ | `LabBoss.gd:12-13,49`; objective "Defeat the mercenary" `story.json:82`. The listed leftover (a story.json zone for LabBoss) is superseded by D618: titles come from `locations.json:21` via `GameFlow.location_title()` (`GameFlow.gd:126-127`) |
| 9 Demo end + full route | 🟡 | Code ✅: `LaboratoryOutside.gd:49,103` (`demo_end_complete`), `UI/verify_lab_route.gd`, `UI/verify_demo_end.gd`. The leftovers the plan lists are not done: no `fb17_*` captures anywhere in `design/` (needs a display), and the exe rebuild cannot be checked from the repo |
| 10 Art and voices (D309/D310) | ✅ | `Assets/Characters/Bosses/*`, `Assets/Characters/NPCs/{malik,prisoner,alchemist}`; `Assets/Backgrounds/Lab/gen_*.png` used in `Maps/LabCells.tscn:4-20`; `Assets/Audio/Voice/Boss/*`, `Voice/Lab/prisoner_incantation_0.ogg`; `Resources/Data/sound_events.json:125-131` boss_voices (incl. `lab_boss`) |

Tails:
- 9 Demo end: the `fb17_*` captures and contact sheet were never taken (non-code; needs a display). The exe rebuild cannot be verified.

Tail summary: lab_story_plan: 1 tail — slice 9 fb17 captures not taken (non-code; code all built)

### design/world_expansion_plan.md
Verdict: TAILS (minor, non-code)
| Slice | Verdict | Evidence |
|---|---|---|
| 1 XP in data (D297; curve amended by D492/D642) | ✅ | `Resources/Data/xp_curve.json` (`to_next`, levels 1-4 still 100/150/200/250); `Scripts/Managers/XPManager.gd:10,27,62`; `xp_reward` in `Resources/Enemies/enemy_stats_melee.tres:21` (30), `enemy_stats_fast.tres:22` (25); `_calculate_xp_reward`: 0 hits; `UI/verify_xp_curve.gd` |
| 2 Spawners per fight | ✅ | `Scripts/Gameplay/RoomEnemySpawner.gd:28` `trigger_area`, `:31` `state_key`, `:75-77` duplicate key → `push_error`, `:109` own children |
| 3 The road (D296, D298) | ✅ | `Maps/MapData.txt`: 6 cells with the DesertRoad uid; `Maps/DesertRoad.tscn:286/321/359` Fight_Dunes/Mesa/Caravan (plus later fights), `:180-181` SavePoint_BeforeCity x 4900, `:163` Terrain, `:440-449` ItemPickups (iron_ingot, herb), `Chest` (chests_plan); `Scripts/Gameplay/ItemPickup.gd:16,58` `picked_<name>`; `UI/verify_desert_road.gd`, `verify_map_geometry.gd`, `verify_room_state.gd` |
| 4 Landmarks (D299) | 🟡 | Art ✅: `DesertRoad.tscn:18-20` `Road/gen_tower`, `gen_wreck`, `gen_shrine`. The `fb23_*` captures along the road are missing from `design/` (non-code) |
| 5 B79, XP survives a save | ✅ | `Scripts/Systems/Save/Modules/PlayerData*.gd:68-69` write level/xp, `:152` `xp_manager.restore(level, xp)` |
| Laboratory outline | ➖ moved | moved to lab_story_plan (D303), see above |

Tails:
- 4 Landmarks: the `fb23_*` road captures were never taken (non-code).

Tail summary: world_expansion_plan: 1 tail — slice 4 fb23 captures not taken (non-code; code all built)
