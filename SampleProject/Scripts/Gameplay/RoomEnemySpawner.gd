extends Node2D
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

## Бій секції (D296): вороги зʼявляються, коли герой заходить у цю зону. Без зони бій запускає кімната
## (DesertRoad.gd, Village.gd …) або auto_spawn_on_ready.
@export var trigger_area: Area2D = null

## Ключ бою в Game.room_state (D152): у кімнаті з кількома боями — свій у кожного спавнера.
@export var state_key: String = "enemies"

## Список всех spawn points в комнате
var spawn_points: Array[EnemySpawnPoint] = []

## Список всех заспавненных врагов
var spawned_enemies: Array[Node] = []

## Бій цього спавнера в Game.room_state[state_key] (D152): {spawn_id: HP} живих ворогів; -1 — HP ще
## невідоме (ворог не встиг зʼявитись). Немає ключа — бій не починали. Вбитих у словнику немає.
## Імʼя кімнати MetSys — запамʼятовуємо одразу: під час вивантаження MetSys уже в іншій.
var _room: String

## Сигнал: все враги заспавнены
signal all_enemies_spawned()

## Сигнал: все враги убиты
signal all_enemies_defeated()

## Сигнал: волна врагов заспавнена
signal wave_spawned(wave_index: int, total_waves: int)

func _ready() -> void:
	"""Инициализация spawner"""
	# Точки шукаємо одразу: _ready() кімнати (DesertRoad тощо) іде після нашого
	# і може відразу почати бій. Раніше тут чекали кадр — і бій стартував без точок,
	# тобто без жодного ворога, але все одно зараховувався.
	_find_spawn_points()
	_room = MetSys.map_data.get_room_from_scene_path(get_parent().scene_file_path, false)
	for other in get_parent().get_children():
		if other != self and other is RoomEnemySpawner and other.state_key == state_key:
			push_error("RoomEnemySpawner: %s and %s share state_key '%s' in %s" % [name, other.name, state_key, _room])
	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger_body_entered)

	# Ждём следующий кадр чтобы комната полностью загрузилась
	await get_tree().process_frame

	# Автоспавн если включен
	if auto_spawn_on_ready:
		if global_spawn_delay > 0:
			await get_tree().create_timer(global_spawn_delay).timeout
		spawn_all_enemies()

	DebugLogger.info("RoomEnemySpawner: Initialized with %d spawn points" % spawn_points.size(), "RoomEnemySpawner")

func _find_spawn_points() -> void:
	"""Точки цього спавнера — його нащадки (у кімнаті може бути кілька боїв, D296)"""
	spawn_points.clear()
	_find_spawn_points_recursive(self)

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

	# Кого спавнити, вирішуємо до першого ворога: _track() одразу пише стан бою, і без
	# цього решта точок вважала б себе вже вбитими.
	var saved = Game.get_singleton().get_room_state(_room, state_key)
	var fight := {}
	for spawn_point in spawn_points:
		var spawn_now: bool = spawn_point.spawn_on_load if saved == null else saved.has(spawn_point.spawn_id)
		spawn_point.set_meta(&"spawn_now", spawn_now)
		if spawn_now:
			fight[spawn_point.spawn_id] = -1 if saved == null else saved[spawn_point.spawn_id]
	# Увесь бій — одразу в стан: інакше ворог із хвилі, що не встигла зʼявитись до виходу
	# з кімнати, вважався б убитим.
	Game.get_singleton().set_room_state(_room, state_key, fight)

	if spawn_in_waves:
		await _spawn_in_waves()
	else:
		# Без await: _spawn_immediately() не корутина (усередині немає жодного
		# await), тож Godot сварився REDUNDANT_AWAIT. _spawn_in_waves() корутина —
		# там await лишається.
		_spawn_immediately()

	all_enemies_spawned.emit()
	DebugLogger.info("RoomEnemySpawner: All enemies spawned (%d total)" % spawned_enemies.size(), "RoomEnemySpawner")

## Герой зайшов у зону бою секції — бій один раз за завантаження кімнати; добитий бій (порожній стан) не повертається.
func _on_trigger_body_entered(body: Node2D) -> void:
	if not body.is_in_group(GameGroups.PLAYER):
		return
	trigger_area.body_entered.disconnect(_on_trigger_body_entered)
	spawn_all_enemies()

## Бій уже йшов і гравець вийшов посеред нього — повертаємось без репліки (D152).
func fight_in_progress() -> bool:
	return Game.get_singleton().get_room_state(_room, state_key) != null

func _should_spawn(spawn_point: EnemySpawnPoint) -> bool:
	return spawn_point.get_meta(&"spawn_now")  # вбитих у збереженому стані вже немає

func _saved_enemies() -> Dictionary:
	return Game.get_singleton().get_room_state(_room, state_key, {})

func _save_hp(spawn_id: String, hp: int) -> void:
	var saved := _saved_enemies()
	saved[spawn_id] = hp
	Game.get_singleton().set_room_state(_room, state_key, saved)

func _spawn_immediately() -> void:
	"""Спавнит всех врагов сразу"""
	for spawn_point in spawn_points:
		if _should_spawn(spawn_point):
			var enemy = spawn_point.spawn_enemy()
			if enemy:
				spawned_enemies.append(enemy)
				_connect_enemy_signals(enemy)
				_track(enemy, spawn_point.spawn_id)

## HP ворога пишемо в стан кімнати при кожній зміні — тоді воно правильне і в сейві посеред
## бою, і після вивантаження кімнати. Збережене HP ставимо, коли ворог уже готовий
## (його _ready() виставляє повне HP зі статів).
func _track(enemy: Node, spawn_id: String) -> void:
	EventBus.enemy_spawned.emit(spawn_id, enemy.global_position)  # перший бій — підказка про атаку (TutorialManager)
	var hp: int = int(_saved_enemies().get(spawn_id, -1))
	_save_hp(spawn_id, hp)
	enemy.ready.connect(func() -> void:
		if hp > 0:
			enemy.current_health = hp
			enemy.health_changed.emit(hp, enemy.Max_Health, false)
		_save_hp(spawn_id, enemy.current_health)
		enemy.health_changed.connect(func(new_health: int, _max: int, _animate: bool) -> void:
			if new_health > 0:
				_save_hp(spawn_id, new_health))
		enemy.entity_died.connect(func() -> void:
			var saved := _saved_enemies()
			saved.erase(spawn_id)
			Game.get_singleton().set_room_state(_room, state_key, saved)),
		CONNECT_ONE_SHOT)

func _spawn_in_waves() -> void:
	"""Спавнит врагов волнами"""
	var total_waves = ceili(float(spawn_points.size()) / float(wave_size))
	var wave_index = 0

	for i in range(0, spawn_points.size(), wave_size):
		# Спавним волну
		var wave_end = mini(i + wave_size, spawn_points.size())
		for j in range(i, wave_end):
			var spawn_point = spawn_points[j]
			if _should_spawn(spawn_point):
				var enemy = spawn_point.spawn_enemy()
				if enemy:
					spawned_enemies.append(enemy)
					_connect_enemy_signals(enemy)
					_track(enemy, spawn_point.spawn_id)

		wave_index += 1
		wave_spawned.emit(wave_index, total_waves)
		DebugLogger.info("RoomEnemySpawner: Wave %d/%d spawned" % [wave_index, total_waves], "RoomEnemySpawner")

		# Ждём перед следующей волной (кроме последней)
		if wave_index < total_waves:
			await get_tree().create_timer(wave_delay).timeout

func _connect_enemy_signals(enemy: Node) -> void:
	"""Подключается к сигналам врага"""
	# B49: CombatBody2D сигналізує смерть через entity_died, не died
	enemy.entity_died.connect(_on_enemy_died.bind(enemy))

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
		if is_instance_valid(enemy) and enemy.is_alive():
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
