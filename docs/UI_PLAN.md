# UI Plan (AAA Indie) - Planning Only

Status: Planning only. No implementation yet.

## Goals
- Production-quality UI for Godot 4.5.1.
- Vertical tab layout as the primary pattern (based on Inventory UI).
- Modal system with consistent behavior and visuals.
- All nodes created via scenes/components; scripts contain logic only.
- Stable, readable UI under window resize and resolution changes.

## Decisions (Locked)
- UI state machine uses addons/fsm/FiniteStateMachine.gd.
- UI FSM lives in a dedicated UIRoot/UIManager (AAA pattern).
- Settings source of truth: SaveSystem + SettingsModule only.
- Store settings inside MetSys slot save (`slot_XX.sav`) under key `game_settings`.
- Remove `game_settings.json` immediately (no fallback).
- Save slots: 4 slots, `slot_01.sav` .. `slot_04.sav`.
- last_slot and save metadata live in `user://saves/profile.json`.
- Languages: uk + en, default uk.
- UI states are recreated on entry (no persistence between transitions).
- Modals are single active (no stack/queue).
- One shared UI theme resource for all UI scenes.

## Architecture Overview
### UIRoot / UIManager
- CanvasLayer for UI
- FiniteStateMachine child
- ModalLayer child (overlay, input lock)

### UI States (FSM)
- MainMenuState
- GameMenuState
- OptionsState
- LoadGameState
- SaveGameState
- ModalState (single active modal controller)

Each state is a scene-based node with a logic script.

## Input Priority (Fixed)
- Modal is always top-most and blocks input to layers below.
- Dialogue (if present) blocks gameplay and may optionally allow Pause.
- GameMenu/Options block gameplay.
- Gameplay input is active only when UI stack is empty.
- Only the top-most active UI layer receives UI input.

## UI Stack / Return Policy
- FSM remains the primary screen model.
- Nested flows use `return_state` + `return_payload` as a standard.
- Any child screen must define where it returns and with what payload.

## Screen vs FocusMode
- `ScreenState`: e.g., `OptionsState`.
- `FocusMode`: `Tabs | Content | Modal`.
- FocusMode is an internal sub-state of a screen, not a separate FSM state.

### Vertical Tab Base Component
- Base scene: `VerticalTabMenu` (based on Inventory tab layout).
- Slots:
  - TabsContainer (left)
  - ContentContainer (center)
  - RightPanel (optional)
  - FooterHints (optional)
- Consistent focus navigation + back-stack integration.
- Focus navigation uses a FocusRouter with per-tab `last_focused` storage.

## Modal System
### Behavior
- ModalLayer blocks input behind it.
- Confirm/Cancel action mapping.
- Optional icon, title, description, and button list.
- Single active modal only (no queue/stack).

## Transition DoD (No Hangs)
- Any transition that waits on a signal (modal/animation/dialogue) must emit a guaranteed `finished` signal for all outcomes (confirm/cancel/close/error).
- (Dev) Optional timeout with logging to surface deadlocks.

### Modal List and Image Placeholders
#### Confirm Exit
![Confirm Exit](images/modals/confirm_exit.png)

#### Unsaved Changes
![Unsaved Changes](images/modals/unsaved_changes.png)

#### Reset Settings
![Reset Settings](images/modals/reset_settings.png)

#### Delete Save
![Delete Save](images/modals/delete_save.png)

#### Overwrite Save
![Overwrite Save](images/modals/overwrite_save.png)

#### Misc Popup Menu
![Misc Popup Menu](images/modals/misc_popup_menu.png)

## Save System Plan
- Save path for slots:
  - user://saves/slot_01.sav
  - user://saves/slot_02.sav
  - user://saves/slot_03.sav
  - user://saves/slot_04.sav
- profile.json:
  - last_slot
  - per-slot metadata (playtime, timestamp, location, preview image optional)
- Autoload last_slot on startup.

## Settings Plan
- SettingsModule remains authoritative.
- Add `game_settings` to MetSys save (SaveManager.set_value).
- On load, read `game_settings` and apply via SettingsModule.
- Language default: uk.
- Language changes emit a UI refresh signal so text updates at runtime.

## UI Scaling and Readability
- Use anchors, containers, size_flags.
- Define minimum window size; test resize behavior.
- Ensure text and controls remain readable on small windows.

## Next Steps (No Implementation Yet)
- Define UIRoot scene and FSM state scenes.
- Extract VerticalTabMenu base from Inventory layout.
- Define ModalLayer base scene and modal templates.
- Align Options UI with SettingsModule and save into MetSys.
- Integrate save slot metadata and last_slot profile.

## Open Questions
- None at the moment.
