---
type: report
status: reference
tags: [tests, audit]
---

# Test suite audit, 2026-10-27

Sapega: «а нам прям всі 140 потрібні?» — «зроби». Every `SampleProject/UI/verify_*.gd` was read (header and checks)
and given a verdict: **keep**, **delete** (every check made elsewhere — named check by check), **merge into X** (unique
checks moved, file deleted) or **speed up**. Tests that run the same rooms were compared check by check. Rules: no check
loses its meaning, no assertion is weakened, real-time tests stay real-time and `## SERIAL`. Not touched: files that
running cloud branches change (`verify_camera_transitions` — rooms-dressing; `verify_bow`, `verify_kusakam_skills`,
`verify_skill_rules`, `verify_skill_trees`, `verify_souls_combat` — skills-v2-data; `verify_hero_death` lives only on
hero-death) and the whole skills group (skills-v2 is rewriting that screen) — those get a verdict below and nothing else.

## Before / after

| Full suite, J=4, this machine (shared with other agents' Godot and ComfyUI) | Scripts | Wall time | Sum of per-test s | FAIL |
|---|---|---|---|---|
| before (`4cca758a`) | 138 | 19 min 32 s | 3436 | 2 — combat_feel, masher (both load flakes, green alone / known) |
| after | 136 | 19 min 47 s | 3440 | 2 — combat_flow (green alone, 42 s), masher (a different [7] line) |
| orchestrator's run before `8ca72031` (no SERIAL yet), quieter machine | ~140 | 14 min 17 s | 3305 | 3 — city_gates_raid, hit_feel (load), masher (180 s cap) |

**Honest result: two files fewer, no measurable wall-time change.** The two removed scripts cost 29 s of CPU
(~7 s of wall at J=4) and city_gates_raid's 20 s moved out of the serial tail — all of it inside the noise of this
machine (masher alone swung 346 → 382 s between the runs because its group fights retry). The suite is slow because
a handful of tests play in real time, not because of duplicates: across 138 scripts only two were fully covered
elsewhere. The levers that do move minutes are follow-ups 1 and 3 below.

## Where the time goes

- **The serial tail is a third of the wall time or more.** `run_verify.sh` runs `## SERIAL` tests after the rest,
  one by one: masher (346 s), city_gates_raid (20 s), hit_feel (16 s) — 6 min 22 s of the before-run's 19 min 32 s
  (and of the orchestrator's 14 min 17 s). Everything else runs four at a time.
- **masher ran [4] and [6] at 1× instead of its SPEED, with a physics step the game never uses.** The test plays at
  `SPEED` 4 (`TimeManager.set_time_scale(4)`, physics at 240 Hz → the game's 1/60 s step). Its [4] meets each boss the
  way the player does, through the room's intro cutscene — and `Cutscene._release()` wrote `Engine.time_scale = 1.0`,
  over whatever `TimeManager` held. From then on ([4] both bosses, [6] the whole drill) the game ran at 1× with a
  1/240 s physics step. Root cause fixed in `Cutscene.gd`: on release it restores `TimeManager`'s scale (1.0 in the
  game, so nothing changes for the player; the skip still runs at `SKIP_SPEED`). Measured with `MASHER_ONLY=DRILL`
  ([4] + [6] only): 203 s before, 192 s after — the gain is small because on this machine 240 Hz physics does not
  keep up anyway (the 4× is not reached); the point of the fix is that [4] and [6] now test the game's physics step.
- **Headless frames are capped at ~145/s, not by `max_fps`.** Measured: `Engine.max_fps` 60 → 63 frames/s, 240 → 147,
  0 → 144; only `OS.low_processor_usage_mode_sleep_usec = 0` uncaps it. In headless the window «can't draw», so Godot
  sleeps `low_processor_usage_mode_sleep_usec` (6900 µs) every frame. masher's `Engine.max_fps = 240` («a frame per
  physics step») therefore gives ~1.65 physics steps a frame, not one. Recorded, not changed: the masher passes in
  this regime and its fights are tuned in it.
- **Why heavy tests are heavy:** they play in real time. `create_timer` sleeps at time scale 1 (combat_enemies 43 of
  them, souls_combat 73, combat_flow 49, audio 27, archer 17) and `for i in N: await physics_frame` walks. The fast
  pattern exists (masher: `TimeManager.set_time_scale(k)` + `Engine.physics_ticks_per_second = 60 * k` +
  waits counted as `Engine.time_scale / Engine.physics_ticks_per_second`), but moving a test onto it means rewriting
  every wall-clock loop inside it (`t += 1.0 / physics_ticks_per_second` would silently become real seconds) and
  re-tuning against the ~145 frames/s cap — one test at a time, not in this pass (follow-up 3).
- **Load flakiness has one shape:** a wall-clock deadline or a process-time `create_timer` waiting for a physics
  outcome. Under suite load a frame can take longer than `max_physics_steps_per_frame` (8) steps, so physics falls
  behind the clock. city_gates_raid was SERIAL for exactly that (its `_until` used `Time.get_ticks_msec()`); its
  deadline now counts physics steps and it runs in the parallel phase. Eleven more scripts carry the same wall-clock
  `_until` copy (`grep -l "get_ticks_msec() + int(max_s" SampleProject/UI/verify_*.gd`); combat_feel failed this way in
  the before-run (B-row candidate below).
- **Wasted waits on the real route:** when lab_route's `_stick_until` sees LaboratoryOutside, the closing talk has
  already run and the end screen already exists (probed: one DemoEndScreen at that line); its following
  `_until(dm.is_dialogue_active(), 6.0)` then waits the full 6 s of clock for a talk that is over. Left as is; worth
  a look when the test is next touched (is the talk really that short with `bubble_time_scale` 0, or is it skipped?).

## Done in this pass

| Script | Change | Coverage kept by |
|---|---|---|
| `verify_lab_rooms` | deleted | room_entrances [1]/[4], lab_cells, lab_boss, lab_route, map_geometry [4], camera_transitions — row below |
| `verify_demo_end` | merged into `verify_lab_route`, deleted | lab_route [5]/[6] + the D473 step checks moved into lab_route `_finale(screen, true)` |
| `verify_city_gates_raid` | `_until` counts physics steps, `## SERIAL` dropped | — (same checks) |
| `verify_masher` (via `Cutscene.gd`) | [4] and [6] run at `SPEED` with the game's physics step | — (same checks) |

## B-row candidates (for the orchestrator)

- **Cutscene._release() overwrote the time scale** (fixed here, `Cutscene.gd`): it set `Engine.time_scale = 1.0`
  instead of `TimeManager`'s scale; any time scale set through `TimeManager` (masher's `SPEED`; in the game a hitstop
  or slow motion that is active when a cutscene ends) was lost while `TimeManager.time_scale` still claimed it.
- **verify_combat_feel flaky under load** (not changed): [2] «a bandit dropped on the hero slides off to the floor
  (y 327.9 vs 368.0)» failed in the J=4 before-run, passes alone. It waits `create_timer(1.2)` (process time) for a
  physics result; when a frame exceeds 8 physics steps the slide is not finished. Fix: wait physics frames
  (72 = 1.2 s), same for its other drop checks.
- **verify_masher flaky under machine load** (not changed): `## SERIAL` keeps the suite's own tests away, not other
  agents' Godot / ComfyUI processes. Today, alone in the suite but on a busy machine: [7] «an enemy idles in reach
  ≤ 1.0 s» failed at 1.08 / 1.13 / 1.46 s, [3] GOOD lost the Caravan group twice, and once (fix reverted) the drill
  missed the melee «evade» answer. Before calling a masher FAIL a regression, rerun it on a quiet machine.

## Follow-ups (not done — over the hour)

1. **One door walk instead of two.** room_entrances [4] and camera_transitions both go through every RoomDoor both
   ways with real E. One walk could record the camera frames and the landing checks together (~60–100 s of CPU).
   Blocked while cloud/rooms-dressing edits camera_transitions.
2. **Small merges (file count, ~5 s boot each):** pause → full_regression (unique: GameMenuState, toggle, reopen on
   Inventory, no PauseMenu); misc_modal + misc_destinations → one Misc test (drop misc_modal's source-text checks,
   B4); gamepad → gamepad_parity; settings_graphics + graphics_quality → one Display test; ladders → laboratory (same
   room); npc_arrival + npc_flow (both D442/D454); quiet_transitions + memory + room_preload → one transitions-perf
   test; full_regression's HUD lines are a subset of combat_hud.
3. **Speed-up by game time:** combat_enemies, audio, archer, combat_flow, bosses — put on masher's `TimeManager`
   pattern, rewrite their `1.0 / physics_ticks_per_second` loops; turn the twelve wall-clock `_until` copies into
   one helper in `input_kit.gd` that counts physics steps.
4. **Skills group** (for the skills-v2 lane): skills / skills_combat / skills_ui / hotbar still say «skills.json is
   empty» (Phase 5 fixtures); skill_trees_ui overlaps skill_screen (both drive the D674 window).

## Every script

Seconds: the before-run above (J=4, loaded machine). «unique» = no other script makes these checks; overlaps that
are not full coverage are named, with the follow-up that would fold them.

| Script | s | Verdict | Reason |
|---|---|---|---|
| `verify_ambient_critters` | 21 | keep | D774 critters in the canyon cave; nobody else checks them. |
| `verify_archer` | 80 | keep | Archer and big archer (D386, D652, D692) in real physics; unique. Heavy: 17 fixed `create_timer` sleeps at time scale 1 — speed-up candidate (follow-up 3). |
| `verify_attributes` | 8 | keep | Attribute points and the Status screen investment (D335, D741); unique. |
| `verify_audio` | 45 | keep | Sound event → bus for every event (D274–D278); unique. 27 fixed sleeps — speed-up candidate (follow-up 3). |
| `verify_blacksmith` | 2 | keep | Blacksmith NPC menu (D69, D154); the tasks/crafting tests start past it. |
| `verify_boss_hits` | 29 | keep | B-boss: a boss lands a weapon hit on a hero who presses nothing. masher [4] is the mashing / waiting-behind case, serial and 6 min — this is the fast regression. |
| `verify_bosses` | 80 | keep | Brass Collector and the jinn, every move (D301, D302); unique. |
| `verify_bow` | 27 | keep (skills-v2-data edits it) | Hero bow (D380–D385). Not touched: cloud/skills-v2-data changes this file. |
| `verify_branches` | 27 | keep | Secret branches (D583, D620, D621); verify_gates only walks the stash cage. |
| `verify_camera_rooms` | 105 | keep (parent edited by rooms-dressing) | Section [3] of verify_camera_transitions, split only to stay under the 180 s cap. Folding it back serialises ~230 s in one process — longer critical path, no saving. |
| `verify_camera_transitions` | 122 | keep (rooms-dressing edits it) | Camera on every edge passage and door, both ways (B153). Not touched: cloud/rooms-dressing changes it. Merge candidate with room_entrances [4] (follow-up 1). |
| `verify_canyon_exit` | 35 | keep | Meditation and canyon descent cutscene (D256); unique. |
| `verify_charms` | 9 | keep | Charms D592; unique. |
| `verify_chests` | 12 | keep | Chest open flow D88; verify_gates only walks the key. |
| `verify_chibi_npcs` | 2 | keep | Chibi sheets D677/D598; unique. |
| `verify_city_gates_raid` | 20 | speed up: SERIAL dropped | Its only clock was a wall-clock `_until` deadline (Time.get_ticks_msec) — under suite load 4 s of clock is less than 4 s of game, which is why it was made SERIAL. Now the deadline counts physics steps (game time); nothing in it measures real time, so it runs in the parallel phase. |
| `verify_city_life` | 18 | keep | Living City D740; unique. |
| `verify_combat_enemies` | 142 | keep | Enemy/boss rules D504/D494; unique. Heaviest parallel test: 43 fixed sleeps at time scale 1 — speed-up candidate (follow-up 3). |
| `verify_combat_feel` | 21 | keep — FAIL in this run (B-row candidate) | D443/D444. Failed once in the before-run under load: «a bandit dropped on the hero slides off to the floor (y 327.9 vs 368.0)»; see report. |
| `verify_combat_flow` | 42 | keep | DesertRoad fight end to end (D131); unique. Failed once in the after-run under load («the swing hits the player in front once (got [])», «…hits the player behind (got [])»), green alone (42 s); 49 fixed sleeps at time scale 1 — same flake shape as combat_feel. |
| `verify_combat_hud` | 4 | keep | HUD binding, theme scope, XP bar (Phase 5.12, D776); superset of full_regression's HUD lines. |
| `verify_combat_player` | 41 | keep | Hero side of combat D504/D776/D777; unique. |
| `verify_combat_stats` | 16 | keep | Crit, evasion, attack speed, enemy tempo (D393, D394); unique. |
| `verify_companions` | 26 | keep | Assists D209/D464/D515; unique. |
| `verify_core_wiring` | 2 | keep | ServiceLocator wake-up regression (Phase 5.2A), 2 s; cheap, unique. |
| `verify_crafting` | 4 | keep | Crafting slice 4; unique. |
| `verify_cutscene` | 52 | keep | Shared cutscene skip = full play (D308); unique. |
| `verify_damage_numbers` | 15 | keep | D66 numbers; unique. |
| `verify_dash` | 6 | keep | Dash off a ledge (D200, D264); unique. |
| `verify_demo_end` | 14 | merged into verify_lab_route, deleted | [1] talks + one end screen = lab_route [5] («lab_outside_complete, demo_end_complete», «one demo end screen»); [2] B66 screen again = lab_route [6] («the demo end screen again, one»); [1b] finale D473 (title hidden and button off, control off, HUD faded, camera top_level, camera into the sky, music swells low, title + farewell, title size, Return focus, kit HexButton) moved into lab_route [5b] — the same finale lab_route already waited for. The finale's first frame (title, button, control, camera y, music dB) is recorded when the screen enters the tree: on lab_route's real walk out the screen already exists when the test sees the new room, and by the time the test reaches `_finale` the pan is already in the sky. |
| `verify_desert_road` | 4 | keep | Road state machine and the four enemies on arrival (D439); unique. |
| `verify_dialogue_speaker` | 6 | keep | Speaker name/portrait (Q31, D437); unique. |
| `verify_dialogue_triggers` | 24 | keep | D737/D738/D739; unique. |
| `verify_difficulty` | 7 | keep | D642 paper simulation; fast counterpart of masher. |
| `verify_enchanted_equip` | 16 | keep | B142 enchanted weapon equip; unique. |
| `verify_enchanting` | 3 | keep | D94/D163/D164; unique. |
| `verify_enemy_fx` | 19 | keep | A17 enemy strike FX; unique. |
| `verify_enemy_stagger` | 20 | keep | D264 stagger poses; unique. |
| `verify_enemy_variety` | 23 | keep | D495/D560/D582/D652 variety; unique. |
| `verify_equip_picker` | 5 | keep | Equipment slot picker (D288), real input; unique. |
| `verify_equipment` | 8 | keep | Equipment screen (Phase 5.3); unique. |
| `verify_eventbus_wiring` | 2 | keep | Static EventBus signal/handler arity scan; unique. |
| `verify_flying_enemies` | 29 | keep | D445/D558/D637 fliers; unique. |
| `verify_full_regression` | 10 | keep | All tabs + modal coexisting, 21 switches, leak scan. Its HUD lines are a subset of combat_hud; its open/close/pause lines overlap verify_pause (follow-up 2). |
| `verify_game_menu` | 9 | keep | Game Menu single scene D116/D151/B7/B38/D118; unique. |
| `verify_game_over` | 2 | keep | Game Over screen (Figma 41:83); unique. |
| `verify_game_ui_theme` | 2 | keep | Theme ↔ tokens and scope; unique. |
| `verify_gamepad` | 8 | keep | Pad slice 1 (D156): action→button, pad moves the hero, Start/B, modal A/B, dialogue A. Overlaps gamepad_parity on «every action has a pad button» (follow-up 2). |
| `verify_gamepad_parity` | 17 | keep | Every screen by pad, device-aware prompts (BACKLOG 24); unique. |
| `verify_gates` | 52 | keep | Gates D562/D619/D722–D724; unique. |
| `verify_gift_popup` | 16 | keep | «You obtained» and loot toast; unique. |
| `verify_graphics_quality` | 3 | keep | Quality preset D553/D554; unique (follow-up 2: could join settings_graphics). |
| `verify_hero_feet` | 3 | keep | Feet on the floor in every frame; unique. |
| `verify_hero_motion` | 13 | keep | Jump state chain and landing dust (D262); unique. |
| `verify_hero_shadow` | 13 | keep | Hero shadow; unique. |
| `verify_hit_areas` | 66 | keep | B128 hit zones = drawn art; unique. |
| `verify_hit_feel` | 16 | keep, SERIAL | Measures hitstop in real ms (Time.get_ticks_msec) — must stay real-time and alone. |
| `verify_hotbar` | 2 | skills group — not touched | Phase 5.7 loadout. Header still says «skills.json is empty» (stale); for the skills-v2 lane to re-audit. |
| `verify_interaction` | 3 | keep | Interaction prompt + pickup (D71, D84, D86); unique. |
| `verify_inventory` | 7 | keep | Inventory screen (Phase 5); unique. |
| `verify_journal` | 8 | keep | Journal screen (Phase 5.14); unique. |
| `verify_journal_notes` | 15 | keep | Notes tab (Q87, D622); unique. |
| `verify_journal_sections` | 12 | keep | Quests/Characters/Bestiary (D290, D486); unique. |
| `verify_kusakam_skills` | 24 | skills group — not touched | Also edited by cloud/skills-v2-data. |
| `verify_lab_boss` | 56 | keep | Mercenary fight D307/D466/D564; unique; owns the LabBoss → LaboratoryOutside walk. |
| `verify_lab_cells` | 65 | keep | Cells cutscene and acquaintance D304/D305/D462; unique; owns «LabCells has Malik, Scientist, Prisoner». |
| `verify_lab_rooms` | 15 | deleted | Every check is made elsewhere: [1] «in LabCells on the floor» + LabCells nodes — lab_cells (hero leaves the cell from the floor; Malik, scientist, prisoner act in the cutscene) and lab_route [2]; [2] CorridorDoor/CellsDoor both ways, «offers Enter», «in front of the door back» — room_entrances [4] (every RoomDoor both ways with real E, «offers Enter», lands at the arrival door, «offers the way back»), camera_transitions (same doors, camera); «on the floor» after a door — room_entrances [1] (every door's floor < 120 px under it, its art's foot on the floor ±2 px) with [4] (lands within 64 px of that door after 20 physics frames), and laboratory [2] / lab_route [3] walk on from there with real input; [3] BossDoor → LabBoss + «has its gates» — room_entrances [4], lab_boss (gates close, lift, no collision); [4] LabBoss → LaboratoryOutside on the move_right, «same floor height across», «just inside the edge» — lab_boss («through the gates into LaboratoryOutside»), lab_route [5] («stick east through the gates»), map_geometry [4] (floor at the same height on every left-right passage), camera_transitions (every edge passage both ways). |
| `verify_lab_route` | 111 | keep (absorbed demo_end) | Whole lab route to the demo end, keyboard + pad; now also checks every step of the D473 finale the first time. |
| `verify_laboratory` | 64 | keep | Corridors D303/D306/B83; unique. Merge candidate: ladders (same room, follow-up 2). |
| `verify_ladders` | 10 | keep | Ladder up, jump-off, no attack/roll on a ladder (D225); laboratory only climbs down. Merge candidate into laboratory (follow-up 2). |
| `verify_level_up` | 17 | keep | D436 level-up panel; unique. |
| `verify_living_world` | 6 | keep | BACKLOG 7 + 19; unique. |
| `verify_locale` | 42 | keep | Two languages everywhere; unique. |
| `verify_locations` | 2 | keep | Locations as data (D565); unique. |
| `verify_main_menu` | 7 | keep | Main menu + splash; unique. |
| `verify_map_geometry` | 4 | keep | MetSys map ↔ room scenes (B52, B61, D248); static, unique. |
| `verify_masher` | 346 | keep, SERIAL; [4]+[6] regime fixed at the root | Real bot fights in real rooms (D642, D754–D777); must stay real-time and alone. Its [4] boss meetings and [6] drill ran at 1× with a 1/240 s physics step: the boss intro cutscene's `_release()` wrote `Engine.time_scale = 1.0` over the test's SPEED. Fixed in Cutscene.gd (see above); [4] and [6] now run at SPEED with the game's 1/60 s step, as the header intends ([4]+[6] alone: 203 → 192 s). Its [7] «idle in reach ≤ 1.0 s» and the group fights' outcomes flake under machine load (1.08 s, 1.13 s, 1.46 s seen today in fights before [4], with and without the fix). |
| `verify_mayor_boss` | 36 | keep | Scorpicore axeman D468/D557/D573; unique. |
| `verify_mayor_hall` | 46 | keep | Mayor Hall D255/D300/D301, B51; unique. |
| `verify_memory` | 21 | keep | B73 leak loop; unique (follow-up 2: one transitions-perf script with quiet_transitions + room_preload). |
| `verify_menu_after_room_change` | 24 | keep | B149 deadlock; unique. |
| `verify_misc_destinations` | 14 | keep | Where the Misc rows really lead, mouse + keys; unique. Merge candidate with misc_modal (follow-up 2). |
| `verify_misc_modal` | 8 | keep | Misc modal styling and focus chain. Still carries the B4-style source-text checks (`find("add_child")`, `find("func show_custom_modal")`) — they assert source, not behaviour; replace rather than carry over when merged (follow-up 2). |
| `verify_mouse_cursor` | 9 | keep | D417 cursor; unique. |
| `verify_music` | 5 | keep | Music per room + fight music (D414); unique. |
| `verify_new_points` | 28 | keep | D742 points buttons, B156; unique. |
| `verify_npc_activity` | 14 | keep | D295 NPC work/idle/talk; unique. |
| `verify_npc_arrival` | 17 | keep | NPCs under the hero, merchant/blacksmith arrival (D291, D293, D311). Overlaps npc_flow on D442/D454 (follow-up 2). |
| `verify_npc_chatter` | 5 | keep | Q48 bubble vs dialogue window; unique. |
| `verify_npc_flow` | 6 | keep | D442/D452/D454 NPC greeting and menu; see npc_arrival. |
| `verify_npc_recall` | 4 | keep | Quest recall (D158, D161, D169); unique. |
| `verify_oath` | 5 | keep | Oath keepers D725–D728; unique. |
| `verify_oath_census` | 66 | keep | Census + leanings; unique. |
| `verify_objective_plaque` | 43 | keep | D717 objective plaque; unique. |
| `verify_onboarding` | 14 | keep | Tutorial frames, Controls page; unique. |
| `verify_party_panel` | 5 | keep | D287 party cards; unique. |
| `verify_pause` | 10 | keep | Pause = game menu contract (Phase 5.11). Most lines overlap full_regression / game_menu / misc_modal; unique: UIManager GameMenuState, toggle open/close, reopen on Inventory, «no PauseMenu» guard (follow-up 2). |
| `verify_progression` | 20 | keep | D447/D488/D492; unique. |
| `verify_quiet_transitions` | 5 | keep | Log lines per transition; unique (follow-up 2). |
| `verify_responsive` | 8 | keep | Canvas composition at other resolutions; unique. |
| `verify_road_sections` | 64 | keep | Desert Road sections and ledges; unique. |
| `verify_room_entrances` | 105 | keep | Door art/opening/front layer/ladders + every door both ways; unique. Merge candidate with camera_transitions' door walk (follow-up 1). |
| `verify_room_preload` | 8 | keep | Background preload + fade (performance slices 2–5, D434); unique (follow-up 2). |
| `verify_room_state` | 36 | keep | Room state across exit/save/new game; unique. |
| `verify_rooms_batch1` | 107 | keep | Branch rooms D643 story walk; unique. |
| `verify_save_load` | 5 | keep | Save/Load shared logic (slice 1b); unique. |
| `verify_save_load_room` | 9 | keep | B82 position and MetSys map on load, black screen between menu and room; unique. |
| `verify_scripts_compile` | 5 | keep | Every .gd compiles + every ext_resource used (B42); unique. |
| `verify_secrets` | 12 | keep | D765 secrets; unique. |
| `verify_settings` | 27 | keep | Settings screen rows (Phase 5.13, settings-2); unique (follow-up 2: settings_graphics could join). |
| `verify_settings_graphics` | 3 | keep | Resolution and FPS limit (BACKLOG 41); unique. |
| `verify_shop` | 5 | keep | Merchant/shop slice 2; unique. |
| `verify_side_stories` | 11 | keep | D791 side stories; unique. |
| `verify_skill_casts` | 23 | skills group — not touched | For the skills-v2 lane. |
| `verify_skill_fx` | 54 | skills group — not touched | For the skills-v2 lane. |
| `verify_skill_icons` | 1 | skills group — not touched | For the skills-v2 lane. |
| `verify_skill_ranks` | 3 | skills group — not touched | For the skills-v2 lane. |
| `verify_skill_rules` | 3 | skills group — not touched | Also edited by cloud/skills-v2-data. |
| `verify_skill_screen` | 8 | skills group — not touched | For the skills-v2 lane; skill_trees_ui overlaps it (both drive the D674 window). |
| `verify_skill_trees` | 3 | skills group — not touched | Also edited by cloud/skills-v2-data. |
| `verify_skill_trees_ui` | 5 | skills group — not touched | Overlaps skill_screen (D674 window, Learn +1 + Accept); for the skills-v2 lane. |
| `verify_skills` | 2 | skills group — not touched | Phase 5.4 fixture test; header «skills.json is empty» is stale. |
| `verify_skills_combat` | 1 | skills group — not touched | Phase 5.5 fixture test; same stale header. |
| `verify_skills_ui` | 6 | skills group — not touched | Phase 5.6 fixture test; same stale header. |
| `verify_souls_combat` | 91 | keep (skills-v2-data edits it) | Not touched: cloud/skills-v2-data changes it. Measures real time (Time.get_ticks_msec hitstop) — stays real-time. |
| `verify_starter_loot` | 5 | keep | Starter gear, no potions; unique. |
| `verify_status` | 8 | keep | Status screen (Phase 5.2); unique. |
| `verify_story_dialogue` | 6 | keep | D110–D112 story presentation; unique. |
| `verify_story_journal` | 3 | keep | Prologue data and StoryState (D120, B43); unique. |
| `verify_tasks` | 8 | keep | Blacksmith tasks (D175); unique. |
| `verify_tips_once` | 30 | keep | D745 tips once per run; unique. |
| `verify_tutorial_hints` | 15 | keep | D289/D732/D744 hints; unique. |
| `verify_use_item` | 6 | keep | Inventory actions (D286, B152); unique. |
| `verify_village_fight` | 12 | keep | Village arrival fight and the elder (D438, D743); unique. |
| `verify_village_house` | 18 | keep | ElderHouse camera limits, walls, pad Y back; room_entrances covers only the door hop. |
| `verify_weapon_animations` | 58 | keep | BACKLOG 42 weapon frames and palettes; unique. |
| `verify_world_map` | 14 | keep | World map two levels; unique. |
| `verify_xp_curve` | 4 | keep | D297 XP curve; unique. |
