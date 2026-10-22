---
type: report
tags: [cloud, routines, ui]
---

# Cloud report rows-2: Game Menu row templates, Skills + Inventory (#50)

**Summary.** Slices 5 (`skills_component`) and 7 (`inventory_component`, `bottom_bar`) of [[game_menu_single_scene_plan]] are done the D423 way: one commit per screen, both captures match the "before" ones (Skills pixel for pixel, Inventory except the play-time clock).
Not done: order 6 `options_component` (left alone on purpose, Settings is being changed on another branch), plus the leftovers listed below.
**D-ID text (next free number; orchestrator applies):** | D4xx | TECH | **Skills, Inventory and bottom-bar rows are scene templates** (D117, #50 slices 5 and 7; agent call; `cloud/rows-2`). Skills: `%Tier` (caption + `TrunkLane` / `OathLane`, each with a `SkillNode` in `Nodes` and a `Pad` sized to the free places of `NODES_PER_LANE`), `%TreeTab`, `%Slot1`, `%Fact` (one label template, even = `StatLabel`, odd = `StatValue`), `%AttributeRow`. Inventory: `%Tab`, `%ItemRow` (an `item_row.tscn` instance). Bottom bar: `%ActionHint`. Rows come from `RowFill.fill()` and are reused between rebuilds (wired once, the skill id lives in meta). New theme types: `SkillCostLearned` / `SkillCostLocked` / `SkillCostSelected`, `IconSlotFramed`, `BottomBar`, `ActionHint`, `ActionBadge`, `ActionBadgeLabel`; new tokens `BOTTOM_BAR_BG`, `ACTION_BADGE_SIZE`. The Skills avatar is a copy of `AvatarChip`. `item_row.gd` reads its children by path, because RowFill copies of a scene instance lose the `%`-name owner. Left: `options_component`, see the rows-2 report. |
**B rows fixed:** none (this is #50 / D117 work, no B-ID).
**Full suite:** `Scripts/Tools/run_verify.sh` → `SUITE: ALL PASS` (no FAIL lines), after both slices.

## What changed

### Slice 5 — Skills (`b736e6bd`)
- `SampleProject/Scenes/Menus/Game/skills_component.tscn`: the hidden `Templates` node is gone. Its templates now sit in their real containers:
  `%TreeTab` in `TreeTabs`, `%Tier` in `Tiers` (`Caption`, `TrunkLane/Nodes/SkillNode` + `TrunkLane/Pad`, same for `OathLane`),
  `%Fact` in `DetailGrid`, `%Slot1` in `HotbarSlots`, `%AttributeRow` in `AttrRows`. `Avatar` gets `theme_type_variation = AvatarChip`.
- `SampleProject/Scripts/Menus/Game/skills_component.gd`: `_build_tabs`, `_build_attribute_rows`, `_build_slot_buttons`, `_rebuild_tree` / `_fill_lane` / `_set_node`
  and `_show_facts` all go through `RowFill.fill()`. The tree reuses tiers and nodes when it is rebuilt: each node is wired once (`_wired`),
  and its handlers read the skill id from meta `skill_id`. `_rename()` first gives temporary names, so a reused row's new name
  (`Tier5`, a skill id) never clashes with a sibling's old one. A node's state caption switches theme variation instead of
  `add_theme_color_override`. The avatar takes a copy of the theme's `AvatarChip` and changes only its colour, like Status and Equipment do.
- Code-built count: from 13 nodes and 1 stylebox down to **0 nodes and 0 styleboxes**. `ButtonGroup.new()` is still there, but it is not chrome.
- Lane layout: `Nodes` (stretch = count) + `Pad` (stretch = `NODES_PER_LANE − count`, hidden at 0) gives the same widths as the old spacers.
- Tests: `verify_skill_screen` [1] has a new check that no control on the screen has a stylebox or colour override except the avatar.
  `verify_skill_screen`, `verify_skills_ui` and `verify_skill_trees_ui` now walk node → `Nodes` → lane → tier (the lane has one more level).

### Slice 7 — Inventory + bottom bar (`f0619bea`)
- `inventory_component.tscn`: `%Tab` in `Tabs` and `%ItemRow` (an `item_row.tscn` instance) in `ItemList`. In `inventory_component.gd`, `_build_tabs`
  and `_refresh_display` use `RowFill`, each row is wired once, and index checks use `items.size()`, because an empty list keeps the hidden template as a child.
- `item_row.gd`: the two `StyleBoxFlat.new()` are gone; the icon frame is the theme variation `IconSlotFramed` (normal) or `IconSlot` (selected).
  The `@onready` vars use paths (`$Row/IconBg`, …) instead of `%` names: a RowFill copy of a scene instance has no owner for the instance's
  inner nodes, so `%Icon` failed with "Node not found". `equip_picker` also uses `item_row`, and `verify_equipment` stays green.
- `bottom_bar.tscn`: the hardcoded `StyleBoxFlat` sub-resource is replaced by the `BottomBar` variation, and one `%ActionHint` (`Badge/Key`, `Name`) is added.
  `bottom_bar.gd`: `set_actions` uses `RowFill`, and `_make_action` (`HBoxContainer`/`PanelContainer`/`StyleBoxFlat`/2×`Label.new()`) is gone.
- Code-built count: inventory goes from 1 node to 0, `item_row` from 2 styleboxes to 0, bottom bar from 4 nodes + 1 stylebox to 0.
- `UITokens.gd`: `BOTTOM_BAR_BG := Color("111118", 0.85)` and `ACTION_BADGE_SIZE := 24`. `build_game_ui_theme.gd` adds `IconSlotFramed`,
  `BottomBar`, `ActionHint`, `ActionBadge` and `ActionBadgeLabel`. `GameUITheme.tres` was regenerated, and `verify_game_ui_theme` reports `ALL CHECKS PASSED`.
- Test: `verify_inventory` [6] has a new check that tabs, item rows, bottom-bar hints and the bar itself have a theme variation and no stylebox override,
  and that the icon frame is `IconSlot` / `IconSlotFramed`.

## RESULT lines (per slice)
- Skills: verify_skill_screen, verify_skill_trees_ui, verify_skills_ui, verify_attributes and verify_kusakam_skills: all `RESULT: ALL PASS`.
  verify_game_ui_theme: `ALL CHECKS PASSED`. verify_kusakam_skills also logs `Parent node is busy setting up children` and `Playback can only
  happen…`; both come from gameplay, not from the menu.
- Inventory / bottom bar: verify_inventory, verify_use_item, verify_equipment, verify_gamepad_parity, verify_game_menu, verify_responsive,
  verify_world_map, verify_settings and verify_skill_screen: all `RESULT: ALL PASS`.

## Shots
- `design/shots/rows_2_menu_skills_before_after.png`: before on the left, after on the right. `compare -metric AE` = 0.
- `design/shots/rows_2_menu_inventory_before_after.png`: 128 px differ, all of them in a 14×13 box at (1625,109), which is the play-time clock (00:22 vs 00:20).
- Script: `SampleProject/UI/capture_rows_2.gd -- <tag>`.

## What is left (#50 / D117)
1. **Order 6 `options_component`** (15 nodes, 1 stylebox): not touched, because `cloud/settings-1` is changing Settings. Do it once that branch is merged.
2. `equip_picker.gd` still calls `ITEM_ROW_SCENE.instantiate()` in a loop. That is a scene, not hand-built chrome, but it is not a RowFill template either.
   Its row styles come from the theme now.
3. `inventory_component.tscn` still has a `StyleBoxLine` sub-resource with a hardcoded border colour for the header rule. It is not a row, but it could
   become an `HSeparator` theme variation.
4. `bottom_bar.tscn` hardcodes margins of 48 and a height of 64. `UITokens.BOTTOM_BAR_HEIGHT` is 64, but `BOTTOM_BAR_PADDING` is 60, not 48. Before
   moving these to tokens, check Figma 121:1073 for the right padding. If they differ, that needs a Q or B.
5. Skills node markers still tint their icon with `modulate = UITokens.*`: an icon colour, not a stylebox.
6. Outside this plan: `skill_hotbar` and `player_vitals_panel` (Combat HUD).

## Notes for the orchestrator
- Update [[game_menu_single_scene_plan]] "Slices 2+": order 5 ✅ and order 7 inventory/bottom_bar ✅ (`cloud/rows-2`, D4xx), both "0 nodes, 0 styleboxes".
- The first Godot import changes `addons/maaacks_menus_template/base/translations/*` and creates stray `.uid` files. They were not committed.
