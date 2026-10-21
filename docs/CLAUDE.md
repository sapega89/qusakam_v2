# CLAUDE.md

This file provides essential guidance to Claude Code when working with this repository.

> **Where the truth lives:** the `design/` Obsidian vault — start at `design/INDEX.md`.
> Old long-form docs in `docs/` (CLAUDE_FULL.md, README.md, TESTS_COMPLETE.md,
> DEMO_TEST_PLAN.md, SENIOR_DEV_ANALYSIS.md, ...) are **archived and outdated** —
> they describe Godot 4.5, GUT tests and a "Dark Realm RPG" that no longer exist.

## Project Overview

**Kusakam** — a **Godot 4.6** metroidvania in GDScript. Combat, inventory, skills,
dialogue, save/load, and the MetroidvaniaSystem (MetSys) addon for the map.

> Version is authoritative from `project.godot` → `config/features=PackedStringArray("4.6", ...)`.
> Running the project on 4.5.x crashes at startup.

## Quick Commands

### Run Game
```bash
godot --path . res://SampleProject/MainMenu.tscn
# Or: F5 in Godot editor
```

### Run Tests
```bash
# All verify scripts (fails on a missing green RESULT line or any SCRIPT ERROR):
Scripts/Tools/run_verify.sh
# One area / a glob:
Scripts/Tools/run_verify.sh combat_flow
```

**Test suite:** ~70 headless SceneTree scripts `SampleProject/UI/verify_*.gd`
(`ls SampleProject/UI/verify_*.gd` for the current count), each prints
`RESULT: ALL PASS` or `RESULT: N FAIL`.
- There are **no GUT tests**, and the GUT addon itself was removed (D240).
- Read the `RESULT:` line, not the exit code: every run of this project segfaults on
  shutdown (exit 139), see `design/test_baseline.md`.

### Build
```bash
godot --headless --path . --export-release "Windows Desktop" build/windows/Qusakam.exe
godot --headless --path . --export-release "Linux" build/linux/Qusakam.x86_64
```
Presets live in `export_presets.cfg`.

## Architecture

### Autoloads (order from `project.godot` → `[autoload]`)
```
MetSys → GameManager → EventBus → SaveSystem → ServiceLocator
→ AudioManager → DisplayManager → ItemDatabase → SkillDatabase → LocalizationManager
→ ModalDialogGlobal → AppConfig → SceneLoader → ProjectMusicController
→ ProjectUISoundController → DialogueQuest
```

### Service Locator Pattern
```gdscript
var inventory = ServiceLocator.get_inventory_manager()
var ui = ServiceLocator.get_ui_manager()
```

**Service Registries:** 5 categorized registries (Core, UI, Gameplay, System, Data)
in `SampleProject/Scripts/Core/ServiceRegistry/`.

### Managers created by GameManager
`SampleProject/Scripts/Managers/Core/GameManager.gd` preloads: CharacterManager,
EquipmentManager, SkillManager, SceneManager, MenuManager, UIManager, TimeManager,
PlayerStateManager, DialogueManager, InventoryManager, XPManager, TutorialManager,
GameFlow, CompanionManager.

All managers extend `ManagerBase` with `_initialize()` pattern.

## Project Structure

```
SampleProject/
├── Scenes/           # .tscn: Characters, Gameplay, Menus, UI, Managers, Systems, ...
├── Scripts/          # .gd: Core, Managers, Combat, Gameplay, Systems, UI, Menus, ...
├── Maps/             # MetSys map rooms
├── Resources/Data/   # game data JSON (items, skills, quests, story, ...)
└── UI/               # theme, tokens, verify_*.gd tests, capture_*.gd screenshots
```

### Critical Files
- `Scripts/Core/EventBus.gd` - Global event system
- `Scripts/Core/ServiceLocator.gd` - Manager access
- `Scripts/Managers/Core/GameManager.gd` - Core manager
- `Scripts/Game.gd` - Main game logic (extends MetSysGame)

## Coding Conventions

### Language
- **Code:** English only
- **Comments:** Ukrainian preferred, English acceptable
- **User-facing:** English and Ukrainian (localization, BACKLOG 31)

### GDScript Style
```gdscript
# Use static typing
var health: int = 100
func take_damage(amount: int) -> void:
	health -= amount

# Use & for StringNames (performance)
if body.is_in_group(&"player"):

# Prefer signals over direct calls
signal health_changed(new_health: int)
```

### Component Design
- **Single Responsibility:** Each script = one clear purpose
- **Event-Driven:** Use EventBus for cross-system communication
- **Manager Pattern:** Access systems through ServiceLocator
- **Avoid God Objects:** Split large classes into focused components

## Common Patterns

```gdscript
# Access a manager
ServiceLocator.get_xp_manager().add_xp(50)

# Emit / listen to global events
EventBus.player_died.emit()
EventBus.enemy_died.connect(_on_enemy_died)  # (enemy_id: String, position: Vector2)
```

### Create New Manager
1. Extend `ManagerBase`
2. Override `_initialize()`
3. Add to GameManager's `_create_managers()`
4. Register in appropriate ServiceRegistry
5. Add getter to ServiceLocator

## Testing & Debug

- `SampleProject/UI/verify_*.gd` headless scripts (see Run Tests above)
- `SampleProject/UI/capture_*.gd` render screenshots into `design/shots/` (need a window, not `--headless`)

```gdscript
DebugLogger.info("Message", "Category")
DebugLogger.warning("Warning", "Category")
DebugLogger.error("Error", "Category")
```

## Addons

Enabled editor plugins (`project.godot` → `[editor_plugins]`): **CustomRunner**,
**MetroidvaniaSystem** (+ its EditorExtension), **ModalDialog**, **dialogue_quest**,
**maaacks_menus_template**. Also in `addons/` without a plugin entry: `fsm`,
`interaction_system`. Everything else was removed in D240.

## Important Systems

### Combat
- Player: `Scripts/Player.gd`
- Enemy: `Scenes/Characters/Enemies/default_enemy.tscn` (script `Scripts/Gameplay/DefaultEnemy.gd`)
- Damage: `Scripts/Combat/Components/DamageApplier.gd`
- Health: `Scripts/Combat/Components/HealthComponent.gd`

### Save System
- `SaveSystem` autoload with 4 modules in `Scripts/Systems/Save/Modules/`
  (PlayerData, Inventory, Flags, Settings), one file per slot.
- Saving is manual: a SavePoint opens the save screen → `Game.save_game()`
  (MetSys data + `SaveSystem.save_player_data()`). There is **no** auto-save on room transitions.

### Map System (MetSys)
- Rooms in `SampleProject/Maps/`
- Live settings: `SampleProject/Resources/Settings.tres` (not the root `MetSysSettings.tres`)

## Known Issues

### Player position on load
The position **is written** (`PlayerDataModule.gd:32`, from `Game._save_full_game_data_to_save_system()`,
`Game.gd:600`) but **never read back**: `PlayerStateManager.get_player_position()` has no callers and
`Game._set_save_data()` is not overridden, so `save_manager.retrieve_game()` (`Game.gd:200`) restores
MetSys map data only. On load the saved room loads and the player keeps its default position.
The comment at `Game.gd:239` ("позиція вже відновлена") is wrong. A new game places the player
at the room's `Arrival` marker (`Game.gd:400`). Tracked as **B82** in `design/BUGS.md`.

## Documentation Index

- `design/INDEX.md` — the vault hub (backlog, bugs, decisions, questions, plans)
- `design/test_baseline.md` — test baseline and known pre-existing issues
- `docs/` — archive only; nothing there is current
