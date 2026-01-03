extends RefCounted
class_name GameGroups

## 🏷️ GameGroups - Централизованные константы для групп узлов
##
## Предоставляет:
## - Константы для всех групп узлов в проекте
## - Типизированные методы для работы с группами
## - Централизованное управление именами групп
## - Кэширование результатов поиска для оптимизации
##
## Соответствует лучшим практикам Godot 4.5.
## Использование констант вместо строк предотвращает опечатки и упрощает рефакторинг.

# Кэш для результатов поиска узлов (статический)
# Используем Dictionary без типизации для вложенных коллекций (ограничение Godot 4.5)
static var _nodes_cache: Dictionary = {}
static var _first_node_cache: Dictionary = {}
static var _cache_timestamps: Dictionary = {}
static var _cache_duration: float = 0.1  # Кэш обновляется каждые 0.1 секунды

# Player groups
const PLAYER = "player"

# Enemy groups
const ENEMIES = "enemies"
const BOSS = "boss"
const MINIBOSS = "miniboss"

# UI groups
const UI_CANVAS = "ui_canvas"
const HEALTH_BAR = "health_bar"
const POTION_UI = "potion_ui"
const SKILL_POINTS_UI = "skill_points_ui"
const UI_ELEMENTS = "ui_elements"

# Scene groups
const AREA_EXIT = "area_exit"
const LOCATION_MANAGER = "location_manager"
const PARALLAX_MANAGER = "parallax_manager"

# Combat groups
const COMBATANTS = "combatants"

# Merchant groups
const MERCHANT = "merchant"

# Portal groups
const BOSS_SPAWN_PORTALS = "boss_spawn_portals"
const SPAWN_PORTALS = "spawn_portals"

## Проверяет, существует ли группа в ProjectSettings.
##
## Args:
##     group_name: Имя группы для проверки
##
## Returns:
##     bool: true, если группа существует в настройках проекта
static func has_group(group_name: String) -> bool:
	return ProjectSettings.has_setting("groups/" + group_name)

## Получает все узлы в группе (типизированный вариант) с кэшированием.
##
## Args:
##     group_name (String): Имя группы (рекомендуется использовать константы: GameGroups.PLAYER, etc.)
##     force_refresh (bool, optional): Если true, принудительно обновляет кэш (по умолчанию false)
##
## Returns:
##     Array[Node]: Массив всех узлов в группе. Типизирован для лучшей безопасности типов.
##                  Возвращает пустой массив, если группа не существует или пуста.
##
## Примеры:
##     # Получить всех врагов
##     var enemies = GameGroups.get_nodes_in_group(GameGroups.ENEMIES)
##     
##     # Принудительно обновить кэш
##     var fresh_enemies = GameGroups.get_nodes_in_group(GameGroups.ENEMIES, true)
##     
##     # Получить всех игроков (обычно один)
##     var players = GameGroups.get_nodes_in_group(GameGroups.PLAYER)
static func get_nodes_in_group(group_name: String, force_refresh: bool = false) -> Array[Node]:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Проверяем кэш
	if not force_refresh and _nodes_cache.has(group_name):
		var cached_nodes_raw = _nodes_cache[group_name]
		var cached_nodes: Array[Node] = []
		if cached_nodes_raw is Array:
			for node in cached_nodes_raw:
				if is_instance_valid(node) and node is Node:
					cached_nodes.append(node)
		var cache_time = _cache_timestamps.get(group_name, 0.0)
		
		# Проверяем валидность кэша (время и валидность узлов)
		if (current_time - cache_time) < _cache_duration:
			# Фильтруем невалидные узлы
			var valid_nodes: Array[Node] = []
			for node in cached_nodes:
				if is_instance_valid(node) and node.is_inside_tree():
					valid_nodes.append(node)
			
			# Если все узлы валидны, возвращаем кэш
			if valid_nodes.size() == cached_nodes.size():
				return valid_nodes
			# Если некоторые узлы невалидны, обновляем кэш
			_nodes_cache[group_name] = valid_nodes
	
	# Обновляем кэш
	var nodes: Array[Node] = []
	if Engine.get_main_loop() is SceneTree:
		var tree = Engine.get_main_loop() as SceneTree
		nodes.assign(tree.get_nodes_in_group(group_name))
	
	_nodes_cache[group_name] = nodes
	_cache_timestamps[group_name] = current_time
	return nodes

## Получает первый узел в группе с кэшированием.
##
## Args:
##     group_name (String): Имя группы (рекомендуется использовать константы: GameGroups.PLAYER, etc.)
##     force_refresh (bool, optional): Если true, принудительно обновляет кэш (по умолчанию false)
##
## Returns:
##     Node: Первый узел в группе или null, если группа пуста или не существует.
##          Возвращает null, если группа не найдена или все узлы невалидны.
##
## Примеры:
##     # Получить игрока
##     var player = GameGroups.get_first_node_in_group(GameGroups.PLAYER)
##     if player:
##         print("Player found: ", player.name)
##     
##     # Получить первый торговец с обновлением кэша
##     var merchant = GameGroups.get_first_node_in_group(GameGroups.MERCHANT, true)
static func get_first_node_in_group(group_name: String, force_refresh: bool = false) -> Node:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Проверяем кэш
	if not force_refresh and _first_node_cache.has(group_name):
		var cached_node_raw = _first_node_cache[group_name]
		var cached_node: Node = null
		if is_instance_valid(cached_node_raw) and cached_node_raw is Node:
			cached_node = cached_node_raw
		var cache_time = _cache_timestamps.get("first_" + group_name, 0.0)
		
		# Проверяем валидность кэша
		if (current_time - cache_time) < _cache_duration:
			if is_instance_valid(cached_node) and cached_node.is_inside_tree():
				return cached_node
			# Узел невалиден, очищаем кэш
			_first_node_cache.erase(group_name)
	
	# Обновляем кэш
	var node: Node = null
	if Engine.get_main_loop() is SceneTree:
		var tree = Engine.get_main_loop() as SceneTree
		node = tree.get_first_node_in_group(group_name)
	
	if node:
		_first_node_cache[group_name] = node
		_cache_timestamps["first_" + group_name] = current_time
	
	return node

## Очищает кэш для указанной группы.
##
## Args:
##     group_name (String, optional): Имя группы для очистки кэша. Если пусто, очищает весь кэш.
##
## Returns:
##     void
##
## Примеры:
##     # Очистить кэш для врагов
##     GameGroups.clear_cache(GameGroups.ENEMIES)
##     
##     # Очистить весь кэш (при смене сцены)
##     GameGroups.clear_cache()
static func clear_cache(group_name: String = "") -> void:
	if group_name.is_empty():
		_nodes_cache.clear()
		_first_node_cache.clear()
		_cache_timestamps.clear()
	else:
		_nodes_cache.erase(group_name)
		_first_node_cache.erase(group_name)
		_cache_timestamps.erase(group_name)
		_cache_timestamps.erase("first_" + group_name)

## Инвалидирует кэш для указанной группы (помечает как устаревший).
##
## Args:
##     group_name (String): Имя группы для инвалидации кэша
##
## Returns:
##     void
##
## Примечание:
##     Кэш будет автоматически обновлен при следующем запросе. Используйте для
##     уведомления системы о том, что состав группы мог измениться.
##
## Примеры:
##     # Инвалидировать кэш после спавна врага
##     GameGroups.invalidate_cache(GameGroups.ENEMIES)
##     
##     # Инвалидировать кэш после удаления игрока
##     GameGroups.invalidate_cache(GameGroups.PLAYER)
static func invalidate_cache(group_name: String) -> void:
	if _cache_timestamps.has(group_name):
		_cache_timestamps[group_name] = 0.0
	if _cache_timestamps.has("first_" + group_name):
		_cache_timestamps["first_" + group_name] = 0.0

## Получает игрока через централизованный доступ с кэшированием.
##
## Returns:
##     Node: Узел игрока или null, если игрок не найден или невалиден.
##
## Примечание:
##     Использует кэширование для оптимизации. Рекомендуется использовать этот метод
##     вместо прямых вызовов get_tree().get_first_node_in_group("player").
##
## Примеры:
##     var player = GameGroups.get_player()
##     if player:
##         print("Player found: ", player.name)
static func get_player() -> Node:
	"""Получает игрока через централизованный доступ с кэшированием"""
	return get_first_node_in_group(PLAYER)

## Получает всех врагов через централизованный доступ с кэшированием.
##
## Returns:
##     Array[Node]: Массив всех врагов или пустой массив, если враги не найдены.
##
## Примеры:
##     var enemies = GameGroups.get_enemies()
##     for enemy in enemies:
##         print("Enemy found: ", enemy.name)
static func get_enemies() -> Array[Node]:
	"""Получает всех врагов через централизованный доступ с кэшированием"""
	return get_nodes_in_group(ENEMIES)

## Получает босса через централизованный доступ с кэшированием.
##
## Returns:
##     Node: Узел босса или null, если босс не найден.
##
## Примеры:
##     var boss = GameGroups.get_boss()
##     if boss:
##         print("Boss found: ", boss.name)
static func get_boss() -> Node:
	"""Получает босса через централизованный доступ с кэшированием"""
	return get_first_node_in_group(BOSS)

## Получает мини-босса через централизованный доступ с кэшированием.
##
## Returns:
##     Node: Узел мини-босса или null, если мини-босс не найден.
static func get_miniboss() -> Node:
	"""Получает мини-босса через централизованный доступ с кэшированием"""
	return get_first_node_in_group(MINIBOSS)

## Получает торговца через централизованный доступ с кэшированием.
##
## Returns:
##     Node: Узел торговца или null, если торговец не найден.
##
## Примеры:
##     var merchant = GameGroups.get_merchant()
##     if merchant:
##         print("Merchant found: ", merchant.name)
static func get_merchant() -> Node:
	"""Получает торговца через централизованный доступ с кэшированием"""
	return get_first_node_in_group(MERCHANT)

## Получает UI Canvas через централизованный доступ с кэшированием.
##
## Returns:
##     Node: Узел UI Canvas или null, если не найден.
static func get_ui_canvas() -> Node:
	"""Получает UI Canvas через централизованный доступ с кэшированием"""
	return get_first_node_in_group(UI_CANVAS)

## Получает Health Bar через централизованный доступ с кэшированием.
##
## Returns:
##     Node: Узел Health Bar или null, если не найден.
##
## Примеры:
##     var health_bar = GameGroups.get_health_bar()
##     if health_bar:
##         print("Health bar found: ", health_bar.name)
static func get_health_bar() -> Node:
	"""Получает Health Bar через централизованный доступ с кэшированием"""
	return get_first_node_in_group(HEALTH_BAR)

## Получает Potion UI через централизованный доступ с кэшированием.
##
## Returns:
##     Node: Узел Potion UI или null, если не найден.
static func get_potion_ui() -> Node:
	"""Получает Potion UI через централизованный доступ с кэшированием"""
	return get_first_node_in_group(POTION_UI)

## Получает Skill Points UI через централизованный доступ с кэшированием.
##
## Returns:
##     Node: Узел Skill Points UI или null, если не найден.
static func get_skill_points_ui() -> Node:
	"""Получает Skill Points UI через централизованный доступ с кэшированием"""
	return get_first_node_in_group(SKILL_POINTS_UI)

## Получает все UI элементы через централизованный доступ с кэшированием.
##
## Returns:
##     Array[Node]: Массив всех UI элементов или пустой массив, если не найдены.
static func get_ui_elements() -> Array[Node]:
	"""Получает все UI элементы через централизованный доступ с кэшированием"""
	return get_nodes_in_group(UI_ELEMENTS)

## Получает все порталы выхода через централизованный доступ с кэшированием.
##
## Returns:
##     Array[Node]: Массив всех порталов выхода или пустой массив, если не найдены.
static func get_area_exits() -> Array[Node]:
	"""Получает все порталы выхода через централизованный доступ с кэшированием"""
	return get_nodes_in_group(AREA_EXIT)

## Получает LocationManager через централизованный доступ с кэшированием.
##
## Returns:
##     Node: Узел LocationManager или null, если не найден.
static func get_location_manager() -> Node:
	"""Получает LocationManager через централизованный доступ с кэшированием"""
	return get_first_node_in_group(LOCATION_MANAGER)

## Получает все порталы спавна боссов через централизованный доступ с кэшированием.
##
## Returns:
##     Array[Node]: Массив всех порталов спавна боссов или пустой массив, если не найдены.
static func get_boss_spawn_portals() -> Array[Node]:
	"""Получает все порталы спавна боссов через централизованный доступ с кэшированием"""
	return get_nodes_in_group(BOSS_SPAWN_PORTALS)

## Получает все порталы спавна через централизованный доступ с кэшированием.
##
## Returns:
##     Array[Node]: Массив всех порталов спавна или пустой массив, если не найдены.
static func get_spawn_portals() -> Array[Node]:
	"""Получает все порталы спавна через централизованный доступ с кэшированием"""
	return get_nodes_in_group(SPAWN_PORTALS)

