---
type: cloud-report
branch: cloud/integration
date: 2026-10-21
tags: [cloud, integration]
---
# Cloud report: integration-1

Branch `cloud/integration` did not exist yet. This run created it from `origin/feature/backlog` @ `dd799fd7`.
Godot 4.6.2 ran headless on Linux. No window was available, so there are no captures.

## Merged branches

| Branch | Merge commit | Report |
|---|---|---|
| `cloud/b82-b10` | `405d4dde` | [[cloud_reports/b82-b10]] |
| `cloud/dialogue-ui` | `905c0182` | [[cloud_reports/dialogue-ui]] |
| `cloud/lab-9-7` | `981e8c09` | [[cloud_reports/lab-9-7]] |
| `cloud/onboarding` | `3258c241` | [[cloud_reports/onboarding]] |
| `cloud/settings-cleanup` | `80df1d60` | [[cloud_reports/settings-cleanup]] |
| `cloud/skills-screen` | `c17c93d1` | [[cloud_reports/skills-screen]] |

None of the six branches touched `MainMenu.tscn`, `GameUITheme.tres`, `playthrough.gd` or `project.godot`. These files
match `feature/backlog`.

## Conflicts and how they were resolved

- **`cloud/dialogue-ui` against `cloud/b82-b10`**:
  - `SampleProject/Scripts/UI/GameDialogueBox.gd`: only the doc comment conflicted. I kept both paragraphs: B10 (Auto and
    Skip are hidden, and why the nodes stay) and BACKLOG 36 (the centred name and the portrait).
  - `SampleProject/UI/verify_npc_recall.gd` [5]: I kept both checks. The grandfather's portrait frame is shown (36,
    which replaces b82-b10's "no portrait frame" check, because he now has a portrait), and Auto and Skip are not
    visible (B10).
  - `dialogue_box.tscn` merged on its own: `AutoButton` and `SkipButton` are still `visible = false`, and `NameMargin`
    is present.
- Every other merge had no conflicts. Some files were changed by two branches and merged on their own:
  - `combat_hud_top.gd` and `Game.gd` objectives (onboarding's arrow and dialogue-ui's plaque fade);
  - `PlayerStateManager` and `PlayerDataModule` (B82 position and skills-screen attributes);
  - the Misc menu (onboarding's Controls page and settings-cleanup's focus ring).

  The verifies of both sides were re-run after each such merge and pass.

## Verifies after each merge (RESULT lines)

- **b82-b10:** these all pass:
  - `save_load_room`, `save_load`, `npc_recall`, `cutscene`: ALL PASS
  - `game_ui_theme`: ALL CHECKS PASSED
- **dialogue-ui:** all pass:
  - `dialogue_speaker`, `objective_plaque`, `gift_popup`, `npc_recall`, `npc_arrival`, `journal`, `story_journal`,
    `combat_hud`, `tasks`, `mayor_hall`, `scripts_compile`: ALL PASS
  - `game_ui_theme`: ALL CHECKS PASSED
- **lab-9-7:** `lab_boss`, `bosses`, `lab_rooms`, `map_geometry` all pass.
- **onboarding:** all pass:
  - its own verifies: `onboarding`, `village_fight`, `tutorial_hints`, `canyon_exit`, `souls_combat`, `misc_modal`,
    `game_menu`, `story_journal`, `scripts_compile`
  - the earlier merges' verifies that it could break: `objective_plaque`, `combat_hud`, `gift_popup`
- **settings-cleanup:** all pass except one expected failure:
  - pass: `scripts_compile`, `map_geometry`, `settings_graphics`, `settings`, `main_menu`, `misc_modal`, `shop`,
    `game_menu`, `game_over`, `save_load`, `gamepad`, `npc_chatter`, `npc_activity`, `npc_arrival`, `npc_recall`,
    `interaction`, `cutscene`, `tasks`, `full_regression`, `onboarding`
  - **`verify_game_ui_theme`: 1 FAILURE, expected.** The message is "every button focus is the shared ring (off:
    FilterButton, MainMenuItem(On), MiscRow(On), NpcMenuItem(On), ShopRow(On))". D329 changed the theme builder, and
    `GameUITheme.tres` may not be regenerated here. **This run regenerated the theme locally (not committed), and the
    verify then printed `ALL CHECKS PASSED`.** Sapega must run
    `godot --headless --path . --script res://SampleProject/UI/build_game_ui_theme.gd` and commit the `.tres`.
- **skills-screen:** `skill_screen`, `attributes`, `skill_trees_ui`, `skills_ui`, `kusakam_skills`, `oath`, `status`,
  `skill_trees`, `equipment`, `combat_flow`, `save_load`, `save_load_room`, `hotbar`, `scripts_compile` all pass.

## Full suite

First run of `Scripts/Tools/run_verify.sh` (78 scripts): **76 PASS, 2 FAIL**.

- **`verify_onboarding`: a regression from the merge, now fixed.** The failure was "every gameplay action in the
  InputMap is listed (missing skills_accept, skills_unpick)". Onboarding's Controls page check requires every
  registered action to be listed, and skills-screen registers two new actions (D331). I added both as rows in
  `controls_component.gd` ("Skills screen: accept the picks" and "Skills screen: undo a pick"), because the page
  already lists menu actions such as Game menu and the tab row. After the fix these pass:
  - `verify_onboarding`: ALL PASS
  - `misc_modal`, `game_menu`, `skill_screen`, `gamepad`: ALL PASS
- **`verify_game_ui_theme`: expected, waits on Sapega.** It reports "no RESULT line" because this script prints
  `=== 1 FAILURE(S)`. The cause is the unregenerated `GameUITheme.tres` (D329, see above). It passes with the
  regenerated theme.

The suite is therefore green except for the theme regeneration, which only Sapega can do. Neither known flake
(`verify_audio`, `verify_souls_combat`) failed in this run.

## Registered

**Decisions** in [[figma_decision_register]], all marked "agent call, Sapega to confirm":

| D-ID | Branch | Decision |
|---|---|---|
| D307 | lab-9-7 | The boss hall. It replaces the reserved row and folds in the B83 note for the hall. |
| D319 | b82-b10 | No Auto or Skip in the dialogue box (B10). |
| D320 | b82-b10 | A load puts the hero where he saved (B82). |
| D321 | dialogue-ui | Who is speaking (BACKLOG 36). |
| D322 | dialogue-ui | The objective plaque fades out and comes back (37). |
| D323 | dialogue-ui | The gift popup and the HUD loot feed (33, the non-art part). |
| D324 | onboarding | The street-fight lessons (D-28a…g, with D-28c amended). |
| D325 | onboarding | The objective arrow (D-28h amended). |
| D326 | onboarding | The keyboard key Z for `weapon_prev` (D-28i). |
| D327, D328 | settings-cleanup | The Resolution and Frame Rate Limit settings. |
| D329 | settings-cleanup | One selection look (Q33). Needs the theme regenerated. |
| D330–D336 | skills-screen | The Skills screen and attribute points. These keep the branch's own numbers because its code cites them. |
| D337 | settings-cleanup | The cleanup scope (39). |
| D338 | settings-cleanup | The NPC chatter route (35). |

**Bugs** in [[BUGS]]:

- Removed:
  - **B82**: fixed. The code places the hero (`Game._initialize_save_and_room`), and `verify_save_load_room` passes.
- Narrowed:
  - **B10**: Auto and Skip are fixed. Only the `!` glyph is left, and nobody has checked it yet.
  - **B83**: the boss hall is fixed. The Laboratory corridors are left, for 9.6.
- Noted again:
  - **B42**: the dead `ObjectiveHUD` ext_resource.
- New and open:
  - **B84**: crit, evasion and speed do nothing in a fight (skills-screen).
  - **B86**: Cyrillic speaker names show in the English UI (dialogue-ui).
  - **B89**: Settings segment rows lose focus after a toggle (settings-cleanup).
  - **B90**: a pressed `ListRow` has no focus ring (settings-cleanup).
- Found and already fixed on their branches (listed in the fixed log):
  - **B85**: `godot_locked.sh` and `run_verify.sh` had no exec bit. This was reported by four branches; b82-b10's
    commit fixes it.
  - **B87**: combat training could kill the bandit.
  - **B88**: `weapon_prev` had no keyboard key.

**Questions:**

- **Q67**: who says chatter lines, and in which language. Not blocking: NPCs stay silent until there are lines.

**BACKLOG:**

- Struck through: 28, 35 (the route is built), 36, 37, 39, 41, 43, 44.
- 33 is marked partly done: the chest art is left.

**[[play_feedback_queue]]:**

- Struck through: 8e, 8i, 9.7.
- Annotated: 8j (36, 37 and the 33 gift and loot parts are done) and 10a (35, 39, 41 are done).

## Unfinished branches (for the next integrator)

- **`cloud/chests`**: no `design/cloud_reports/chests.md` yet. It has 2 commits: a Chest scene and its tool exec bit.
- **`cloud/lab-9-5`**: no report yet. It has 4 commits for row 9.5: the LabCells cutscene, the wake-up, Малік and the
  assists. D304 and D305 are still reserved for it. Note: lab-9-7 changed `build_laboratory.gd`, so props keep their
  children and rooms are packed in edit state. If 9.5 rebuilds LabCells, node ids will differ.

## For Sapega

- Regenerate `GameUITheme.tres` (D329). Until then `verify_game_ui_theme` [3c] fails.
- Nothing here could be captured. Please look at these in the editor or the exe:
  - the dialogue name overlay and each portrait crop (most of all the dervish and the gate guard);
  - the loot toast column;
  - the objective arrow;
  - the Controls page;
  - the new Skills screen (the deliberate Figma deviation, D333);
  - the focus ring in every menu.
