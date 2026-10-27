---
type: plan
status: in-progress
blocked-by: [Q83, Q84]
tags: [performance, loading, rendering]
---

# Performance — weak-PC lag and room-change freezes — plan

**Slices 1–6 built; 1, 2, 3 and 6 checked and closed 2026-10-27** ([[perf-check]]: tests and a before/after table).
Slice 7 waits on Q83. First measured 2026-10-23. Sapega: the game lags badly on a weak PC, although it is small, and moving
between locations freezes it with no loading screen. Figma: no loading-screen frame exists. The only "loading" in
`design/` is the Maaack `SceneLoader` row in [[ui_theme_scope_audit]].

The numbers come from `SampleProject/UI/measure_performance.gd` (re-runnable, see § How to measure). They were taken
on the dev PC: Ryzen 5 5600, RTX 3060, `gl_compatibility`, a 1920×1080 window, debug build run from the project.
That PC is far stronger than Sapega's, so read **shares and ratios** (what dominates), not absolute milliseconds.
Transition numbers are medians of 4 runs (3 full, 1 short), with ranges where game state made them vary. Frame numbers come from
the last run.

## Top costs, ranked by impact

1. **The first visit to each room freezes one frame for 39–172 ms** (DesertRoad 172, Village 166, LabCells 89,
   CityGates 86, MayorHall 82, City 62). A weak CPU makes that ≈3–5× longer. Everything is synchronous on the main
   thread (`MetSysGame.gd:89` `load()`, then `instantiate()` + `add_child()`). In a room's own cold load, **GDScript
   compilation takes 46–89 %**: Canyon 72 of 118 ms, Village 81 of 106, DesertRoad 62 of 90, MayorHall 53 of 63,
   LabBoss 21 of 24. Textures add 1–23 ms, the room's music file 10–12 ms (a 4.6–5.2 MB read), scene parsing
   2.5–8 ms, and `add_child`+`_ready` 2–25 ms. This happens once per room per session, because compiled scripts stay
   cached for the whole process.
2. **New Game takes 517 ms (497–540) from the click to the first room frame, in two frozen frames of ~278 and
   ~216 ms, with no loading screen.** Game.tscn load+instantiate is 275 ms, of which its own load is 250 ms (scripts
   154, `Player.gd` alone 52–58; textures 66). The next frame does `Game` add_child+`_ready` in 44 ms, then the Canyon
   load in 115–132 ms. On a weak PC this is an estimated 1.5–2.5 s.
3. **Every later room change still blocks 13–51 ms, giving hitch frames of 25–84 ms.** Walking across an edge takes
   13–48 ms from the cell change to the room being ready; the longest frame is 25–70 ms. The room you left is freed,
   so coming back reloads its scene, textures and 5 MB music (6–29 ms), plus add_child+`_ready` (1–22 ms). Game
   state can add 55–60 ms: enemies spawned in `_ready` (CityGates `EnemySpawner` 56 ms, Laboratory `Fight_Lower`
   58 ms) or the boss setting up (`FireDjinn` 61.5 ms). In debug builds each transition also prints 19–57 log lines
   at 0.6–1.5 ms per line.
4. **GPU work per frame at 1920×1080 is the likely cause of the in-play lag on a weak PC.** On the RTX 3060 a frame
   needs 0.67–1.07 ms of GPU; the whole frame takes 1.0–1.2 ms uncapped, and game logic only ~0.3 ms of CPU. A/B
   windows show where the GPU time goes:
   - **post-processing** (WorldEnvironment glow + colour curves, D233): **19–33 %** in every room;
   - parallax layers: 0–36 % (9–21 % outdoors);
   - lab lights: 16–36 % (LabCells, Laboratory);
   - depth blur: 0–9 %.

   Outdoor rooms shade 17.6–19.9 MP per frame, which is 8.5–9.6× the screen (parallax layers alone are 5.5–7.0×).
   3.4–4.0 screens of that go through the 9-tap blur. 56 % of the backdrop texels are fully transparent but are
   shaded anyway. An old integrated GPU has roughly 1/10–1/30 of a 3060's fill rate and bandwidth, so the estimate is
   7–32 ms of GPU per frame, which is under 60 fps. This is **not measured on the weak PC** (Q83).
5. **First-use loads during play** (sporadic):
   - enemy scenes on their first spawn (`EnemySpawnPoint.gd:82`, 28 ms cold, of which 24 ms is script compile);
   - the enemy health bar per spawn (`DefaultEnemy.gd:199`);
   - the shop UI (`Merchant.gd:45`);
   - cast VFX (`PlayerCombat.gd:435`);
   - skill-FX frames, one `load()` per frame (`OathSkillFX.gd:61`).

   One more hitch is **unexplained**: a 1743 ms and a 1904 ms process-phase stall in the LabCells cells cutscene,
   seen in 1 of 4 runs. Dialogue parsing is ruled out (0.2 ms per `.dqd`). Reported for a B-ID, see § Found along
   the way.
6. **Logging is not a per-frame cost, but it is heavy on room changes.** While playing outside story events there are
   0 lines/s. A room change prints 19–57 lines and New Game prints 95. The reasons: `Game.gd:51` forces the INFO level
   in every build "temporarily", and `Game.gd` has 48 diagnostic `print()`s on the load path. In the debug build that
   costs 0.64–1.52 ms per line (12–85 ms per transition). The release build does not flush stdout per line, so it is
   much cheaper (not measured: there is no way to run the script inside an export).
7. **Boot**: engine plus autoloads take 1.27–1.33 s before the first script runs, including `AudioManager` loading 326
   audio files (`AudioManager.gd:54-66`). The main menu then loads in 28–30 ms. This is once per launch.

**Checked, not a cost:**
- **Textures.** The biggest is 3606×320 (4.4 MB). Every sprite is drawn magnified at 3.38 screen px per texel (camera
  zoom 2.25 × sprite scale 1.5), so none is oversized and mipmaps are unnecessary. VRAM is 4–14 MB per room; total
  texture memory is 72–86 MB.
- **The big PNGs in `assets/`** have zero runtime references and are excluded from export.
- **Draw calls** are 12–64 per frame and **nodes** 266–382.
- There is no SubViewport, BackBufferCopy or CanvasGroup.
- **The brightness shader** is off at the default 50.
- **Auto-save on room change** is off by default; when on it adds 5.6–6.3 ms per change.

## What exists today
| Thing | Where | State |
|---|---|---|
| Room load | `addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd:89` `load(path)`, `:105-106` instantiate + add_child | ⚠️ synchronous, main thread |
| Walk transition | `addons/.../Modules/ScrollingRoomTransitions.gd:60` (load), `:105-117` (tree paused for the 0.4 s scroll, `SCROLL_TIME` set in `Game.gd:258`) | ✅ |
| Game's `load_room` override | `SampleProject/Scripts/Game.gd:350-381`: 2–3 prints per call; `init_room()` `:410-490` ~15 more | ⚠️ diagnostic prints |
| Teleports | `Game.gd:389-400` `teleport_to_room()`, used by `Scripts/Gameplay/RoomDoor.gd:24`, `Scripts/Gameplay/Scenes/Canyon.gd:694` (→ DesertRoad), `Scripts/Gameplay/Scenes/MayorHall.gd:151` (→ LabCells) | ⚠️ synchronous |
| Neighbour list for preloading | `addons/MetroidvaniaSystem/Scripts/RoomInstance.gd:144` `get_neighbor_rooms()`, documented as "useful for preloading adjacent rooms" | ⚠️ exists, 0 callers |
| Threaded load + loading screen | Maaack `SceneLoader` autoload, `addons/maaacks_menus_template/base/nodes/autoloads/scene_loader/scene_loader.gd:94-108` (`load_threaded_request`, loading screen = Maaack's example, `scene_loader.tscn:7`); shader warm-up example `…/examples/scenes/loading_screen/loading_screen_with_shader_caching.gd` | ⚠️ exists, 0 `SceneLoader.` calls in `SampleProject/` |
| New Game / Load Game | `Scripts/Menus/MainMenu.gd:119-123`, `Scripts/Menus/LoadGameMenu.gd:151`: `change_scene_to_file()` | ⚠️ synchronous, no loading screen |
| Room music | a `Music` AudioStreamPlayer in every room with the track as ext_resource, e.g. `Maps/Canyon.tscn:19, 582-584` | ⚠️ 4.6–5.2 MB OGG read with each room load |
| Enemy spawn | `Scripts/Gameplay/EnemySpawnPoint.gd:82` `load()` of the enemy scene per spawn, `:147` stats; `Scripts/Gameplay/DefaultEnemy.gd:199` `load()` of the health bar per enemy | ⚠️ synchronous, on first use and after release |
| Log level | `Scripts/Game.gd:50-51` sets `DebugLogger.LogLevel.INFO` ("ТИМЧАСОВО … Прибрати після розбору"); `Scripts/Core/DebugLogger.gd:54-58` `info()` has no release check; 170 `print()` + 211 `DebugLogger.info/verbose` in `Scripts/` | ⚠️ |
| Post-processing | `Game.tscn:162-174` Environment (canvas background, glow, adjustments + colour LUT) on `WorldEnvironment` `Game.tscn:377`; D233 | ✅ works; the largest GPU item |
| Depth blur | `Shaders/depth_blur.gdshader` (9 taps), `Resources/Materials/depth_blur_{far,mid,near,front}.tres` on the backdrop scenes `Scenes/Backgrounds/*.tscn`; D233 | ✅ |
| 2D lights | Laboratory 11, LabCells 5, LabBoss 3 `PointLight2D` (no shadows) + `CanvasModulate` | ✅ |
| Brightness | `Shaders/brightness.gdshader` (reads the screen), visible only when brightness ≠ 50, `Scripts/Systems/DisplayManager.gd:136` | ✅ free at default |
| Textures | 323 imports under `SampleProject/Assets`: `compress/mode=0` (lossless), no mipmaps | ✅ none oversized |
| `assets/` | 2.2 GB, incl. `parallax_foreground_4k__00001_.png` (13.7 MB) and `The Desert/*` (5–7 MB each); no `res://assets/` reference in `SampleProject/` (only Maaack's Kenney-prompts installer); export excludes `assets/*` (`export_presets.cfg:10`) | ✅ no runtime cost |
| Audio at boot | `Scripts/Systems/AudioManager.gd:54-66`: 2 music tracks + 324 SFX at startup | ✅ part of the 1.3 s boot |
| Auto-save | `Scripts/Systems/SaveSystem.gd:90-96`: `Game.save_game()` on `room_entered` if `auto_save`; default false, `Scripts/Systems/Save/Modules/SettingsModule.gd:24` | ✅ off by default |
| Defaults | `SettingsModule.gd:14-19`: windowed 1920×1080, vsync on, 60 fps; export `script_export_mode=2`, no console (`export_presets.cfg:23, 29`) | ✅ |
| Measuring | `SampleProject/UI/measure_performance.gd` (this pass) | ✅ |

## Missing entirely
- Any background (threaded) room loading: `grep -rn load_threaded SampleProject addons/MetroidvaniaSystem` → 0 hits.
- Neighbour preloading: `get_neighbor_rooms` has 0 callers.
- A loading screen or indicator of our own, in Figma or in Godot. `SceneLoader` points at Maaack's example scene and
  is not called.
- A graphics-quality setting: Settings has Display Mode, Resolution, VSync, FPS limit and Brightness only
  (`DisplayManager.gd`).

## Measurements

### Room loads — first visit in the session (`teleport_to_room`, previous room still alive, as in play)
| Room | load()+instantiate | of it instantiate | scene parse only | add_child+_ready (slowest subtree) | whole call | hitch frame | log lines |
|---|---|---|---|---|---|---|---|
| Canyon (by New Game) ³ | 121 | 0.6 | 5.6 | 8 (room script 3.8) | — | 278 / 216 (start) | 95 |
| Village | 113 | 0.5 | 6.3 | 8 (8–67: room script, story start) | 122 (115–186) | 166 (128–202) | 29 |
| ElderHouse | 4 | 0.1 | 1.7 | 2 | 7 | 48 (17–80) | 20 |
| DesertRoad | 113 (98–131) | 0.6 | 6.6 | 25 (Merchant 7.7–9.5, room script 4.4) | 139 (121–157) | 172 (138–204) | 40 |
| CityGates | 35 (35–93) | 0.3 | 4.7 | 4 | 42 (41–98) | 86 (56–117) | 26 |
| City | 47 | 0.5 | 6.2 | 4 | 52 | 62 | 21 |
| MayorHall | 63 | 0.3 | 5.7 | 6 (BrassCollector 3.8) | 70 | 82 | 26 |
| LabCells | 56 | 0.3 | 6.3 | 2 (2–126: cutscene start in `_ready`) | 60 (58–190) | 89 (85–1743) | 28 |
| Laboratory | 17 | 0.6 | 5.1 | 6 (5–63: `Fight_Lower` spawn 58) | 23 (23–80) | 39 (38–97) | 26 |
| LabBoss | 27 | 0.4 | 2.6 | 7 (6–64: `FireDjinn` 61.5) | 36 (34–93) | 105 (51–108) | 25 |
| LaboratoryOutside | 34 | 0.2 | 3.5 | 3 | 38 | 55 | 22 |

All values are ms. A `load()` of a PackedScene that is still held returns in < 0.05 ms, which is what preloading
buys: only instantiate + add_child are left. Medians of 4 runs (3 full, 1 short).

³ The script now times Canyon from `Game.ready`, so it includes `_initialize_save_and_room()`'s resets (+~13 ms):
132 ms in the latest run. The game's own prints are no longer needed for timing, so slice 1 does not break the
measurement.

### Room loads — revisit (scripts compiled; the room's scene, textures and music were freed and reload)
| Room | load()+instantiate | add_child+_ready | whole call | hitch frame | log lines |
|---|---|---|---|---|---|
| Canyon | 28 | 6 | 35 | 53 (49–108) | 46 |
| Village | 20 | 11 (8–12) | 32 | 50 (46–114) | 37 (27–37) |
| ElderHouse | 14 | 1 | 17 | 30 (30–88) | 20 |
| DesertRoad | 29 (29–41) | 21 (12–23) | 51 (42–65) | 80 (57–133) | 57 (40–57) |
| CityGates | 10 | 4 (4–60: `EnemySpawner` 56) | 16 (16–71) | 84 (27–87) | 26 |
| City | 23 | 4 | 28 | 43 | 21 |
| MayorHall | 22 | 6 | 30 (30–89) | 45 (45–104) | 25 |
| LabCells | 10 | 2 | 13 | 37 (37–94) | 31 |
| Laboratory | 10 | 5 | 16 | 31 | 25 |
| LabBoss | 13 | 6 | 20 | 38 (37–99) | 25 |

### Walking through a room edge (MetSys → `ScrollingRoomTransitions` → `load_room`; rooms already visited)
| Walk | cell change → room ready | load()+instantiate | add_child+_ready | longest frame | log lines |
|---|---|---|---|---|---|
| Canyon → Village | 38 | 26 | 11 (6–12) | 54 (42–64) | 36 |
| DesertRoad → CityGates | 48 (18–79) | 14 (13–72) | 4 (4–64) | 60 (30–91) | 25 |
| CityGates → City | 32 | 25 | 5 | 41 (39–101) | 19 |
| City → MayorHall | 16 (15–97) | 8 | 6 (6–88) | 25 (25–107) | 24 |
| LabCells → Laboratory ¹ | 15 | 8 | 5 | 70 (30–73) | 36 |
| Laboratory → LabBoss ¹ | 13 | 6 | 6 | 25 | 25 |
| LabBoss → LaboratoryOutside | 28 (28–88) | 19 | 8 (8–67) | 42 (42–103) | 27 |

¹ A wall or door blocked the walk, so the script set the hero 8 px past the edge. The code path from the cell change
on is the same.

### Game start
| Step | ms |
|---|---|
| Engine + autoloads, before the first script | 1270–1330 |
| `MainMenu.tscn` load / instantiate / add_child+_ready / first frame | 28–30 / 0.5 / 10 / 11–13 |
| New Game → `room_entered` | **517** (497–540) |
| — the click frame: `Game.tscn` load+instantiate | 275 (256–293) |
| — the next frame: `Game` add_child+_ready, then Canyon load+instantiate, add_child+_ready | 44, 115–132, 8 → a 204–258 ms frame |
| `Game.tscn` scene parse (deps alive) / instantiate | 14–16 / 2–3 |

### What `load()` spends its time on — cold, each resource on its own (`-- attribution`)
Order as in play: main menu, `Game.tscn`, the rooms of the route, enemy scenes. Anything an earlier step already
loaded is not counted again.

| Scene | files | on disk incl. shared | own load | of it scripts | of it textures |
|---|---|---|---|---|---|
| MainMenu | 8 | 2.9 MB | 30 | 12 | 15 (`main_menu_background.jpg` 15) |
| Game.tscn (hero, HUD) | 260 | 1.1 MB | 250–266 | 154–162 (`Player.gd` 52–58) | 66–74 |
| Canyon | 37 | 5.2 MB | 118–127 | 72–74 (`Canyon.gd` 56–57) | 23–31 |
| Village | 45 | 5.5 MB | 106–118 | 81–83 (`Village.gd` 46–48, `StoryNpc.gd` 29–30) | 9–17 |
| ElderHouse | 14 | 5.3 MB | 3 | 0 | 2 |
| DesertRoad | 55 | 5.1 MB | 90–94 | 62–63 | 13–16 |
| CityGates | 40 | 5.3 MB | 41–48 | 19–20 | 8–11 |
| City | 53 | 4.9 MB | 47–53 | 24–25 | 9–12 |
| MayorHall | 31 | 4.8 MB | 63–69 | 53–57 (`MayorHall.gd` 50–54) | 6–8 |
| LabCells | 39 | 5.0 MB | 50–56 | 23–24 | 8–11 |
| Laboratory | 29 | 5.0 MB | 14–19 | 8–9 | 2–6 |
| LabBoss | 32 | 5.0 MB | 24–26 | 21–24 | 1 |
| LaboratoryOutside | 29 | 5.1 MB | 20–25 | 14–15 | 5–9 |
| Enemy scenes | 15 | 0.1 MB | 28 | 24 (`ArcherEnemy.gd` 24) | 2 |

| By type, whole route | files | own load | share | on disk |
|---|---|---|---|---|
| GDScript | 39 | 565 ms | **64 %** | 0.3 MB |
| CompressedTexture2D | 298 | 169–217 ms | 19 % | 2.4 MB |
| AudioStreamOggVorbis (room music) | 6 | 62–72 ms | 7 % | **28.9 MB** |
| PackedScene (parse) | 62 | 61 ms | 7 % | 0.4 MB |
| everything else | 22 | 28 ms | 3 % | 1.6 MB |

The music is 90 % of the bytes a room reads from disk. That does not show on this PC, because the OS file cache is
warm, but on a slow HDD 5 MB is roughly another 50–100 ms per room.

### Per frame — 5 s windows, 1920×1080, vsync off and fps uncapped (capped, every frame reads 16.7 ms)
| Room | fill/frame (× screen) | of it parallax | 9-tap blur (screens) | lights | frame avg / p99 | CPU: physics per step / process / render | GPU | −blur | −parallax | −post | −lights | draw calls |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Canyon | 9.1 | 5.5 | 3.8 | 0 | 1.19 / 2.10 | 0.20 / 0.13 / 0.79 | 0.83 | 0.78 | 0.74 | **0.58** | — | 63 |
| Village | 8.6 | 5.8 | 3.4 | 0 | 1.09 / 1.79 | 0.18 / 0.12 / 0.72 | 0.80 | 0.78 | 0.73 | **0.55** | — | 59 |
| ElderHouse | 2.1 | 0 | 0 | 0 | 1.07 / 1.74 | 0.17 / 0.11 / 0.73 | 0.70 | 0.70 | 0.77 | **0.57** | — | 54 |
| DesertRoad | 8.6 | 6.0 | 4.0 | 0 | 1.07 / 1.71 | 0.18 / 0.12 / 0.71 | 0.79 | 0.80 | 0.71 | **0.54** | — | 60 |
| CityGates | 8.7 | 6.0 | 4.0 | 0 | 1.06 / 1.78 | 0.17 / 0.12 / 0.70 | 0.78 | 0.76 | 0.65 | **0.56** | — | 60 |
| City | 9.6 | 7.0 | 4.0 | 0 | 0.98 / 1.85 | 0.16 / 0.13 / 0.60 | 0.82 | 0.83 | 0.65 | **0.62** | — | 20 |
| MayorHall | 2.9 | 0 | 0 | 0 | 1.01 / 1.63 | 0.07 / 0.12 / 0.64 | 0.67 | 0.65 | 0.67 | **0.49** | — | 14 |
| LabCells ² | 3.7 | 1.9 | 1.9 | 5 | 1.17 / 1.95 | 0.07 / 0.19 / 0.72 | 0.90 | 0.85 | 0.77 | **0.61** | 0.76 | 26 |
| Laboratory | 4.4 | 3.0 | 3.0 | 11 | 1.19 / 2.68 | 0.06 / 0.12 / 0.69 | 1.07 | 0.97 | **0.68** | 0.72 | **0.68** | 18 |
| LabBoss | 3.3 | 1.9 | 1.9 | 3 | 1.03 / 1.48 | 0.16 / 0.12 / 0.65 | 0.75 | 0.75 | 0.75 | **0.61** | 0.76 | 16 |
| LaboratoryOutside | 8.5 | 5.9 | 3.9 | 0 | 1.06 / 1.52 | 0.06 / 0.12 / 0.69 | 0.83 | 0.86 | 0.76 | **0.63** | — | 25 |

How to read the table:
- All times are ms. The −X columns give the GPU ms with only X switched off; they overlap and do not add up (lab
  lights also light the parallax layers).
- The hero standing and the hero running (5 s, back and forth inside the room) give the same frame cost: run avg
  1.01–1.19 ms, worst 2–21 ms. In MayorHall, LabCells, Laboratory and LaboratoryOutside a cutscene held him (0 px).
- ² LabCells' standing window holds the unexplained 1904 ms stall, so its row shows the run window.
- Steady state prints 0 lines/s. `_process` runs on 1–4 nodes per script (NpcActivity ×4, cutscene_skip_prompt ×4,
  OathKeeper ×3).

### Textures and VRAM
| | value |
|---|---|
| Biggest textures | DesertRoad_Terrain 3606×320 (4.4 MB), Canyon_Terrain 1728×640 (4.2), Village/City_Terrain 1728×~320 (2.0–2.1), CityGates/LaboratoryOutside_Terrain (1.8–1.9) |
| Size on screen | every drawn sprite at **3.38 screen px per texel**, so nothing is larger than it is shown |
| Room VRAM (estimate) | 4.0 (ElderHouse) – 14.1 MB (Canyon), 6–28 textures |
| Monitors | texture memory 72–86 MB, video memory 131–179 MB |
| Backdrop alpha (81 textures, 14.5 MP) | the opaque bounding box covers **69 %** of the area; only **44 %** of texels are not fully transparent. City_Terrain uses 15 %, DesertRoad_Terrain 47 % |
| Import | all lossless (`compress/mode=0`), no mipmaps; decoding is 1–23 ms per room |

## Decisions required
1. **Loading screen or indicator — answered by D434** (Sapega, 2026-10-23): a fade to black, as in Tails of Iron,
   and no loading-screen art. Room changes fade out, load in the background and fade in. New Game and Load Game use the
   same fade over a black screen. The screen itself must appear before the threaded load starts.
2. **What the weak PC is (Q83).** It blocks slice 7 only. Needed: CPU, GPU, RAM, HDD or SSD, Windows version; the
   exported `Qusakam.exe` or the editor; fullscreen or windowed, and at what resolution. Best is to run
   `measure_performance.gd` on that PC. Failing that, the GPU name from the first console lines ("OpenGL API … Using
   Device: …").
3. **Which looks may be cut on weak PCs (Q84).** GAME/ART DECISION REQUIRED; it blocks slice 7. D233's glow and colour
   curves are 19–33 % of the GPU frame, parallax 0–36 %, lab lights 16–36 %, blur 0–9 %. Options:
   - (a) a Graphics High/Low setting, where Low drops the post-processing and the depth blur and stops lab lights from
     lighting the backdrop layers;
   - (b) render the world at half resolution (960×540, ×2). That is 4× less fill. The art is drawn at 3.375 px/texel,
     so backdrops lose no detail, and the HUD stays at full resolution, but edge crispness changes;
   - (c) change nothing and accept a lower fps on weak PCs.

   Recommendation: (a). Today's look stays the default and the change is reversible. It is Sapega's call, because
   D233 is his.
4. **Memory for preloading.** Technical, not blocking. Holding the neighbours' scenes costs 4–14 MB of VRAM and ~5 MB
   of RAM (music) per room, at most ~60 MB. Recommendation: hold only the direct neighbours and the door targets.

## Slices
Sequential; each ships on its own. "Measure" means rerunning `measure_performance.gd` and comparing the named rows
with this plan's tables.

### Slice 1 — Quiet room changes (no decision) — ✅ done (perf-check 2026-10-27)
State: a room change prints 2 lines (the B145 `room swap` pair), New Game 4; `verify_quiet_transitions`.
- `Scripts/Game.gd`: delete the temporary `DebugLogger.current_level = DebugLogger.LogLevel.INFO` (`:50-51`). Delete,
  or downgrade to `DebugLogger.verbose()`, the diagnostic `print()`s in `_ready`, `_initialize_save_and_room`,
  `load_room` and `init_room` (48 in the file). The INFO lines from Player, GateController, StateChangeTrigger and
  RoomEnemySpawner go quiet with the level.
- Keep `push_warning` / `push_error` for real problems. They flush the log file in every build.
- Verify: new `SampleProject/UI/verify_quiet_transitions.gd`. Count lines with an `OS.add_logger()` counter, like
  `measure_performance.gd`, then teleport Canyon → Village and walk back. Check each room change prints ≤ 5 lines.
- Measure: the `log lines` column in `PERF load` / `again` / `walk` (19–57 today, 95 at New Game), and the hitch
  frames in debug.
- Commit: `Slice 1 of performance_plan: room changes stop printing`.

### Slice 2 — Neighbour rooms load in the background (removes the walk-transition freeze) — ✅ done (perf-check 2026-10-27)
State: walk load+instantiate 17–53 → 1.4–2.6 ms; the walk goes through `FadeRoomTransitions` (D434), not the scroll;
`verify_room_preload` [1], [2].
- New `SampleProject/Scripts/Gameplay/RoomPreloader.gd`, a **MetSysModule** like `ScrollingRoomTransitions`, added
  next to it (`Game.gd:257`). On `room_loaded` it calls `ResourceLoader.load_threaded_request()` for every
  `MetSys.get_current_room_instance().get_neighbor_rooms()` (`RoomInstance.gd:144`). Each frame (`process_frame`) it
  moves finished loads into a held Dictionary with `load_threaded_get()`, and it drops rooms that are no longer
  neighbours.
- `MetSysGame.load_room()` does not change. Its `load(path)` hits the cache, or waits for the remainder of the
  in-flight threaded load.
- Check: scripts now compile on the worker thread. Watch for SCRIPT ERRORs; `run_verify.sh` fails on them. Texture
  decoding moves off the main thread, but the GL upload still happens on it (room VRAM 4–14 MB).
- Verify: new `SampleProject/UI/verify_room_preload.gd`. Boot with `Kit.boot()`. In Canyon, wait ≤ 3 s for
  `ResourceLoader.has_cached(Village)`. Walk east with a real `KEY_D` hold and check the room is Village, Canyon is
  still held, and a non-neighbour (LabBoss) is not cached.
- Measure: `PERF walk` load+instantiate should go from 6–26 ms to under 1 ms, and "cell change → room ready" from
  13–48 ms to the add_child+`_ready` share (4–12 ms).
- Commit: `Slice 2 of performance_plan: neighbour rooms load in the background`.

### Slice 3 — Doors and story teleports preload their target (no decision) — ✅ done (perf-check 2026-10-27)
State: `verify_room_preload` [3] (ElderHouse), `verify_canyon_exit` (DesertRoad held before the cutscene teleport),
`verify_mayor_boss` (LabCells held from the fight's start).
- `RoomPreloader` also requests every `RoomDoor` target in the current room (`RoomDoor.gd:24`). The two story
  teleports request their target when their cutscene starts: `Canyon.gd:694` → DesertRoad (first visit 152 ms) and
  `MayorHall.gd:151` → LabCells (60 ms).
- Verify: extend `verify_room_preload.gd`. In Village, ElderHouse is held.
- Measure: `verify_room_preload.gd` plus the hitch on a door walk. The `PERF load` rows teleport straight from the
  script, so they show the un-preloaded cost on purpose and stay as the reference.
- Commit: `Slice 3 of performance_plan: doors and story teleports preload their target`.

### Slice 4 — Draw only the used part of the backdrop textures (same look, no decision)
- For every backdrop and terrain `Sprite2D` (`Scenes/Backgrounds/*.tscn`, `Maps/*.tscn`): set `region_enabled` with
  `region_rect` = `Image.get_used_rect()` grown by 2 px, and shift `offset` by the rect's origin. The pixels and
  their blur neighbours stay the same; only the transparent margin stops being shaded.
- Do it once with a tool script that writes the values into the `.tscn` (layout lives in scenes). It must not run at
  runtime: `get_image()` reads back from the GPU.
- Verify: `capture_*` screenshots of the six outdoor rooms before and after, with a pixel diff of 0.
- Measure: the `PERF fill` MP/frame; backdrop bounding boxes are 69 % of their area today. Also the `gpu` column.
- Commit: `Slice 4 of performance_plan: backdrop sprites draw only their used region`.

### Slice 5 — First-use gameplay scenes warm in the background (no decision)
- After the game starts, `load_threaded_request()` and hold:
  - the enemy scenes (`EnemySpawnPoint.ENEMY_SCENES`, 28 ms cold, of which 24 ms is script compile);
  - `Scenes/UI/enemy_health_bar.tscn` (`DefaultEnemy.gd:199`);
  - `Scenes/Shop/shop_menu.tscn` (`Merchant.gd:45`);
  - the cast VFX of known skills (`PlayerCombat.gd:435`).

  The game keeps running while these load; there is no wait.
- Verify: extend `verify_room_preload.gd`: these paths are `has_cached` within 5 s of `room_entered`.
- Measure: the `PERF type` / `res` rows of `-- attribution` list what is still cold. The frame windows' `spikes`
  should show no `EnemySpawner` / `Fight_*` subtree above 10 ms in `PERF load` / `again`.
- Commit: `Slice 5 of performance_plan: first-use scenes warm in the background`.

### Slice 6 — New Game and Load Game through a threaded load behind a fade to black (D434) — ✅ done (perf-check 2026-10-27)
State: the click frame is 0.2 ms (was 275–331); `verify_main_menu` [6] (New Game), `verify_save_load_room` [3]
(Load Game). **Not as written below:** the threaded request covers `Game.tscn` only; the first room still loads on
the main thread in `_initialize_save_and_room()`, under black (Canyon 237–240 ms on llvmpipe). Making it threaded
would make the first `load_room()` asynchronous for every boot path; left as is.
- `MainMenu.gd:123` and `LoadGameMenu.gd:151` call `SceneLoader.load_scene(GAME)` instead of `change_scene_to_file()`.
  `scene_loader.gd:94` already does `load_threaded_request` and shows `loading_screen_path`; that becomes a plain black screen
  with the D434 fade instead of Maaack's example.
- The same request covers the first room (Canyon, or the saved room), so `Game._initialize_save_and_room()` finds it
  cached.
- `Game` add_child+`_ready` (44 ms) still runs on the main thread after the switch, under the screen.
- Verify: extend `verify_main_menu.gd`. A real click on New Game (`viewport.push_input` at the button centre) fades
  to black, then Game becomes `current_scene`, then `room_entered` fires.
- Measure: the `PERF start` row. The click frame should go from 275 ms to one ordinary menu frame.
- Commit: `Slice 6 of performance_plan: New Game loads behind a fade to black (D434)`.

### Slice 7 — The GPU budget on weak PCs — **blocked on Q83, then Q84**
- First run `measure_performance.gd` on the weak PC, or get its GPU (Q83). If its GPU frame is under ~10 ms, stop
  here.
- Otherwise build the option Sapega picks in Q84, for example a Graphics row in Settings ([[settings_plan]]) that turns
  off post-processing (`Game.tscn:162-174`) and depth blur, and stops lab lights lighting the backdrop layers.
- Verify: `verify_settings.gd`: the row persists and is applied.
- Measure: the `gpu` and `-post` / `-blur` / `-lights` columns, on the weak PC.
- Commit: `Slice 7 of performance_plan: Graphics quality setting (Q83, Q84)`.

### Slice 8 — only if the numbers after slices 2–5 still show frames > 33 ms
- What would remain is room `_ready` work: DesertRoad add_child+`_ready` 22–25 ms (Merchant 7.7–9.5, room script
  4–11), boss setup (`FireDjinn` 61.5 ms in one run) and enemies spawned in `_ready`. The `slowest:` field of
  `PERF load` names the subtree. Profile that one and make it lazy or move it to the preload.

## Order and dependencies
`1 → 2 → 3 → 4 → 5`. None of these needs a decision, and together they remove the in-game freezes: first visits
move off the main thread, revisits and walks hit the cache, and first enemy spawns stop compiling.
4 does not depend on 1–3 and can move. `6` is unblocked by D434 (fade to black) and can go any time. `7` needs Q83, then Q84. `8` happens only if the measurement says so.

## Out of scope for this pass
- **`assets/` cleanup** (2.2 GB, no runtime cost). That is repo and import hygiene, in the plugin-cleanup line
  (D240/D241), not performance.
- **VRAM-compressed textures.** Textures are not a cost at these sizes, and compression would smear pixel art.
- **Boot time** (1.3 s), measured as a whole, not per autoload.
- **Release-build numbers.** The release cost of `print()` and parse times with binary scenes and tokenised scripts
  need an export, and this pass did not build.

## Found along the way (for the registers; not performance slices)
- **LabCells cells cutscene stall.** 1743 ms then 1904 ms frames, all in the process phase, during
  `LabCells._cells_cutscene()` (`LabCells.gd:84-101`) around `Lab_Cells_Injection`. Seen in 1 of 4 runs, and story
  state differed. The `.dqd` parser costs 0.2 ms, so it is not the cause. Candidate **B-ID**, needs a repro.
- **`ItemDatabase.gd:262`** checks icons with `FileAccess.file_exists()`. In an exported build the source PNGs are not
  in the pck (only `.import` + `.ctex`), so this is false and every icon would fall back to the placeholder.
  `ResourceLoader.exists()` is the export-safe check. Candidate **B-ID**, unverified in an export.
- **`docs/CLAUDE.md` says there is no auto-save on room transitions.** There is one, opt-in: `SaveSystem.gd:90-96` with
  the `auto_save` setting.
- **Four `cutscene_skip_prompt.gd` instances process at once** in one room. It may be a prompt left behind by finished
  cutscenes; the CPU cost is negligible.

## How to measure
```bash
# One full run ≈ 10 min, needs a window (no --headless). Read only the PERF lines.
Scripts/Tools/godot_locked.sh --path . --resolution 1920x1080 --script res://SampleProject/UI/measure_performance.gd > logs/perf.log 2>&1
Scripts/Tools/godot_locked.sh --path . --resolution 1920x1080 --script res://SampleProject/UI/measure_performance.gd -- attribution > logs/perf_attr.log 2>&1
grep '^PERF' logs/perf.log logs/perf_attr.log
# shorter: ... -- secs=1 rooms=Canyon,Village
```
- **Rows:** `env`; `start`; `load`, `tex`, `fill` and `frame` (idle / run / −blur / −parallax / −post / −lights) per
  room; `walk`; `again` (revisit); `save`; `bigtex`, `proc` and `log` (summary). The attribution mode prints `disk`,
  `type` and `res`.
- **Caveats:**
  - Frames are uncapped.
  - The OS file cache is warm, so disk time is not included (see the disk MB).
  - The editor reads text `.tscn` / `.gd`; the export reads binary scenes and compressed script tokens
    (`script_export_mode=2`), so parsing is cheaper there and compiling is not.
  - `print()` costs are debug-build costs.
  - Story state depends on timing, so some rows vary between runs; compare medians of 3 runs.
  - The script writes only to `user://script_run_saves/` (`SaveSystem._start_script_run_dir`), never to the player's
    saves.
