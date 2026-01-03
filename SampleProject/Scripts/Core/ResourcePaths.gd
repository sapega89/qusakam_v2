extends RefCounted
class_name ResourcePaths

## 📁 ResourcePaths - Централизованные пути к ресурсам
## Соответствует лучшим практикам Godot 4.5
## Устраняет магические строки и улучшает поддерживаемость

# ============================================================================
# Базовые пути
# ============================================================================

const BASE_PATH = "res://SampleProject"
const SCENES_PATH = BASE_PATH + "/Scenes"
const RESOURCES_PATH = BASE_PATH + "/Resources"
const SCRIPTS_PATH = BASE_PATH + "/Scripts"

# ============================================================================
# Сцены персонажей (Characters)
# ============================================================================

const CHARACTERS_PATH = SCENES_PATH + "/Characters"
const ENEMIES_PATH = CHARACTERS_PATH + "/Enemies"
const BOSSES_PATH = CHARACTERS_PATH + "/Bosses"

# Враги
const ENEMY_DEFAULT = CHARACTERS_PATH + "/default_enemy.tscn"
const ENEMY_MELEE = ENEMIES_PATH + "/enemy_melee.tscn"
const ENEMY_RANGED = ENEMIES_PATH + "/enemy_ranged.tscn"
const ENEMY_FAST = ENEMIES_PATH + "/enemy_fast.tscn"
const ENEMY_TANK = ENEMIES_PATH + "/enemy_tank.tscn"
const ENEMY_MINIBOSS = ENEMIES_PATH + "/miniboss.tscn"

# Боссы
const BOSS_CONTROLLER = SCENES_PATH + "/Gameplay/BossController.tscn"
const BOSS_DEFAULT = BOSSES_PATH + "/boss.tscn"
const BOSS_ENEMY = ENEMIES_PATH + "/boss.tscn"
const BOSS_DEMO = BOSSES_PATH + "/demo_boss.tscn"
const BOSS_MINIBOSS = BOSSES_PATH + "/demo_miniboss.tscn"
const BOSS_FINAL = BOSSES_PATH + "/final_boss.tscn"

# ============================================================================
# Сцены объектов (Objects/NPCs)
# ============================================================================

const OBJECTS_PATH = SCENES_PATH + "/Objects"
const NPCS_PATH = OBJECTS_PATH + "/NPCs"

const MERCHANT = NPCS_PATH + "/merchant.tscn"

# ============================================================================
# Сцены уровней (Levels)
# ============================================================================

const LEVELS_PATH = SCENES_PATH + "/Levels"

# Main game scene
const GAME_ROOT = LEVELS_PATH + "/GameRoot.tscn"

# ============================================================================
# Сцены меню (Menus)
# ============================================================================

const MENUS_PATH = SCENES_PATH + "/Menus"
const MENU_GAME_PATH = MENUS_PATH + "/Game"

const GAME_MENU = MENU_GAME_PATH + "/game_menu.tscn"

# ============================================================================
# Ресурсы данных (Data)
# ============================================================================

const DATA_PATH = RESOURCES_PATH + "/Data"

const MAP_LOCATIONS_CONFIG = DATA_PATH + "/map_locations.json"
const PATHFINDER_CLASSES = DATA_PATH + "/pathfinder_classes.json"

# ============================================================================
# Ресурсы аудио (Audio)
# ============================================================================

const AUDIO_PATH = RESOURCES_PATH + "/Audio"
const MUSIC_PATH = AUDIO_PATH + "/Music"

const MUSIC_SANDS_OF_SERENITY = MUSIC_PATH + "/Sands of Serenity.mp3"
const MUSIC_SANDY_HORIZONS = RESOURCES_PATH + "/Audio/Sandy Horizons.mp3"

# ============================================================================
# Скрипты (Scripts)
# ============================================================================

const SYSTEMS_PATH = SCRIPTS_PATH + "/Systems"
const MANAGERS_PATH = SCRIPTS_PATH + "/Managers"
const RESOURCES_SCRIPT_PATH = SCRIPTS_PATH + "/Resources"
const CORE_PATH = SCRIPTS_PATH + "/Core"

# Системы
const CHARACTER_SCRIPT = SYSTEMS_PATH + "/Character.gd"

# Менеджеры (модульна структура)
const UI_MANAGER_SCRIPT = MANAGERS_PATH + "/UI/UIManager.gd"
const TIME_MANAGER_SCRIPT = MANAGERS_PATH + "/TimeManager.gd"
const PLAYER_STATE_MANAGER_SCRIPT = MANAGERS_PATH + "/Gameplay/PlayerStateManager.gd"
const DEBUG_MANAGER_SCRIPT = MANAGERS_PATH + "/Debug/DebugManager.gd"
const GAME_MUSIC_MANAGER_SCRIPT = MANAGERS_PATH + "/Audio/GameMusicManager.gd"
const SETTINGS_MANAGER_SCRIPT = SYSTEMS_PATH + "/SettingsManager.gd"

# Системы (Systems)
const LOOT_SYSTEM_SCRIPT = SYSTEMS_PATH + "/LootSystem.gd"
const FORGE_SYSTEM_SCRIPT = SYSTEMS_PATH + "/ForgeSystem.gd"

# Resource классы
const PLAYER_STATE_RESOURCE_SCRIPT = RESOURCES_SCRIPT_PATH + "/PlayerStateResource.gd"
const CAMERA_STATE_RESOURCE_SCRIPT = RESOURCES_SCRIPT_PATH + "/CameraStateResource.gd"
const UI_STATE_RESOURCE_SCRIPT = RESOURCES_SCRIPT_PATH + "/UIStateResource.gd"

# ============================================================================
# Утилитные функции
# ============================================================================

## Получает путь к сцене врага по типу.
##
## Args:
## 	enemy_type: Тип врага ("default_enemy", "enemy_melee", "enemy_ranged", etc.)
##
## Returns:
## 	Путь к сцене врага (String). Если тип неизвестен, возвращает ENEMY_DEFAULT.
static func get_enemy_scene_path(enemy_type: String) -> String:
	match enemy_type:
		"default_enemy":
			return ENEMY_DEFAULT
		"enemy_melee":
			return ENEMY_MELEE
		"enemy_ranged":
			return ENEMY_RANGED
		"enemy_fast":
			return ENEMY_FAST
		"enemy_tank":
			return ENEMY_TANK
		"miniboss":
			# Проверяем наличие специальной сцены минибосса
			if ResourceLoader.exists(ENEMY_MINIBOSS):
				return ENEMY_MINIBOSS
			# Fallback: используем enemy_tank
			return ENEMY_TANK
		"boss", "demo_boss":
			# Проверяем наличие специальных сцен босса в порядке приоритета
			if ResourceLoader.exists(BOSS_DEMO):
				return BOSS_DEMO
			if ResourceLoader.exists(BOSS_CONTROLLER):
				return BOSS_CONTROLLER
			if ResourceLoader.exists(BOSS_DEFAULT):
				return BOSS_DEFAULT
			if ResourceLoader.exists(BOSS_ENEMY):
				return BOSS_ENEMY
			# Fallback: используем enemy_tank
			return ENEMY_TANK
		"miniboss", "demo_miniboss":
			# Проверяем наличие специальной сцены минибосса
			if ResourceLoader.exists(BOSS_MINIBOSS):
				return BOSS_MINIBOSS
			if ResourceLoader.exists(ENEMY_MINIBOSS):
				return ENEMY_MINIBOSS
			# Fallback: используем enemy_tank
			return ENEMY_TANK
		"final_boss":
			# Финальный босс
			if ResourceLoader.exists(BOSS_FINAL):
				return BOSS_FINAL
			# Fallback: используем demo_boss
			if ResourceLoader.exists(BOSS_DEMO):
				return BOSS_DEMO
			# Fallback: используем enemy_tank
			return ENEMY_TANK
		_:
			# По умолчанию используем default_enemy
			return ENEMY_DEFAULT

## Получает массив путей к сценам боссов в порядке приоритета.
##
## Returns:
## 	Array[String] с путями к сценам боссов
static func get_boss_scene_paths() -> Array[String]:
	return [BOSS_CONTROLLER, BOSS_DEFAULT, BOSS_ENEMY]

## Проверяет существование ресурса по пути.
##
## Args:
## 	path: Путь к ресурсу
##
## Returns:
## 	true если ресурс существует, false иначе
static func resource_exists(path: String) -> bool:
	return ResourceLoader.exists(path)

