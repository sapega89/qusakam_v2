---
type: report
status: done
tags: [cloud, performance, loading, D434, S14]
---

# Cloud report — `cloud/perf-check` (2026-10-27)

**Done:** [[performance_plan]] slices **1, 2, 3 and 6 are closed** (MASTER_PLAN S14). Each was checked on today's branch and is covered by a test; the WIP `3046e46f` works as its slices say. On the main thread a room change now costs 1.3–3.0 ms of load+instantiate (before: 4–202 ms), and it prints 2 lines (before: 19–45).
**Fixed along the way:** a **New Game regression** from `735777c0` (Skills party, D742). The HUD's new-points buttons ran a synchronous `load()` of the whole `game_menu.tscn` at game start, which added ~0.6 s under black. Found by bisect. The menu is now warmed in the background, and New Game takes 1.5 s instead of 2.2–3.0 s on llvmpipe (§2).
**Not as the plan says:** slice 6's "the same request covers the first room". The first room still loads on the main thread, under black (§1).
**Slice 7** was not touched (Q83).
**D-IDs for the register (agent calls, for Sapega to confirm):** PC1 and PC2, text in §4. **B rows fixed:** none (§3 has two candidate B rows).
**Full suite:** SUITE_LINE

## 1. The slices on today's branch

| Slice | Code today | Covered by | State |
|---|---|---|---|
| 1 Quiet room changes | `Game.gd` no longer forces INFO. It has 2 `print()`s left, the B145 `room swap` pair (`Game.gd:399, 406`), kept on purpose for the release crash log | `verify_quiet_transitions`: the level is WARNING; teleport Canyon → Village and walk back, each ≤ 5 lines | ✅ done |
| 2 Neighbours in the background | `RoomPreloader.gd` (MetSysModule, `Game.gd:229`): on `room_loaded` it requests the neighbours, the door targets and the current room, collects them each frame and drops the rest. The walk goes through `FadeRoomTransitions.gd` (D434) instead of `ScrollingRoomTransitions` | `verify_room_preload` [1], [2]: Village is held within 3 s in Canyon, LabBoss is not loaded, a real D-hold walk swaps under black with no frame > 100 ms, Canyon is still held | ✅ done |
| 3 Doors and story teleports | Door targets: `RoomPreloader._on_room_loaded`. Story: `Canyon.gd:673` and `MayorHall.gd:126` → `Game.preload_room()` | `verify_room_preload` [3]: ElderHouse is held in Village. **New:** `verify_canyon_exit` checks DesertRoad is held before the cutscene's teleport; `verify_mayor_boss` checks LabCells is held within 3 s of the fight starting | ✅ done |
| 6 New Game / Load Game behind the fade | `MainMenu.gd:121-129` and `LoadGameMenu._load_slot` (`:143-155`): `ScreenFade.to_black`, then `SceneLoader.load_scene`. The loading screen is `Scenes/UI/loading_black.tscn` (`scene_loader.tscn:7`) | `verify_main_menu` [6]: a real click on New Game → fade → Game → `room_entered` → light, with no lit frame between. **New:** `verify_main_menu` checks no frame from the click to full black is ≥ 100 ms (17–18 ms; the old synchronous click froze 275–331 ms). **New:** `verify_save_load_room` [3] clicks the saved slot in the Load Game menu: fade → SceneLoader → Game → saved room and position → light | ✅ done, with one exception (next row) |
| 6 "the same request covers the first room" | **Not true.** The threaded request is `Game.tscn` only. `Game._initialize_save_and_room()` loads the first room synchronously, under black: Canyon 237–240 ms on llvmpipe | — | left as is (PC2) |

## 2. Before / after

`measure_performance.gd -- secs=1 rooms=Canyon,Village,ElderHouse,DesertRoad,CityGates,City` in an xvfb 1920×1080 window, opengl3 on **llvmpipe** (software), on a 4-core 2.1 GHz Xeon, debug build.
- **Before** = `3046e46f^` (`4c7903b8`), in its own worktree, with that commit's own `measure_performance.gd`.
- **After** = today's branch with the fix in §3 (runs 3 and 4).
- Two runs per side, given as `run A / run B`, all in ms.
- The two trees differ by 610 commits of content too (Canyon has new doors and props), so read the main-thread costs as ratios.

### Room loads — main-thread load+instantiate
| Room | first visit before | first visit after | revisit before | revisit after |
|---|---|---|---|---|
| Village | 146 / 202 | 1.5 / 1.5 | 27 / 31 | 1.5 / 1.5 |
| ElderHouse | 6.5 / 4.3 | 1.4 / 1.5 | 30 / 23 | 1.3 / 1.6 |
| DesertRoad | 153 / 144 | 2.2 / 2.5 | 49 / 42 | 2.4 / 2.3 |
| CityGates | 49 / 61 | 1.8 / 1.5 | 14.3 / 14.7 | 1.5 / 1.5 |
| City | 69 / 64 | 1.8 / 1.7 | — | — |
| Canyon | (start) | (start) | 41 / 42 | 3.0 / 2.4 |

**Ratio:** a room swap's load+instantiate is **20–100× smaller** on a first visit and **10–20×** on a revisit. ElderHouse is the exception (~3× on a first visit) because it was already cheap.

The `PERF load` rows teleport straight from the script without a preload. The background load now runs during the fade-out (`fade out+black` 216–311 ms), and frames keep coming. Before, the same work was one frozen frame. The whole teleport now takes 0.44–0.64 s of animated fade (before: 8–206 ms frozen). That is D434's fade, not a freeze.

### Walking through an edge
| Walk | before: cell change → room ready | after: swap → room ready | load+instantiate before → after |
|---|---|---|---|
| Canyon → Village | 59 / 51 | 4.6 / 4.7 | 52 / 46 → 1.7 / 1.5 |
| DesertRoad → CityGates | 25 / 20 | 10.4 / 5.5 | 22 / 17 → 2.6 / 1.4 |
| CityGates → City | 53 / 48 | 13.4 / 9.0 | 44 / 41 → 2.4 / 1.8 |

**Ratio:**
- The swap's main-thread cost is **4–12× smaller**, and what is left is add_child+`_ready` (3–11 ms).
- load+instantiate is **12–30× smaller**.

### Log lines per room change
| Event | before | after |
|---|---|---|
| room change | 19–45 | 2 (Canyon 5: its `_ready` prints) |
| New Game | 95 | 4 |

### Game start (New Game)
| | before | after, at `735777c0`…`HEAD` without the fix | after, with the fix |
|---|---|---|---|
| click frame (menu still lit) | 331 / 275 | 0.2 / 0.3 | **0.2 / 0.2** |
| New Game → `room_entered` | 2310 / 920 | 2956 / 2183 | **1472 / 1538** (light again 1579 / 1647) |
| first room, load+instantiate | 213 / 147 | 826 / 838 | 240 / 237 |
| longest frame while lit | the click frame + 1816 / 509 (no fade) | 100 / 127 | **108 / 110** (one llvmpipe frame) |
| longest frame under black | — | 2098 / 1290 | **626 / 631** |

**Ratio:**
- The click went from a frozen lit frame (275–331 ms) to an ordinary one.
- The start's longest frame is now under black and **2–3× shorter** than before the fix.
- New Game as a whole is **~1.6–1.9× faster** than before the fix, and about the same as `3046e46f^` (whose 920–2310 ms spread came from llvmpipe's first-frame shader work).

### What depends on the software renderer
- **Rendering-bound (llvmpipe), do not compare with the dev-PC tables:**
  - all "longest frame" and "frames > 33 ms" values. An idle frame here costs ~100–140 ms of draw, so every hitch frame is mostly rendering;
  - the fade durations, which are quantised to those frames;
  - MainMenu's "first frame" (36–219 ms);
  - the total New Game time, which includes first-draw shader setup.
- **CPU-side, valid as ratios:** load+instantiate, add_child+`_ready`, swap → room ready, log lines, and the click frame. These are slower in absolute terms on this 2.1 GHz Xeon than on the dev PC's Ryzen 5 5600.

## 3. What was broken and fixed

**New Game regression (root cause found by bisect, fixed).**
- **Symptom:** today's branch spent 826–838 ms between `Game` add_child and the first room, against 70–160 ms at `3046e46f`.
- **Finding the commit:** `git bisect run` with a headless probe (time from Game add_child to `room_loaded`, with Canyon already cached) pointed at `735777c0` («Skills party … Diablo II-style new-points buttons», D742).
- **Cause:** `UI/Components/hud_new_points.gd` `_connect_game()` (deferred from `_ready`) → `refresh()` → `is_tab_unlocked()` → `_tab_unlock_flags()` → `load(game_menu.tscn).get_state()`. That loads and compiles the whole Game Menu (every tab, its scripts and textures) on the main thread, just to read two metadata strings.
- **Fix:**
  - `SceneWarmer.paths()` now also warms `GameMenuState.GAME_MENU_SCENE_PATH`. That also makes the first menu open a cache hit.
  - `_connect_game()` turns the buttons on only once the menu is cached.
  - The buttons only show when points are waiting, so a few seconds after the start is no change in play.
- **Tests:**
  - `verify_main_menu` [6] checks the buttons are not yet on at `room_loaded`. It fails without the fix ("room_loaded seen true", checked by stashing it) and passes with it.
  - `verify_new_points` waits for the warm and checks that the menu is held.
- Commit `New Game no longer compiles the whole Game Menu under black…`.

**`verify_save_load_room` timing (test only).** D764 (`5db238da`) put a 0.3 s hop (`SavePoint.HOP_TIME`) before the 0.8 s sit. The test still waited only 0.8 + 0.3 s, so the save screen was not open yet ("NullState"), and the hero was saved mid-hop 16 px above the floor. It now waits `HOP_TIME + MEDITATE_SIT_TIME + 0.3`. The oath-census report had listed this test as failing on base.

**Candidate B rows (not fixed, outside S14):**
- **B?: `verify_save_load` [7] fails since D764.** The test builds a bare `SavePoint` with no `$Seat`, so `SavePoint._meditate` hits a null `global_position` (`SavePoint.gd:62`). The test needs the real save point scene. Its wait has the same `HOP_TIME` gap.
- **B?: `verify_progression` fails since D764** ("pose: Jump", "he stands up (Fall)"). Its meditation checks predate the hop.
- **Not a bug, noise:** `Resources/Audio/Music/heavy_battle.mp3.import` was committed without `uid`, `path` or `dest_files`. A fresh import rewrites it, and this branch commits the regenerated file together with three missing `.uid` files and `meditation_spot.png.import`.

## 4. Agent calls (for the register)
- **PC1.** The HUD's new-points buttons (D742) appear once the Game Menu has finished warming in the background (a few seconds after the start under llvmpipe), not on the first frame of the game. The rejected alternative was a synchronous load at the start, which costs ~0.6 s under black.
- **PC2.** The first room after New Game / Load Game keeps loading on the main thread, under the black screen. Slice 6's "the same request covers the first room" is not done. It would make the first `load_room()` asynchronous for every boot path (tests, `Kit.boot`, `place_player` right after it, MetSys setup), and the frame is invisible (black), so the cost is a longer black. If a weak-PC measurement (Q83) shows that black lasting too long, the next step is: `MainMenu` / `LoadGameMenu` request the first room after `Game.tscn` finishes (one at a time, as `RoomPreloader` does to avoid the double-compile errors), and `Game._initialize_save_and_room()` takes it from the cache.

## 5. Plan lines to update
`performance_plan.md` is edited on this branch:
- the header line;
- slice 1, 2, 3 and 6 headings are marked ✅ with a State line each;
- slice 6's State line says the first room is not part of the threaded request.

MASTER_PLAN is **not** edited. Suggested S14 row: «✅ perf-check (27.10): slices 1–3, 6 перевірені й закриті тестами; заміри до/після в cloud_reports/perf-check.md; знайдено й виправлено регрес New Game (+0,6 с, hud_new_points вантажив Game Menu синхронно); перша кімната після New Game ще вантажиться під чорним (PC2); slice 7 чекає Q83».

## 6. Tests
- Touched or added:
  - `verify_main_menu`, `verify_save_load_room`, `verify_canyon_exit`, `verify_mayor_boss`, `verify_new_points`: `RESULT: ALL PASS`.
  - `verify_room_preload`, `verify_quiet_transitions`, `verify_level_up`, `verify_demo_end`: `RESULT: ALL PASS`.
- Required: `verify_scripts_compile`, `verify_room_entrances`, `verify_camera_transitions`, `verify_save_load_room`, `verify_main_menu`: `RESULT: ALL PASS`.
- Full suite: SUITE_DETAIL
