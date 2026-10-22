---
type: report
status: done
tags: [cloud, ui, dialogue, game-menu, d117]
---

# Cloud report — `cloud/ui-fixes` (2026-10-22)

**Summary.** **B112 fixed** (row to remove): the speaker's name is now the first row of the dialogue box, and the row is hidden on narration. **GitHub #50, order 3 (Status) and order 4 (Equipment) done.** Their rows are scene templates (D117), styled by the theme, and both captures match the before shots. The only difference is the playtime clock. Not done: order 5 `skills_component`, order 6 `options_component` (left alone on purpose, `cloud/settings-1` is editing Settings), and `inventory_component` / `bottom_bar`. See §3.
D-ID text (proposed, number to be assigned): **"Status and Equipment rows are scene templates (D117, #50 slices 3–4).** `%WeaponBox`, `%PointAttr`, `%AttrRow`, `%ActionCard` (Status) and `%SlotRow`, `%AttrRow` (Equipment) live in the `.tscn`. Further rows come from `RowFill.fill()` (`ui_rows.gd`), and one `%AttrRow` template fills both attribute columns. The styles come from the theme types `AvatarFrame`, `AvatarChip`, `AttrRow`, `IconSlot`, `AccentTick` and `AccentDot`. The avatar colour is set on a copy of the theme stylebox, because it is per-character data."
Full suite: running (line added when it finishes).

Branch `cloud/ui-fixes` from `origin/feature/backlog` @ `64ffcefc`. Commits: `42d1002b` (B112), `962720cd` (slice 3),
`66e322fb` (slice 4).

## 1. B112: the speaker's name over the first line

- `SampleProject/Scenes/UI/dialogue_box.tscn`: `NameMargin` (now `%NameMargin`, `visible = false`) moved from the
  `DialogueBox` root into `Margin/Rows` as its first child, above `RowTop`. Its overlay margins (top 14, left/right 10)
  are gone, because the box's `Margin` already pads it.
- `SampleProject/Scripts/UI/GameDialogueBox.gd`: `set_name_text()` override. It shows the row only when the name is
  non-empty, so a narration line has no blank line above it. It follows the same pattern as `set_portrait_image()`.
- `SampleProject/UI/verify_dialogue_speaker.gd`: each named line checks that the name's bottom edge is above
  `DialogueText`'s top, for example `Grandfather … (B112: 760 ≤ 768)`. Narration checks that `%NameMargin` is hidden.
  [4] now checks that `NameMargin` is child 0 of `Margin/Rows`, and that it and `Name` still ignore the mouse.
  `RESULT: ALL PASS`.
- Shots (xvfb, `capture_ui_fixes.gd -- <tag> dialogue`): `design/shots/ui_fixes_dialogue_{before,after}.png` (Grandfather),
  `ui_fixes_dialogue_narration_{before,after}.png`, and the side-by-side crop `ui_fixes_dialogue_compare.png`.
  The box grows upward by one line (it is bottom-anchored, `grow_vertical = 0`). The portrait stays beside the text.

## 2. Game Menu slices 3 and 4 (#50, D117)

New capture script: `SampleProject/UI/capture_ui_fixes.gd -- <tag> [dialogue|menu]`. It writes `design/shots/ui_fixes_*`.

### Slice 3: `stats_component` (`962720cd`)
- `.tscn` templates: `%WeaponBox` (BoxPanel + `Letter`), `%PointAttr` (`Caption`/`Value`), `%AttrRow` (`Row/Icon|Name|Value`,
  the same structure the code built, so `verify_status`'s `get_child(0).get_child(2)` paths still hold) and `%ActionCard`
  (`Col/Head/Caption|Divider|Title`). `Avatar` uses theme type `AvatarFrame`.
- `.gd`: `_update_weapon_slots`, `_fill_point_attrs` (rows renamed to the attribute id, which `verify_status` [4] reads),
  `_fill_rows` and `_update_actions` now go through `RowFill.fill`. `_make_weapon_box`, `_make_attr_row` and
  `_make_action_card` are deleted. The script no longer calls `Label.new()`, `Panel.new()` or `StyleBoxFlat.new()`.
- `verify_status`: new check "attribute rows, action cards and weapon boxes are template copies styled by the theme (D117)".
  `RESULT: ALL PASS`. `verify_game_ui_theme`: `=== ALL CHECKS PASSED ===`.
- Shot: `design/shots/ui_fixes_menu_status_after.png`. It is pixel-identical to the before shot (`compare -metric AE` = 0).

### Slice 4: `equipment_component` (`66e322fb`)
- `.tscn` templates: `%SlotRow` (ListRow button, 63 high: `Row/Icon|Caption|ItemName|Dot`, the same node names the
  tests and `capture_game_menu_batch` use) and `%AttrRow` (`Row/Name|Value|Delta`; `Delta` is hidden by default).
  `Avatar` uses theme type `AvatarChip`.
- `.gd`: `_build_slot_rows` and `_update_attributes` use `RowFill`, and the new `_fill_attr_row` replaces
  `_make_slot_row` and `_make_attr_row`. The script makes no nodes or styleboxes. `_slot_rows` (slot id → Button) is unchanged.
- Theme (`build_game_ui_theme.gd` → regenerated `GameUITheme.tres`): `AttrRow` is shared by both screens. Status's
  `AttrIcon` is renamed `IconSlot` and is also used for Equipment's 40 px slot icon. `AvatarChip` and `AccentDot` are new.
- `verify_equipment` [6b]: "Max. SP has no delta" now checks that `Delta` is hidden, not that the row has 2 children. There are
  new checks for 12 slot rows + 10 attribute rows and that the rows carry theme variations without stylebox overrides.
  `RESULT: ALL PASS`. `verify_equip_picker`: `RESULT: ALL PASS`.
- Shot: `design/shots/ui_fixes_menu_equipment_after.png`. It matches the before shot except a 25×22 px area, which is
  the Equipment panel's playtime clock (00:00:30 → 00:00:17).

**Not a bug (no B-ID).** In both menu shots the sidebar highlights Misc while Status or Equipment is shown, both before
and after. The capture starts a new game, where those tabs are still story-locked (`game_menu.gd:43` `_lock_tabs` opens
the menu on Misc). The script then forces the tab with `switch_to_tab()`. A player cannot reach this state.

## 3. What is left in #50 (Slices 2+)

These are rough counts of `*.new()` calls in each script. A node built in a loop counts once.

| Order | Screen | Code-built today | Note |
|---|---|---|---|
| 5 | `skills_component` | 8 `X.new()` calls, 1 stylebox | next slice |
| 6 | `options_component` | 16 calls, 1 stylebox | **not touched**: `cloud/settings-1` edits Settings in parallel; do it after that merges |
| 7 | `inventory_component` | 1 call | small |
| 7 | `bottom_bar` (`UI/Components/bottom_bar.gd`) | 4 calls, 1 stylebox | small |

Done: party_status_panel (D127), journal, **stats (slice 3)**, **equipment (slice 4)**.
The plan's table in `design/game_menu_single_scene_plan.md` should mark orders 3 and 4 ✅ (orchestrator).

## 4. For the orchestrator
- `design/BUGS.md`: remove the B112 row.
- `design/figma_decision_register.md`: add the D-ID text above.
- `GameUITheme.tres` was regenerated twice. The diff is large because the sub-resource ids were renumbered. If it conflicts
  at merge, regenerate it from the merged `build_game_ui_theme.gd`; never merge it by hand.
