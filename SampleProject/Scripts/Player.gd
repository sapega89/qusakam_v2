# Player controller with WASD/Arrow keys support
extends CombatBody2D

# Preloaded VFX scenes
const SLASH_TRAIL_SCENE = preload("res://SampleProject/Scenes/FX/SlashTrail.tscn")
const LEVEL_UP_FLASH_SCENE = preload("res://SampleProject/Scenes/FX/LevelUpFlash.tscn")
const LEVEL_UP_PARTICLES_SCENE = preload("res://SampleProject/Scenes/FX/LevelUpParticles.tscn")

const SPEED_MIN = 300.0
const SPEED_MAX = 400.0
const ACCEL = 50.0
const JUMP_VELOCITY = -450.0
const MAX_FALL_SPEED = 900.0
const COYOTE_TIME: float = .1
const SHORT_HOP: float = .5

var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var animation: String

var reset_position: Vector2
# Indicates that the player has an event happening and can't be controlled.
var event: bool = false

var abilities: Array[StringName]
var double_jump: bool
var prev_on_floor: bool
var airtime: float = 0
var fall_start_height: float = 0.0  # Высота Y при начале падения
var speed: float = SPEED_MIN
var last_direction: int = 1  # 1 = вправо, -1 = влево
var jump_direction: int = 1  # Сохраняем направление прыжка для Fall
var animation_change_cooldown: float = 0.0  # Затримка для переключення анімацій

# HP бар
var health_bar: HealthBar = null

# Захист від постійного виклику kill()
var kill_cooldown: float = 0.0
var kill_cooldown_time: float = 1.0  # Мінімальний час між викликами kill()
var is_dying: bool = false  # Флаг, що гравець зараз вмирає

# Components
var combat: PlayerCombat = null

func _ready() -> void:
	# Добавляем игрока в группу для боевой системы
	add_to_group(GameGroups.PLAYER)
	
	# ВАЖНО: Гарантуємо, що process_mode встановлено правильно
	process_mode = Node.PROCESS_MODE_INHERIT
	
	# Инициализация боевых параметров
	Starting_Health = 100
	Max_Health = 100
	current_health = Starting_Health
	
	# ВАЖНО: Гарантуємо, що event = false при ініціалізації
	event = false
	
	# Инициализация компонентов
	_initialize_components()
	
	# Создаем HP бар для игрока
	_initialize_health_bar()
	
	on_enter()

	# Subscribe to level up events
	EventBus.player_leveled_up.connect(_on_player_leveled_up)

	# Діагностика: перевіряємо початковий стан
	DebugLogger.info("Player: Ініціалізовано, event = %s, paused = %s, process_mode = %s" % [event, get_tree().paused, process_mode], "Player")

func _physics_process(delta: float) -> void:
	# Діагностика: перевіряємо process_mode
	if process_mode == Node.PROCESS_MODE_DISABLED:
		DebugLogger.physics_warning("Player: process_mode = DISABLED! Рух заблоковано!", "player_process_mode")
		return

	if event:
		# Діагностика: перевіряємо, чому event = true
		if OS.is_debug_build():
			DebugLogger.physics_verbose("Player: Рух заблоковано через event = true", "player_event")
		return

	# Діагностика: перевіряємо, чи гра на паузі
	if get_tree().paused:
		if OS.is_debug_build():
			DebugLogger.physics_verbose("Player: Рух заблоковано через паузу гри", "player_paused")
		return
	
	var new_animation: String  # Оголошуємо змінну один раз на початку функції
	
	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * delta, MAX_FALL_SPEED)
		airtime += delta
		# Сохраняем высоту начала падения (только если начали падать вниз и еще не сохранили)
		if velocity.y > 50.0 and fall_start_height == 0.0:  # Только если падаем со скоростью > 50
			fall_start_height = global_position.y
	elif not prev_on_floor and &"double_jump" in abilities:
		# Some simple double jump implementation.
		double_jump = true
		airtime = 0
	
	var on_floor_ct: bool = is_on_floor() or airtime < COYOTE_TIME
	# Jump with Space or W
	# ВАЖНО: Перевіряємо, чи не натиснуто Escape (щоб не стрибати при відкритті меню)
	if Input.is_action_just_pressed("jump") and (on_floor_ct or double_jump) and not Input.is_key_pressed(KEY_ESCAPE):
		if not on_floor_ct:
			double_jump = false
		
		if Input.is_action_pressed("move_down"):
			position.y += 8
		else:
			velocity.y = JUMP_VELOCITY
	
	if Input.is_action_just_released("jump"):
		if not is_on_floor() and velocity.y < 0:
			velocity.y = min(0, velocity.y - JUMP_VELOCITY * SHORT_HOP)
			
	
	if is_on_wall():
		speed = SPEED_MIN
	
	# Move with A/D or Arrow keys
	# ВАЖНО: Пріоритет клавіатурі - перевіряємо джойстик тільки якщо клавіатура не використовується
	var direction := 0.0
	
	# Спочатку перевіряємо клавіатуру (пріоритет)
	if Input.is_action_pressed("move_left"):
		direction -= 1.0
	if Input.is_action_pressed("move_right"):
		direction += 1.0
	
	# Якщо клавіатура не використовується, перевіряємо джойстик (тільки якщо він підключений)
	if direction == 0.0 and Input.get_connected_joypads().size() > 0:
		var joypad_direction = Input.get_axis("move_left", "move_right")
		# Використовуємо джойстик тільки якщо він активний (не в мертвій зоні)
		if abs(joypad_direction) > 0.1:
			direction = joypad_direction
	
	if direction:
		speed = min(SPEED_MAX, speed + ACCEL * delta)
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED_MIN)
		speed = SPEED_MIN

	# Обновляем последнее направление на основе velocity.x
	if absf(velocity.x) > 1:
		last_direction = sign(velocity.x)

	# Проверяем приземление: если раньше были в воздухе, а теперь на земле
	var was_in_air = not prev_on_floor
	var now_on_floor = is_on_floor()
	
	prev_on_floor = is_on_floor()
	
	move_and_slide()
	
	# Діагностика руху (тільки в debug режимі)
	if OS.is_debug_build() and absf(velocity.x) > 10:
		# Перевіряємо, чи рух блокується колізією
		if is_on_wall() and absf(velocity.x) > 1:
			DebugLogger.physics_warning("Player: Рух блокується стіною (is_on_wall = true)", "player_wall")
	
	# Оновлюємо затримку для переключення анімацій
	if animation_change_cooldown > 0:
		animation_change_cooldown -= delta
	
	# Отправляем сигнал приземления, если игрок приземлился
	if was_in_air and now_on_floor:
		# Вычисляем высоту падения
		# В Godot Y растет вниз, поэтому конечная позиция больше начальной
		var fall_height: float = 0.0
		if fall_start_height > 0.0:
			fall_height = global_position.y - fall_start_height  # Правильная формула: конечная - начальная
			DebugLogger.physics_verbose("Player: Landing! Fall height = %.1f pixels (start: %.1f, end: %.1f)" % [fall_height, fall_start_height, global_position.y], "player_landing")
		else:
			DebugLogger.physics_verbose("Player: Landing but no fall_start_height recorded (probably small jump)", "player_landing")
		
		# Сбрасываем отслеживание высоты
		fall_start_height = 0.0
		airtime = 0
		
		# Минимальная высота падения для эффекта (игнорируем очень маленькие падения)
		var min_fall_height = 20.0  # Минимум 20 пикселей
		
		# Проверяем, что высота падения достаточна для эффекта
		if fall_height < min_fall_height:
			DebugLogger.physics_verbose("Player: Fall height too small (%.1f < %.1f), skipping effect" % [fall_height, min_fall_height], "player_landing")
			return

		# EventBus доступен напрямую как autoload
		if EventBus and EventBus.has_signal("player_landed"):
			DebugLogger.physics_verbose("Player: Emitting player_landed signal with fall_height = %.1f" % fall_height, "player_landing")
			EventBus.player_landed.emit(fall_height)
	
	# Обновляем кулдаун kill()
	if kill_cooldown > 0:
		kill_cooldown -= delta
	
	# Обработка атаки (левая кнопка мыши или кнопка X на контроллере)
	if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("attack")) and not combat.is_attacking:
		combat.perform_attack(last_direction)
	
	# Не меняем анимацию во время атаки (кроме важных состояний Fall/Jump)
	if combat.is_attacking and animation == &"Attack":
		# Если атака активна, но нужно переключиться на важное состояние (Fall, Jump)
		# - разрешаем прерывание атаки для этих состояний
		new_animation = &"Idle"
		if velocity.y < 0:
			new_animation = &"Jump"
		elif velocity.y >= 0 and not is_on_floor():
			new_animation = &"Fall"
		
		# Прерываем атаку только для важных состояний
		if new_animation == &"Fall" or new_animation == &"Jump":
			combat.is_attacking = false
			if combat.damage_applier:
				combat.damage_applier.disable_damage()
			if combat.hitbox:
				combat.hitbox.monitoring = false
				combat.hitbox.monitorable = false
			animation = new_animation
			if new_animation == &"Jump":
				jump_direction = last_direction
			$AnimationPlayer.play(new_animation)
			if new_animation == &"Fall":
				if jump_direction < 0:
					$Sprite2D.flip_h = true
				else:
					$Sprite2D.flip_h = false
		# Если атака активна и не нужно переключаться на Fall/Jump - не меняем анимацию
		return
	
	# Определяем новую анимацию (можем прервать текущую анимацию, если нужно)
	new_animation = &"Idle"
	if velocity.y < 0:
		new_animation = &"Jump"
	elif velocity.y >= 0 and not is_on_floor():
		new_animation = &"Fall"
	elif absf(velocity.x) > 1:
		new_animation = &"Run"
	
	# Переключаем анимацию, если она изменилась (з затримкою для плавності)
	if new_animation != animation and animation_change_cooldown <= 0:
		animation = new_animation
		animation_change_cooldown = 0.05  # Невелика затримка для плавності
		# При переключении на Jump - сохраняем направление прыжка
		if new_animation == &"Jump":
			jump_direction = last_direction
		# Використовуємо плавне переключення анімацій
		if $AnimationPlayer.current_animation != new_animation:
			$AnimationPlayer.play(new_animation)
		# Для Fall используем направление из прыжка
		if new_animation == &"Fall":
			# Если прыжок был влево - отзеркаливаем Fall (flip_h = true)
			# Если прыжок был вправо - не отзеркаливаем Fall (flip_h = false)
			if jump_direction < 0:
				$Sprite2D.flip_h = true
			else:
				$Sprite2D.flip_h = false
	
	# Применяем отзеркаливание для Idle, Jump, RESET и Run
	# Fall НЕ отзеркаливаем - фиксируем flip_h = false
	if new_animation == &"Run" or new_animation == &"Idle" or new_animation == &"Jump" or new_animation == &"RESET":
		if absf(velocity.x) > 1:
			# Во время движения - обновляем по текущему направлению
			if velocity.x > 1:
				$Sprite2D.flip_h = true
			elif velocity.x < -1:
				$Sprite2D.flip_h = false
		else:
			# Во время стояния/прыжка - используем последнее направление
			if last_direction > 0:
				$Sprite2D.flip_h = true
			else:
				$Sprite2D.flip_h = false
	elif new_animation == &"Fall":
		# Фиксируем flip_h для Fall на основе направления прыжка
		if jump_direction < 0:
			$Sprite2D.flip_h = true  # Прыжок был влево - отзеркаливаем Fall
		else:
			$Sprite2D.flip_h = false  # Прыжок был вправо - не отзеркаливаем Fall

func die() -> void:
	"""Override CombatBody2D.die() to call kill() for player respawn"""
	# Вызываем родительский die() для установки is_dead и эмита сигналов
	super.die()

	# Вызываем kill() для респавна игрока
	kill()

func kill():
	# Захист від постійного виклику kill()
	if is_dying or kill_cooldown > 0:
		DebugLogger.warning("Player: kill() заблоковано - гравець вже вмирає або кулдаун активний (cooldown = %.2f)" % kill_cooldown, "Player")
		return

	# Встановлюємо флаг смерті та кулдаун
	is_dying = true
	kill_cooldown = kill_cooldown_time

	DebugLogger.info("Player: kill() викликано! reset_position = %s, поточна позиція = %s" % [reset_position, position], "Player")
	
	# Player dies, reset the position to the entrance.
	if reset_position != Vector2.ZERO:
		position = reset_position
		DebugLogger.info("Player: Позиція встановлена на reset_position: %s" % position, "Player")
	else:
		DebugLogger.warning("Player: reset_position = ZERO! Використовуємо поточну позицію.", "Player")

	# Скидаємо флаги смерті и восстанавливаем здоровье для респавна
	is_dead = false
	is_dying = false
	current_health = Max_Health
	health_changed.emit(current_health, Max_Health, true)

	# Викликаємо load_room тільки якщо це не призведе до циклу
	var game = Game.get_singleton()
	if game:
		var current_room = MetSys.get_current_room_name()
		DebugLogger.info("Player: Завантажуємо кімнату: %s (HP відновлено до %d/%d)" % [current_room, current_health, Max_Health], "Player")
		game.load_room(current_room)

# Combat logic delegates to PlayerCombat component
func perform_attack():
	combat.perform_attack(last_direction)

func _initialize_components():
	combat = PlayerCombat.new()
	combat.sprite = $Sprite2D
	combat.animation_player = $AnimationPlayer
	combat.hitbox = get_node_or_null("Hitbox")
	combat.damage_applier = get_node_or_null("Hitbox/DamageApplier")
	add_child(combat)
	DebugLogger.info("Player: Components initialized", "Player")

func _initialize_health_bar():
	"""Находит и настраивает HP бар для игрока (HP бар должен быть в Game.tscn в UI CanvasLayer)"""
	# Ищем HP бар в сцене (он должен быть добавлен в Game.tscn)
	var scene = get_tree().current_scene
	if not scene:
		# Если сцена еще не готова, откладываем поиск
		call_deferred("_initialize_health_bar")
		return
	
	# Ищем HP бар в UICanvas CanvasLayer (специальный CanvasLayer для UI элементов игры)
	var ui_canvas = scene.get_node_or_null("UICanvas")
	if ui_canvas:
		health_bar = ui_canvas.get_node_or_null("PlayerHealthBar") as HealthBar
	
	# Если HP бар не найден, создаем его (fallback для совместимости)
	if not health_bar:
		push_warning("Player: HP бар не найден в сцене, создаем через скрипт")
		var health_bar_scene = load("res://SampleProject/Scenes/UI/health_bar.tscn")
		if health_bar_scene:
			health_bar = health_bar_scene.instantiate() as HealthBar
			# Создаем UICanvas если его нет
			if not ui_canvas:
				ui_canvas = CanvasLayer.new()
				ui_canvas.name = "UICanvas"
				scene.add_child(ui_canvas)
			if health_bar and ui_canvas:
				ui_canvas.add_child(health_bar)
				health_bar.name = "PlayerHealthBar"
				health_bar.position = Vector2(10, 40)
				health_bar.custom_minimum_size = Vector2(150, 20)
	
	# Настраиваем HP бар для игрока
	if health_bar:
		health_bar.setup_for_entity(self, "Player")
		health_bar.visible = true
		health_bar.z_index = 100
		
		# Обновляем начальные значения
		await get_tree().process_frame
		if health_bar.bar:
			health_bar.bar.max_value = Max_Health
			health_bar.bar.value = current_health
			health_bar.current_value = current_health
			health_bar.max_value = Max_Health
			health_bar.update_health_color(current_health)
			health_bar.update_health_text()
			DebugLogger.info("Player: HP бар инициализирован - HP: %d/%d" % [current_health, Max_Health], "Player")
	else:
		push_error("Player: Не удалось найти или создать HP бар")


func on_enter():
	# Position for kill system. Assigned when entering new room (see Game.gd).
	# ВАЖНО: Не скидаємо позицію, тільки зберігаємо reset_position
	var old_reset_position = reset_position
	reset_position = position
	
	# Діагностика: перевіряємо, чи не змінилася позиція після встановлення reset_position (DEBUG)
	# TODO: Remove this diagnostic logging after confirming teleportation bug is fixed
	if old_reset_position != Vector2.ZERO and old_reset_position.distance_to(reset_position) > 100.0:  # Increased threshold to 100 to reduce noise
		DebugLogger.info("Player: on_enter() - reset_position changed (room transition): old = %s, new = %s" % [old_reset_position, reset_position], "Player")

	DebugLogger.info("Player: on_enter() викликано, reset_position = %s, поточна позиція = %s" % [reset_position, position], "Player")
	
	# Скидаємо флаг смерті при вході в нову кімнату
	is_dying = false
	kill_cooldown = 0.0
	
	# ВАЖНО: Скидаємо event = false при вході в нову кімнату, щоб гравець міг рухатися
	# Якщо event залишився true після переходу через портал, це блокує рух
	if event:
		DebugLogger.warning("Player: on_enter() - event був true, скидаємо до false", "Player")
		event = false

func _spawn_attack_vfx() -> void:
	"""Spawns slash trail VFX for player attack"""
	if not SLASH_TRAIL_SCENE:
		return

	var slash = SLASH_TRAIL_SCENE.instantiate()
	if not slash:
		return

	add_child(slash)

	# Position in front of player based on direction
	var offset_x = 30 * last_direction
	var offset_y = -20  # Slightly above center
	slash.position = Vector2(offset_x, offset_y)

	# Set slash direction for particle emission
	if slash.has_method("set_direction"):
		slash.set_direction(last_direction)

func _spawn_level_up_vfx() -> void:
	"""Spawns level up celebration VFX (flash + particles)"""
	# Spawn full-screen white flash
	if LEVEL_UP_FLASH_SCENE:
		var flash = LEVEL_UP_FLASH_SCENE.instantiate()
		if flash:
			# Add to UI layer (z_index high to be on top)
			var ui_root = get_tree().current_scene.get_node_or_null("CanvasLayer")
			if ui_root:
				ui_root.add_child(flash)
				flash.z_index = 300  # Above all other UI
			else:
				# Fallback to scene root
				get_tree().current_scene.add_child(flash)
				flash.z_index = 300

	# Spawn golden particle burst from player
	if LEVEL_UP_PARTICLES_SCENE:
		var particles = LEVEL_UP_PARTICLES_SCENE.instantiate()
		if particles:
			# Add to scene root (not player child, so it persists if player moves)
			get_tree().current_scene.add_child(particles)
			particles.global_position = global_position
			particles.z_index = 200  # Above gameplay, below flash

	DebugLogger.verbose("Player: Spawned level up VFX", "Player")

func _on_player_leveled_up(new_level: int, old_level: int) -> void:
	"""Called when player levels up - applies stat bonuses"""
	var xp_manager = ServiceLocator.get_xp_manager()
	if not xp_manager:
		DebugLogger.warning("Player: XPManager not found, cannot apply level up bonuses", "Player")
		return

	# Get stat bonuses
	var hp_bonus = xp_manager.get_hp_bonus()
	var damage_bonus = xp_manager.get_damage_bonus()

	# Calculate old max HP before applying bonus
	var old_max_hp = Max_Health

	# Apply HP bonus (base HP + level bonuses)
	Max_Health = Starting_Health + hp_bonus

	# Heal player by the HP increase amount
	var hp_increase = Max_Health - old_max_hp
	current_health = min(current_health + hp_increase, Max_Health)

	# Update HP bar
	if health_bar:
		health_bar.max_value = Max_Health
		health_bar.current_value = current_health
		if health_bar.bar:
			health_bar.bar.max_value = Max_Health
			health_bar.bar.value = current_health
		health_bar.update_health_text()
		health_bar.update_health_color(current_health)

	DebugLogger.info("Player: Level %d! HP: %d->%d (+%d)" % [
		new_level, old_max_hp, Max_Health, hp_increase
	], "Player")

	# === LEVEL UP VFX ===
	_spawn_level_up_vfx()
