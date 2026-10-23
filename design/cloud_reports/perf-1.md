---
type: report
status: done
tags: [cloud, performance, loading, D434]
---

# Cloud report — `cloud/perf-1` (2026-10-23)

**Done:** [[performance_plan]] slices 1, 2, 3 and 6, plus D434. A room change now fades to black (0.25 s), the room swaps under black and the screen fades back in (0.25 s). Walking across an edge, doors, story teleports, New Game and Load Game all use this fade. On the main thread a swap now costs 0.4–2.3 ms for load+instantiate (before: 4–260 ms), and every room change prints 0–4 log lines (before: 19–95). **Not done:** slices 4, 5 and 7 (not requested; 7 is still blocked on Q83/Q84). The first room after New Game/Load Game still loads on the main thread, under a black screen (see §5).
**D-IDs for the register (agent calls, for Sapega to confirm):** D477–D480 (text in §6). **B rows fixed:** none.
**Full suite:** see §7.

Branch `cloud/perf-1` from `origin/feature/backlog` @ `4c7903b8`.

## 1. Slice 1: quiet room changes
- `Scripts/Game.gd`: removed the temporary `DebugLogger.current_level = INFO` and every `print()`/`print_stack()` on the load path (`_ready`, `_initialize_save_and_room`, `load_room`, `init_room`). Also removed `_dump_quest_flags()` (the same "temporary" quest-flag diagnostic, run on each `init_room`). `set_quest_flag()` now logs through `DebugLogger.verbose`. Real problems still go to `push_warning`/`push_error`.
- New `SampleProject/UI/verify_quiet_transitions.gd`. It counts log lines with an `OS.add_logger()` counter. Teleport Canyon → Village: **0 lines**. Walking back west into Canyon: **3 lines**, under the limit of 5. `RESULT: ALL PASS`.

## 2. Slice 2: neighbour rooms load in the background
- New `Scripts/Gameplay/RoomPreloader.gd`, a MetSysModule added in `Game._initialize_save_and_room()` before the first `load_room()`. On every `room_loaded` it holds the current room, every `get_neighbor_rooms()` room and every `RoomDoor.target_room`, using `ResourceLoader.load_threaded_request()`. It drops anything else it held. On `process_frame` it moves finished loads into `held` with `load_threaded_get()`. `wait(path)` yields frames until a requested room is ready.
- `MetSysGame.load_room()` is unchanged: its `load()` now hits the held scene.
- New `SampleProject/UI/verify_room_preload.gd`, `RESULT: ALL PASS`:
  - Village is held within 3 s of Canyon, the current room is held, and LabBoss is not cached.
  - A real `KEY_D` hold walks into Village: the screen is black at the swap, the longest frame of the change is 18 ms (headless), and fade+swap+fade takes 534 ms.
  - After the walk Canyon is still held and LabBoss is still not loaded.
- No SCRIPT ERROR from compiling scripts on the worker thread, in the suite or in the measurement run.

## 3. Slice 3: doors and story teleports preload their target
- Door targets come from `RoomPreloader._on_room_loaded()`: in Village, ElderHouse is held.
- The new `Game.preload_room(path)` is called from `Canyon.gd:670` at the start of the descent cutscene (→ DesertRoad) and from `MayorHall.gd` `_fight()` (→ LabCells; the fight ends in that teleport whether you win or lose).
- `verify_room_preload` [3]–[4] checks the door target, `preload_room()`, and a held room swapping at once under a cutscene's own black.

## 4. D434: the fade, in the one place every room change goes through
- **`Game.load_room()`** is now the only path:
  1. it pauses the tree and requests the room;
  2. `ScreenFade.to_black(0.25 s)`, skipped when a cutscene already made the screen black;
  3. `room_preloader.wait()`, so the screen stays black only while the load is still running;
  4. `room_swapping`, then it detaches and frees the old room and calls `super.load_room()` (synchronous);
  5. it restores the pause and starts `from_black(0.25 s)` without awaiting it, so the caller places the hero in the same frame, still under black;
  6. `room_change_finished` fires when the screen is light again.

  A change that starts during another one waits for `room_change_finished`.
- **`teleport_to_room()`** is now a coroutine: it awaits `load_room()`, places the hero, and awaits the fade-in. `RoomDoor` still calls it deferred.
- **Walking across an edge**: the new `Scripts/Gameplay/FadeRoomTransitions.gd` replaces `ScrollingRoomTransitions`, whose camera pan would happen under black and so would never be seen. The new module keeps the room-offset shift, the 16 px edge nudge and the camera smoothing reset. It keeps the tree paused until the fade-in ends, as the scroll did, so the hero cannot cross back. The addon file is untouched.
- **Cutscenes that teleport** (Canyon → DesertRoad, MayorHall → LabCells) still fade out themselves (0.6 s) and call `teleport_to_room()` without `await`, because their room is freed. They no longer call `from_black`: the room change lifts their black (D478). `verify_canyon_exit` and `verify_mayor_hall` pass.
- **`ScreenFade`** (`Scripts/Systems/Cutscenes/ScreenFade.gd`):
  - it takes a `time` and gains `is_on()`/`is_black()`;
  - `from_black()` keeps the overlay itself rather than its host, which a teleport may have freed (this caused a SCRIPT ERROR in `verify_lab_boss`);
  - it takes the layer out of the tree at once, so a room change that starts right after cannot reuse a dying layer.
- New token: `UITokens.ROOM_FADE_TIME := 0.25`.
- **The callers in the tests and captures** (58 files under `SampleProject/UI/`) now `await game.teleport_to_room(...)`. Three tests checked something during the first frames after a teleport, and now look at the swap instead:
  - `verify_city_gates_raid` [7]: the B80 fall is checked right after the swap, not after the fade-in;
  - `verify_lab_cells`: `started.clear()` moved before the teleport, because the cells cutscene starts during the fade-in.

## 5. Slice 6: New Game and Load Game
- `MainMenu.new_game_button_up()` and `LoadGameMenu._load_slot()` now run `await ScreenFade.to_black(0.25 s)`, then `SceneLoader.load_scene()`, which loads `Game.tscn` with `load_threaded_request` behind a plain black loading screen. The new `Scenes/UI/loading_black.tscn` replaces Maaack's example in `scene_loader.tscn`.
- The overlay lives in the root, so it stays black through the scene change. The first `Game.load_room()` lifts it once the room is in.
- **Left as is:** `Game` add_child+`_ready` (50 ms) and the first room's load (Canyon 237 ms here) still run on the main thread. They run under a fully black screen, so nothing visible freezes. Moving that first load onto the worker thread would change the start sequence that about 100 test scripts rely on (they instance `Game.tscn` and expect a synchronous first room).
- `verify_main_menu` [6]: a real mouse click on New Game starts the fade, the screen stays black until Game is `current_scene`, `room_entered` fires, and the screen is light again 699 ms after the click. `RESULT: ALL PASS`.

## 6. D-ID text (next free numbers after D476)
| D-ID | Kind | Decision |
|---|---|---|
| D477 | AGENT CALL | **Walking across a room edge fades like every other room change (D434).** The camera scroll (`ScrollingRoomTransitions`, 0.4 s) is replaced by `FadeRoomTransitions`: 0.25 s out, swap, 0.25 s in. The tree is paused from the cell change until the fade-in ends. A pan under a black screen cannot be seen. |
| D478 | AGENT CALL | **A cutscene that ends in a teleport lifts its black through the room change, in 0.25 s instead of 0.6 s.** Canyon's descent and the Mayor Hall transport still fade out themselves in 0.6 s, then `Game.load_room()` lifts the black. |
| D479 | AGENT CALL | **New Game and Load Game: the menu fades to black in 0.25 s, `SceneLoader` loads `Game.tscn` in the background behind a plain black screen (`Scenes/UI/loading_black.tscn`, which replaces Maaack's example loading screen), and the game fades in once the first room is ready.** The first room itself still loads on the main thread under black. |
| D480 | AGENT CALL | **RoomPreloader holds the current room, its MetSys neighbours, its door targets and any room a cutscene asks for with `Game.preload_room()`.** Everything else is released on each room change. This is the "direct neighbours and door targets" recommendation in the plan's Decisions §4, plus the current room, so walking back is free. |

## 7. Measurements: `measure_performance.gd`, before vs after
Run in this container under xvfb: `llvmpipe` software GL on a 4-core Xeon at 2.10 GHz. Every frame costs 110–200 ms just to draw, so the "longest frames" columns are set by the renderer, not by the load, and are not comparable with the plan's RTX 3060 numbers. The CPU columns (load, instantiate, `_ready`, log lines) are valid.

The **before** run is from a clean worktree of `origin/feature/backlog` @ `4c7903b8`. An earlier attempt was discarded because it read files while they were being edited. The **after** run is this branch. Logs are `/tmp/perf_before.log` and `/tmp/perf_after.log` (not committed). `measure_performance.gd` was adapted to the faded room change:
- the room timing starts at `Game.room_swapping`;
- a `fade out+black` column was added;
- the walk row splits "cell change → swap" from "swap → room ready";
- New Game is clicked through `MainMenu.new_game_button_up()`.

**New Game**
| | before | after |
|---|---|---|
| click frame | **314 ms** (Game.tscn load+instantiate) | **0.2 ms** (the fade starts) |
| click → room_entered | 1356 ms | 1274 ms (light again at 1420 ms) |
| Canyon load+instantiate | 259 ms, visible freeze | 237 ms, under black |
| longest frame with something on screen | 910 ms | 147 ms (= this renderer's draw time) |
| longest frame under black | — | 584 ms (Game `_ready` + Canyon load) |
| log lines | 95 | 4 |

**Room changes.** Time on the main thread is load+instantiate at the swap. "Black beyond fade" is how long the black screen held after the 250 ms fade-out because the load was still running (≈0 means the room was already held).
| Change | before: load+instantiate / log lines | after: load+instantiate / black beyond fade / log lines |
|---|---|---|
| teleport → Village (first visit) | 181 ms / 29 | 1.1 ms / ≈12 ms / 0 |
| teleport → DesertRoad (first visit) | 152 ms / 40 | 2.3 ms / ≈58 ms / 1 |
| teleport → MayorHall (first visit) | 84 ms / 26 | 1.0 ms / ≈20 ms / 0 |
| teleport → LabCells (first visit) | 69 ms / 28 | 1.0 ms / ≈1 ms / 1 |
| teleport → LabBoss (first visit) | 54 ms / 25 | 1.5 ms / ≈129 ms / 1 |
| teleport → LaboratoryOutside (first visit) | 65 ms / 22 | 1.2 ms / ≈21 ms / 0 |
| walk Canyon → Village | 36 ms (cell → ready 42) / 36 | 1.2 ms (swap → ready 6.5) / 0 / 0 |
| walk DesertRoad → CityGates | 16 ms (18) / 25 | 0.8 ms (2.8) / 0 / 0 |
| walk CityGates → City | 51 ms (61) / 19 | 1.2 ms (5.7) / ≈14 ms / 0 |
| walk City → MayorHall | 12 ms (16) / 24 | 0.9 ms (4.8) / 0 / 0 |
| walk LabBoss → LaboratoryOutside | 24 ms (29) / 27 | 0.9 ms (4.9) / 0 / 1 |
| revisit DesertRoad | 61 ms / 57 | 1.8 ms / 0 / 1 |
| revisit Canyon | 45 ms / 46 | 1.2 ms / 0 / 3 |

The "first visit" teleports come straight from the script, so they are the un-preloaded case on purpose. Their load now runs on the worker thread while the screen fades and holds black, and it no longer freezes a frame. Some "fade out+black" values are under 250 ms (123–171 ms) because this renderer's 130 ms frames quantise the tween. `LabCells` still shows one 553 ms frame during its cells cutscene (2235 ms before). That is the unexplained stall in the plan's § Found along the way. It is not a room-change cost.

## 8. Tests
- New: `verify_quiet_transitions` ALL PASS, `verify_room_preload` ALL PASS. Extended: `verify_main_menu` [6] ALL PASS.
- Re-run after the fixes: `verify_lab_cells`, `verify_lab_boss`, `verify_city_gates_raid`, `verify_canyon_exit`, `verify_mayor_hall`, `verify_scripts_compile` all PASS.
- Full suite: filled in below.
