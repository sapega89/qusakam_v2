# Next steps

## Goals
- Verify how modals behave in-game and from menus.
- Configure each game menu entry and expected navigation flow.
- Build the demo map structure and link rooms.
- Implement a clear start and end for the demo.

## 1) Verify modal behavior
- Inventory: open MISC and confirm each button opens the correct modal.
- Confirm dialogs: check "Exit to Main Menu" and "Exit Game" confirm text and button results.
- Input handling: verify mouse and keyboard both work; focus moves between modal buttons.
- Blocking: ensure underlying UI does not receive input while modal is open.
- Cleanup: after closing a modal, controls return to the menu and no overlay blocks input.

## 2) Configure each game menu entry
- Define the target for each tab (Inventory, Equipment, World Map, Misc, Journal, Skills, Status).
- For Misc:
  - Settings -> options scene or SettingsManager flow
  - Tutorial -> tutorial menu scene
  - Exit to Main Menu -> confirm modal, then title screen
  - Exit Game -> confirm modal, then quit
- Add tests for each action (open scene, open modal, confirm flow).
- Add keyboard navigation rules (focus order, Enter/Space activate, Esc closes).

## 3) Build demo map structure
- List rooms and intended connections in a simple table.
- Update MetSys/MapData (or room metadata) with links.
- Verify transitions between rooms and map display.
- Add a route for the demo (start room -> mid room -> boss/goal -> exit).

## 4) Implement demo start/end
- Start:
  - Define the initial room and player spawn.
  - Show intro (title or short fade) and enable input.
- End:
  - Define end trigger (boss defeat, item pickup, or room reach).
  - Show end screen and return to main menu.
  - Lock input until the end screen is dismissed.

## Deliverables
- All menu actions wired and tested.
- Stable modal behavior (mouse + keyboard).
- Demo map complete with connected rooms.
- Start/end flow implemented and verified.

## Production demo readiness notes
### Project gaps to address
- **Menu flows:** MISC buttons now open scenes/modals, but each action should be validated end-to-end (settings, tutorial, exit).
- **Title screen return:** ensure `show_title_screen` is set on exit-to-main and the main menu honors it.
- **Tutorial menu:** `tutorial_menu.tscn` is a placeholder; add real tutorial content.
- **Journal:** `SampleProject/Scripts/Menus/Game/journal_component.gd` has TODOs for init/update.
- **MetSys room routing:** `SampleProject/Scripts/Managers/Scene/SceneManager.gd` has TODO for MetSys border/connection migration.
- **Player position debug:** `SampleProject/Scripts/Player.gd` still has debug logging for teleportation; remove once confirmed fixed.
- **Ranged enemy:** `SampleProject/Scripts/Gameplay/Characters/Enemies/EnemyRanged.gd` TODO for projectiles.

### Demo polish checklist
- **Input consistency:** mouse + keyboard navigation across all menus and modals.
- **Save/Load clarity:** confirm warnings, slot metadata, and default slot handling.
- **Performance:** verify scene transitions and UI overlays don’t block input.
- **Localization:** check EN/UK strings for menu entries and modals.
- **Audio:** ensure menu SFX/music configs exist (currently missing).
- **QA pass:** run `docs/DEMO_TEST_PLAN.md` and archive any DEBUG_* docs after fixes.
