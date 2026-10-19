---
type: audit
status: reference
tags: [code, memory, plugins]
---

# Code review — the whole game, 2026-10-19

Sapega: «треба зробити код ревью нашої гри всієї, знайти діри в пам'яті, незручність в підтримуванні, можливо
вже той час коли нам треба переходити на свій код і не використовувати плагіни».

Scope: 245 scripts / 34,114 lines in `SampleProject` (Legacy excluded), 25 addons, 20 autoloads. Method: a
memory run in the real game (laps through seven rooms, `Performance` monitors, `Node.print_orphan_nodes()`), a
reference map of every addon and autoload, grep metrics, reading the hot spots. Bugs in [[BUGS]] terms, decisions
in [[questions_for_sapega]] (Q61–Q63), unbuilt work in [[BACKLOG]].

## Verdict

- **One real memory leak, fixed and now guarded by a test (B73).** Every room change kept a whole copy of the room.
- **Plugins:** two are the game's spine (MetroidvaniaSystem, DialogueQuest), one is entangled (Maaack menus), three
  are small enough to own, **~17 are dead weight** — five of them start an autoload with the game, one is a broken
  GDExtension. Moving to our own code pays off now for the dead and the small ones; for MetSys and DialogueQuest it
  does not.
- **Maintainability:** the room story flow is copy-pasted into six scripts (B66 came straight from that), 215 raw
  `print()`, dead EventBus signals, and an `addons/**` ignore rule that hides edits to addon files.

## 1. Memory

### B73 — every room change leaked a whole room (fixed, `866673ea`)

`MetSysGame.load_room` — the project's edit of the MetSys template — instantiated the room scene once to "check"
it, never freed it, and instantiated it again for the map. Ten laps through Canyon → Village → DesertRoad →
CityGates → City → MayorHall → Laboratory:

| | per lap of 7 rooms | static memory after lap 1 |
|---|---|---|
| before | +374 orphan nodes, +395 objects, +3.3 MB | 173 MB |
| after | 0 orphans, +1 object, +0.0 MB | 119.5 MB |

`SampleProject/UI/verify_memory.gd` laps the rooms and fails on orphans piling up or static memory growing; on the
old code it fails (449 → 1,197 orphans, +6.5 MB), on the fixed one it passes.

### Smaller notes

- +1 object per lap after the fix with flat memory — noise, not worth chasing.
- `UIManager._exit_tree` disconnects EventBus signals "against leaks" (`UIManager.gd:43–55`) — unnecessary in
  Godot 4, freed objects drop their connections. Delete when the file is next touched.
- 50 `await get_tree().create_timer(...)` coroutines. They are guarded by run ids, not by the node still being in
  the tree; Godot 4 drops a resume on a freed object, so nothing crashes today — keep it in mind for new flows.

## 2. Plugins — keep, own, remove

| Addon | Lines | Used by the game | Verdict |
|---|---|---|---|
| MetroidvaniaSystem | 4,249 | `MetSys` in 34 files, rooms, map, transitions | **Keep.** Its `Template/` scripts are already edited by us (B73 lived there) — treat them as our code |
| dialogue_quest | 2,514 | `DialogueQuest` in 7 files; D110 keeps it as engine and data | **Keep** |
| maaacks_menus_template | 5,529 | `MainMenu` base class in 17 files, input remapping UI, `ProjectMusicController` | **Replace with our own menus** when the Figma screens are next touched (Q63) — medium effort |
| fsm | 97 | `FiniteStateMachine` / `FSMState` in `ui_root.gd`, `ui_state.gd` | **Own** — copy into `Scripts/UI` |
| interaction_system | 60 | `Interactable` in ItemPickup and the NPCs | **Own** |
| ModalDialog | 369 | `modal_dialog.tscn` inside `modal_layer.tscn` | **Own** with the modal layer; its `ModalDialogGlobal` autoload is unused |
| CustomRunner | 101 | `SampleProject/CustomRunnerIntegration` (editor run configs) | Sapega's call — dev tool (Q61) |
| DropShadowCaster2D, TweenAnimation, demo, dynamic_water_2d, godot-triggers, godot_tree_table, input_manager, midi, moving_platforms, scatter2d, tree_maps, tween_resource | ~14,000 | nothing | **Remove** |
| basic_settings_menu | 337 | nothing (its `SettingsData` autoload starts anyway) | **Remove** |
| easy_trajectory | 1,197 | nothing (`TrajectoryRegister` autoload starts anyway) | **Remove** |
| long_scene_manager | 1,171 | nothing (`LongSceneManager` autoload starts anyway; scenes change via `change_scene_to_file` in 8 scripts) | **Remove** |
| modal_window | 406 | nothing (`ModalWindowManager` autoload starts anyway) | **Remove** |
| godot-rapier2d | 660 | nothing; registered in `extension_list.cfg` **without binaries** — errors on every start | **Remove** |
| gut | 18,454 | nothing — the project has no GUT tests, the suite is `verify_*.gd` | **Remove** |

Plan: **phase 1** remove the dead ones in one commit (suite + playthrough) — fewer autoloads at start, no rapier
errors, ~40k lines of other people's code gone (Q61); **phase 2** own fsm, interaction_system and ModalDialog;
**phase 3** our own menus instead of Maaack (Q63).

## 3. Maintainability

1. **The room story flow is copy-pasted six times** — Canyon.gd (768 lines), Village.gd (338), Laboratory.gd (217),
   CityGates.gd (192), DesertRoad.gd (190), LaboratoryOutside.gd (180) each carry their own `_execute_step`,
   `_play_dialogue`, `advance_state`, `_complete_quest_for_dialogue`. The rule "an already-done branch must call
   `advance_state()`" lives in a comment in Village.gd and was missed in LaboratoryOutside.gd — that was B66. A
   shared `RoomStoryFlow` base (steps as data, the skip rule in one place) removes ~100 lines per room and the class
   of bug ([[BACKLOG]]).
2. **215 raw `print()`** in game code next to `DebugLogger` — `Game.load_room` alone prints 2–4 emoji lines per room
   load. Route through `DebugLogger` with a level, or delete.
3. **EventBus (40 signals):** `scene_loaded`, `scene_transition_completed` and `player_respawned` are listened to and
   never emitted — `UIManager.gd:34–35` never rebuilds the UI root on a scene change, `player_vitals_panel.gd:59`
   never runs; `scene_transition_started` and `item_used` are unused; four are emitted with nobody listening. Prune.
4. **Silent fallbacks against the project rule:** 14 `has_method`, 25 `get_node_or_null`, 71 `is_instance_valid`.
   Review per file when touched — fail loudly, fix the cause.
5. **`Game.load_room` guards a "double call"** (MetSys emitting `room_loaded` several times) with a block and logs —
   a symptom guard; the cause is unknown.
6. **Repository:** `.gitignore` has `addons/**` while ~1,400 addon files are tracked — an edit to a tracked addon
   file needs `git add -u`, a new addon file is silently untracked (Q62). Tracked dead folders, all `.gdignore`d:
   `Extensions` (46 files), `NZ_projectiles` (68), `demo_test_scene_manager` (16), `Maps/Legacy` (18). The git pack
   is 2.46 GB.
7. **Files to split when next touched:** Canyon.gd 768, DefaultEnemy.gd 634, Game.gd 602, EnemyLogic.gd 584,
   SkillManager.gd 506, the Game Menu components 360–470 each.

## Priorities

1. ~~B73 + `verify_memory.gd`~~ — done.
2. ~~Remove the dead plugins (Q61)~~ — done (D240). The "unused" `basic_settings_menu` turned out to cap the game at
   60 FPS and reset the audio buses at every start; the cap is now our own setting.
3. `RoomStoryFlow` base class — kills the B66 class of bugs.
4. `print` → `DebugLogger`; prune EventBus.
5. Repository hygiene: ~~the `addons/**` rule (Q62)~~ done (D241); the dead folders, and the root clutter (two C# projects,
   `test.tscn`, `map.tscn`, `tile_map_set.*`, loose `*.gd.uid` without scripts, `debug_metsys.gd`, `follower_click.gd`).
6. Our own menus instead of Maaack (D242) — when the menus are next touched.
