# CLAUDE.md

> **Note:** Full detailed documentation available in `CLAUDE_FULL.md`

This file provides essential guidance to Claude Code when working with this repository.

## Project Overview

**Godot 4.5** metroidvania-style game with GDScript. Integrates combat, inventory, dialogue, save/load, and MetroidvaniaSystem addon for map management.

## Quick Commands

### Run Game
```bash
godot --path . res://SampleProject/MainMenu.tscn
# Or: F5 in Godot editor
```

### Run Tests
```bash
# GUI: Godot → GUT tab → Run All
# CLI:
godot --path . -s addons/gut/gut_cmdln.gd
```

**Test Coverage:** 154 tests (100% pass rate)
- Unit: 134 tests | Integration: 20 tests
- See: `docs/TESTS_COMPLETE.md`, `tests/README.md`

## Architecture

### Key Autoloads (in order)
```
MetSys → GameManager → EventBus → DialogueQuest → SaveSystem
→ ServiceLocator → Audio/Display/Music Managers → ItemDatabase
```

### Service Locator Pattern
```gdscript
# Access managers through ServiceLocator
var inventory = ServiceLocator.get_inventory_manager()
var ui = ServiceLocator.get_ui_manager()
```

**Service Registries:** 5 categorized registries (Core, UI, Gameplay, System, Data)
- See: `Scripts/Core/ServiceRegistry/` for implementation
- Details: `CLAUDE_FULL.md` → Service Registry Architecture

### Manager Hierarchy
```
GameManager (autoload)
├── CharacterManager
├── EquipmentManager
├── InventoryManager
├── DialogueManager
├── XPManager
├── TutorialManager
├── UIManager
├── MenuManager
├── TimeManager
└── [+ 10 more managers]
```

All managers extend `ManagerBase` with `_initialize()` pattern.

## Project Structure

### Key Directories
```
SampleProject/
├── Scenes/           # Scene files (.tscn)
│   ├── Gameplay/     # Player, enemies, objects
│   ├── Menus/        # UI and menus
│   ├── Managers/     # Manager scene nodes
│   └── Systems/      # System autoloads
├── Scripts/          # GDScript files
│   ├── Core/         # EventBus, ServiceLocator
│   ├── Managers/     # Manager implementations
│   ├── Gameplay/     # Gameplay logic
│   ├── Systems/      # System scripts
│   └── UI/           # UI scripts
├── Maps/             # MetSys map rooms
├── Resources/        # Resources (.tres)
└── Assets/           # Art, audio, fonts
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
- **User-facing:** English (future localization)

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

### Access Manager
```gdscript
# In any script
func _ready():
	var xp_mgr = ServiceLocator.get_xp_manager()
	xp_mgr.add_xp(50)
```

### Emit Event
```gdscript
# Emit global event
EventBus.player_died.emit()
EventBus.xp_gained.emit(amount)

# Listen to events
func _ready():
	EventBus.enemy_died.connect(_on_enemy_died)
```

### Create New Manager
1. Extend `ManagerBase`
2. Override `_initialize()`
3. Add to GameManager's `_create_managers()`
4. Register in appropriate ServiceRegistry
5. Add getter to ServiceLocator

See `CLAUDE_FULL.md` for detailed examples.

## Testing & Debug

### Manual Testing
- F5: Run game
- F6: Run current scene
- See: `docs/DEMO_TEST_PLAN.md`

### Automated Testing
- GUT framework with 154 tests
- Tests in `tests/unit/` and `tests/integration/`
- Coverage: XP, Coins, Tutorial, VFX, UI, Combat
- Full guide: `docs/TESTS_COMPLETE.md`

### Debug Logging
```gdscript
DebugLogger.info("Message", "Category")
DebugLogger.warning("Warning", "Category")
DebugLogger.error("Error", "Category")
```

## Required Addons

### Critical
- **MetroidvaniaSystem** - Map/room management
- **GUT** - Testing framework
- **DialogueQuest** - Dialogue system

### Installed
Basic Settings Menu, Modal Dialog, Maaacks Menus Template, Tree Maps, Dynamic Water 2D, properUI (Modal/Toast)

Full list: See `project.godot` → `[editor_plugins]`

## Important Systems

### Combat System
- Player: `Scripts/Player.gd`
- Enemy: `Scripts/Gameplay/Actors/Enemy.gd`
- Damage: `Scripts/Gameplay/Components/DamageApplier.gd`
- Health: `Scripts/Gameplay/Components/HealthComponent.gd`
- Details: `CLAUDE_FULL.md` → Combat System Architecture

### Save System
- Modular architecture with 4 modules
- Auto-save on room transitions
- Manual save via SaveSystem.save_game()
- Details: `CLAUDE_FULL.md` → Save System

### Map System (MetSys)
- Rooms in `SampleProject/Maps/`
- Player spawn handled by MetSys
- Portal system for room transitions
- Config: `MetSysSettings.tres`

## Known Issues & Fixes

### Player Spawning
⚠️ Player position NOT persisted between sessions
- Spawns at MetSys starting coords on load
- Save system tracks last map, not position
- See: `CLAUDE_FULL.md` → Player Spawning System

### Recent Fixes (ЕТАП 2.x)
All major refactorings and bug fixes documented in:
- `CLAUDE_FULL.md` - Full technical details
- `docs/BUGS_FIXED_SUMMARY.md` - Bug fix summaries
- `docs/REFACTORING_REPORT.md` - Refactoring history

Key fixes:
- ✅ Portal infinite loop (static cooldown)
- ✅ Enemy spawning/physics
- ✅ ServiceLocator God Object → Registry pattern
- ✅ HealthBar system consolidation
- ✅ MetSys integration cleanup

## Documentation Index

**For Claude Code:**
- `CLAUDE.md` ← You are here (condensed)
- `CLAUDE_FULL.md` - Complete detailed documentation

**Technical Documentation:**
- `DOCUMENTATION.md` - Developer guide
- `TESTS_COMPLETE.md` - Testing guide
- `BUGS_FIXED_SUMMARY.md` - Bug fixes
- `REFACTORING_REPORT.md` - Refactoring history
- `SENIOR_DEV_ANALYSIS.md` - Architecture analysis

**Testing:**
- `tests/README.md` - Test organization
- `DEMO_TEST_PLAN.md` - Manual test plan

## Quick Reference

### File an Enemy
```gdscript
# In room scene
var enemy_scene = preload("res://SampleProject/Scenes/Gameplay/Actors/Enemy.tscn")
var enemy = enemy_scene.instantiate()
add_child(enemy)
```

### Save Custom Data
```gdscript
# In SaveSystem custom module
func save_data() -> Dictionary:
    return {"my_value": 123}

func load_data(data: Dictionary) -> void:
    my_value = data.get("my_value", 0)
```

### Add UI Element
```gdscript
# Access through UIManager
var ui_mgr = ServiceLocator.get_ui_manager()
var health_bar = ui_mgr.get_health_bar()
health_bar.update_health(current, maximum)
```

---

**For detailed implementation guides, full code examples, and technical deep-dives, see `CLAUDE_FULL.md`**
