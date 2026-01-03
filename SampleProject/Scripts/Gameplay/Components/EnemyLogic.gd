extends Node
class_name EnemyLogic

## 🧠 EnemyLogic - Логіка симуляції ворога
## Відповідає за: AI, рух, бій, стан
## НЕ відповідає за: анімації, спрайти, візуальні ефекти
## Дотримується принципу розділення Simulation & View

# Посилання на ворога
var enemy: CharacterBody2D = null

# Стан руху
var velocity: Vector2 = Vector2.ZERO
var is_on_floor: bool = false

# AI стан
enum AIState {
	IDLE,
	CHASE,
	ATTACK,
	RETREAT,  # Відступлення
	RETURN_HOME,  # Повернення на позицію спавну (leash)
}

var current_state: AIState = AIState.IDLE
var state_timer: float = 0.0

# Тактичні параметри
var speed: float = 70.0
var detection_range: float = 300.0
var attack_range: float = 100.0
var chase_range: float = 400.0
var leash_range: float = 600.0  # Максимальна відстань від спавну по X
var return_home_speed: float = 55.0
var lost_player_timer: float = 0.0
var max_lost_time: float = 3.0

# Параметри відступлення
var retreat_distance: float = 150.0  # Відстань відступу
var retreat_speed: float = 50.0  # Швидкість відступу
var retreat_timer: float = 0.0
var retreat_duration: float = 1.0  # Тривалість відступу
var retreat_target_position: Vector2 = Vector2.ZERO  # Цільова позиція відступу

# Кулдауни
var chase_cooldown: float = 2.0  # Кулдаун перед початком переслідування
var chase_cooldown_timer: float = 0.0
var last_chase_time: float = 0.0

# Бойові параметри
var base_damage: float = 10.0
var damage: float = 10.0
var last_attack_time: float = 0.0
var attack_cooldown: float = 1.5

# Raycast для виявлення гравця
var raycast_enabled: bool = true
var raycast_angles: Array[float] = [-45.0, -30.0, -15.0, 0.0, 15.0, 30.0, 45.0]  # Кути для raycast
var raycast_range: float = 300.0
var raycast_timer: float = 0.0  # Таймер для throttling raycast
var raycast_interval: float = 0.1  # Інтервал між raycast перевірками (секунди)
var last_raycast_result: bool = false  # Результат останнього raycast

# Посилання на гравця
var player: Node = null
var player_in_area: bool = false
var last_direction: int = 0  # Для відстеження зміни напрямку
var player_detected_via_raycast: bool = false

# Позиція "дому" (спавн), щоб ворога можна було пробігати повз без arena-lock
var home_position: Vector2 = Vector2.ZERO

# Сигнали для View
signal state_changed(new_state: AIState)
signal direction_changed(direction: int)  # -1 left, 1 right, 0 none
signal attack_started()
signal attack_ended()
signal player_detected()
signal player_lost()

func _ready():
	"""Ініціалізація EnemyLogic"""
	DebugLogger.info("EnemyLogic: Initialized", "EnemyLogic")

func initialize(enemy_node: CharacterBody2D):
	"""Ініціалізує EnemyLogic з посиланням на ворога"""
	enemy = enemy_node
	if not enemy:
		push_error("❌ EnemyLogic: Enemy node is null!")
		return
	
	# Отримуємо параметри з ворога (якщо вони є)
	if enemy.has_method("get_enemy_params"):
		var params = enemy.get_enemy_params()
		speed = params.get("speed", 70.0)
		detection_range = params.get("detection_range", 300.0)
		attack_range = params.get("attack_range", 100.0)
		chase_range = params.get("chase_range", 400.0)
		base_damage = params.get("base_damage", 10.0)
		damage = base_damage
		leash_range = params.get("leash_range", max(chase_range * 1.5, 450.0))
		return_home_speed = params.get("return_home_speed", max(speed * 0.8, 40.0))

	# Запам'ятовуємо позицію спавну
	home_position = enemy.global_position

	# Знаходимо гравця через GameGroups
	player = GameGroups.get_player()

	DebugLogger.info("EnemyLogic: Initialized with enemy: %s" % enemy.name, "EnemyLogic")

func process_physics(delta: float) -> Vector2:
	"""Обробляє фізику та повертає нову швидкість"""
	if not enemy:
		return Vector2.ZERO
	
	# Оновлюємо стан
	is_on_floor = enemy.is_on_floor()
	
	# Оновлюємо таймери
	state_timer += delta
	lost_player_timer += delta
	chase_cooldown_timer += delta
	retreat_timer += delta
	raycast_timer += delta

	# Обробляємо AI
	process_ai(delta)

	# Применяем гравитацию - враги должны падать на платформы
	# Сохраняем Y компонент velocity для гравитации (устанавливается в DefaultEnemy._physics_process)
	# НЕ обнуляем velocity.y - иначе враги будут висеть в воздухе!

	return velocity

func process_ai(delta: float):
	"""Обробляє AI ворога"""
	if not enemy or not is_instance_valid(enemy):
		return
	
	# Перевіряємо, чи ворог мертвий
	if enemy.has_method("is_dead") and enemy.is_dead:
		velocity = Vector2.ZERO
		return
	
	# Якщо гравець не знайдений, намагаємося знайти його через GameGroups
	if not player or not is_instance_valid(player):
		player = GameGroups.get_player()

	# Основний AI цикл
	match current_state:
		AIState.IDLE:
			handle_idle_state(delta)
		AIState.CHASE:
			handle_chase_state(delta)
		AIState.ATTACK:
			handle_attack_state(delta)
		AIState.RETREAT:
			handle_retreat_state(delta)
		AIState.RETURN_HOME:
			handle_return_home_state(delta)

	# Дебаг: виводимо стан кожні 60 кадрів
	if Engine.get_process_frames() % 60 == 0:
		var state_name = AIState.keys()[current_state] if current_state < AIState.keys().size() else "UNKNOWN"
		var _player_pos = player.global_position if player and is_instance_valid(player) else Vector2.ZERO
		var enemy_pos = enemy.global_position if enemy and is_instance_valid(enemy) else Vector2.ZERO
		var distance = enemy_pos.distance_to(_player_pos) if _player_pos != Vector2.ZERO else 0.0
		DebugLogger.verbose("EnemyLogic: State=%s, Velocity=%s, Distance to player=%.1f" % [state_name, velocity, distance], "EnemyLogic")

func handle_idle_state(_delta: float):
	"""Обробляє стан очікування"""
	velocity.x = 0

	# Якщо ворог з якихось причин від'їхав від спавну — повертаємо його назад
	if abs(enemy.global_position.x - home_position.x) > 10.0:
		change_state(AIState.RETURN_HOME)
		return
	
	# Перевіряємо, чи повинен ворог переслідувати гравця на основі HP
	if not should_chase_player():
		return
	
	# Перевіряємо кулдаун переслідування
	if chase_cooldown_timer < chase_cooldown:
		return
	
	# Використовуємо raycast для виявлення гравця (з throttling)
	if raycast_enabled and player and is_instance_valid(player):
		# Оновлюємо результат raycast тільки раз на raycast_interval
		if raycast_timer >= raycast_interval:
			raycast_timer = 0.0
			last_raycast_result = check_player_with_raycast()

		if last_raycast_result:
			player_detected_via_raycast = true
			# Перевіряємо відстань
			var distance_x = abs(player.global_position.x - enemy.global_position.x)
			if distance_x <= detection_range:
				chase_cooldown_timer = 0.0
				change_state(AIState.CHASE)
				return
		else:
			player_detected_via_raycast = false
	
	# Fallback: перевіряємо відстань без raycast
	if player and is_instance_valid(player):
		var distance_x = abs(player.global_position.x - enemy.global_position.x)
		if distance_x <= detection_range:
			chase_cooldown_timer = 0.0
			change_state(AIState.CHASE)
			return

func handle_chase_state(delta: float):
	"""Обробляє стан переслідування"""
	if not player or not is_instance_valid(player):
		change_state(AIState.IDLE)
		return
	
	# Перевіряємо, чи повинен ворог продовжувати переслідувати на основі HP
	if not should_chase_player():
		# Якщо не повинен переслідувати, переходимо до відступлення або очікування
		var enemy_hp = get_enemy_health()
		if enemy_hp.current <= 1 or enemy_hp.percent <= 1.0:
			start_retreat()
			change_state(AIState.RETREAT)
		else:
			change_state(AIState.IDLE)
		return
	
	# Відстань до гравця тільки по X координаті
	var distance_to_player_x = abs(player.global_position.x - enemy.global_position.x)

	# Leash: якщо відійшли надто далеко від дому — припиняємо переслідування і йдемо назад
	var distance_to_home_x = abs(enemy.global_position.x - home_position.x)
	if distance_to_home_x > leash_range:
		change_state(AIState.RETURN_HOME)
		player_lost.emit()
		chase_cooldown_timer = 0.0
		return
	
	# Якщо гравець занадто далеко, втрачаємо його
	if distance_to_player_x > chase_range:
		lost_player_timer += delta
		if lost_player_timer > max_lost_time:
			change_state(AIState.RETURN_HOME)
			player_lost.emit()
			chase_cooldown_timer = 0.0
			return
	else:
		lost_player_timer = 0.0
	
	# Перевіряємо, чи можемо атакувати (тільки по X)
	if distance_to_player_x <= attack_range:
		change_state(AIState.ATTACK)
		return
	
	# Переслідуємо гравця (тільки по X, без урахування Y координати)
	# Використовуємо raycast для визначення напрямку, а не просто слідуємо за гравцем
	var direction_x = get_chase_direction_from_raycast()
	
	if direction_x == 0:
		# Якщо raycast не знайшов гравця, використовуємо простий напрямок
		var player_x = player.global_position.x
		var enemy_x = enemy.global_position.x
		direction_x = player_x - enemy_x
	
	# Якщо гравець і ворог на одній координаті X (або дуже близько), зупиняємося
	if abs(direction_x) <= 5.0:
		velocity.x = 0
		if last_direction == 0:
			last_direction = 1 if direction_x >= 0 else -1
	else:
		# Рухаємося до гравця тільки якщо відстань більше порогу
		velocity.x = sign(direction_x) * speed
		
		# Емітуємо сигнал зміни напрямку
		var dir = 1 if direction_x > 0 else -1
		if dir != last_direction:
			direction_changed.emit(dir)
			last_direction = dir

func handle_attack_state(_delta: float):
	"""Обробляє стан атаки"""
	if not player or not is_instance_valid(player):
		change_state(AIState.IDLE)
		return
	
	# Відстань до гравця тільки по X координаті
	var distance_to_player_x = abs(player.global_position.x - enemy.global_position.x)
	
	# Якщо гравець занадто далеко, переслідуємо
	if distance_to_player_x > attack_range * 1.2:
		change_state(AIState.CHASE)
		return
	
	# Зупиняємо горизонтальний рух під час атаки (але залишаємо гравітацію)
	velocity.x = 0
	
	# Повертаємося до гравця під час атаки (тільки для розвороту спрайта, тільки по X)
	var player_x = player.global_position.x
	var enemy_x = enemy.global_position.x
	var direction_x = player_x - enemy_x
	
	if abs(direction_x) > 0.1:
		var dir = 1 if direction_x > 0 else -1
		# Відправляємо сигнал, якщо напрямок змінився
		if dir != last_direction:
			direction_changed.emit(dir)
			last_direction = dir
	
	# Атакуємо
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_attack_time >= attack_cooldown:
		perform_attack()
		last_attack_time = current_time
		
		# Приймаємо рішення: нападати чи відступати на основі HP
		var should_retreat = should_retreat_after_attack()
		
		if should_retreat:
			# Починаємо відступлення
			start_retreat()
			change_state(AIState.RETREAT)
		else:
			# Продовжуємо переслідування (якщо кулдаун пройшов)
			if chase_cooldown_timer >= chase_cooldown:
				chase_cooldown_timer = 0.0
				change_state(AIState.CHASE)
			else:
				# Якщо кулдаун не пройшов, але не відступаємо - залишаємося в атаці
				pass

func change_state(new_state: AIState):
	"""Змінює стан AI"""
	if current_state == new_state:
		return
	
	var _old_state = current_state
	current_state = new_state
	state_timer = 0.0
	
	state_changed.emit(new_state)
	
	# Емітуємо подію через EventBus
	if Engine.has_singleton("EventBus"):
		var enemy_name: String = "unknown"
		if enemy and is_instance_valid(enemy):
			enemy_name = enemy.name
		
		var state_name: String = "unknown"
		var state_keys = AIState.keys()
		if new_state >= 0 and new_state < state_keys.size():
			state_name = state_keys[new_state]
		
		EventBus.enemy_state_changed.emit(enemy_name, state_name)

func perform_attack():
	"""Виконує атаку"""
	if not enemy or not is_instance_valid(enemy):
		return
	
	attack_started.emit()
	
	# Емітуємо подію через EventBus
	if Engine.has_singleton("EventBus"):
		if player:
			EventBus.attack_started.emit(enemy, player)
	
	# Наносимо ушкодження гравцю (якщо ворог має метод start_attack)
	if enemy.has_method("start_attack"):
		enemy.start_attack()
	
	# Пряме нанесення ушкоджень (якщо гравець близько)
	if player and is_instance_valid(player) and player.has_method("take_damage"):
		var distance = enemy.global_position.distance_to(player.global_position)
		if distance <= attack_range * 1.2:
			player.take_damage(damage)
			
			# Емітуємо подію через EventBus
			if Engine.has_singleton("EventBus"):
				EventBus.damage_dealt.emit(enemy, player, int(damage))
	
	# Завершуємо атаку через невелику затримку
	await get_tree().create_timer(0.3).timeout
	attack_ended.emit()
	
	if enemy.has_method("end_attack"):
		enemy.end_attack()

func on_player_detected(player_node: Node):
	"""Обробляє виявлення гравця"""
	player_in_area = true
	player = player_node
	player_detected.emit()
	
	if current_state == AIState.IDLE:
		change_state(AIState.CHASE)

func on_player_lost():
	"""Обробляє втрату гравця"""
	player_in_area = false
	player_lost.emit()

func get_state() -> AIState:
	"""Отримує поточний стан"""
	return current_state

func get_velocity() -> Vector2:
	"""Отримує поточну швидкість"""
	return velocity

func set_velocity(new_velocity: Vector2):
	"""Встановлює швидкість"""
	velocity = new_velocity

func handle_retreat_state(delta: float):
	"""Обробляє стан відступлення"""
	retreat_timer += delta
	
	# Перевіряємо, чи повинен ворог продовжувати відступати на основі HP
	var enemy_hp = get_enemy_health()
	
	# Якщо у ворога більше 1% HP - перестаємо відступати
	if enemy_hp.percent > 1.0:
		retreat_timer = 0.0
		velocity.x = 0
		# Перевіряємо, чи повинен ворог переслідувати гравця
		if should_chase_player() and chase_cooldown_timer >= chase_cooldown:
			chase_cooldown_timer = 0.0
			change_state(AIState.CHASE)
		else:
			change_state(AIState.IDLE)
		return
	
	# Якщо час відступлення минув, переходимо до очікування
	if retreat_timer >= retreat_duration:
		retreat_timer = 0.0
		velocity.x = 0
		# Перевіряємо, чи повинен ворог переслідувати гравця
		if should_chase_player() and chase_cooldown_timer >= chase_cooldown:
			chase_cooldown_timer = 0.0
			change_state(AIState.CHASE)
		else:
			change_state(AIState.IDLE)
		return
	
	# Рухаємося від гравця
	var direction_away = get_retreat_direction()
	if direction_away != 0:
		velocity.x = direction_away * retreat_speed
		
		# Емітуємо сигнал зміни напрямку
		if direction_away != last_direction:
			direction_changed.emit(direction_away)
			last_direction = direction_away
	else:
		velocity.x = 0

func start_retreat():
	"""Починає відступлення"""
	retreat_timer = 0.0
	# Визначаємо напрямок відступу (від гравця)
	if player and is_instance_valid(player):
		var player_x = player.global_position.x
		var enemy_x = enemy.global_position.x
		var direction_away = -sign(player_x - enemy_x)  # Від гравця
		if direction_away == 0:
			direction_away = -last_direction if last_direction != 0 else -1
		
		# Визначаємо цільову позицію відступу
		retreat_target_position = enemy.global_position + Vector2(direction_away * retreat_distance, 0)

func get_retreat_direction() -> int:
	"""Отримує напрямок відступлення"""
	if player and is_instance_valid(player):
		var player_x = player.global_position.x
		var enemy_x = enemy.global_position.x
		var direction_away = -sign(player_x - enemy_x)  # Від гравця
		if direction_away == 0:
			direction_away = -last_direction if last_direction != 0 else -1
		return direction_away
	return -last_direction if last_direction != 0 else -1

func handle_return_home_state(_delta: float) -> void:
	"""Повертає ворога на позицію спавну по X (без примусових аренд)"""
	# Якщо ворог помер — не рухаємось
	if enemy.has_method("is_dead") and enemy.is_dead:
		velocity.x = 0
		return

	# Поки повертаємось — не атакуємо і не "переагрюємось" миттєво
	var dx = home_position.x - enemy.global_position.x
	if abs(dx) <= 5.0:
		velocity.x = 0
		change_state(AIState.IDLE)
		return

	var dir = 1 if dx > 0 else -1
	velocity.x = dir * return_home_speed
	if dir != last_direction:
		direction_changed.emit(dir)
		last_direction = dir

func check_player_with_raycast() -> bool:
	"""Перевіряє наявність гравця через raycast"""
	if not player or not is_instance_valid(player) or not enemy:
		return false
	
	var space_state = enemy.get_world_2d().direct_space_state
	var enemy_pos = enemy.global_position
	
	# Перевіряємо raycast під різними кутами
	for angle_deg in raycast_angles:
		var angle_rad = deg_to_rad(angle_deg)
		var direction = Vector2(cos(angle_rad), sin(angle_rad))
		var end_pos = enemy_pos + direction * raycast_range
		
		var query = PhysicsRayQueryParameters2D.new()
		query.from = enemy_pos
		query.to = end_pos
		query.exclude = [enemy]
		query.collision_mask = 1  # Layer 1 - Player
		
		var result = space_state.intersect_ray(query)
		if result and result.collider == player:
			return true
	
	return false

func get_chase_direction_from_raycast() -> float:
	"""Отримує напрямок переслідування з raycast"""
	if not player or not is_instance_valid(player) or not enemy:
		return 0.0
	
	var space_state = enemy.get_world_2d().direct_space_state
	var enemy_pos = enemy.global_position
	var player_pos = player.global_position
	var player_x = player_pos.x
	var enemy_x = enemy_pos.x
	
	# Перевіряємо raycast в напрямку гравця
	var direction_to_player = (player_pos - enemy_pos).normalized()
	var end_pos = enemy_pos + direction_to_player * raycast_range
	
	var query = PhysicsRayQueryParameters2D.new()
	query.from = enemy_pos
	query.to = end_pos
	query.exclude = [enemy]
	query.collision_mask = 1  # Layer 1 - Player
	
	var result = space_state.intersect_ray(query)
	if result and result.collider == player:
		# Якщо raycast знайшов гравця, повертаємо напрямок по X
		return player_x - enemy_x
	
	# Якщо raycast не знайшов гравця, повертаємо 0 (зупиняємося)
	return 0.0

func get_enemy_health() -> Dictionary:
	"""Отримує HP ворога"""
	if not enemy:
		return {"current": 0, "max": 0, "percent": 0.0}
	
	var current = 0
	var max_hp = 0
	
	# Використовуємо CombatBody2D методи (вони завжди доступні, бо DefaultEnemy наслідується від CombatBody2D)
	if enemy.has_method("get_current_health"):
		current = enemy.get_current_health()
	if enemy.has_method("get_max_health"):
		max_hp = enemy.get_max_health()
	
	var percent = 0.0
	if max_hp > 0:
		percent = float(current) / float(max_hp) * 100.0
	
	return {"current": current, "max": max_hp, "percent": percent}

func get_player_health() -> Dictionary:
	"""Отримує HP гравця"""
	if not player or not is_instance_valid(player):
		return {"current": 0, "max": 0, "percent": 0.0}
	
	var current = 0
	var max_hp = 0
	
	# Використовуємо CombatBody2D методи (вони завжди доступні, бо PlayerController наслідується від CombatBody2D)
	if player.has_method("get_current_health"):
		current = player.get_current_health()
	if player.has_method("get_max_health"):
		max_hp = player.get_max_health()
	
	var percent = 0.0
	if max_hp > 0:
		percent = float(current) / float(max_hp) * 100.0
	
	return {"current": current, "max": max_hp, "percent": percent}

func should_retreat_after_attack() -> bool:
	"""Визначає, чи повинен ворог відступати після атаки на основі HP"""
	var enemy_hp = get_enemy_health()
	var player_hp = get_player_health()
	
	# Якщо у ворога 1 HP - завжди відступаємо
	if enemy_hp.current <= 1:
		return true
	
	# Якщо у ворога більше 1% HP - не відступаємо
	if enemy_hp.percent > 1.0:
		return false
	
	# Якщо у ворога більше HP, ніж у гравця - не відступаємо (завжди наступаємо)
	if enemy_hp.current > player_hp.current:
		return false
	
	# В інших випадках відступаємо (якщо кулдаун не пройшов)
	return chase_cooldown_timer < chase_cooldown

func should_chase_player() -> bool:
	"""Визначає, чи повинен ворог переслідувати гравця на основі HP"""
	var enemy_hp = get_enemy_health()
	var player_hp = get_player_health()
	
	# Якщо у ворога більше HP, ніж у гравця - завжди наступаємо
	if enemy_hp.current > player_hp.current:
		return true
	
	# Якщо у ворога 1 HP - не переслідуємо (відступаємо)
	if enemy_hp.current <= 1:
		return false
	
	# Якщо у ворога більше 1% HP - переслідуємо
	if enemy_hp.percent > 1.0:
		return true
	
	# В інших випадках не переслідуємо
	return false
