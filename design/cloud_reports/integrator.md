---
type: report
tags: [cloud, integrator, round-14]
---

# Integrator — round 14 (2026-10-26)

**Summary.** `cloud/dash-fix` and `cloud/world-map` are merged into `feature/backlog`. Godot 4.6.2 ran in this sandbox,
so everything the two branches left unrun has now been run. Register rows: **D713** (a dash keeps the state it started
in), **D714** (both World Map frames approved), **D715** (the two-level World Map as built). **B150** is fixed (the
dash-fix bug, which the branch had called B149). **Q98** (what is a secret) and **Q99** (wells) are filed with
defaults. **B149 is fixed at the root** (the menu deadlock against the room preloader). **The dash plays the new
frames**, with no roll or spin. `cloud/hard-fights` is not merged, because it is still running.
**Full suite: 121/121, `SUITE: ALL PASS` on the first run.**

## Merged

| Branch | D-IDs | B | Q | Conflicts |
|---|---|---|---|---|
| dash-fix | D713 (was D713) | B150 fixed (was "B149") | — | none |
| world-map | D714, D715 (were D713, D714) | — | Q98, Q99 | none |

The references were renumbered in both reports and in [[MASTER_PLAN]]; no code comment cited the IDs.
**History note:** both merges were made as merge commits, but a plain `git pull --rebase` before the first push flattened
them into linear commits (`7a3b75cc` dash-fix, `8ac6d57f`…`01297bc5` world-map). The content is identical. Rewriting a
pushed shared branch was not worth the risk, and every later pull used `--rebase=merges`.

## What the branches left unrun, now run

- Theme regenerated: `GameUITheme.tres` now has the map types (`MapPin*`, `MapCard*`, `MapRoomName`, `MapPassage`,
  `MapVeil`, `MapLegendTitle`).
- First runs: `verify_world_map`, `verify_responsive`, `verify_souls_combat`, `verify_combat_flow` and
  `verify_combat_player` were ALL PASS. Three failed and were fixed, one commit each:
  1. `verify_dash` [a] «loses height every frame in the air». The game was right: in the frame where the hero leaves
     the edge, `move_and_slide` still stands on it, the same as walking off a ledge. From the next frame on, he falls
     (16 → 163 px/s, landing in 12 frames while still dashing). The check now starts from the frame after the edge.
  2. `verify_game_ui_theme` «HUD v2 text at its Figma size». world-map added eight types to `FIGMA_FONT_TYPES`; the
     check's size list now has them and their tokens.
  3. `verify_locale` [1] uk: `world_map_pin.tscn` had a placeholder name «Location». The code always sets the name,
     so the placeholder is gone.
- `capture_world_map` was skipped (it needs a window): the orchestrator captures it locally.

## B149 — the root cause and the fix

- **Repro:** `verify_skill_screen` without its preloader wait, 8 copies in parallel. It hung about 1 run in 7 (gdb
  attached to each hung process; release binary, so addresses only, plus `--verbose` load logs).
- **What collides:** `game_menu_state.gd` had `const GAME_MENU_SCENE = preload(".../game_menu.tscn")`. A preload
  loads the scene while the script compiles, and compilation holds the GDScript cache's global mutex. `game_menu.tscn`
  shares `base_menu.tscn`, `bottom_bar.tscn` and `party_status_panel.tscn` with `shop_menu.tscn`. SceneWarmer pins
  the shop into RoomPreloader, which loads it with `load_threaded_request`.
  - The main thread (holding the mutex) reached `base_menu.tscn`, found it in progress on the worker, and waited.
  - The worker, inside `shop_menu.tscn → base_menu.tscn → …`, needed the same mutex to compile a script, and waited
    for ever.
  - `tutorial_component.gd` → `preload(tutorial_menu.tscn)` → `bottom_bar.tscn` had the same pattern.
- **Fix:** both load at open time, outside any compilation (`game_menu_state.gd`, `tutorial_component.gd`). The menu
  scene is kept in a `static var` after the first opening. There is no wait or retry. The two skill tests no longer
  wait for `room_preloader.busy()`.
- **Proof:** the same repro passed 48/48 with no hang.
- **New `verify_menu_after_room_change`:**
  - [1] A static rule, in both directions: no script in the game menu's tree preloads a scene that shares a scripted
    scene with the rooms or the warm-up list. It fails on the old code and names both preloads.
  - [2] The first opening of the menu while the shop is reloading in the background.
  - [3] 15 room changes, with the menu and its Skills tab opened in the first frame of each new room (the preloader
    was busy at 11 of them). No hang.

## Dash art

In `Player.tscn`, the `Roll` animation (name kept) now uses `Sprites/Player/Dash/1.png` for 0–0.05 s, `2.png` held to
0.25 s and `3.png` to 0.3 s; the length is still 0.3 s. Every frame is 64×64 with its lowest opaque row at 56, the same
as Idle, Walk and the old Roll, so every `Sprite2D:offset` key is (0, 0). Idle and Run use (0, 0) too, so the feet do
not jump or sink. The Roll PNGs stay in the repo; their ext_resources are gone from `Player.tscn`. The weapon libraries
have no Roll, so every weapon falls back to this one. `verify_dash` [d] checks the frames, the times and the feet line.
`verify_weapon_animations`, `verify_combat_player`, `verify_combat_flow`, `verify_hit_areas` and `verify_souls_combat`
all PASS.

## What Sapega should check first in the build

1. **The World Map tab, two levels.**
   - Level 1: pins over the illustrated map. The hero's location is selected, and the card shows explored % and chests.
     Left and Right walk the pins; A opens a visited location.
   - Level 2: the location's rooms on parchment, with explored, seen (dashed) and hidden cells, icons, passages and a
     legend. B returns to level 1.
   - Nothing has been compared with the Figma frames yet: the shot is the orchestrator's next step. No secrets count
     (Q98) and no «криниця» (Q99).
2. **A dash off a step.** Dash from the floor over the edge of a step or ledge: the hero falls at dash speed and does
   not hover. A dash started in the air still flies level (D713).
3. **The new dash frames.** A low push-off, a long mid-dash with the cape streaming back, and a braking stop, with no
   rolling. Look at the start and end of the dash next to Idle and Run for a jump or a sink in the feet.
4. **The menu right after a room change.** Enter a room (the Canyon is the heaviest) and open the game menu (Skills
   tab) at once, several times. It should never freeze (B149).

## Not done / next

- `capture_world_map` and the comparison with Figma `539:6472` / `539:6615` (needs a window; orchestrator).
- `cloud/hard-fights` waits for its own integration.
- Q98 and Q99 are open for Sapega, with their defaults built.
