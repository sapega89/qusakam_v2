extends RefCounted
class_name GameSettings

## ⚙️ GameSettings - Централизованные настройки игры
## Содержит все магические числа, строки и дефолтные значения
## Соответствует лучшим практикам Godot 4.5
## Устраняет магические числа и строки из кода
## АДАПТИРОВАНО: Исключены level, experience, stat_points (используется система из текущего проекта)

# ============================================================================
# Игровые константы
# ============================================================================

## Имена сцен
const DEFAULT_SCENE = "VillageScene"

## ID персонажей
const DEFAULT_CHARACTER_ID = "player_1"

## Классы и подклассы
const DEFAULT_CLASS_ID = "champion"
const DEFAULT_SUBCLASS_ID = "paladin"

## Типы врагов
const ENEMY_TYPE_DEFAULT = "default_enemy"
const ENEMY_TYPE_MELEE = "enemy_melee"
const ENEMY_TYPE_RANGED = "enemy_ranged"
const ENEMY_TYPE_FAST = "enemy_fast"
const ENEMY_TYPE_TANK = "enemy_tank"
const ENEMY_TYPE_MINIBOSS = "miniboss"
const ENEMY_TYPE_BOSS = "boss"

# ============================================================================
# Здоровье и зелья
# ============================================================================

const DEFAULT_HEALTH = 100
const DEFAULT_MAX_HEALTH = 100
const DEFAULT_POTIONS = 3
const DEFAULT_MAX_POTIONS = 5

# ============================================================================
# Статы персонажа (начальные значения)
# ============================================================================

const DEFAULT_STRENGTH = 10
const DEFAULT_INTELLIGENCE = 10
const DEFAULT_DEXTERITY = 10
const DEFAULT_CONSTITUTION = 10

# ============================================================================
# Пределы валидации
# ============================================================================

## Пределы для статов (1-100)
const STAT_MIN = 1
const STAT_MAX = 100

## Пределы для позиций (разумные границы для 2D игры)
const POSITION_MIN = -10000.0
const POSITION_MAX = 10000.0

# ============================================================================
# Позиции спавна
# ============================================================================

## Дефолтная позиция спавна врагов
const DEFAULT_ENEMY_SPAWN_POSITION = Vector2(528, 519)

## Дефолтная позиция спавна торговца
const DEFAULT_MERCHANT_POSITION = Vector2(400, 500)

## Позиция спавна игрока в новой игре
const DEFAULT_PLAYER_SPAWN_POSITION = Vector2(300, 549)

## Позиция спавна игрока (левая сторона)
const LEFT_SPAWN_X = 100

## Смещение для торговца относительно игрока
const MERCHANT_OFFSET_FROM_PLAYER = Vector2(200, 0)
const MERCHANT_Y_POSITION = 500

# ============================================================================
# Фон локации (дефолтные значения)
# ============================================================================

const DEFAULT_BACKGROUND_POSITION = Vector2(561, 277.75)
const DEFAULT_BACKGROUND_SCALE = Vector2(1.1, 0.56)

## Вариация позиции фона (для рандомизации)
const BACKGROUND_POSITION_VARIATION_X = 50.0
const BACKGROUND_POSITION_VARIATION_Y = 30.0

# ============================================================================
# Позиции спавна врагов (для автогенерации)
# ============================================================================

## Массив возможных позиций для спавна врагов
static func get_default_enemy_spawn_positions() -> Array[Vector2]:
	return [
		Vector2(300, 519),
		Vector2(528, 519),
		Vector2(756, 519),
		Vector2(984, 519),
		Vector2(1212, 519),
		Vector2(1440, 519),
		Vector2(1668, 519),
		Vector2(1896, 519)
	]

# ============================================================================
# Инвентарь (дефолтные значения)
# ============================================================================

const DEFAULT_COINS = 1000
const DEFAULT_KEYS = 0

## Дефолтные количества предметов в инвентаре
static func get_default_inventory_items() -> Dictionary:
	return {
		"potions": DEFAULT_POTIONS,
		"coins": DEFAULT_COINS,
		"keys": DEFAULT_KEYS,
		"items": {
			# Weapons
			"iron_sword": 1,
			"copper_sword": 1,
			"silver_sword": 1,
			# Armor
			"iron_armor": 1,
			"leather_armor": 1,
			"iron_helmet": 1,
			"iron_shield": 1,
			# Consumables
			"hi_potion": 3,
			"ether": 2,
			# Resources - Ores
			"iron_ore": 10,
			"copper_ore": 15,
			"silver_ore": 5,
			"gold_ore": 3,
			# Resources - Ingots
			"iron_ingot": 5,
			"copper_ingot": 8,
			"silver_ingot": 2,
			"gold_ingot": 1,
			# Resources - Other
			"wood_log": 20,
			"wood_plank": 10,
			"stone": 30,
			"herb": 15,
			"mana_crystal": 5,
			"leather": 12
		}
	}

# ============================================================================
# Таймеры и задержки
# ============================================================================

## Задержка для загрузки сцены (в секундах)
const SCENE_LOAD_DELAY = 0.05

## Длительность анимации перехода (в секундах)
const DEFAULT_TRANSITION_DURATION = 1.0

# ============================================================================
# Области и сцены
# ============================================================================

const DEFAULT_AREA = 1
const MIN_AREA = 1

# ============================================================================
# Утилитные функции
# ============================================================================

## Получает дефолтную позицию спавна для торговца.
##
## Args:
## 	player_position: Позиция игрока (опционально)
##
## Returns:
## 	Vector2: Позиция для спавна торговца
static func get_merchant_spawn_position(player_position: Vector2 = Vector2.ZERO) -> Vector2:
	if player_position != Vector2.ZERO:
		var pos = player_position + MERCHANT_OFFSET_FROM_PLAYER
		pos.y = MERCHANT_Y_POSITION
		return pos
	return DEFAULT_MERCHANT_POSITION

## Получает дефолтную позицию спавна врага.
##
## Returns:
## 	Vector2: Позиция для спавна врага
static func get_enemy_spawn_position() -> Vector2:
	return DEFAULT_ENEMY_SPAWN_POSITION

## Получает дефолтную позицию спавна игрока.
##
## Returns:
## 	Vector2: Позиция для спавна игрока
static func get_player_spawn_position() -> Vector2:
	return DEFAULT_PLAYER_SPAWN_POSITION

## Получает дефолтную позицию спавна минибосса.
##
## Returns:
## 	Vector2: Позиция для спавна минибосса
static func get_miniboss_spawn_position() -> Vector2:
	return DEFAULT_ENEMY_SPAWN_POSITION  # Используем дефолтную позицию врага

