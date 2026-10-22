---
type: cloud-report
branch: cloud/integration
date: 2026-10-22
tags: [cloud, integration]
---
# Cloud report: integration-3

This report is named `integration-3` because `integration-2.md` already existed from the previous run.

Start: `origin/cloud/integration` (integration-2), then `origin/feature/backlog` merged in. That merge brought the
owner's art: A3 dagger, mace and halberd frames, and the A2 elder's-house rework `9523ce09`. Godot 4.6.2 ran headless
on Linux. There was no window, so there are no captures.

## Merged branches

| Branch | Merge commit | Report |
|---|---|---|
| `cloud/buildings` | `067e477d` | [[cloud_reports/buildings]] |
| `cloud/lab-9-6` | `d312d8d0` | [[cloud_reports/lab-9-6]] |
| `cloud/weapon-gamepad` | `7f2efe7d` | [[cloud_reports/weapon-gamepad]] |
| `cloud/localization-1` | `5e644b97` | [[cloud_reports/localization-1]] |

These were already merged by integration-1 and integration-2: `b82-b10`, `chests`, `dialogue-ui`, `lab-9-5`, `lab-9-7`,
`onboarding`, `settings-cleanup` and `skills-screen`.

My own commits:
- `66fb4699`: the `.import` sidecars for the owner's new weapon art.
- `675ba8a1`: a merge fix, described below.
- `9da76a07`: the registers.

`MainMenu.tscn`, `GameUITheme.tres`, `playthrough.gd` and `project.godot` are unchanged from `feature/backlog`.

## Conflicts and how I resolved them

**`cloud/buildings`** conflicted with the owner's art rework `9523ce09`, which landed after the branch was cut. The rework
replaced the elder's house: it was 278×201 and two storeys, and is now 468×191 and one storey. It also repainted the
interior wall.

- **`.png.import` (add/add, UID only):** I kept `feature/backlog`'s sidecars. No scene refers to the textures by UID.
- **READMEs:** I kept the branch's "where it is used" text and the rework's description of the art.
- **Placement:** the branch placed the house for the old art. At x 2120 the new 702 px-wide house would run 230 px past
  the Village's east edge (2592). I moved it:
  - `ElderHouse`: (2120, 124) → **(1890, 150)**. Threshold row 167 now sits at y ≈ 400 like the other buildings, and
    the right edge is on the room edge.
  - `ElderDoor`: 2354 → **2163**, on the new arched door (x 163–201).
  - `GrandpaHouse`: 1413 → **1398**, so the two houses don't overlap. The grandfather at 1572 still stands left of
    his door.
  - `verify_village_house` passes.

**`cloud/lab-9-6`, `cloud/weapon-gamepad` and `cloud/localization-1`** merged without textual conflicts.
`weapon-gamepad` and `localization-1` both edit 7 files, and git merged those cleanly. There was still one semantic
regression:
- **`verify_locale` [3a]/[3] UK:** the Load menu's bottom bar showed the new keyboard badge "Arrows". It comes from
  weapon-gamepad's `InputGlyphs.badge()`.
- **Fix `675ba8a1`:** `badge()` now translates "Arrows" (→ «Стрілки») and "D-pad" (→ «Хрестовина»). They are names,
  not labels printed on a key or pad button, so they should be translated. I added both to `uk.po` and ran
  `po_sync.py`.
- After the fix these all pass: `locale`, `gamepad_parity`, `hotbar` and `combat_hud`.

## Verifies after each merge

All of these printed `RESULT: ALL PASS`.
- **buildings:** `village_house`, `map_geometry`, `oath`, `npc_activity`, `npc_arrival`, `journal_sections`.
- **lab-9-6:** `laboratory`, `lab_rooms`, `map_geometry`, `ladders`, `lab_cells`, `demo_end`, `journal`,
  `story_journal`, `lab_boss`.
- **weapon-gamepad:** `souls_combat`, `gamepad_parity`, `skill_casts`, `combat_flow`, `chests`, `gamepad`,
  `onboarding`, `scripts_compile`, `game_menu`, `main_menu`, `settings`, `world_map`, `journal_sections`,
  `tutorial_hints`, `game_over`, `demo_end`, `crafting`.
- **localization-1:** `locale` passed after the fix above. Also `gamepad_parity`, `scripts_compile`, `settings`,
  `game_menu`, `skill_screen`, `hotbar`, `demo_end`, `equipment`.

## Full suite

`Scripts/Tools/run_verify.sh` ran 83 scripts: **82 PASS, 1 FAIL**.

- The one failure is `verify_game_ui_theme`, which prints no RESULT line. It is expected and is the same failure as in
  integration-1 and integration-2: D329 is waiting for `GameUITheme.tres` to be regenerated. `lab-9-6` confirmed that
  regenerating it makes the check pass. I did not file it as a new B-row because it would duplicate D329.
- `verify_audio` passed in this run. It is flaky (B94).
- `verify_onboarding` passed too.

I found no merge regressions besides the one fixed above.

## Registered

**Decisions** (all marked "agent call, Sapega to confirm"):

| D-ID | Branch | Decision |
|---|---|---|
| D306 | lab-9-6 | The mob corridors (fills the reserved row). |
| D341 | buildings | The oath keepers' buildings and the grandfather's house. Includes the integrator's x 1398. |
| D342 | buildings | The village elder's house and the `ElderHouse` room. Includes the integrator's re-placement for the reworked art. |
| D343 | buildings | Companion lore stubs. |
| D344 | weapon-gamepad (its D370) | Weapon frames are made per weapon type, one `AnimationLibrary` each. |
| D345 | weapon-gamepad (D371) | How the sword frames map to the hero's animations. |
| D346 | weapon-gamepad (D372) | Badges show the last-used device's buttons. "LS / Arrows" (UK: «Стрілки»). |
| D347 | weapon-gamepad (D373) | The World Map pans only while it has focus. |
| D348 | weapon-gamepad (D374) | Game Menu routing. |
| D349 | localization-1 | `.po` files with English keys, registered in code. |
| D350 | localization-1 | The game starts in English. |
| D351 | localization-1 | Each language's name is written in the current language. |
| D352 | localization-1 | Ukrainian wording of game terms. |
| D353 | localization-1 | Dialogue: one `.dqd` file per language. This is the part 2 plan; it is not built yet. |

**Bugs:**
- **Added:**
  - B93: `Game.gd:390` fails to compile when a verify names `RoomDoor` (buildings).
  - B94: `verify_audio` focus tick is flaky (buildings and localization-1).
  - B95: Keyboard Enter after a mouse click in the Game Menu (localization-1).
  - B96: The Controls list shows action ids as names (localization-1).
- **Removed as fixed:**
  - **B83:** `lab-9-6` lowered the corridor bridges, and `verify_laboratory` [5] checks them.
  - **B89:** `options_component._rebuild_list` re-grabs focus on the same row, and `verify_gamepad_parity` checks it.
- **Found and fixed by `weapon-gamepad`:** its B100–B104, renumbered **B97–B101**. They are logged in the
  [[BUGS]] fixed log, with no rows.

**Queue and backlog:**
- [[BACKLOG]]:
  - Struck through: 24, 29 and 38, each with what is left.
  - Annotated: 17 (corridors done), 31 (part 1 done), 34 (the stubs are done; the Journal pages are left) and 42 (the
    sword is done).
- [[play_feedback_queue]]:
  - Struck through: 8f, 9.6 and 9b.
  - Annotated: 8g, 8k and 10a.

## Unfinished branches

None. Every `origin/cloud/*` branch has its report and is merged.

## For Sapega

- Regenerate `GameUITheme.tres` (D329). It is the only red check left.
- Please look at the Village east end in the game. I placed the reworked elder's house (D342) by its pixel measurements,
  without a capture.
- The dagger, mace and halberd frames are in the repo, but only the sword is wired (D344). The next slices are in
  [[hero_weapon_animation_plan]].
- Localization part 2 continues from D353 / [[localization_plan]] §4.
