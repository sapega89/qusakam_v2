---
type: cloud-report
branch: cloud/weapon-gamepad
date: 2026-10-21
tags: [cloud, combat, animation, gamepad]
---

# Cloud report: weapon-gamepad (BACKLOG 42 sword + BACKLOG 24 gamepad parity)

Start: `origin/cloud/integration`, then `origin/feature/backlog` merged in (it brought art A3, the sword frames, in
`SampleProject/Sprites/Player/Weapons/sword/`). Godot 4.6.2 ran headless on Linux. There is no window, so there are no
captures. The Figma MCP was not available. The bottom-bar badge change follows Figma's own `UI/Bottom Bar` variants
`input=gamepad / input=keyboard` (121:1073).

## Task A: BACKLOG 42, Kusakam holding the sword

The plan is [[hero_weapon_animation_plan]] (new). It records the decision, the animation set per weapon type, how the
switch works, and the slices: sword ✅ → palette swap → dagger → mace → halberd → dual-wield → bare hands.

The sword frames exist (25 frames, 96×96), so they are wired in:

- `SampleProject/Player.tscn`:
  - New `AnimationLibrary_sword` (`:1147`), mounted as `libraries/sword` (`:1232`), with `Idle` (CombatIdle 1–4), `Run`
    (7 frames, 0.8 s), `Jump`/`Apex`/`Fall` (Air 1/2/3), `Land`, `Attack1–3`, `HeavyWindup`, `HeavyStrike`, `Block` and
    `Hurt`.
  - Every sword animation also keys `Sprite2D:offset` (0, −16), because the 64×64 body sits at (16, 32) in the 96×96
    cell. Every base animation keys it back to (0, 0).
- `Scripts/Player.gd`:
  - `body_animation()` (`:236`) resolves a base name to `<library>/<name>`, and `Attack` to `<library>/Attack<step+1>`.
  - `play_body()` (`:246`) is now the single entry point for hero body animations.
  - `_physics_process` (`:146`) replays the current animation from the new library when the weapon is drawn, sheathed
    or switched.
- `Scripts/Player/Components/PlayerCombat.gd`: the swing (`:264`) and `_play` (`:322`, used by heavy, block, hurt and
  cast) go through `play_body`.
- `Scripts/Player/Components/WeaponView.gd`:
  - `body_library()` (`:117`) returns the category name when the weapon in hand has frames, its grip is `one_handed`
    and it is drawn (in combat or mid-swing).
  - `_drawn_in_frame()` (`:125`) hides the overlay sprite while those frames play.
  - Out of combat the base frames play and the weapon stays hidden (D268 unchanged). Swing smears stay.
- `UI/verify_souls_combat.gd`:
  - [11] and [12] are updated for the sword frames.
  - New **[12c]** (`:633`) checks:
    - combat idle uses the sword frames with the overlay hidden and the 96×96 offset;
    - `Attack1–3` match the base swing (0.3 s = `swing_time`, strike key at 0.05 s);
    - the combo plays `Attack1–3`, with the hitbox **on and no overlay at each strike frame**;
    - the hitbox is off afterwards;
    - heavy plays from the sword frames, and the wind-up length equals `heavy_windup`;
    - out of combat the base frames return, the offset goes back and the sword is hidden.

## Task B: BACKLOG 24, gamepad parity

**Audit.** I checked every action in `project.godot [input]`, every action that code registers (`CombatInput`,
`SkillScreenInput`, `dialogue_quest_inputs`), and every action the code reacts to. Each one already had a pad event.
Built-in `ui_page_up`, `ui_page_down` and `ui_paste` have none, but no game screen uses them. The gaps were in focus
and hints, and these were fixed:

- `Scripts/UI/focus_router.gd` (Game Menu):
  - Pad buttons are now handled, not only keys. Before, B in a tab's content closed the whole menu.
  - The router follows the real focus. D-pad or arrow moves into content now count as "in content". A click does not,
    so Esc after a mouse click still closes the menu as before.
  - A/Enter on another tab switches to it. Before, it jumped into the old tab's content.
  - A view-only tab (Status) keeps focus on the tab.
  - Hidden panels are skipped when the router looks for the first focusable.
- `Scripts/Menus/Game/metsys_map_component.gd` + `.tscn` (`focus_mode = 2`): the World Map pans only while it has
  focus (`_gui_input`). Before, its `_input` ate the arrows and D-pad whenever the map was visible, so you could not
  leave the World Map tab with a pad or keyboard.
- `Scripts/Menus/Game/game_menu.gd`: `_update_pointer` and `switch_to_tab` no longer search the typed button array
  for a non-button focus owner (the map). That search raised an engine error.
- Main menu (`Scripts/Menus/MainMenu.gd`): B (`ui_cancel`) opens the quit dialog. Before, only raw `KEY_ESCAPE` did.
  Settings opened from the main menu now take focus (`options_component.focus_current_tab`).
- Settings (`Scripts/Menus/Game/options_component.gd`):
  - D-pad right from a sidebar tab enters the first row (`_link_sidebar_to_list`). Before, it went to Restore.
  - Display Mode, VSync, Language, Tutorial Windows and Restore keep focus when their row rebuilds. Rows and cells
    have stable names.
- Forge (`Scripts/Crafting/crafting_ui.gd`): the category buttons are focusable. D-pad left from the rows reaches
  them, and A picks one.
- Dialogue choices (`addons/dialogue_quest/.../choice_menu.gd`): the first answer takes focus when the menu shows.
  No `.dqd` uses choices yet.
- Demo end (`Scripts/UI/DemoEndScreen.gd`): the Return button takes focus.
- Hints and badges follow the last device:
  - `Scripts/Core/InputDeviceWatcher.gd` (new, created by `GameManager._initialize`) sees all input.
  - `InputGlyphs.note_event` emits the new `EventBus.input_device_changed`.
  - New `InputGlyphs.badge()`.
  - `UI/Components/bottom_bar.gd`: `set_actions` takes `{action, label}` and redraws on a device change. The callers
    (Game Menu default, Load/Save, Shop, Forge, Enchanting, Tutorial) name actions instead of fixed pad letters.
  - `UI/Components/skill_hotbar.gd`: the skill slot, weapon and assist badges show `1`/`RT`, `Q`/`D-pad` and `F`/`LT`.
  - Skills and Equipment bottom hints are refreshed on a device change.
  - The Game Over footer key reads `ENTER`/`A`.
- New **`UI/verify_gamepad_parity.gd`**:
  - [0] every action has a pad event; the code is scanned too.
  - [1] main menu → Settings (Display/VSync, Game/Language) → back → quit dialog, pad only.
  - [2] Game Menu with every tab unlocked:
    - each tab is reached with D-pad + A;
    - D-pad right goes into the content, and B goes back while the menu stays open;
    - Misc opens with focus, and B returns to the Misc tab;
    - the bottom bar and hotbar badges switch between pad and keyboard.
  - [3] Forge: RB switches the station, D-pad + A picks a category, the badge reads `LB/RB`.
  - [4] Choice menu.
  - [5] Game Over.
  - [6] Demo end.

Already driven by the pad elsewhere, so not repeated here:
- inventory: verify_use_item
- equipment picker: verify_equip_picker
- Skills Accept (Y): verify_skill_screen / verify_skill_trees_ui / verify_attributes
- journal: verify_journal_sections
- shop: verify_shop
- oath keepers: verify_oath
- chests: verify_chests / verify_gift_popup
- tutorial windows: verify_tutorial_hints
- Controls page: verify_onboarding
- cutscene skip: verify_cutscene
- dialogue A: verify_gamepad

`UI/verify_world_map.gd` [5] now pans through `_gui_input` with the map focused.

## Decisions (agent calls, Sapega to confirm)

**D370 to D374 and B100 to B104 were picked clear of the other overnight branches. Integrator: renumber them if
these IDs are taken.**

| D-ID | Decision |
|---|---|
| D370 | Weapon frames are baked per weapon TYPE. Each type is an `AnimationLibrary` on the hero named after the items.json `category`, with the weapon drawn in the frame and the overlay hidden while those frames play. A type without frames keeps the D268 overlay for all its animations. Item variants get a palette swap, not frames (BACKLOG 42, 2026-10-22). Agent call, Sapega to confirm. |
| D371 | Sword mapping:<br>• `Attack1–3` follow the combo step, with the base swing's length and key times (wind-up 0, strike 0.05, follow-through 0.13, stance 0.21), so hitbox timings are unchanged.<br>• `Land` is CombatIdle/1.<br>• Roll, Climb and casts stay on the base frames.<br>• Dual-wield keeps the overlay until `dual_sword` frames exist.<br>Agent call, Sapega to confirm. |
| D372 | Bottom-bar badges name the button of the last device (Figma's input=gamepad / input=keyboard variants, 121:1073). The Game Menu's "Select" badge reads **LS / Arrows**, not Figma's "LB": LB does nothing there. Agent call, Sapega to confirm. |
| D373 | The World Map pans only while it has focus. You enter it with D-pad → or A from its tab, and leave with B / Esc. Agent call, Sapega to confirm. |
| D374 | Game Menu routing:<br>• A or Enter on another tab switches to it; on the active tab it enters the content.<br>• Esc or B returns from content to the tabs when you got there by keys or pad. After a mouse click, Esc closes the menu as before.<br>• Forge categories are reached by D-pad ← from the rows, because LB/RB already switch stations.<br>Agent call, Sapega to confirm. |

## Bugs found and fixed (for BUGS.md)

| B-ID | Bug | Fix |
|---|---|---|
| B100 | Game Menu, pad: B in a tab's content closed the whole menu. FocusRouter handled only `InputEventKey`. A/Enter on a non-active tab jumped into the old tab's content and never switched (keyboard too). | `focus_router.gd` |
| B101 | World Map tab: its `_input` ate every arrow and D-pad press while visible, so the player could not move to another tab. `_update_pointer` raised a typed-array error when focus was on the map. | `metsys_map_component.gd/.tscn`, `game_menu.gd` |
| B102 | Main menu, pad: B did nothing (raw `KEY_ESCAPE`). Settings opened without focus. D-pad right from a sidebar tab went to Restore. Display Mode, VSync, Language, Tutorial Windows and Restore dropped focus when their row rebuilt. | `MainMenu.gd`, `options_component.gd` |
| B103 | Without a mouse, Forge categories could not be reached (`FOCUS_NONE`). Dialogue choices and the Demo end screen had no focus. | `crafting_ui.gd`, `choice_menu.gd`, `DemoEndScreen.gd` |
| B104 | Bottom-bar badges were fixed pad letters on every device ("LB Select" even with a keyboard). Hotbar badges showed keys only. The Game Over keycap was fixed to "ENTER". | `bottom_bar.gd` + callers, `skill_hotbar.gd`, `game_over_screen.gd`, `input_glyphs.gd`, `InputDeviceWatcher.gd` |

## Verifies

- `verify_souls_combat`: RESULT: ALL PASS (with [12c])
- `verify_gamepad_parity`: RESULT: ALL PASS
- `verify_skill_casts`, `combat_flow`, `chests`, `gamepad`, `onboarding`, `scripts_compile`: RESULT: ALL PASS
- `verify_game_menu`, `main_menu`, `settings`, `settings_graphics`, `map_geometry`, `misc_modal`, `misc_destinations`,
  `journal_sections`, `hotbar`, `combat_hud`, `game_over`, `demo_end`, `crafting`, `shop`, `enchanting`,
  `tutorial_hints`, `equip_picker`, `equipment`, `skill_screen`: RESULT: ALL PASS

**Full suite (`Scripts/Tools/run_verify.sh`):** FULL_SUITE_RESULT

## Left

- Weapon art for dagger, mace, halberd, dual-wield and the bare-hands stance (laptop, comfy-sprite). Then add each
  library per the plan.
- Palette-swap shader for item variants (BACKLOG 42 slice 2). Needs the A3 blade key colours measured.
- No captures (headless). Sapega should look at:
  - the sword frames in a fight (offset, how the run reads);
  - the badges in the Game Menu, Shop and Forge with a pad and with a keyboard.
- Small leftovers:
  - `interaction_prompt.gd` keeps its own device flag and fixed E/Y textures, so remaps are not shown.
  - Prologue "Press any key to continue..." (any pad button works).
  - The inventory tooltip says "Double-click or Enter" (tooltip only).
  - Game Menu top-level tabs have no LB/RB, because LB/RB switch sections inside Journal, Skills and Tutorial.
