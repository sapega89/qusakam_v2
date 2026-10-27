extends Node2D
class_name RoomEnemySpawner

const EnemyVariety := preload("res://SampleProject/Scripts/Gameplay/EnemyVariety.gd")
const LocationDB := preload("res://SampleProject/Scripts/Systems/LocationDB.gd")

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

## D492: звичайний бій — вороги повертаються, коли герой медитує (D447) або повертається в регіон, з якого пішов.
## Боси й сюжетні бої (false) памʼятають своїх убитих назавжди (D152).
@export var respawns: bool = false

## D642: рівень ворогів бою — рівень, на якому герой сюди доходить (verify_difficulty бере його з XP-кривої).
@export var enemy_level: int = 1

## D583: здобич бою — item_id → кількість, дається один раз, коли бій добито вперше (стан кімнати
## <state_key>_reward, у сейві); повернення ворогів (D492) її не повторює. Порожньо — без здобичі.
@export var reward: Dictionary[String, int] = {}

## D817: досвід за перемогу над усім боєм, понад досвід його ворогів, — щоразу, як бій добито (і після повернення
## ворогів, D492). Групи дороги стали меншими (не більше трьох), а дорога дає той самий досвід, що й до того (D297).
@export var win_xp: int = 0

## Список всех spawn points в комнате
var spawn_points: Array[EnemySpawnPoint] = []

## Список всех заспавненных врагов
var spawned_enemies: Array[Node] = []

## D817: цей запуск бою ще спавнить хвилі / скільки його ворогів убито / чи вже заплатив win_xp.
var _spawning := false
var _killed := 0
var _win_paid := false

## Бій цього спавнера в Game.room_state[state_key] (D152): {spawn_id: HP} живих ворогів; -1 — HP ще
## невідоме (ворог не встиг зʼявитись). Немає ключа — бій не починали. Вбитих у словнику немає.
## Імʼя кімнати MetSys — запамʼятовуємо одразу: під час вивантаження MetSys уже в іншій.
var _room: String
## D492: регіон кімнати (лише для respawns) і чи цей бій ще пишеться в стан: після медитації посеред кімнати
## живі вороги й решта хвиль старого бою більше не пишуть HP і смерть — наступний вхід почне бій спочатку.
var _region: String
var _recording := true

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
	if respawns:
		_region = LocationDB.of_scene(get_parent().scene_file_path)
		Game.get_singleton().ordinary_fights_reset.connect(_on_ordinary_fights_reset)

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
	_recording = true
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
	if respawns:
		Game.get_singleton().register_ordinary_fight(_room, state_key, _region)

	_spawning = true
	_killed = 0
	_win_paid = false
	if spawn_in_waves:
		await _spawn_in_waves()
	else:
		# Без await: _spawn_immediately() не корутина (усередині немає жодного
		# await), тож Godot сварився REDUNDANT_AWAIT. _spawn_in_waves() корутина —
		# там await лишається.
		_spawn_immediately()
	_spawning = false
	_pay_win_xp()  # останнього вбили, поки чекала порожня хвиля

	all_enemies_spawned.emit()
	DebugLogger.info("RoomEnemySpawner: All enemies spawned (%d total)" % spawned_enemies.size(), "RoomEnemySpawner")

## Герой зайшов у зону бою секції — бій один раз за завантаження кімнати; добитий бій (порожній стан) не повертається.
func _on_trigger_body_entered(body: Node2D) -> void:
	if not body.is_in_group(GameGroups.PLAYER):
		return
	trigger_area.body_entered.disconnect(_on_trigger_body_entered)
	# D737: посеред розмови бій не починається (вороги били б героя, якого тримає розмова) — після неї, якщо герой
	# ще в зоні; вийшов — зона знову чекає входу.
	ServiceLocator.get_dialogue_manager().when_story_free_inside(trigger_area, spawn_all_enemies,
			func() -> void: trigger_area.body_entered.connect(_on_trigger_body_entered))

## Бій уже йшов і гравець вийшов посеред нього — повертаємось без репліки (D152).
func fight_in_progress() -> bool:
	return Game.get_singleton().get_room_state(_room, state_key) != null

## Бій добито: його починали, і живих у ньому не лишилось (D296, D306).
func fight_cleared() -> bool:
	return fight_in_progress() and _saved_enemies().is_empty()

## D492: у room_state — «цей звичайний бій уже колись добито» (Game.reset_ordinary_fights ставить, коли бій повертається).
const WON_SUFFIX := "_won"

## Бій добито зараз або колись до повернення ворогів (D492) — для сюжету, що чекає перемоги.
func fight_won() -> bool:
	return fight_cleared() or Game.get_singleton().get_room_state(_room, state_key + WON_SUFFIX, false)

func _should_spawn(spawn_point: EnemySpawnPoint) -> bool:
	return spawn_point.get_meta(&"spawn_now")  # вбитих у збереженому стані вже немає

func _saved_enemies() -> Dictionary:
	return Game.get_singleton().get_room_state(_room, state_key, {})

func _save_hp(spawn_id: String, hp: int) -> void:
	if not _recording:
		return
	var saved := _saved_enemies()
	saved[spawn_id] = hp
	Game.get_singleton().set_room_state(_room, state_key, saved)

func _spawn_immediately() -> void:
	"""Спавнит всех врагов сразу"""
	for spawn_point in spawn_points:
		if _should_spawn(spawn_point):
			_spawn(spawn_point)

func _spawn(spawn_point: EnemySpawnPoint) -> void:
	var enemy = spawn_point.spawn_enemy()
	if enemy:
		# Ворог додається відкладено (EnemySpawnPoint.spawn_enemy) — розмір і рівень встигають до його _ready();
		# еліта — властивість виду (D652), ворог бере її сам.
		enemy.size_kind = variant_size(spawn_point)
		enemy.level = enemy_level
		spawned_enemies.append(enemy)
		_connect_enemy_signals(enemy)
		_track(enemy, spawn_point.spawn_id)

## Розмір ворога точки (D560): заданий — як є; auto — кидок за вагами виду у звичайному бою, medium у сюжетному.
func variant_size(spawn_point: EnemySpawnPoint) -> String:
	if spawn_point.size != "auto":
		return spawn_point.size
	return EnemyVariety.roll_size(spawn_point.kind(), _variant_key(spawn_point)) if respawns else "medium"

## Ключ кидків: кімната й точка — кімната щоразу та сама (D560).
func _variant_key(spawn_point: EnemySpawnPoint) -> String:
	return "%s/%s" % [_room, spawn_point.spawn_id]

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
			if not _recording:
				return
			var saved := _saved_enemies()
			saved.erase(spawn_id)
			Game.get_singleton().set_room_state(_room, state_key, saved)),
		CONNECT_ONE_SHOT)

## D492: бій цього спавнера повернувся — далі він живе лише до виходу з кімнати.
func _on_ordinary_fights_reset(region: String) -> void:
	if region == "" or region == _region:
		_recording = false

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
				_spawn(spawn_point)

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
	enemy.ready.connect(func() -> void: enemy.enemy_logic.state_changed.connect(_rouse.bind(enemy)), CONNECT_ONE_SHOT)

## Бій — одна група (D754): хто з ворогів бою кинувся на героя, той піднімає решту, і вони не чекають, доки герой
## підійде до кожного по черзі.
## Стан — int: тип EnemyLogic тут замкнув би коло залежностей (ServiceLocator → … → спавнер → EnemyLogic → PlayerCombat).
func _rouse(state: int, enemy: Node) -> void:
	var states: Dictionary = enemy.enemy_logic.AIState
	if state != states.CHASE:
		return
	for other: Node in spawned_enemies:
		if other != enemy and is_instance_valid(other) and other.is_alive() \
				and other.enemy_logic.current_state in [states.IDLE, states.RETURN_HOME]:
			other.enemy_logic.change_state(states.CHASE)

func _on_enemy_died(enemy: Node) -> void:
	"""Обработчик смерти врага"""
	spawned_enemies.erase(enemy)
	_killed += 1
	DebugLogger.info("RoomEnemySpawner: Enemy died, %d remaining" % get_alive_enemies_count(), "RoomEnemySpawner")

	# Проверяем все ли враги убиты
	if get_alive_enemies_count() == 0:
		all_enemies_defeated.emit()
		DebugLogger.info("RoomEnemySpawner: All enemies defeated!", "RoomEnemySpawner")
	if not reward.is_empty():
		_grant_reward.call_deferred()  # після того, як _track() викреслив убитого зі стану бою
	_pay_win_xp()

## D817: бій добито в цьому запуску — усі хвилі вийшли, живих немає — win_xp герою, один раз за запуск.
func _pay_win_xp() -> void:
	if win_xp == 0 or _spawning or _win_paid or _killed == 0 or not spawned_enemies.is_empty():
		return
	_win_paid = true
	ServiceLocator.get_xp_manager().add_xp(win_xp)

const REWARD_SUFFIX := "_reward"

## Бій добито вперше — здобич в інвентар і модалка «You obtained».
func _grant_reward() -> void:
	var game := Game.get_singleton()
	if not fight_cleared() or game.get_room_state(_room, state_key + REWARD_SUFFIX, false):
		return
	game.set_room_state(_room, state_key + REWARD_SUFFIX, true)
	var inventory: InventoryManager = ServiceLocator.get_inventory_manager()
	for item_id: String in reward:
		inventory.add_item(item_id, reward[item_id])
	ServiceLocator.get_ui_manager().show_obtained(reward)

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
