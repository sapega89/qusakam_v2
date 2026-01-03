extends Node
class_name RoomEnemySpawner

## 🏠 RoomEnemySpawner - Управляет спавном врагов в комнате
## Автоматически находит все EnemySpawnPoint в комнате и спавнит врагов
## Добавьте этот скрипт как дочерний узел комнаты

## Автоматически спавнить врагов при загрузке комнаты
@export var auto_spawn_on_ready: bool = true

## Задержка перед спавном всех врагов (секунды)
@export var global_spawn_delay: float = 0.0

## Спавнить волнами (если true, спавнятся группами с задержкой)
@export var spawn_in_waves: bool = false

## Размер волны (количество врагов в одной волне)
@export var wave_size: int = 3

## Задержка между волнами (секунды)
@export var wave_delay: float = 2.0

## Контейнер для spawn points (если не задан, ищет по всей комнате)
@export var spawn_points_container: Node = null

## Список всех spawn points в комнате
var spawn_points: Array[EnemySpawnPoint] = []

## Список всех заспавненных врагов
var spawned_enemies: Array[Node] = []

## Сигнал: все враги заспавнены
signal all_enemies_spawned()

## Сигнал: все враги убиты
signal all_enemies_defeated()

## Сигнал: волна врагов заспавнена
signal wave_spawned(wave_index: int, total_waves: int)

func _ready() -> void:
	"""Инициализация spawner"""
	# Ждём следующий кадр чтобы комната полностью загрузилась
	await get_tree().process_frame

	# Находим все spawn points
	_find_spawn_points()

	# Автоспавн если включен
	if auto_spawn_on_ready:
		if global_spawn_delay > 0:
			await get_tree().create_timer(global_spawn_delay).timeout
		spawn_all_enemies()

	DebugLogger.info("RoomEnemySpawner: Initialized with %d spawn points" % spawn_points.size(), "RoomEnemySpawner")

func _find_spawn_points() -> void:
	"""Находит все EnemySpawnPoint в комнате"""
	spawn_points.clear()

	var search_root = spawn_points_container if spawn_points_container else get_parent()
	if not search_root:
		DebugLogger.error("RoomEnemySpawner: No search root found", "RoomEnemySpawner")
		return

	# Рекурсивный поиск всех spawn points
	_find_spawn_points_recursive(search_root)

	DebugLogger.info("RoomEnemySpawner: Found %d spawn points" % spawn_points.size(), "RoomEnemySpawner")

func _find_spawn_points_recursive(node: Node) -> void:
	"""Рекурсивно ищет spawn points в дереве"""
	# Проверяем текущий узел
	if node is EnemySpawnPoint:
		spawn_points.append(node)

	# Проверяем детей
	for child in node.get_children():
		_find_spawn_points_recursive(child)

func spawn_all_enemies() -> void:
	"""Спавнит всех врагов на всех spawn points"""
	if spawn_points.is_empty():
		DebugLogger.warning("RoomEnemySpawner: No spawn points found", "RoomEnemySpawner")
		all_enemies_spawned.emit()
		return

	if spawn_in_waves:
		await _spawn_in_waves()
	else:
		await _spawn_immediately()

	all_enemies_spawned.emit()
	DebugLogger.info("RoomEnemySpawner: All enemies spawned (%d total)" % spawned_enemies.size(), "RoomEnemySpawner")

func _spawn_immediately() -> void:
	"""Спавнит всех врагов сразу"""
	for spawn_point in spawn_points:
		if spawn_point.spawn_on_load:
			var enemy = spawn_point.spawn_enemy()
			if enemy:
				spawned_enemies.append(enemy)
				_connect_enemy_signals(enemy)

func _spawn_in_waves() -> void:
	"""Спавнит врагов волнами"""
	var total_waves = ceili(float(spawn_points.size()) / float(wave_size))
	var wave_index = 0

	for i in range(0, spawn_points.size(), wave_size):
		# Спавним волну
		var wave_end = mini(i + wave_size, spawn_points.size())
		for j in range(i, wave_end):
			var spawn_point = spawn_points[j]
			if spawn_point.spawn_on_load:
				var enemy = spawn_point.spawn_enemy()
				if enemy:
					spawned_enemies.append(enemy)
					_connect_enemy_signals(enemy)

		wave_index += 1
		wave_spawned.emit(wave_index, total_waves)
		DebugLogger.info("RoomEnemySpawner: Wave %d/%d spawned" % [wave_index, total_waves], "RoomEnemySpawner")

		# Ждём перед следующей волной (кроме последней)
		if wave_index < total_waves:
			await get_tree().create_timer(wave_delay).timeout

func _connect_enemy_signals(enemy: Node) -> void:
	"""Подключается к сигналам врага"""
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy))

func _on_enemy_died(enemy: Node) -> void:
	"""Обработчик смерти врага"""
	spawned_enemies.erase(enemy)
	DebugLogger.info("RoomEnemySpawner: Enemy died, %d remaining" % get_alive_enemies_count(), "RoomEnemySpawner")

	# Проверяем все ли враги убиты
	if get_alive_enemies_count() == 0:
		all_enemies_defeated.emit()
		DebugLogger.info("RoomEnemySpawner: All enemies defeated!", "RoomEnemySpawner")

func get_alive_enemies_count() -> int:
	"""Возвращает количество живых врагов"""
	var count = 0
	for enemy in spawned_enemies:
		if is_instance_valid(enemy) and enemy.has_method("is_alive"):
			if enemy.is_alive():
				count += 1
		elif is_instance_valid(enemy):
			count += 1
	return count

func despawn_all_enemies() -> void:
	"""Удаляет всех заспавненных врагов"""
	for spawn_point in spawn_points:
		spawn_point.despawn_enemy()

	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()

	spawned_enemies.clear()
	DebugLogger.info("RoomEnemySpawner: All enemies despawned", "RoomEnemySpawner")

func respawn_all_enemies() -> void:
	"""Респавнит всех врагов (удаляет и создаёт заново)"""
	despawn_all_enemies()
	await get_tree().process_frame
	spawn_all_enemies()
