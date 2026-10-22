---
type: report
branch: cloud/ui-bugs
base: feature/backlog @ 14ca889c
date: 2026-10-22
---

# cloud/ui-bugs: the open UI bugs (round 6)

Eight rows from [[BUGS]]: B95, B96, B19, B22, B90, B14, B10, B8. Every row was re-checked first, in code and on
screen (xvfb, 1920×1080, Godot 4.6.2 Linux). **All eight were still true**, but three only in part (B8, B19,
B10). The details are under each bug. Every one is fixed with a test, plus a capture where only a picture can
prove it. Captures come from `SampleProject/UI/capture_ui_bugs.gd -- <before|after>` and land in
`design/shots/ui_bugs_<frame>_<before|after>.png`.

**For the orchestrator:** delete rows B95, B96, B19, B22, B90, B14, B10 and B8 from [[BUGS]], add the D-IDs below to
[[figma_decision_register]] (numbers are yours to assign), and file the new bug **B-new-1** found on the way. Remove
the D193 / #98 line ("Controls mixes keyboard and pad") from [[BACKLOG]] → Settings and mark Slice 2 of
[[settings_plan]] built.

**`GameUITheme.tres` is not committed.** The owner must regenerate it
(`godot --headless --path . --script res://SampleProject/UI/build_game_ui_theme.gd`). Until then B8, B22, B90 and
the Controls device tabs' frame do not show in the game, and `verify_game_ui_theme` fails on its new B8/B22/B90
checks. With a locally regenerated theme, `verify_game_ui_theme` is **ALL CHECKS PASSED**, including the old [3c].

## Commits

| Commit | What |
|---|---|
| `914c85c5` | B95 |
| `8a7d4019` | B96 |
| `b3b36373` | B10 |
| `4dc9b5ed` | B14 |
| `657cd2f7` | B8, B22, B90 (shared token/theme files) |
| `04c2ee54` | B19 (= D193, Settings Slice 2) |
| `c2aa9ca6` | `capture_ui_bugs.gd` + shots |

---

## B95: Enter after a mouse click in the Game Menu does not press the focused button

- **Still true:** yes. With `verify_locale` [2]'s `focus_content()` workaround removed, "keyboard Enter on English"
  failed: after a click the router stays in `"Tabs"` (D348), and the Enter press became `focus_content()`.
- **Fix (the row's own):** `SampleProject/Scripts/UI/focus_router.gd:136-141`. In `"Tabs"` mode, `ui_accept` passes
  through when the focus owner is already inside `panels_container_path`. Esc after a click still closes the menu (D348
  untouched).
- **Test:** `verify_locale.gd:578-584` drops the workaround, checks that the router is still in `Tabs` after the click
  and that Enter on the focused cell switches the language. It fails without the fix (`RESULT: 3 FAIL`) and passes with
  it. `verify_game_menu`, `verify_gamepad_parity` and `verify_pause` are green.
- **D-ID:** none. The row named the fix.

## B96: Settings → Controls lists action ids as names

- **Still true:** yes. The rows read `Dq Accept`, `Save Delete`, `Menu Prev Tab`, `Skills Unpick`, `Weapon Prev`,
  `Cutscene Skip`… (`String.capitalize()` of the id).
- **Fix:** `SampleProject/Scenes/Menus/Game/input_options_menu.tscn:72-73` gives the maaacks list an explicit
  `input_action_names` / `readable_action_names` pair for all 25 bound actions (it is set after `capitalize_action_names`,
  whose setter would otherwise overwrite it). `uk.po` drops the capitalised keys for the new ones and `en.po` is regenerated
  with `po_sync.py`; `Delete Save` reuses the Save screen's key.
- **Test:** `verify_settings.gd:273-292`. Every bound action has a name in the scene, every name is in `uk.po`, and the rows
  read `Next Dialogue Line`, not `Dq Accept`.
- **D-new (B96):** *Settings → Controls action names* (agent call, Sapega to confirm): Move Up / Down / Left / Right,
  Interact, **Next Dialogue Line** (Діалог: далі), Game Menu, Jump, Attack, Dodge, **Next Weapon** / **Previous Weapon**,
  **Call Companion** (Покликати супутника), **Delete Save**, **Previous / Next Menu Tab**, Skill Slot 1–4, Heavy Attack,
  Block, **Skip Cutscene** (Пропустити катсцену), **Skills: Accept Picks** (Навички: прийняти вибір), **Skills: Undo
  Pick** (Навички: зняти позначку). The same order as before.

## B19: the Attack row puts gamepad bindings in the keyboard columns, with two naming schemes

- **Still true:** **in part.** The two naming schemes are gone: there is no `Button #0` any more, and every pad button
  goes through the addon's `JOY_BUTTON_NAMES` (`Button X`). The columns were still mixed, in almost every row and not
  just Attack: Attack = `Left Mouse Button | Button X | –`, Previous Weapon = `Dpad Left | Z`, Interact = `E | Button Y`.
  The cause is that the addon fills Primary / Secondary / Tertiary by InputMap index, whatever the device. Pad events
  past the third (`Dpad Up`) were not shown at all. Before: `ui_bugs_settings_controls_before.png` (already with the
  B96 names).
- **Fix = D193** (Sapega 2026-10-16: keyboard & mouse and gamepad are two separate tabs; [[settings_plan]] Slice 2,
  #98). It is built over the maaacks widget without editing the addon:
  - `SampleProject/Scripts/Menus/Game/device_actions_list.gd` (extends the addon's `input_actions_list.gd`, set on
    `%InputActionsList`):
    - Rows show only the open tab's device; an action without a binding on that device shows empty cells, ready to
      assign.
    - A rebind replaces or adds only that device's slot and keeps the other device's events. Keyboard and mouse events
      come first in InputMap, pad events last.
    - `reset()` restores the defaults of that device only.
    - The list rebuilds on a language change: the engine translates mouse names ("ЛКМ"), and the cells used to keep
      the old language.
    - The name column takes the longest name, because the long B96 names and the Ukrainian ones shifted their row's
      cells.
  - `device_key_assignment_window.gd` (extends the addon window, set on `KeyAssignmentWindow`): the Assign window
    records only the tab's device: keys and mouse buttons, or pad buttons and axes.
  - `device_input_options_menu.gd` (replaces the root script, extends the addon's): the tab switch.
    `input_options_menu.tscn:42-65` adds the `DeviceRow` with `%KeyboardTab` / `%GamepadTab` (the Settings segment
    look). New keys `Keyboard & Mouse` = Клавіатура й миша, `Gamepad` = Геймпад.
  - Theme: `build_game_ui_theme.gd:299` adds a `SettingsSegmentFrame` variation. `options_component.gd:247` uses it
    instead of building the frame's StyleBoxFlat in code.
- **Test:** `verify_settings.gd` [21] (`_device_tabs`) checks:
  - both tabs are shown and the keyboard tab lists no pad event;
  - B19: Attack is the left mouse button only on the keyboard tab and `Button X` only on the gamepad tab; Move Up on the
    pad tab is `Left Stick Up | Dpad Up`;
  - the Assign window takes keys and mouse buttons on the keyboard tab and only the pad on the gamepad tab;
  - a keyboard rebind fills the keyboard slot; a pad rebind replaces the pad button and keeps the keyboard binding;
  - pad Reset keeps the keyboard rebind; keyboard Reset restores the keyboard tab;
  - every row's first cell is at one x (checked in Ukrainian).

  The test saves and restores InputMap and `user://player_config.cfg`. Captures: `ui_bugs_settings_controls_after.png`
  and `ui_bugs_settings_controls_pad_after.png`.
- **D-new (B19, D193 as built):** *Controls device tabs* (agent call on D193, Sapega to confirm):
  - A segment switch **Keyboard & Mouse | Gamepad** sits under "Actions & Inputs". Keyboard & Mouse is open by default.
  - Each tab lists every bound action with three slots of its own device.
  - Rebinding listens to that device only; mouse buttons are accepted on the keyboard tab.
  - Reset restores that tab only.
  - In InputMap, keyboard and mouse events come before pad events.
  - The names column is as wide as the longest name.
  - The Controls page in Misc (D-28f) is unchanged.

## B22: Settings → Audio volume steppers have no control chrome

- **Still true:** yes. Bare `−` / `+` glyphs (`ui_bugs_settings_audio_before.png`). The theme builder cites Figma
  17:546 / 17:549 for the arrows as "16px, no background", so B22 asks for a deviation from Figma.
- **Fix:** `SettingsStepper` (`build_game_ui_theme.gd:325`) gets a 1px `BORDER` box: hover and pressed use
  `BORDER_STRONG` + `SURFACE_HOVER`, disabled uses a `TEXT_DISABLED` border, and focus stays the D329 ring. A new
  token `UITokens.SETTINGS_STEPPER_BOX := 32` (`UITokens.gd:163`) is the square size, which
  `options_component.gd:297,332,349` sets on `−`/`+` and on the `‹`/`›` stepper arrows (Resolution, Frame Rate Limit).
- **Test:** `verify_game_ui_theme.gd:71-74` (1px BORDER frame) and `verify_settings.gd:186-190` (`Minus`/`Plus` are
  ≥ 32×32 `SettingsStepper`). Capture: `ui_bugs_settings_audio_after.png`.
- **D-new (B22):** *Settings stepper buttons are framed* (agent call, Sapega to confirm; deviates from Figma 17:546 /
  17:549, which have no background): `−`/`+` and `‹`/`›` are 32×32 boxes with a 1px border, like the segment control,
  Reset and the footer buttons, so they read as buttons.

## B90: a pressed (selected) ListRow shows no focus ring (D329)

- **Still true:** yes, and worst in the Journal, where the focused row is always the selected one
  (`journal_component.gd` `_on_row_focused` presses it), so the cursor was never visible there
  (`ui_bugs_journal_focus_before.png`).
- **Fix:** the `focus` stylebox cannot know the pressed state, so:
  - `ListRow` gets a second theme stylebox, `focus_selected` = the white on-accent ring (D329's rule for accent-filled
    controls), at `build_game_ui_theme.gd:416`. `ListSubRow` inherits it.
  - A new `SampleProject/UI/Components/list_row.gd` (extends Button, no class_name) draws it in `_draw()` when the row is
    both focused and pressed. Rows that use it:
    - `UIItemRow` (`item_row.gd:1`, now extends `list_row.gd`), i.e. inventory and equip-picker rows;
    - the Journal `%EntryRow`;
    - the Tutorial `%TopicRow`.
  - Equipment slot rows and Controls-page rows are not toggle buttons, so they never show this state.
- **Test:** `verify_game_ui_theme.gd:75-82` (the ring, inherited by ListSubRow) and `verify_journal.gd:189-190` (rows run
  `list_row.gd`). Capture: `ui_bugs_journal_focus_after.png` (white ring on the selected "Canyon I").
- **D-new (B90):** *Cursor on a selected list row* (agent call, Sapega to confirm; completes D329): a selected (gold)
  list row under the cursor shows the white 2px ring; an unselected one keeps the gold ring.

## B14: the Game Over text is unreadable over the stone-wall art

- **Still true:** yes (`ui_bugs_game_over_before.png`). "Khalahas Heroes" was invisible, and "Game Over" collided with
  the door bars.
- **Fix:** a full-screen `Scrim` ColorRect between the art (+ vignette) and the text
  (`game_over_screen.tscn:43`), coloured `UITokens.OVERLAY` in `game_over_screen.gd:57`. That is the same token as the
  modal `Blocker` and the menu dim. The frame, corners and text stay on top.
- **Test:** `verify_game_over.gd:72-75` (OVERLAY colour; z-order after the vignette and before `Center`). Capture:
  `ui_bugs_game_over_after.png`. The title now reads cleanly. The eyebrow is visible but still faint: it is 14px
  `GAME_OVER_FRAME` `#5c5655`, the Figma colour, which I did not change.
- **D-new (B14):** *Game Over scrim* (agent call, Sapega to confirm): the stone-wall art sits under the shared
  `OVERLAY` (#000 @ 56%) scrim, like every modal. If the "Khalahas Heroes" eyebrow is still too faint for Sapega, that
  is a colour call on `GAME_OVER_FRAME` (a Q-ID, not filed).

## B10: a stray orange `!` glyph inside the dialogue box

- **Still true:** yes (`ui_bugs_dialogue_before.png`, the old man's line typed out). The glyph is the dialogue_quest
  addon's **text-finished marker** (`addons/dialogue_quest/art/quest_marker.png` in `%BobbingMarker`). The addon shows
  it once a line is fully typed (`dialogue_box.gd` `_on_all_text_shown`), so it was never in a resting screenshot.
- **Fix:** `SampleProject/Resources/Dialogue/dialogue_box_settings.tres` sets `text_finished_marker_enabled = false`,
  following the D319 pattern for Auto/Skip.
- **Test:** `verify_npc_recall.gd:132-135` checks the marker stays hidden after `finish()`. It fails without the fix
  (`RESULT: 1 FAIL`). Capture: `ui_bugs_dialogue_after.png`.
- **D-new (B10):** *No "line finished" marker in the dialogue box* (agent call, Sapega to confirm; Figma
  npc-dialog-simple 36:6 has none): the next press continues as before (D254 slow text). With D319, the box has none of
  the addon's own chrome left.

## B8: menu surfaces are transparent; the parchment map bleeds through (systemic)

- **Still true:** **in part.**
  - **No longer true:** the Overwrite Save modal is opaque since D195 (`ModalPanel` = BACKGROUND);
    `ui_bugs_save_overwrite_after.png` shows no map. The Skills tab is no longer surface-less: it has `TreePanel`s.
  - **Still true:** `SURFACE` @56% over the dimmed map. The parchment labels ran through the Inventory content
    ("No items in this category." over "Oasis of Qadira"), the Skills tree / detail / attribute panels, the sidebar
    and all four Save slot cards, which had no fill at all. See `ui_bugs_menu_inventory_before.png`,
    `ui_bugs_menu_skills_before.png` and `ui_bugs_save_before.png`.
- **Fix:**
  - A new token **`UITokens.MENU_SURFACE := BACKGROUND`** (opaque, `UITokens.gd:17-21`). It is used for the menu panels
    that carry text: `CenterPanel`, `SidePanel`, `CardPanel`, `BoxPanel`, `ActionCard`, `TreePanel`
    (`build_game_ui_theme.gd:590-639`), and as the fill of `SaveSlotCard` (`:908-914`).
  - `SHOP_PANEL_BG` is opaque too (`UITokens.gd:239`).
  - The map stays visible in the gutters between panels, which is the intended parchment (`menu_shell.gd`). The HUD's
    default `PanelContainer` (`SURFACE`) is untouched.
- **Test:** `verify_game_ui_theme.gd:63-70` (each panel opaque `MENU_SURFACE`, save cards, ShopPanel). Captures:
  `ui_bugs_menu_inventory_after.png`, `ui_bugs_menu_skills_after.png`, `ui_bugs_save_after.png`. The Shop was checked by
  the theme test only, not captured (`capture_shop.gd` would overwrite committed shots).
- **D-new (B8):** *Opaque menu surfaces* (agent call, Sapega to confirm; deviates from Figma `color/surface` @56% on
  panels and from the save card's "no fill"): panels holding text in the Game Menu, the Save/Load slot cards and the Shop
  panels are opaque `#111118` (`MENU_SURFACE`), like the modals (D195) and the Settings page. The parchment map shows
  only between panels. Buttons and rows keep the 56% / 30% surface.

---

## New bug found (for [[BUGS]])

### B-new-1: the speaker's name is drawn over the first line of the dialogue text
- **Where:** `SampleProject/Scenes/UI/dialogue_box.tscn` (`NameMargin` overlay on the `DialogueBox` root).
- **Evidence:** `design/shots/ui_bugs_dialogue_before.png` / `_after.png`: "Grandfather" sits across "…took our relic.
  It's the key…".
- **Expected:** the name centred above the text (D321).
- **Got:** D321 placed the name as an overlay over the Auto/Skip row. D319 then hid both buttons, `RowTop` collapsed
  to 0px, and the text moved up under the name.
- **Fix (proposed, not done):** move `NameMargin` into `Margin/Rows` as the first row (hidden when the name is empty,
  so narration has no blank line), and update `verify_dialogue_speaker` [4], which looks it up at `box/NameMargin`.
- **Severity:** visual (every named dialogue line).
- **Found:** 2026-10-22, `cloud/ui-bugs`.

## Notes

- `capture_ui_bugs.gd` takes `-- <tag> [dialogue]`. Slots go to `user://capture_ui_bugs/`, never the real saves.
- `verify_settings` [21] rewrites `user://player_config.cfg` while it rebinds, then puts the original bytes back (or
  deletes the file if there was none) and restores InputMap.
- In a headless run, the Controls checks print "Not supported by this display server" (keycode lookups). This is
  baseline noise, known issue 5.

## Results

_Full suite still running when this draft was pushed; results follow in the next commit._
