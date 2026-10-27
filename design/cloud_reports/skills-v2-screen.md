---
type: report
tags: [cloud, skills, v2, ui]
branch: cloud/skills-v2-screen
---

# cloud/skills-v2-screen: skills v2 slice 2, the Skills screen at 19 a tab

**Summary**
- **Already there:** the Dragon Nest window (D674/D691) has a 4 × 5 grid, and `cloud/skills-v2-data` put 19 skills in each tab. D728 (only the base tree and the chosen path's tree) was already built by `cloud/oath-census`. The paid Reset all is already wired (D628/D629). This pass fixes what kept the screen from fitting and reading at 1920 × 1080.
- **Fixed:** selecting a learned active (which shows the hotbar row) grew the window to 1137 px against 902 px of room. The title "SKILLS", the tree tabs and the bottom bar were cut off: `grow_vertical = both` split the overflow above and below. The worst case is now 868 of 902 in both en and uk. See D-sv2s.
- **Fixed:** prerequisite lines ran through the rank label under a cell ("1 | 3"). They now start below the label.
- **Gamepad:** a new check walks the D-pad across both trees and reaches all 38 cells.
- **B77** (a mouse cannot learn) was already fixed by D330's Learn +1 and is covered by `verify_skill_screen` [4]. Nothing was left to do. No B rows fixed.
- **Full suite:** `SUITE: 6 FAIL`. Five of these are known from the skills-v2-data report and fail the same way without this branch: `verify_map_geometry`, `verify_progression`, `verify_save_load`, `verify_save_load_room` (all on feature/backlog) and `verify_difficulty` (D-sv2c). The sixth, `verify_city_gates_raid`, passed on one re-run (ALL PASS), so it was a timing flake that does not touch the skills screen.
- Figma `485:6490` was not redrawn: it cannot be reached from the cloud, and D716 makes Figma inspiration only. The screen keeps D691's approved look.

## D-ID text (for the orchestrator; placeholder D-sv2s)

| ID | Kind | Text |
|---|---|---|
| D-sv2s | ROUTINE CALL | **Skills screen at 19 a tab: the detail panel fits** (skills v2 slice 2; D535, D691, D716; `cloud/skills-v2-screen`). With a learned active selected, the detail panel needed 235 px more than the window has. The window spread past the screen, so its title, tabs and points bar were cut off. Changes: (1) **the hotbar row is one row of 8 square icon slots** (`UITokens.SKILL_HOTBAR_SLOT_SIZE` 40, `SkillSlot` style, as in the battle hotbar). Each slot shows the held skill's icon and its key number in a corner badge; "N · Skill name" moves to the tooltip. It was a 2 × 4 grid of text buttons. (2) **Cooldown shows only when the skill has one** (only ultimates do). The "—" row on the other actives is gone. (3) Detail spacing goes 16 → 12 and fact rows 8 → 4. (4) **Prerequisite lines start under the rank label** of the prerequisite cell instead of crossing "1 / 3". Worst case (Fire Strike, en and uk) needs 868 of 902 px. `verify_skill_screen` [10] checks the fit for every skill in both languages, 19 per tab, the slot size, the lines and D-pad reach over all 38 cells. |

## Files
- `SampleProject/Scenes/Menus/Game/skills_component.tscn`: `HotbarSlots` has 8 columns. The `Slot1` template is a 40 px `SkillSlot` with an `Art` icon and a `Key` badge (`SkillLevelBadge`). Detail separation is 12, fact v_separation 4.
- `SampleProject/Scripts/Menus/Game/skills_component.gd`: `_refresh_hotbar` (icon, key, tooltip). Cooldown is shown only when > 0. `_refresh_links` passes the prerequisite's cell.
- `SampleProject/Scripts/Menus/Game/skill_tree_links.gd`: comment only (the line starts at the given control's bottom).
- `SampleProject/UI/Tokens/UITokens.gd`: `SKILL_HOTBAR_SLOT_SIZE := 40`.
- `SampleProject/UI/verify_skill_screen.gd`: new [10]. [3] expects no Cooldown row on Fire Strike. [8] checks the slot's icon, key and tooltip.

## Tests
- `verify_skill_screen` ALL PASS (new [10]: en/uk fit 868 of 902, 38 of 38 cells by D-pad)
- `verify_skill_trees_ui`, `verify_skills_ui`, `verify_kusakam_skills`, `verify_new_points`, `verify_responsive`, `verify_menu_after_room_change`, `verify_skill_ranks`, `verify_gamepad_parity`, `verify_scripts_compile`: ALL PASS
- `verify_game_ui_theme`: "=== ALL CHECKS PASSED ===". The theme was not rebuilt because the new token is not read by the builder.
- Full suite: `SUITE: 6 FAIL` (see the summary).

## Shots
- `design/shots/skills_v2_screen_before_after.png`: before (title and tabs cut off at the top, lines crossing the rank labels, 2 × 4 text hotbar) and after.
- `design/shots/skills_v2_screen.png`, `design/shots/skills_v2_screen_passive.png`: after, 1920 × 1080 (`capture_skills_dn.gd`).

## Env note
Not committed: Godot's import rewrite of `heavy_battle.mp3.import` (see the skills-v2-data report), plus `meditation_spot.png.import` and three `.uid` files Godot generated for other branches' scripts.
