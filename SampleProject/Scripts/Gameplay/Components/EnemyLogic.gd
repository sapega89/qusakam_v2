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
## Іде замах або удар (D198): ворог стоїть, рішень не приймає.
var is_attacking: bool = false
## Іде саме замах (ще не удар): ворог розвертається за героєм, тож від удару не втекти, просто ступивши за спину.
var winding_up: bool = false
## Яку частку замаху ворог ще розвертається (мок).
const TRACK_PART := 0.6

## Відкидання (D203): за KNOCKBACK_TIME ворог проїжджає задану відстань, AI чекає.
const KNOCKBACK_TIME := 0.15
var knockback_left: float = 0.0
var knockback_speed: float = 0.0
## Оглушення (D207): ворог стоїть, а замах, що вже йде, не закінчиться ударом.
var stun_left: float = 0.0
## Замах зірвано важким ударом (відкидання, D208) — удару не буде.
var attack_broken: bool = false
## Комбо (D265): наступні удари серії — з коротшим замахом; останній удар серії — фінішер, збиває героя довше.
const COMBO_WINDUP := 0.25
const FINISHER_STAGGER := 0.6
var finisher: bool = false

# Raycast для виявлення гравця

# Посилання на гравця
var player: Node = null
var player_in_area: bool = false
var last_direction: int = 0  # Для відстеження зміни напрямку

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

	var params: Dictionary = enemy.get_enemy_params()
	speed = params["speed"]
	detection_range = params["detection_range"]
	attack_range = params["attack_range"]
	chase_range = params["chase_range"]
	base_damage = params["base_damage"]
	damage = base_damage
	leash_range = params["leash_range"]
	return_home_speed = params["return_home_speed"]

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
	if enemy.is_dead:
		velocity = Vector2.ZERO
		return

	if knockback_left > 0.0:
		knockback_left -= delta
		velocity.x = knockback_speed
		return

	if stun_left > 0.0:
		stun_left -= delta
		velocity.x = 0
		return

	# Якщо гравець не знайдений, намагаємося знайти його через GameGroups
	if not player or not is_instance_valid(player):
		player = GameGroups.get_player()

	# Атака вже почалась — доводимо її до кінця на місці
	if is_attacking:
		velocity.x = 0
		if winding_up:
			_face_player()
		return

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

	# Переслідування — за відстанню по X. (Raycast тут був, але будь-яке його
	# влучання закінчувалось тією ж перевіркою відстані — прибрано, D131.)
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
	var direction_x: float = player.global_position.x - enemy.global_position.x

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
		last_attack_time = current_time
		perform_attack()

## Після удару: нападати далі чи відступати на основі HP. Викликається, коли удар закінчився (D198),
## а не в момент замаху — інакше ворог біг геть посеред замаху й анімація walk перебивала attack.
func _decide_after_attack() -> void:
	if current_state != AIState.ATTACK or enemy.is_dead:
		return
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

func stun(duration: float) -> void:
	if enemy.super_armor and is_attacking:
		return  # броня (tank, D208): замах оглушенням не зірвати
	stun_left = maxf(stun_left, duration)

## Збій (D264): стоїть [param duration] с, замах і серія зірвані, хітбокс гасне — навіть у броні.
func stagger(duration: float) -> void:
	stun_left = maxf(stun_left, duration)
	if is_attacking:
		attack_broken = true
		enemy.end_attack()

## Відкидання на [param push] px за KNOCKBACK_TIME. Удар героя ([param breaks_attack]) зриває замах,
## власний ривок ворога — ні.
func start_knockback(push: float, breaks_attack: bool = true) -> void:
	knockback_left = KNOCKBACK_TIME
	knockback_speed = push / KNOCKBACK_TIME
	if breaks_attack and is_attacking:
		attack_broken = true

func perform_attack():
	"""Серія з 1–combo_hits ударів (D265): замах, потім удар хітбоксом у бік погляду (D198). Ушкодження — DamageApplier хітбокса."""
	is_attacking = true
	attack_broken = false
	var swings := 1
	while swings < enemy.combo_hits and randf() < enemy.combo_chance:
		swings += 1
	for i in swings:
		if enemy.is_dead or stun_left > 0.0 or attack_broken:
			break
		var windup: float = enemy.attack_windup if i == 0 else COMBO_WINDUP
		finisher = swings > 1 and i == swings - 1
		winding_up = true
		attack_started.emit()
		EventBus.attack_started.emit(enemy, player)
		# Замах: перші TRACK_PART ворог стежить за героєм, далі напрямок зафіксовано — перекат за спину
		# саме тоді рятує, а просто відійти на крок — ні.
		await get_tree().create_timer(windup * TRACK_PART).timeout
		winding_up = false
		await get_tree().create_timer(windup * (1.0 - TRACK_PART)).timeout
		# Оглушили (якщо без броні), збили чи парирували посеред серії — далі ударів немає (D207, D208, D264)
		if enemy.is_dead or stun_left > 0.0 or attack_broken:
			break
		# Б'є туди, куди дивиться наприкінці замаху (розвертався за героєм)
		var direction := last_direction if last_direction != 0 else 1
		enemy.start_attack(direction)
		if enemy.lunge > 0.0:
			start_knockback(direction * enemy.lunge, false)  # ривок разом з ударом (fast)
		await get_tree().create_timer(enemy.attack_active_time).timeout
		enemy.end_attack()

	finisher = false
	is_attacking = false
	attack_ended.emit()
	_decide_after_attack()

func _face_player() -> void:
	if not player or not is_instance_valid(player):
		return
	var dx: float = player.global_position.x - enemy.global_position.x
	var dir := 1 if dx > 0 else -1
	if absf(dx) > 0.1 and dir != last_direction:
		direction_changed.emit(dir)
		last_direction = dir

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
	if enemy.is_dead:
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

func get_enemy_health() -> Dictionary:
	"""Отримує HP ворога"""
	if not enemy:
		return {"current": 0, "max": 0, "percent": 0.0}

	var current = 0
	var max_hp = 0

	# Використовуємо CombatBody2D методи (вони завжди доступні, бо DefaultEnemy наслідується від CombatBody2D)
	current = enemy.get_current_health()
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
	current = player.get_current_health()
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
