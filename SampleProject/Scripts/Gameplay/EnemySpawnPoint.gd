extends Node2D
class_name EnemySpawnPoint

## 🎯 EnemySpawnPoint - Маркер для спавна врагов
## Размещается в комнате и указывает где и какой тип врага должен появиться
## Используется RoomEnemySpawner для автоматического создания врагов

## Тип врага для спавна
@export_enum("melee", "tank", "fast", "ranged") var enemy_type: String = "melee"

## Спавнить при загрузке комнаты (если false, нужно вызвать spawn() вручную)
@export var spawn_on_load: bool = true

## Задержка перед спавном (секунды)
@export var spawn_delay: float = 0.0

## Ресурс с кастомными настройками врага (опционально)
@export var custom_enemy_stats: Resource = null

## Спавнить только один раз (если true, после смерти врага больше не спавнится)
@export var spawn_once: bool = true

## ID спавн поинта (для отслеживания состояния)
@export var spawn_id: String = ""

## Патрульные точки для врага (опционально)
@export var patrol_points: Array[Vector2] = []

## Спавненый враг (ссылка)
var spawned_enemy: Node = null

## Флаг был ли враг уже заспавнен
var has_spawned: bool = false

func _ready() -> void:
	"""Инициализация spawn point"""
	# Генерируем ID если не задан
	if spawn_id.is_empty():
		# String(...) навколо обох гілок: Node.name це StringName, а "unknown" —
		# String, і Godot сварився INCOMPATIBLE_TERNARY на різних типах.
		spawn_id = "%s_%s" % [String(get_parent().name) if get_parent() else "unknown", String(name)]

	# Добавляем в группу для удобного поиска
	add_to_group("enemy_spawn_points")

	# В редакторе показываем иконку маркера
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	"""Рисуем визуальный маркер в редакторе"""
	if Engine.is_editor_hint():
		# Рисуем крест для визуализации позиции
		var color := Color.RED
		match enemy_type:
			"melee": color = Color.RED
			"tank": color = Color.BLUE
			"fast": color = Color.GREEN
			"ranged": color = Color.YELLOW

		# Крест
		draw_line(Vector2(-10, 0), Vector2(10, 0), color, 2.0)
		draw_line(Vector2(0, -10), Vector2(0, 10), color, 2.0)
		# Круг
		draw_circle(Vector2.ZERO, 15, Color(color, 0.3))

func spawn_enemy() -> Node:
	"""Спавнит врага на этой позиции"""
	if has_spawned and spawn_once:
		DebugLogger.warning("EnemySpawnPoint: Spawn point %s already spawned and is set to spawn_once" % spawn_id, "EnemySpawnPoint")
		return null

	# Загружаем сцену врага
	var enemy_scene = load("res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn")
	if not enemy_scene:
		DebugLogger.error("EnemySpawnPoint: Failed to load enemy scene", "EnemySpawnPoint")
		return null

	# Создаём экземпляр
	var enemy = enemy_scene.instantiate()
	if not enemy:
		DebugLogger.error("EnemySpawnPoint: Failed to instantiate enemy", "EnemySpawnPoint")
		return null

	# Устанавливаем позицию
	enemy.global_position = global_position

	# Применяем тип врага (загружаем соответствующий EnemyStats ресурс)
	if custom_enemy_stats:
		# Используем кастомный ресурс если задан
		enemy.enemy_stats = custom_enemy_stats
	else:
		# Загружаем стандартный ресурс по типу
		var stats_path := ""
		match enemy_type:
			"melee":
				stats_path = "res://SampleProject/Resources/Enemies/enemy_stats_melee.tres"
			"tank":
				stats_path = "res://SampleProject/Resources/Enemies/enemy_stats_tank.tres"
			"fast":
				stats_path = "res://SampleProject/Resources/Enemies/enemy_stats_fast.tres"
			"ranged":
				# TODO: Create ranged enemy stats
				stats_path = "res://SampleProject/Resources/Enemies/enemy_stats_melee.tres"

		if ResourceLoader.exists(stats_path):
			enemy.enemy_stats = load(stats_path)

	# Устанавливаем уникальное имя для отслеживания
	enemy.name = "Enemy_%s" % spawn_id

	# Добавляем врага в сцену
	var room = get_parent()
	if room:
		room.add_child(enemy)
	else:
		DebugLogger.error("EnemySpawnPoint: No parent room found for spawn point %s" % spawn_id, "EnemySpawnPoint")
		enemy.queue_free()
		return null

	# Подключаемся к сигналу смерти врага
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)

	# Сохраняем ссылку и помечаем что заспавнили
	spawned_enemy = enemy
	has_spawned = true

	DebugLogger.info("EnemySpawnPoint: Spawned %s enemy at %s (spawn_id: %s)" % [enemy_type, global_position, spawn_id], "EnemySpawnPoint")

	return enemy

func _on_enemy_died() -> void:
	"""Обработчик смерти врага"""
	DebugLogger.info("EnemySpawnPoint: Enemy died at spawn point %s" % spawn_id, "EnemySpawnPoint")
	spawned_enemy = null

	# Если spawn_once = false, можно респавнить врага позже
	if not spawn_once:
		has_spawned = false

func despawn_enemy() -> void:
	"""Удаляет заспавненного врага"""
	if spawned_enemy and is_instance_valid(spawned_enemy):
		spawned_enemy.queue_free()
		spawned_enemy = null
	has_spawned = false

func is_enemy_alive() -> bool:
	"""Проверяет жив ли заспавненный враг"""
	return spawned_enemy != null and is_instance_valid(spawned_enemy)
