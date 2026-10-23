---
type: report
status: done
tags: [cloud, performance, graphics, D553, D554]
---

# Cloud report — `cloud/perf-gfx` (2026-10-23)

**Done:** [[performance_plan]] slices 4, 5 and 7 (D554). Settings → Display has a **Quality** row (High / Low). Low turns off glow, colour curves, depth blur, light shadows and halves big particle counts. A first run on a weak Intel GPU or ANGLE 10_x picks Low. Low applies before the first room draws. On the software renderer, Low cuts the GPU frame by 58–82 % (Canyon 118 → 35 ms).
**Not done as specified:** slice 4's **pixel diff is not 0**: 333 k px over 36 shots (0.4 %), mostly one-pixel texel-boundary ties (§1). Nothing was measured on the HD 3000 itself; numbers come from llvmpipe.
**D-IDs for the register (agent calls, for Sapega to confirm):** D603–D611 (text in §5). **B rows fixed:** none.
**Full suite:** `SUITE: 3 FAIL` of 103: `verify_onboarding` fails identically on base `62dd198f`; `verify_combat_flow` passes alone on both; `verify_main_menu` had 5 SCRIPT ERRORs from slice 5. Those are fixed in `RoomPreloader` (§2, §6) and pass on reruns. The suite was not re-run after the fix.

Branch `cloud/perf-gfx` from `origin/feature/backlog` @ `62dd198f`. Commits: slice 4 `eafc64e7`, slice 5 `a919bab7`, slice 7 `551b72d6`.

## 1. Slice 4: backdrop and terrain sprites draw only their used region
- One-off tool `Scripts/Tools/region_backdrops.gd` (headless, never at runtime). It reads alpha from the PNG on disk, not via `get_image()`, and writes `offset`, `region_enabled`, `region_rect` into the `.tscn` as text, so nothing else in the file changes. Scope: every `Sprite2D` in `Maps/*.tscn` and `Scenes/Backgrounds/*.tscn` whose texture is under `Assets/Backgrounds/` (not `Decor/`), with no frames and no region yet, that saves ≥ 5 %. The tool is idempotent. **Re-run it after `build_terrain.gd -- place`**, which rewrites the terrain nodes.
- 27 sprites in 11 scenes. Backdrop texels: 18.06 → 12.01 MP (67 %). `PERF fill` per frame: Canyon 8.8 → 6.8× screen, Village 10.5 → 8.1×, DesertRoad 8.3 → 6.0×, CityGates 8.4 → 6.5×, City 9.3 → 6.5×, LaboratoryOutside 8.3 → 5.9×, Lab rooms 3.3–4.4 → 2.7–3.4×. Depth-blurred MP drops 22–33 %.
- **Pixel diff.** `SampleProject/UI/capture_backdrop_regions.gd` renders the six outdoor rooms with scripts stripped and processing off, 6 camera spots each, before and after. Captures are deterministic: two after runs give 0 px.
  - The first attempt (crop = used rect + 4 px margin) differed in 906 k px. Cause: `snap_2d_vertices_to_pixel` puts quad edges on whole screen pixels, and a texel is 3.375 px (1.5 × 2.25), so a cropped edge on a fractional pixel moved the texture up to ½ px.
  - The tool now aligns each cropped edge to a step that is a whole number of pixels at every Settings resolution (16 texels for scale-1.5 sprites; ×2/3, ×5/6, ×1, ×4/3). That brings the diff to **333 212 px / 36 × 2.07 MP ≈ 0.45 %**. 87 % of the differing pixels equal the before pixel one step up/down/left/right.
  - What is left: with nearest filtering at 3.375 px per texel, every 8th texel boundary lands exactly on a pixel centre. Which texel such a tie picks depends on float rounding of the interpolated UV, and that changes with any change of quad. The rest is the depth blur's 9 taps hitting the same ties. Exactly 0 is not reachable with a smaller quad. The look is unchanged: one-pixel texel edges flip side on some rows, as they already do when the camera moves. → **D608**.
  - Fullscreen at a native size that is not one of the four (e.g. 1366×768) can still shift a cropped edge by under ½ px.

## 2. Slice 5: first-use scenes warm in the background
- New `Scripts/Gameplay/SceneWarmer.gd` (MetSys module, created in `Game._initialize_save_and_room()` next to RoomPreloader). On the first `room_loaded` it pins these through RoomPreloader, which holds them for the whole game (`RoomPreloader.pin()`; a room change does not release pinned paths):
  - the 4 enemy scenes (`EnemySpawnPoint.ENEMY_SCENES`) and their stats `.tres` (new `EnemySpawnPoint.STATS_PATH`);
  - `Merchant.SHOP_SCENE` (new const, was a literal);
  - `GameOverScreen.SCENE_PATH`;
  - for every learned skill: its cast VFX (`PlayerCombat.begin_cast`) and, for oath skills, the 7 `OathSkillFX` frames. Those frames were `load()`ed on every cast and freed after it.
  
  `EventBus.skill_unlocked` adds a skill learned in play. Pinned paths go one at a time, and only while no room is loading (`RoomPreloader._pin_queue`). Two loader threads compiling the same scripts at once broke compiles, see §6. `enemy_health_bar.tscn` is gone (D539), so it is not in the list.
- `verify_room_preload.gd` [1b]: every warmed path is held and `has_cached` within 5 s of the start. A skill learned in play warms its effect and frames. A room change keeps them held. `RESULT: ALL PASS`.
- Measured: in `PERF load`/`again` (before and after) the `EnemySpawner` / `Fight_*` subtrees were already at 0.1–0.2 ms, so the gain shows on first spawn and first cast, which the route does not exercise. New Game → room_entered was 2713 ms in the before run and 1465 ms in the after run. Single llvmpipe runs vary, and this slice does not touch that path, so the drop is not claimed for it.

## 3. Slice 7: Graphics quality High / Low (D553, D554)
- `Scripts/Systems/GraphicsQuality.gd`, a node of the `DisplayManager` autoload (`DisplayManager.tscn`). `DisplayManager.apply_display_settings()` passes it `settings["graphics_quality"]`.
  - **Low:** `WorldEnvironment` gets a copy of its Environment with `glow_enabled` and `adjustment_enabled` off (D233 curves). The shared resource is untouched.
  - **Low:** the `depth_blur` / `background_blur` materials come off their nodes. `brightness.gdshader` stays, because it is the player's setting (D428).
  - **Low:** `Light2D.shadow_enabled` off. No light in the game casts shadows today, so this is future-proofing.
  - **Low:** CPU/GPU particles with `amount ≥ 16` are halved (AmbientDust 36, FireStrike 44, LevelUp 40, arrow streak 40, …; small sparks stay).
  - **High** restores each node from its saved meta.
  - It applies through `SceneTree.node_added`, so every node is already Low when it enters the tree, before its first frame. On a change it also walks the whole tree.
- Settings: `SettingsModule.default_settings["graphics_quality"]` = `GraphicsQuality.default_for_adapter(RenderingServer.get_video_adapter_name())`, set in `_ready`. A settings file without the key (the first run, or an old file) gets the adapter default through `read()`'s merge. The key is saved with the other settings. Settings are applied at boot (`SaveSystem._ready`, deferred), before the main menu, so Low is in place before Game and the first room exist. Restore Defaults goes back to the adapter default.
- UI: Display tab, row **Quality** (segment High / Low) between Frame Rate Limit and Screen Brightness. It is the same Figma 17:280 segment row as VSync, so there are no new tokens. The Brightness preview stays last, so the row pitch stays 68 + 2. The hint text mentions graphics quality. `en.po` / `uk.po`: Quality / Якість, High / Висока, Low / Низька, plus the hint. Shot: `design/shots/perfgfx_display.png`.
- Adapter rule (→ **D611**):
  - Low: "HD Graphics" with no number, or a 4-digit number ≤ 4000 (Ironlake, Sandy Bridge, Ivy Bridge: HD, 2000, 2500, 3000, 4000).
  - Low: any ANGLE renderer string with `vs_4_0` / `vs_4_1` (Direct3D 11 feature level 10.x, where Godot falls back when there is no GL 3.3; the HD 3000 lands here, D553).
  - High: everything else, including HD 4200–6300, the 3-digit HD 510–630 (Skylake+, several times an HD 4000), UHD, Iris, all discrete GPUs, and llvmpipe.
- `verify_graphics_quality.gd` (new): `RESULT: ALL PASS`, 43 checks.
  - [1] 15 adapter strings; the default comes from this adapter; a file without the key gets it; a saved choice wins.
  - [2] Clicking Low stores it, applies it, writes the file, and survives a module restart.
  - [3] Low/High on stand-in nodes: glow and curves, shared resource untouched, blur, particles 36 → 18 while 8 stays, shadows; all come back on High.
  - [4] Low set, then Game.tscn added. At `room_loaded` (before the first frame) Game's WorldEnvironment has no glow or curves, 8 blurred layers of Canyon are stripped, and AmbientDust is 18. Switching to High in play restores the glow.
  
  `verify_settings_graphics.gd`: row order includes Quality. `verify_settings`, `verify_locale`: `ALL PASS`.
- `measure_performance.gd` prints a `low` frame row per room (the whole preset on, then back to High).
- Capture: `design/shots/graphics_quality/Village_high_vs_low.png` (High left, Low right; full-size `Village_high.png`, `Village_low.png`). Low is sharper (no depth blur) and a touch flatter (no glow, no grade).

## 4. Measurements (`measure_performance.gd`, full route, 5 s windows)
Environment: llvmpipe (LLVM 20.1.2, software GL 3.3) on 4 Xeon cores, xvfb 1920×1080, debug build.
- **This is not the HD 3000.** Software rasterising is fill-bound like a weak iGPU, so the *ratios* are the useful part. The HD 3000 itself is still unmeasured. Run the command in the plan's "How to measure" on that PC; `PERF env` shows its adapter string.
- Before = `feature/backlog` @ `62dd198f`. After = this branch (slices 4 + 5 on High, plus the Low row).

| Room | fill × screen before → after | GPU ms before (High) | GPU ms after, High | GPU ms after, **Low** | frame avg ms before → High → **Low** |
|---|---|---|---|---|---|
| Canyon | 8.8 → 6.8 | 118.1 | 100.1 | **35.5** | 128.8 → 108.5 → **42.8** |
| Village | 10.5 → 8.1 | 130.5 | 98.7 | **43.8** | 141.7 → 108.4 → **51.0** |
| ElderHouse | 2.1 → 2.1 | 64.0 | 63.2 | **11.6** | 72.0 → 71.8 → **18.6** |
| DesertRoad | 8.3 → 6.0 | 113.6 | 91.6 | **33.2** | 125.7 → 101.8 → **42.4** |
| CityGates | 8.4 → 6.5 | 115.2 | 103.0 | **36.1** | 123.8 → 114.5 → **42.9** |
| City | 9.3 → 6.5 | 122.0 | 103.3 | **38.8** | 130.9 → 114.2 → **47.0** |
| MayorHall | 2.9 → 2.9 | 63.6 | 61.7 | **15.9** | 72.2 → 71.5 → **24.3** |
| LabCells | 3.6 → 3.0 | 148.5 | 113.3 | **64.0** | 155.3 → 120.8 → **71.6** |
| Laboratory | 4.4 → 3.4 | 174.0 | 131.9 | **73.0** | 182.7 → 140.5 → **82.2** |
| LabBoss | 3.3 → 2.7 | 116.4 | 114.4 | **51.9** | 125.3 → 127.9 → **57.8** |
| LaboratoryOutside | 8.3 → 5.9 | 130.7 | 91.1 | **33.3** | 145.0 → 99.4 → **41.3** |

- Slice 4 alone (High): the GPU frame is 9–30 % lower in rooms with parallax backdrops. Interiors without a backdrop are unchanged, as expected. On this renderer the post-processing (glow) is the biggest cost: `-post` alone was 50–82 % of the GPU frame before.
- Low vs today: −58 to −82 % GPU per frame. The lab rooms stay the heaviest on Low (64–73 ms here) because of their 3–11 lights, which D554 does not touch. If the HD 3000 is still short there, the next step is the plan's "stop lab lights lighting the backdrop layers".
- LabBoss Low p99 472 ms is one boss-setup frame inside the window, not a render cost.
- Raw logs are not committed (they are 135 PERF lines each). The table is the summary.

## 5. D-IDs (text for the register)
| D608 | AGENT CALL (`cloud/perf-gfx`) | **Slice 4 crops backdrops to whole-pixel steps; the pixel diff is near zero, not zero.** `Scripts/Tools/region_backdrops.gd` crops each backdrop/terrain sprite to its used alpha rect plus 4 texels for the depth blur. Each cropped edge is rounded outward to a step of texels that is a whole number of screen pixels at camera zoom 2.25 for all four Settings resolutions (16 texels at sprite scale 1.5), because `snap_2d_vertices_to_pixel` otherwise shifts the texture by up to ½ px. 0.45 % of pixels still differ: texel boundaries that fall exactly on a pixel centre (every 8th texel at 3.375 px per texel) round to the other side. Any change of quad does this, so exactly 0 cannot be reached. The look is the same. Backdrop texels drop to 67 %, fill per frame by 22–30 % outdoors. |
| D609 | AGENT CALL (`cloud/perf-gfx`) | **First-use scenes warmed after the start (slice 5):** the four enemy scenes and their stats, the shop menu, the game-over screen, and each learned skill's cast effect with its oath-skill frames (also when a skill is learned in play). They are loaded in the background from the first room on and held for the whole game (`SceneWarmer.gd`, `RoomPreloader.pin`). The enemy HP bar scene no longer exists (D539). |
| D610 | AGENT CALL (`cloud/perf-gfx`) | **What Low turns off (D554):** WorldEnvironment glow and colour adjustment (D233), the depth-blur/background-blur layer shaders, Light2D shadows, and half of every particle emitter with 16 or more particles. Screen Brightness stays (it is the player's setting, D428), and the lab lights stay on. The Quality row sits in Settings → Display between Frame Rate Limit and Screen Brightness. It uses the existing segment row and switches live, no restart. |
| D611 | AGENT CALL (`cloud/perf-gfx`) | **First-run Quality default from the adapter name (D553):** Low for Intel "HD Graphics" with no number or a four-digit number up to 4000 (Ironlake, Sandy Bridge, Ivy Bridge), and for any ANGLE renderer on Direct3D 11 feature level 10.x (`vs_4_0`/`vs_4_1`). High for everything else, including HD 4200+ and the three-digit HD 510–630, UHD, Iris and discrete GPUs. The rule only sets the default; a saved choice always wins, and Restore Defaults goes back to it. |

## 6. Full suite
`Scripts/Tools/run_verify.sh` (103 scripts) → **SUITE: 3 FAIL**.
- `verify_onboarding` — `1 FAIL: keyboard: a light hit does not pass Heavy`. **Pre-existing**: the same failure on a clean `origin/feature/backlog` @ `62dd198f` worktree. Not from this branch.
- `verify_combat_flow` — `2 FAIL: the fast enemy lunges forward (19 px), the lunge reaches a hero 100 px away`. Run alone: `ALL PASS` on this branch and on base. It depends on timing under the suite's load.
- `verify_main_menu` — `ALL PASS, 5 SCRIPT ERROR`: `Could not resolve class "DefaultEnemy"` (ArcherEnemy.gd) and `Could not preload HealingPalm.tscn` (Village.gd:23). **Caused by slice 5**: the warmer's threaded loads compiled the same scripts as the neighbour-room loads, in parallel. Fixed by a pin queue in `RoomPreloader`: one warm load at a time, only while no room loads. After the fix, `verify_main_menu` ×2, `verify_room_preload`, `verify_graphics_quality` and `verify_quiet_transitions` all give `ALL PASS` with 0 SCRIPT ERROR.
- The full suite was not run a second time after that fix (the rules allow one run).
- Exit-time noise: `verify_graphics_quality` can print `Parse Error … DesertRoad.tscn:34` *after* `RESULT`. A cutscene's `preload_room()` starts a threaded load, and the process quits mid-load. It does not happen in play.
