extends Node

## 🎯 PlayerTracker - Singleton для відстеження гравця
## Оптимізує пошук гравця для ворогів та інших систем
## Замість того, щоб кожен ворог шукав гравця через GameGroups,
## використовуємо один централізований трекер

## Посилання на гравця
var player: Node = null

## Кеш валідності гравця (оновлюється кожен кадр)
var _is_player_valid: bool = false

## Час останнього оновлення
var _last_update_time: float = 0.0

## Інтервал оновлення (секунди)
const UPDATE_INTERVAL: float = 0.1

func _ready() -> void:
	"""Ініціалізація PlayerTracker"""
	# Підключаємося до EventBus для відстеження появи/зникнення гравця
	if EventBus.has_signal("player_spawned"):
		EventBus.player_spawned.connect(_on_player_spawned)
	if EventBus.has_signal("player_died"):
		
		EventBus.player_died.connect(_on_player_died)

	# Шукаємо гравця при старті
	call_deferred("_find_player")

	DebugLogger.info("PlayerTracker: Initialized", "PlayerTracker")

func _process(_delta: float) -> void:
	"""Періодично перевіряємо валідність гравця"""
	var current_time = Time.get_ticks_msec() / 1000.0

	# Оновлюємо статус валідності з throttling
	if (current_time - _last_update_time) >= UPDATE_INTERVAL:
		_last_update_time = current_time
		_update_player_validity()

func get_player() -> Node:
	"""Отримує посилання на гравця (з автоматичним пошуком якщо потрібно)

	Returns:
		Node: Посилання на гравця або null
	"""
	# Якщо гравець невалідний, шукаємо знову
	if not _is_player_valid:
		_find_player()

	return player

func is_player_valid() -> bool:
	"""Перевіряє чи гравець валідний

	Returns:
		bool: true якщо гравець існує та валідний
	"""
	return _is_player_valid

func get_player_position() -> Vector2:
	"""Отримує позицію гравця

	Returns:
		Vector2: Позиція гравця або Vector2.ZERO
	"""
	if _is_player_valid and player is Node2D:
		return (player as Node2D).global_position
	return Vector2.ZERO

func _find_player() -> void:
	"""Знаходить гравця через GameGroups"""
	player = GameGroups.get_first_node_in_group(GameGroups.PLAYER)
	_update_player_validity()

	if _is_player_valid:
		DebugLogger.verbose("PlayerTracker: Player found at %s" % player.global_position if player is Node2D else "unknown", "PlayerTracker")

func _update_player_validity() -> void:
	"""Оновлює статус валідності гравця"""
	_is_player_valid = player != null and is_instance_valid(player)

func _on_player_spawned() -> void:
	"""Обробник появи гравця"""
	DebugLogger.info("PlayerTracker: Player spawned, updating reference", "PlayerTracker")
	_find_player()

func _on_player_died() -> void:
	"""Обробник смерті гравця"""
	DebugLogger.info("PlayerTracker: Player died, clearing reference", "PlayerTracker")
	player = null
	_is_player_valid = false

func _exit_tree() -> void:
	"""Відключаємося від EventBus при видаленні"""
	if EventBus.has_signal("player_spawned") and EventBus.player_spawned.is_connected(_on_player_spawned):
		EventBus.player_spawned.disconnect(_on_player_spawned)
	if EventBus.has_signal("player_died") and EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)
