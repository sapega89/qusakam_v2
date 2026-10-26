---
type: report
tags: [cloud, camera, rooms]
---

# Cloud report: camera-transitions (B153)

**Summary**
- Done: Sapega's «камера скаче багато де, передивись переходи між кімнатами» is measured and fixed. 13 of 14 doors
  jumped 35–246 px in one visible frame and slid up to 1 s after the fade-in; a new game and a loaded save jumped
  74 / 43 px (slid 0.75 s). After the fix every case is 0 px and 0 s.
- Root cause: the door / teleport path never reset `position_smoothing`, and the room's limits were set later, deferred,
  in `init_room()`. Now one place (`Game.load_room()`) does it for every room change: limits → hero → snap → fade-in.
- Edge passages, the two cutscene ends that change rooms and running/jumping/dropping inside every room were already still.
- No new D-ID. B row: **B153** (B151/B152 are taken by `cloud/ui-critic`), filed in `design/BUGS.md` as fixed;
  `design/MASTER_PLAN.md` § 3 row B153.
- Full suite (one run): `SUITE: 2 FAIL`, 120 PASS — `verify_audio` (hero_hurt SFX not heard) and
  `verify_combat_enemies` (a tell 481 ms before its strike); neither touches the camera, each re-run alone: ALL PASS.

## What changed

| File | Change |
|---|---|
| `SampleProject/Scripts/Game.gd` `load_room()` | right after the swap `_fit_camera_to_room()` (MetSys cell limits + D483 `_raise_camera_bottom`); `_lift_fade()` is now `call_deferred`, so it runs after the caller placed the hero (edge passage, door, cutscene teleport, save load) |
| `Game.gd` `_lift_fade()` | first `_snap_camera()` (`reset_smoothing` + `force_update_scroll`), then D434's `ScreenFade.from_black` unchanged |
| `Game.gd` first room | the same: limits at once, snap / fade-in deferred; a new game places the hero in the same frame (the `await process_frame` before `_position_player_at_start()` let the camera show Game.tscn's default spot and slide from it) |
| `Game.gd` `init_room()` | no longer sets limits (it ran deferred, after the hero was placed and sometimes after the fade-in began) |
| `SampleProject/Scripts/Gameplay/FadeRoomTransitions.gd` | its own `reset_smoothing` removed — `_lift_fade()` does it for every path |
| `SampleProject/UI/verify_camera_transitions.gd` | new probe/verify, below |

D483's ground share (`CAMERA_GROUND_SHARE`, `camera_floor_y`) and D434's fade (`ROOM_FADE_TIME`, black during the swap)
are untouched. Cutscenes that detach the camera (`Cutscene.detach_camera`, `DemoEndScreen`) still drive it themselves;
`Canyon.gd`'s descent limits are replaced by the new room's at the swap, under black. No `SampleProject/Maps/*` edits.

## The verify

`verify_camera_transitions.gd` (headless, `Engine.max_fps = 60`, real input through `Input.action_press` / `Kit.key`):
- **[1]** every edge passage from `MapData` (borders ≥ 1 to another room; gates opened): the hero walks into the edge;
- **[2]** every `RoomDoor` in every room: the hero walks up to the door and presses E;
- **[3]** inside every room: from every cell, run right and left with a jump (drops off ledges on the way);
- **[4]** the Canyon descent cutscene (walk to the bridge edge after the village) and the MayorHall defeat → LabCells;
- **[5]** a new game and loading a save, the way the menu starts them (screen already black);
- **[6]** LabBoss → LaboratoryOutside last (the demo-end screen takes the camera; no way back, so that edge is skipped).

Per frame, from the first frame of the fade until 1.5 s after the screen is fully lit: `get_screen_center_position()`,
limits, fade alpha, hero position. It fails on a camera move > 12 px between two visible frames, on the camera being
> 4 px off its target (hero clamped to limits) after the fade ends, on a limit change between two visible frames, and
inside rooms on a frame where the camera moves > 12 px more than the hero or the limits change. Every failure names the
room, passage and frame (and the centre/hero/limits around it). Recording stops when a cutscene of the new room detaches
the camera. `-- <digits>` runs only those sections, `dump` prints the frames around a limit change.

`Canyon down → DesertRoad` has no hole to drop through — that way is the descent cutscene, covered in [4].

## Before / after

Before = `feature/backlog` code with the final probe (`Game.gd` and `FadeRoomTransitions.gd` stashed); after = this branch.

| Passage | Before: biggest visible one-frame move, px | Before: slide after fade, s | After: move, px | After: slide, s |
|---|---|---|---|---|
| Canyon right → Village | 0.0 | 0.00 | 0.0 | 0.00 |
| Village left → Canyon | 0.0 | 0.00 | 0.0 | 0.00 |
| DesertRoad right → CityGates | 0.0 | 0.00 | 0.0 | 0.00 |
| CityGates left → DesertRoad | 0.0 | 0.00 | 0.0 | 0.00 |
| City left → CityGates | 0.0 | 0.00 | 0.0 | 0.00 |
| City right → MayorHall | 0.0 | 0.00 | 0.0 | 0.00 |
| MayorHall left → City | 0.0 | 0.00 | 0.0 | 0.00 |
| LabCells right → Laboratory | 0.0 | 0.00 | 0.0 | 0.00 |
| Laboratory left → LabCells | 0.0 | 0.00 | 0.0 | 0.00 |
| Laboratory right → LabBoss | 0.0 | 0.00 | 0.0 | 0.00 |
| LabBoss left → Laboratory | 0.0 | 0.00 | 0.0 | 0.00 |
| BanditCamp door ExitDoor → DesertRoad | 134.0 | 0.92 | 0.0 | 0.00 |
| BanditCamp door ShortcutDoor → DesertRoad | 246.0 | 0.48 | 0.0 | 0.00 |
| Canyon door LizardCaveDoor → LizardCave | 62.2 | 0.00 | 0.0 | 0.00 |
| Canyon door DragonMuralDoor → DragonMural | 10.7 | 0.00 | 0.0 | 0.00 |
| CityGates door CellarDoor → GatehouseCellar | 72.9 | 0.00 | 0.0 | 0.00 |
| DesertRoad door BanditCampDoor → BanditCamp | 94.6 | 0.08 | 0.0 | 0.00 |
| DesertRoad door MesaClimbDoor → MesaClimb | 42.8 | 0.13 | 0.0 | 0.00 |
| DesertRoad door CampShortcutDoor → BanditCamp | 0.0 | 0.00 | 0.0 | 0.00 |
| DragonMural door ExitDoor → Canyon | 84.3 | 0.85 | 0.0 | 0.00 |
| ElderHouse door ExitDoor → Village | 141.9 | 0.93 | 0.0 | 0.00 |
| GatehouseCellar door ExitDoor → CityGates | 51.5 | 0.78 | 0.0 | 0.00 |
| LizardCave door ExitDoor → Canyon | 40.4 | 0.77 | 0.0 | 0.00 |
| MesaClimb door ExitDoor → DesertRoad | 199.0 | 1.00 | 0.0 | 0.00 |
| Village door ElderDoor → ElderHouse | 35.5 | 0.08 | 0.0 | 0.00 |
| BanditCamp inside (camera move beyond the hero's, px) | 0.0 more than the hero | — | 0.0 more than the hero | — |
| Canyon inside | 0.0 more than the hero | — | 0.0 more than the hero | — |
| City inside | 0.0 more than the hero | — | 0.0 more than the hero | — |
| CityGates inside | 0.0 more than the hero | — | 0.0 more than the hero | — |
| DesertRoad inside | 4.8 more than the hero | — | 4.8 more than the hero | — |
| DragonMural inside | 0.0 more than the hero | — | 0.0 more than the hero | — |
| ElderHouse inside | 0.0 more than the hero | — | 0.0 more than the hero | — |
| GatehouseCellar inside | 0.0 more than the hero | — | 0.0 more than the hero | — |
| LabBoss inside | 5.8 more than the hero | — | 5.8 more than the hero | — |
| LabCells inside | 0.0 more than the hero | — | 0.0 more than the hero | — |
| Laboratory inside | 0.0 more than the hero | — | 0.0 more than the hero | — |
| LizardCave inside | 0.0 more than the hero | — | 0.0 more than the hero | — |
| MayorHall inside | 0.0 more than the hero | — | 0.0 more than the hero | — |
| MesaClimb inside | 0.0 more than the hero | — | 0.0 more than the hero | — |
| Village inside | 0.0 more than the hero | — | 0.0 more than the hero | — |
| Canyon descent cutscene → DesertRoad | 0.0 | 0.00 | 0.0 | 0.00 |
| MayorHall defeat cutscene → LabCells | 0.0 | 0.00 | 0.0 | 0.00 |
| new game → Canyon | 74.1 | 0.00 | 0.0 | 0.00 |
| load → DesertRoad | 43.2 | 0.75 | 0.0 | 0.00 |
| LabBoss right → LaboratoryOutside | 0.0 | 0.00 | 0.0 | 0.00 |


## RESULT lines

- `verify_camera_transitions` (sections 1, 2, 4, 5, 6): ALL PASS, ~130 s; before the fix 25 FAIL (the same probe
  with all sections, old `Game.gd` / `FadeRoomTransitions.gd`).
- `verify_camera_rooms` (section 3): ALL PASS, ~106 s. Split from the first so each stays under run_verify's 180 s.
- Touched verifies, each ALL PASS: canyon_exit, city_gates_raid, cutscene, demo_end, gates, lab_boss, lab_cells,
  lab_rooms, lab_route, laboratory, mayor_boss, mayor_hall (once empty under a 400 s timeout while the lock was busy;
  alone 60 s, ALL PASS), quiet_transitions, room_preload, room_state, rooms_batch1, save_load, save_load_room,
  village_fight, village_house.
- Full suite: `SUITE: 2 FAIL`, 120 PASS — verify_audio, verify_combat_enemies (flaky under load, both ALL PASS alone).

## Notes for the orchestrator

- The routine prompt asked to file the B row in `design/BUGS.md` and a § 3 row in `design/MASTER_PLAN.md`, which
  ROUTINE_RULES reserves for the orchestrator. I followed the prompt; both are one-line additions (BUGS.md after the
  B150 note, MASTER_PLAN.md after B-hard) and should merge cleanly.
- `SampleProject/Assets/Backgrounds/Decor/*_sheet.png.import` (9 files) were generated by the headless import and are
  committed; they are deterministic, so a branch that adds the same files will not conflict.
- Headless measurement runs at `Engine.max_fps = 60`; the first frame after a heavy load has a long delta, so the fade
  tween can jump to ~0.45 alpha in one step — that is why the boots were visible at all and why the snap must happen
  before the first lit frame, not "soon after".
