---
type: plan
status: planned
---

# Gamepad — plan

**Slice 1 built 2026-10-18 (D211)** — the hero moves, jumps, attacks on a pad; A / B in menus and modals; Start opens the Game Menu. Was: menus half-work, gameplay does not (2026-10-14). Found while building D155
(NPC menu: arrows / D-pad only, sticks stay on the hero).
Figma: no gamepad layout exists; `UI/Bottom Bar` `121:1073` has an `input=gamepad` variant
([[ui_navigation_map]]). Related: D37, D48, D98, D155, **D156** (layout), **D157** (mouse), Q30.

## What exists today

| Thing | Where | State |
|---|---|---|
| `interact` on pad A (button 0) | `project.godot` `[input]` | ✅ |
| `save_delete` on Y (3), `menu_prev_tab` / `menu_next_tab` on LB / RB (9 / 10) | `project.godot` `[input]` | ✅ |
| `ui_up/down/left/right` on D-pad + left stick | Godot defaults (no override) | ✅ menus can be walked |
| `ui_accept`, `ui_cancel` | Godot defaults — keys only (probed `InputMap.action_get_events`) | ❌ no pad button confirms or backs out of any menu |
| `move_left`, `move_right`, `move_up`, `move_down`, `jump`, `attack`, `skill_slot_1..4` | `project.godot` `[input]` | ❌ **no joypad events** — the hero cannot move, jump or attack on a pad |
| Stick read for movement | `Scripts/Player/Components/PlayerMover.gd:110-113` | ⚠️ `get_axis("move_left","move_right")` — dead until those actions get axis events |
| Last-used-device switch | `UI/Components/interaction_prompt.gd:23,54-66` | ✅ D98, but private to the prompt (static on that class) |
| NPC menu pad rules | `UI/Components/npc_action_menu.gd` | ✅ D155: D-pad rows, A picks, stick swallowed |
| Bottom-bar hints | 6 `set_actions` callers, e.g. `Scripts/Menus/LoadGameMenu.gd` `_apply_mode` | ⚠️ always gamepad glyphs (`A Confirm`, `B Back`) — Q30 |
| Controls / rebinding screen | maaacks widget in Settings | ⚠️ D48 open: keep or own |
| `Scripts/Test/ControllerTest.gd` (158 lines) + `Scenes/Test/ControllerTest.tscn` | debug scene | ⚠️ not referenced by the game |

## Mouse — Sapega, 2026-10-14

"Миші мені не хотілось би зовсім у грі, або тільки якщо попередньо натиснув якийсь Ctrl."
Today: `attack` is **left mouse button** (`project.godot`), 6 UI scripts focus on hover
(`mouse_entered.connect(...grab_focus)`), nothing sets `Input.mouse_mode`. Turning the mouse off
→ answered as D157: attack stays on LMB, cursor hidden, Ctrl toggles; Game Menu always has the mouse.

## Missing entirely

- Pad events on every gameplay action (`grep -n joypad project.godot` → only the four above).
- A pad button on `ui_accept` / `ui_cancel`, so Shop, Crafting, Save/Load, Game Over, modals work.
- A pad button that opens the Game Menu (today Esc only).
- One shared "last device" source; the prompt keeps its own (`interaction_prompt.gd:23`).
- A `verify_gamepad.gd`.

## Decisions required

1. ✅ **Button layout — answered: D156.** Was Q46. Jump, attack,
   interact, back, menu, 4 skills. Conflict to settle: `interact` is already A, and A is the
   usual jump. Recommendation (Xbox names): A jump · X attack · B back/cancel · Y interact in
   the world (save_delete stays Y inside Save/Load only) · Start Game Menu · LB/RB tabs (as now) ·
   skills on LT / RT / LB+RB? — undecided, see 3.
2. ✅ **D-pad outside menus — settled by D202 / D211:** D-pad ←→ switch the weapon in hand, ↑↓ move up/down; the stick runs. Was: moves the hero like the stick, or does nothing? D155 only says
   the D-pad drives menus and the stick drives the hero *while the NPC menu is open*.
   Recommendation: D-pad also moves the hero (2D platformer convention). Non-blocking.
2b. ✅ **Mouse — answered: D157.** Ctrl toggles; cursor hidden otherwise; attack stays on LMB.
   **Technical point for slice 1b:** a hidden cursor still clicks GUI. LMB-attack must not press a
   HUD/menu button under the invisible pointer — with the mouse off, mouse events must skip the GUI
   but still reach `Player._unhandled_input` (attack). Check this first; it decides the approach.
3. **Four skill slots on a pad** — D37 left them undesigned. Blocks slice 3 only.
4. **Bottom-bar glyphs follow the last device** (Q30, default "leave as-is"). Blocks slice 4 only.

## Slices

### Slice 1 — gameplay on a pad — ✅ built 2026-10-18 (D211, `verify_gamepad.gd`)
- `project.godot`, per D156: left stick + D-pad on `move_*`; A `jump`; X `attack`; Y `interact`
  (off A); A `ui_accept`, B `ui_cancel` (overriding a `ui_*` action replaces Godot's defaults —
  re-list the keys); Start opens the Game Menu.
- `UIManager` / wherever Esc opens the Game Menu: also the new menu action.
- `SampleProject/UI/verify_gamepad.gd`: every gameplay action has a joypad event; synthetic
  `InputEventJoypadButton` presses reach jump / attack / interact; A confirms and B backs out of
  one modal.
- Commit: "Gamepad: the hero moves, jumps and attacks; menus confirm and go back".

### Slice 1b — mouse off (D157)
- Cursor hidden by default; a `toggle_mouse` action on **Alt** flips it (D157 → D417: Ctrl is block since D270). Opening the Game
  Menu shows the cursor regardless; closing it restores the Ctrl state. With the mouse off,
  GUI ignores mouse events (hover focus in the 6 UI scripts included) while LMB still attacks.
- `verify_gamepad.gd`: Ctrl toggles; with the mouse off a click does not press a Button.

### Slice 2 — one device source
- Move `_using_gamepad` out of `interaction_prompt.gd` into a small autoload-free static
  (`InputDevice.gd`) both the prompt and the bottom bar read. Prompt behaviour unchanged (D98).
- Extend `verify_interaction.gd` rather than a new test.

### Slice 3 — skills on a pad (after D37 / decision 3)
### Slice 4 — bottom-bar glyphs by device (after Q30)
### Slice 5 — Controls screen shows pad binds (after D48)

## Order and dependencies

`1 → 2 → 4`; 3 and 5 hang off their own decisions and can go in any order after 1.

## Out of scope for this pass

- Rebinding UI — D48.
- Rumble, per-pad glyph sets (PlayStation vs Xbox), multiple pads.
