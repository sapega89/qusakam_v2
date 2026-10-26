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
- Full suite: FULLSUITE

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

TABLE

## RESULT lines

RESULTS
