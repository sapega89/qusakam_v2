---
type: report
tags: [cloud, routines, living-world]
---

# ambient-critters — slice 1 of [[ambient_critters_plan]] (D774)

**Done:** `AmbientCritter.gd` + `critter_bat.tscn`, two bats under `LizardCave/FrontDark`, `verify_ambient_critters`
(ALL PASS, 0 SCRIPT ERROR), `verify_room_entrances` ALL PASS, capture `design/shots/ambient_critters_cave.png`.
**Not done:** slices 2 (bird sheet, wing sound) and 3 (every room) — as planned.
**D-ID (next free, as built):** D775, text below. **B rows fixed:** none.
**Full suite:** running (updated when it finishes)
**Environment note:** `Resources/Audio/Music/heavy_battle.mp3.import` on `feature/backlog` lacks `uid`/`path`/`dest_files`;
the first `--import` rewrites it, and without that rewrite AudioManager asserts on `music fight` and every sound event
is unknown (dozens of SCRIPT ERRORs in any test). It came in with `41629a64` (D771); not committed here (outside
this task) — the orchestrator should commit the imported version.

## D775 (as built)
| D775 | ADDED (builds D774) | **Ambient critter, slice 1: the cave bat** (Sapega 2026-10-27: «…може летюча миша або якась річ, яка, коли ти туди підходиш, вона улітає і з'являється не одразу, як вийшов з зони огляду, а через час»). `Scenes/Backgrounds/Decor/critter_bat.tscn` + `Scripts/Gameplay/AmbientCritter.gd` (preloaded, no `class_name`): a Node2D with `Sprite` (AnimatedSprite2D, the bat sheet's `fly` row, 4 frames, 12 fps, scale 1, darkened by `FrontDark`) and `Perch` (VisibleOnScreenNotifier2D, 64×64, stays at the perch). Perched it hangs **upside down** (`flip_v`) on frame 0 of `fly`, held. When the hero (`GameGroups.PLAYER`) is within **160 px horizontally** and **320 px vertically** of its drawn `global_position` (the Parallax2D moves it), it plays `fly` and flies (1.4 s, ease-in) by (360 px away from the hero, 560 px up) — out of the view — then hides and stores the time in a static dictionary keyed by room scene + node path (survives leaving the room; not saved). It is back perched, with no fly-in, only when **30 s** have passed **and** its perch is out of the view. Exported, set in the `.tscn`: `scare_distance` 160, `scare_height` 320, `return_delay` 30. No body or area: it touches nothing. Lizard Cave: `FrontDark/Bat1` (620, 130) under Roots2, `FrontDark/Bat2` (960, 130) under Roots3 — away from ExitDoor (320), the gate (1240), the mural (1440) and the chest (1600); the room has no save point. |

## Calls made (owner unreachable)
- **Vertical reach.** The plan's 160 px measured as a straight distance never fires in the cave: the bat hangs at the
  ceiling (~y 130) and the hero walks at ~y 380. So 160 px is the horizontal distance and a separate `scare_height`
  (320 px, two thirds of a 480 px view) keeps a hero on another storey from scaring it.
- **Hanging upside down.** The plan says «frame 0 of fly, held»; held right side up it reads as a frozen flier, so it is
  flipped vertically while perched — a bat hanging from the roots (see the shot). Flight is upright, facing away.
- **On-screen test.** A `VisibleOnScreenNotifier2D` never fires under `--headless` (the dummy renderer; checked with a
  bare scene: `is_on_screen()` false at the camera's centre). The script keeps the notifier node for the perch rect and
  compares that rect, through `get_global_transform_with_canvas()`, with the viewport rect itself
  (`AmbientCritter.gd` `_perch_on_screen`) — one path, the same in the game and in tests.
- **Return time** is counted from the moment it vanishes (end of the flight), not take-off — 1.4 s apart.

## Files
- `SampleProject/Scripts/Gameplay/AmbientCritter.gd` — `_physics_process` (scare / return), `_sit`, `_fly_off`, `_gone`,
  `_perch_on_screen`; static `left_at: Dictionary[String, int]`.
- `SampleProject/Scenes/Backgrounds/Decor/critter_bat.tscn` — layout and the three exported values.
- `SampleProject/Maps/LizardCave.tscn` — one ext_resource (`x5`) and the `Bat1`, `Bat2` nodes under `FrontDark`; nothing
  else in the room touched.
- `SampleProject/UI/verify_ambient_critters.gd` — [1] two bats, on FrontDark, no CollisionObject2D, perched, defaults
  160/30, the hero at the door scares nobody; [2] real `move_right` up to Bat1 → takes off at 156 px, flaps, flies up and
  away, ends out of the view, time remembered; [3] the delay (2 s) over with the perch on screen → still away; perch off
  screen before the delay (8 s) → still away; after it → hangs again, one held frame, time cleared; [4] scared again,
  Canyon and back → a fresh instance still away with the perch off screen (30 s not over), the other bat untouched,
  `return_delay` 0.5 → back. The lizard fight nodes are freed in the test (they lock the camera; the bat is tested, not
  the fight).
- `SampleProject/UI/capture_ambient_critters.gd` → `design/shots/ambient_critters_cave.png`: Bat1 mid-flight up-left,
  Bat2 perched under the roots (its `scare_distance` set to 0 for the frame so the hero can pass under it).

## Results
- `verify_ambient_critters`: `RESULT: ALL PASS`, 0 SCRIPT ERROR.
- `verify_room_entrances`: `RESULT: ALL PASS`, 0 SCRIPT ERROR — incl. `LizardCave: Sprite hangs clear of the hero's
  head` for both bats (234 px at y 150; now y 130).
- Full suite: running (updated when it finishes)
