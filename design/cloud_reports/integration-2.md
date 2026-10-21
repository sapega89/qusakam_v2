---
type: cloud-report
branch: cloud/integration
date: 2026-10-21
tags: [cloud, integration]
---
# Cloud report: integration-2

Start: `origin/cloud/integration` (integration-1), then `origin/feature/backlog` merged in. It was a fast-forward and
brought the owner's new art (A1 Raise frames, A2 houses). Godot 4.6.2 ran headless on Linux. No window, so there are no
captures.

## Merged branches

| Branch | Merge commit | Report |
|---|---|---|
| `cloud/chests` | `a2cf52c0` | [[cloud_reports/chests]] |
| `cloud/lab-9-5` | `e7296e7d` | [[cloud_reports/lab-9-5]] |

Both merges had **no conflicts**:
- `modal_templates.items_obtained` from `cloud/chests` is byte-identical to the one that `dialogue-ui` already added.
- `build_laboratory.gd` auto-merged: lab-9-5 changed the `npcs` table, and lab-9-7 changed how rooms are packed.
- `MainMenu.tscn`, `GameUITheme.tres`, `playthrough.gd` and `project.godot` are unchanged from `feature/backlog`.

I made one extra commit: the generated `.uid` / `.png.import` sidecars. They cover the merged scripts and the owner's
new art, which had been pushed without its `.import` files.

## Verifies after each merge

- **chests:** all `RESULT: ALL PASS`: `chests`, `road_sections`, `desert_road`, `interaction`, `save_load_room`,
  `room_state` and `gift_popup`.
- **lab-9-5:** all `RESULT: ALL PASS`:
  - `lab_cells`, `lab_rooms`, `mayor_hall`, `companions`, `laboratory` and `demo_end`
  - `journal`, `story_journal` and `map_geometry`
  - lab-9-7's `lab_boss` and `bosses`
  - `scripts_compile`

## Full suite

`Scripts/Tools/run_verify.sh` ran 80 scripts: **78 PASS, 2 FAIL**.
- **`verify_onboarding`: "pad: a held block does not pass Parry".** Two re-runs alone both gave `RESULT: ALL PASS`, so
  this is a timing flake. If it recurs, it is a candidate for the known-flaky list.
- **`verify_game_ui_theme`: expected, the same failure as integration-1.** D329 is still waiting on a theme
  regeneration: "every button focus is the shared ring (off: FilterButton, MainMenuItem(On), MiscRow(On),
  NpcMenuItem(On), ShopRow(On))". Only Sapega can regenerate `GameUITheme.tres`.

No merge regressions.

## Registered

**Decisions** (all "agent call, Sapega to confirm"):

| D-ID | Branch | Decision |
|---|---|---|
| D304 | lab-9-5 | The Laboratory cells cutscene. This fills the reserved row. |
| D305 | lab-9-5 | The wake, the acquaintance, Малік (`malik_escort`), and all assists at once. This fills the reserved row. |
| D339 | chests | Chests: opening, hero pose, the "You obtained:" modal, and staying open. |
| D340 | chests | The first chest: DesertRoad caravan ledge, Mana Crystal × 2. |

**Bugs:**

| B-ID | Branch | Bug |
|---|---|---|
| B91 | chests | The chest raise uses `Idle`. The Raise frames have now landed (`b56cbe6a`) but are not wired into the player. |
| B92 | lab-9-5 | A `Cutscene` that never reaches `end()` outlives its game, and the next dialogue segfaults. Severity: blocker. |

No B-rows were fixed or removed.

**Queue and backlog:**
- [[play_feedback_queue]]: 8j and 9.5 are struck through.
- [[BACKLOG]]: 33 is struck through, with B91 left. 17 is annotated: 9.5 and 9.7 are done; 9.6 and 9.8 are left.

## Unfinished branches

- **`cloud/buildings`**: there is no `design/cloud_reports/buildings.md` yet. The next integrator takes it.

## For Sapega

- Regenerate `GameUITheme.tres` (D329). Run
  `godot --headless --path . --script res://SampleProject/UI/build_game_ui_theme.gd` and commit the result.
- B91 is a small task: add a `Raise` animation to the player and set `Chest.HERO_POSE`.
- B92 is a crash when you quit or load during a cutscene.
- Nothing could be captured. Please look at the LabCells cutscene and the chest on the caravan ledge.
