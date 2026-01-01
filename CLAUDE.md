# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Godot 4.5** metroidvania-style game project built with GDScript. The project integrates multiple systems including combat, inventory, dialogue, save/load, and map management using the MetroidvaniaSystem addon.

## Common Development Commands

### Running the Game

Open the project in Godot 4.5 editor and press F5, or use:
```bash
# Run from command line (requires Godot in PATH)
godot --path . res://SampleProject/MainMenu.tscn
```

### Testing

Currently no automated test suite. Manual testing through the Godot editor:
- F5: Run main scene
- F6: Run current scene
- Check console output for debug messages

## Architecture Overview

### Autoload Singletons (Global Systems)

The project uses Godot's autoload system extensively. Key autoloads in order:
- **MetSys** - MetroidvaniaSystem plugin for map/room management
- **GameManager** - Core game manager, creates child managers on _ready()
- **EventBus** - Event system using signals for decoupled communication
- **DialogueQuest** - Dialogue system plugin
- **SaveSystem** - Save/load game data
- **ServiceLocator** - Dependency injection, provides access to all managers
- **AudioManager, MusicManager, DisplayManager** - Media management
- **ItemDatabase** - JSON-based item database
- **LocalizationManager** - i18n support

### Service Locator Pattern

Access managers through ServiceLocator autoload:
```gdscript
var inventory = ServiceLocator.get_inventory_manager()
var scene_mgr = ServiceLocator.get_scene_manager()
var menu = ServiceLocator.get_menu_manager()
```

### Service Registry Architecture (ЭТАП 3.1 ✅)

**Problem:** ServiceLocator was a God Object (405 lines, 20+ services, violating Single Responsibility Principle)

**Solution:** ServiceLocator now delegates to 5 categorized Registry classes for better organization:

**Registry Classes:**
1. **CoreServiceRegistry** (`SampleProject/Scripts/Core/ServiceRegistry/CoreServiceRegistry.gd`)
   - GameManager, SaveSystem

2. **UIServiceRegistry** (`SampleProject/Scripts/Core/ServiceRegistry/UIServiceRegistry.gd`)
   - UIManager, UIUpdateManager, MenuManager, DisplayManager

3. **GameplayServiceRegistry** (`SampleProject/Scripts/Core/ServiceRegistry/GameplayServiceRegistry.gd`)
   - CharacterManager, EquipmentManager, PlayerStateManager, EnemyStateManager, InventoryManager, DialogueManager

4. **SystemServiceRegistry** (`SampleProject/Scripts/Core/ServiceRegistry/SystemServiceRegistry.gd`)
   - TimeManager, AudioManager, MusicManager, DebugManager, SceneManager

5. **DataServiceRegistry** (`SampleProject/Scripts/Core/ServiceRegistry/DataServiceRegistry.gd`)
   - ItemDatabase, SettingsManager, LocalizationManager

**Usage (both styles work):**
```gdscript
# Old style (backward compatible) - recommended for consistency
var inventory = ServiceLocator.get_inventory_manager()
var char_mgr = ServiceLocator.get_character_manager()

# New style (direct registry access) - useful for category-based access
var inventory = ServiceLocator.gameplay.get_inventory_manager()
var ui_mgr = ServiceLocator.ui.get_ui_manager()
```

**Benefits:**
- ✅ Single Responsibility - each Registry manages its category
- ✅ Better code organization - services grouped logically by function
- ✅ Easier testing - can mock entire service categories
- ✅ Full backward compatibility - all existing code continues to work
- ✅ Reduced ServiceLocator size from 405 to 164 lines (-59%)

### Manager Hierarchy

GameManager creates these managers as child nodes during _ready():
- **CharacterManager** - Player/NPC character state
- **EquipmentManager** - Equipment slots and items
- **SceneManager** - Scene transitions
- **MenuManager** - Game menu UI
- **EnemyStateManager** - Enemy alive/dead tracking
- **InventoryManager** - Item storage and manipulation
- **UIManager** - UI element references
- **TimeManager** - Game time and pause
- **PlayerStateManager** - Player state (health, position, etc.)
- **UIUpdateManager** - Auto-update UI via EventBus
- **DebugManager** - Debug mode utilities

### Combat System Architecture

Component-based combat using interfaces:
- **ICombatant** - Entities that both deal and take damage
- **IDamageable** - Can receive damage
- **IDamageDealer** - Can deal damage

Key components:
- **CombatBody2D** - Base class for combat entities (extends CharacterBody2D)
- **HealthComponent** - Manages health/damage
- **HurtboxComponent** - Damage receiving area (Area2D)
- **DamageApplier** - Damage dealing component (attached to Hitbox Area2D)
- **EnemyStats** - Resource-based enemy configuration (NEW)

Player/Enemy structure:
```
Entity (extends CombatBody2D)
├── HealthComponent (Node)
├── Hurtbox (Area2D)
│   └── HurtboxComponent (Node)
└── Hitbox (Area2D)
    └── DamageApplier (Node)
```

### Enemy Configuration System

**EnemyStats.gd** - Resource class for enemy configuration (ЭТАП 2.1 ✅)
- Location: `SampleProject/Scripts/Gameplay/Characters/Enemies/EnemyStats.gd`
- Type: Resource (extends Resource)
- Purpose: Unified configuration for all enemy types instead of duplicated scripts
- **Status:** ✅ FULLY IMPLEMENTED - Integrated into DefaultEnemy.gd, 3 resource files created

**Integration in DefaultEnemy.gd:**
```gdscript
@export var enemy_stats: EnemyStats

func _ready():
    super._ready()
    # Apply stats from resource if set
    if enemy_stats:
        _apply_stats(enemy_stats)
    # ... rest of initialization

func _apply_stats(stats: EnemyStats) -> void:
    speed = stats.speed
    base_damage = stats.base_damage
    damage = stats.base_damage
    attack_cooldown = stats.attack_cooldown
    detection_range = stats.detection_range
    attack_range = stats.attack_range
    chase_range = stats.chase_range
    Max_Health = stats.max_health
    current_health = Max_Health
```

**EnemyStats Properties:**
- `enemy_type: String` - Enemy type identifier ("melee", "tank", "fast")
- `speed: float` - Movement speed
- `base_damage: float` - Attack damage
- `attack_cooldown: float` - Time between attacks
- `detection_range: float` - Player detection range
- `attack_range: float` - Attack trigger range
- `chase_range: float` - Maximum chase distance
- `max_health: int` - Maximum health points

**Available Resource Files:**
1. `SampleProject/Resources/Enemies/enemy_stats_melee.tres` - Standard melee enemy
   - Speed: 70, Damage: 10, HP: 100, Attack Cooldown: 1.5s
2. `SampleProject/Resources/Enemies/enemy_stats_tank.tres` - Slow tanky enemy
   - Speed: 50, Damage: 15, HP: 200, Attack Cooldown: 2.0s
3. `SampleProject/Resources/Enemies/enemy_stats_fast.tres` - Fast weak enemy
   - Speed: 120, Damage: 8, HP: 60, Attack Cooldown: 1.0s

**Migration Complete:**
- ❌ DELETED: `EnemyMelee.gd`, `EnemyTank.gd`, `EnemyFast.gd` (duplicate code eliminated)
- ✅ Use `DefaultEnemy` with different `enemy_stats` resources instead
- **Code Reduction:** ~75 lines of duplicate code removed

### Unified HealthBar System (ЭТАП 2.2 ✅)

**HealthBar.gd** - Unified health bar for Player, Enemy, and Boss
- Location: `SampleProject/Scripts/UI/HealthBar.gd`
- Type: Control (extends Control)
- Purpose: Single class for all HP bars instead of separate HealthBar/EnemyHealthBar
- **Status:** ✅ FULLY IMPLEMENTED - Merged EnemyHealthBar functionality

**HealthBar Types:**
```gdscript
enum HealthBarType {
    PLAYER,   # Static UI bar for player
    ENEMY,    # Dynamic bar following enemy
    BOSS      # Boss HP bar (customizable)
}

@export var bar_type: HealthBarType = HealthBarType.PLAYER
```

**Type-Specific Features:**
- **PLAYER:** Static position, no auto-hide, z_index=0
- **ENEMY:** Follows entity, auto-hides after 3s, z_index=100, `top_level=true`
- **BOSS:** Customizable (typically static top-of-screen bar), z_index=200

**Usage Examples:**
```gdscript
# For enemies (in DefaultEnemy.gd):
health_bar.bar_type = HealthBar.HealthBarType.ENEMY
health_bar.setup_for_entity(self, "Enemy")

# For player (in scene):
# Just set bar_type to PLAYER in inspector (default)
```

**Additional ENEMY/BOSS Properties:**
- `follow_entity: bool` - Follow entity position (auto-enabled for ENEMY)
- `auto_hide: bool` - Auto-hide after delay (auto-enabled for ENEMY)
- `auto_hide_delay: float` - Delay before hiding (default: 3.0s)
- `offset_y: float` - Vertical offset from entity (default: -60.0)
- `offset_x: float` - Horizontal offset from entity (default: 0.0)

**Migration Complete:**
- ❌ DELETED: `EnemyHealthBar.gd` (274 lines eliminated)
- ✅ All functionality merged into `HealthBar.gd`
- **Code Reduction:** ~200+ lines of duplicate code removed
- **Benefit:** Easier to maintain, consistent behavior, less memory usage

### MetSys Integration Cleanup (ЭТАП 2.4 ✅)

**Problem:** Duplicate spawn/portal positioning logic conflicting with MetroidvaniaSystem (MetSys)

**What was removed:**
1. ❌ **SpawnPortal.gd** - Created duplicate player instances instead of using MetSys spawn points
2. ❌ **Game._pending_saved_position** - Redundant with MetSys save_manager.retrieve_game()
3. ❌ **Game manual SavePoint search** - MetSys automatically handles spawn points
4. ❌ **SceneManager.portal_entry_side** - MetSys manages portal direction through borders

**Changes Made:**

**Game.gd:**
- Removed `_pending_saved_position` variable and all related methods
- Removed manual SavePoint positioning code (lines 162-179)
- Simplified `init_room()` - removed pending position logic
- Added comments explaining MetSys handles positioning automatically

**SceneManager.gd:**
- Removed `portal_entry_side` variable
- Removed `set_portal_entry_side()` method
- Simplified portal positioning logic with TODO for full MetSys migration

**Files Deleted:**
- `SampleProject/Scripts/Gameplay/SpawnPortal.gd` (114 lines)
- `SampleProject/Scenes/Gameplay/Objects/Portals/spawn_portal.tscn`

**How MetSys Works Now:**
```gdscript
# Save player position
save_manager.store_game(self)  # Automatically saves position

# Load player position
save_manager.retrieve_game(self)  # Automatically restores position

# No manual positioning needed - MetSys handles it!
```

**Benefits:**
- ✅ No more spawn position conflicts
- ✅ Proper MetSys integration
- ✅ Eliminated ~150 lines of duplicate positioning code
- ✅ Cleaner, more maintainable codebase

### Manager Base Class System (ЭТАП 2.3 ✅)

**ManagerBase.gd** - Base class for all manager systems
- Location: `SampleProject/Scripts/Managers/Core/ManagerBase.gd`
- Type: Node (extends Node)
- Purpose: Unified initialization pattern for all managers
- **Status:** ✅ FULLY IMPLEMENTED - 13 managers updated

**How it Works:**
```gdscript
extends Node
class_name ManagerBase

func _ready():
    # Defer initialization to ensure scene tree is ready
    call_deferred("_initialize")

func _initialize():
    # Must be overridden by child classes
    push_error("ManagerBase: _initialize() must be overridden in ", get_script().resource_path)
```

**Updated Managers (13 total):**
1. **CharacterManager** - Renamed `_initialize_dependencies()` to `_initialize()`
2. **EquipmentManager** - Renamed `_initialize_dependencies()` to `_initialize()`
3. **SceneManager** - Moved `create_transition_overlay()` to `_initialize()`
4. **MenuManager** - Added empty `_initialize()` (no initialization needed)
5. **EnemyStateManager** - Added empty `_initialize()` (no initialization needed)
6. **UIUpdateManager** - Renamed `_ready()` content to `_initialize()`
7. **PlayerStateManager** - Renamed `_ready()` to `_initialize()`
8. **GameManager** - Renamed `_ready()` to `_initialize()` (Note: Uses ManagerBase pattern but doesn't extend it since it's an autoload scene)
9. **UIManager** - Renamed `_ready()` content to `_initialize()`
10. **GameMusicManager** - Renamed `_ready()` to `_initialize()`
11. **TimeManager** - Renamed `_ready()` to `_initialize()`
12. **DebugManager** - Renamed `_ready()` to `_initialize()`
13. **CompanionManager** - Renamed `_ready()` to `_initialize()`

**Benefits:**
- ✅ Consistent initialization pattern across all managers
- ✅ Deferred initialization ensures scene tree is ready
- ✅ Clear error messages when `_initialize()` is not overridden
- ✅ Easier to maintain and extend manager system
- ✅ Better code organization and readability

**Usage Pattern:**
```gdscript
extends ManagerBase
class_name MyManager

func _initialize():
    """Initialize MyManager"""
    # Your initialization logic here
    print("MyManager: Initialized")
```

### Event-Driven Communication

EventBus provides signals for system communication:
```gdscript
# Subscribe
EventBus.player_health_changed.connect(_on_health_changed)
EventBus.item_added.connect(_on_item_added)

# Emit
EventBus.player_health_changed.emit(current_hp, max_hp)
EventBus.enemy_died.emit(enemy_id)
```

### Save System

Two save systems work together:
1. **MetSys SaveManager** - Map state, collectibles, room data (user://example_save_data.sav)
2. **SaveSystem** - Player data, inventory, flags (user://savegames/player_data.json)

Saving triggered by SavePoint nodes (Area2D). Game.gd manages quest/dialogue/cutscene/boss flags.

### Game State Flags

Game.gd extends MetSysGame and adds flag dictionaries:
- `quest_flags` - Quest progression
- `cutscene_flags` - Cutscene viewing state
- `boss_flags` - Boss defeat tracking
- `location_flags` - Location discovery

Access via Game singleton:
```gdscript
var game = Game.get_singleton()
game.set_quest_flag("quest_1_completed", true)
var completed = game.get_quest_flag("quest_1_completed", false)
```

## Project Structure

### Key Directories

- **SampleProject/** - Main game code and scenes
  - **Scripts/** - All GDScript files organized by type
    - **Core/** - ServiceLocator, EventBus, GameGroups, ResourcePaths, GameSettings
    - **Systems/** - Inventory, Save, Dialogue, Audio, Cutscenes
    - **Managers/** - Character, Equipment, Scene, Menu, UI managers
    - **Combat/** - Combat system, interfaces, components
    - **Gameplay/** - Enemies, NPCs, Companions, Projectiles
    - **UI/** - UI components (HealthBar, Menus, Dialogs)
    - **Menus/** - Game menu system
    - **Shop/** - Shop UI components
  - **Scenes/** - Scene files (.tscn)
  - **Resources/** - Data files (JSON), art assets
- **addons/** - Godot plugins
  - **MetroidvaniaSystem/** - Map/room management
  - **dialogue_quest/** - Dialogue system (REQUIRED)
  - **maaacks_menus_template/** - Menu templates
  - **forge/** - Crafting system
  - Plus many other addons (see project.godot)
- **docs/** - Documentation
  - **Combat/** - Combat system setup guides
  - **SYSTEMS_OVERVIEW.md** - Detailed systems overview
  - **ADDONS_REQUIRED.md** - Required addon list
  - **HOW_TO_SAVE.md** - Save system usage

### Important Files

- **project.godot** - Project configuration, autoloads, input mappings
- **SampleProject/MainMenu.tscn** - Main entry scene
- **SampleProject/Scripts/Game.gd** - Core game script (extends MetSysGame)
- **SampleProject/Scripts/Core/ServiceLocator.gd** - Dependency injection
- **SampleProject/Scripts/Core/EventBus.gd** - Event system

## Coding Conventions

### Language and Comments

Code comments are mixed Russian/Ukrainian/English. When adding new code:
- Use English for code and comments to maintain consistency with future development
- Preserve existing Russian/Ukrainian comments when editing

### GDScript Style

- Class names use PascalCase: `CharacterManager`, `InventoryManager`
- Functions/variables use snake_case: `get_inventory_manager()`, `quest_flags`
- Type hints are used: `func get_player() -> Node2D:`
- Export variables for inspector configuration: `@export var starting_map: String`

### Component Design

- Use composition over inheritance (component-based architecture)
- Interfaces (ICombatant, IDamageable) for duck typing
- Components as separate Node scripts attached to entities
- Minimal logging except for critical errors/warnings

### Manager Access

Always access managers through ServiceLocator, never direct references:
```gdscript
# Good
var inventory = ServiceLocator.get_inventory_manager()

# Bad
var inventory = get_node("/root/GameManager/InventoryManager")
```

## Required Addons

### Critical Dependencies

**DialogueQuest** - MUST be installed for dialogue system to work
- Install from Asset Library
- Configure in project.godot: `data_directory="res://dialogue_quest/"`
- Autoload: `DialogueQuest="*res://addons/dialogue_quest/scripts/dialogue_quest_interface.gd"`

### Already Installed

All other addons are included in the addons/ directory. See project.godot [editor_plugins] section for full list.

## Collision Layers

Standard layer setup:
- Layer 1 (bit 0): Player
- Layer 2 (bit 1): Enemies / Hurtboxes
- Layer 3 (bit 2): Environment
- Layer 4 (bit 2): Hitboxes
- Layer 8 (bit 3): Dialogue Triggers

## Animation Integration

Combat damage is triggered via AnimationPlayer Call Method tracks:
- Call `DamageApplier.enable_damage()` on attack keyframe
- Call `DamageApplier.disable_damage()` after attack completes

## Common Patterns

### Adding a New Manager

1. Create script in `SampleProject/Scripts/Managers/`
2. Add creation in `GameManager._ready()`
3. Register in `ServiceLocator._register_managers()`
4. Add getter method in ServiceLocator

### Creating a Combat Entity

1. Extend CombatBody2D
2. Add HealthComponent child node
3. Add Hurtbox Area2D with HurtboxComponent
4. Add Hitbox Area2D with DamageApplier
5. Configure collision layers properly

### Adding Save Data

1. Add data to SaveSystem.save_game() / load_game()
2. Add flags to Game.gd dictionaries if needed
3. Emit EventBus signals on data changes
4. Update UI via UIUpdateManager subscriptions

## Debug and Development Files

### Active Debug Files

**DEBUG_TELEPORTATION_BUG.md** - Investigation of player teleportation bug
- Location: Project root
- Status: ✅ RESOLVED (2025-12-31)
- Purpose: Track teleportation to save point when releasing input keys
- **Root Cause:** `call_deferred` in Game._ready() caused `_load_full_game_data_from_save_system()` to execute AFTER `load_room()`, so `_pending_saved_position` was empty when `init_room()` checked it
- **Solution:** Changed to synchronous call - `_load_full_game_data_from_save_system()` now executes BEFORE `load_room()`
- **Fix Location:** `Game.gd:125-127` - removed `call_deferred` wrapper
- Debug logging (can be removed after testing):
  - `Player.gd:300-303` - kill() function with print_stack()
  - `Player.gd:116-119` - Jump key release tracking
  - `Hazard.gd:26` - Hazard kill() call tracking

### Debug Logging Conventions

When adding debug logging:
- Use emoji prefixes for visual scanning: 💀 (kill), 🔑 (input), ☠️ (hazard), 🎮 (game state)
- Include `print_stack()` for tracking call chains
- Log position and velocity for movement bugs
- Document all debug changes in respective DEBUG_*.md files
- Remove debug logging after bug is fixed

### Bug Investigation Workflow

1. Create `DEBUG_[BUG_NAME].md` in project root
2. Document symptoms, user reports, and technical analysis
3. Add targeted debug logging to relevant scripts
4. Update DEBUG_*.md with logging locations
5. Test and analyze console output
6. Fix bug based on findings
7. Remove debug logging and archive DEBUG_*.md to docs/

## Notes

- Main scene is MainMenu.tscn, not a game scene
- Player spawns at SavePoints or Portals
- MetSys manages room transitions and map state
- No level/experience system (intentionally excluded)
- ItemDatabase works without item_database addon (uses raw JSON)
- Check DEBUG_*.md files in project root for active bug investigations
