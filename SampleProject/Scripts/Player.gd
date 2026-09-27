# Player controller with WASD/Arrow keys support
extends CombatBody2D

# Preloaded VFX scenes
const SLASH_TRAIL_SCENE = preload("res://SampleProject/Scenes/FX/SlashTrail.tscn")
const LEVEL_UP_FLASH_SCENE = preload("res://SampleProject/Scenes/FX/LevelUpFlash.tscn")
const LEVEL_UP_PARTICLES_SCENE = preload("res://SampleProject/Scenes/FX/LevelUpParticles.tscn")

var animation: String

var reset_position: Vector2
# Indicates that the player has an event happening and can't be controlled.
var event: bool = false

var abilities: Array[StringName]
var animation_change_cooldown: float = 0.0  # Затримка для переключення анімацій

# HP бар
var health_bar: HealthBar = null

# Захист від постійного виклику kill()
var kill_cooldown: float = 0.0
var kill_cooldown_time: float = 1.0  # Мінімальний час між викликами kill()
var is_dying: bool = false  # Флаг, що гравець зараз вмирає

# Components — дочірні вузли Player.tscn (а не створені через .new()), щоб їхні
# @export-параметри були доступні для налаштування в інспекторі.
@onready var combat: PlayerCombat = get_node_or_null("PlayerCombat") as PlayerCombat
@onready var mover: PlayerMover = get_node_or_null("PlayerMover") as PlayerMover

# Рух винесено в PlayerMover (speed_min/max, jump_velocity, gravity тощо).
# last_direction лишаємо тут як forwarding-властивість, бо на нього посилаються
# ззовні (Systems/VFXHooks.gd, save-система через abilities).
var last_direction: int:
	get:
		return mover.last_direction if mover else 1

func set_movement_enabled(enabled: bool) -> void:
	"""Enable or disable player movement and input"""
	event = !enabled
	if not enabled:
		velocity = Vector2.ZERO # Stop immediately
		# Reset animation to Idle to improve visual feedback
		animation = "Idle"
		if $AnimationPlayer:
			$AnimationPlayer.play("Idle")
		# Also reset sprite flipping if needed or keep it
	
	DebugLogger.info("Player: Movement enabled = %s (event = %s)" % [enabled, event], "Player")

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

	# Гравітація, стрибок, горизонтальний рух, move_and_slide() та детекція
	# приземлення тепер живуть у PlayerMover (SRP: Player.gd відповідає лише
	# за стан здоров'я/анімацію/атаку, PlayerMover — за фізику руху).
	mover.physics_move(delta)

	# Оновлюємо затримку для переключення анімацій
	if animation_change_cooldown > 0:
		animation_change_cooldown -= delta

	# Обновляем кулдаун kill()
	if kill_cooldown > 0:
		kill_cooldown -= delta
	
	# Атака обробляється в _unhandled_input(), а не тут: опитування Input.* не знає,
	# чи клік уже спожив елемент інтерфейсу.

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
				mover.jump_direction = last_direction
			$AnimationPlayer.play(new_animation)
			_update_facing(new_animation)
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
			mover.jump_direction = last_direction
		# Використовуємо плавне переключення анімацій
		if $AnimationPlayer.current_animation != new_animation:
			$AnimationPlayer.play(new_animation)
	
	_update_facing(new_animation)

func _unhandled_input(ev: InputEvent) -> void:
	"""Атака.

	Саме _unhandled_input, а не опитування Input.is_mouse_button_pressed() у
	_physics_process: до цього методу подія доходить ЛИШЕ якщо її не спожив
	жоден Control. Тому кліки по діалоговому вікну та UI більше не б'ють мечем.

	Ім'я параметра `ev` — бо зайняті обидва очевидні варіанти: `event` — це поле
	цього класу (ознака катсцени), а `input_event` — сигнал CollisionObject2D.
	"""
	if ev.is_action_pressed(&"attack") and not combat.is_attacking:
		if event:
			return  # під час катсцени не б'ємо
		if ev is InputEventMouseButton and get_tree().paused:
			return
		combat.perform_attack(last_direction)

func _update_facing(anim: StringName) -> void:
	"""Єдине місце, де виставляється flip_h.

	Спрайт намальований обличчям ПРАВОРУЧ, тому дзеркалимо лише при русі ліворуч.
	Для Fall беремо напрямок, зафіксований на момент стрибка, щоб персонаж не
	розвертався в повітрі.
	"""
	var dir: int = mover.jump_direction if anim == &"Fall" else last_direction
	$Sprite2D.flip_h = dir < 0

func die() -> void:
	"""Override CombatBody2D.die() to call kill() for player respawn"""
	# Вызываем родительский die() для установки is_dead и эмита сигналов
	super.die()

	# Figma game-over-screen 41:83: екран Game Over замість миттєвого респавну.
	# Якщо показати нікуди (немає поточної сцени) — стара поведінка.
	if GameOverScreen.present(self):
		return

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
	# Компоненти тепер є вузлами Player.tscn, тому створювати їх тут не треба:
	# посилання дає @onready, а @export-поля PlayerCombat (sprite, animation_player,
	# hitbox, damage_applier) прив'язані NodePath'ами прямо в сцені.
	# Якщо сцену зібрано без них — падаємо одразу і зрозуміло, бо інакше помилка
	# спливе аж у _physics_process як "nil value" через кадр після старту.
	var missing: Array[String] = []
	if not combat:
		missing.append("PlayerCombat")
	if not mover:
		missing.append("PlayerMover")

	if not missing.is_empty():
		var msg := "Player: у сцені '%s' бракує обов'язкових компонентів: %s" % [scene_file_path, ", ".join(missing)]
		push_error(msg)
		DebugLogger.error(msg, "Player")
		return

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
	
	# Страховка від "залипання" event після переходу через портал: якщо блокування
	# лишилось увімкненим без причини, гравець більше ніколи не зрушить.
	#
	# АЛЕ скидати наосліп не можна. Сцена (напр. Village) стартує катсцену вже у
	# своєму _ready(), тобто ДО init_room() -> on_enter(). Безумовне скидання гасило
	# щойно поставлене блокування: гравець ходив під час діалогу, йшов з кімнати з
	# відкритим вікном, діалог не завершувався — і VillageAbduction висів назавжди.
	# Тому питаємо DialogueManager, чи блокування зараз законне.
	if event:
		var dm = ServiceLocator.get_dialogue_manager() if ServiceLocator else null
		if dm and dm.is_dialogue_active():
			DebugLogger.info("Player: on_enter() - event=true через активний діалог, залишаємо блокування", "Player")
		else:
			DebugLogger.warning("Player: on_enter() - event залип без діалогу, скидаємо до false", "Player")
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

func _on_player_leveled_up(new_level: int, _old_level: int) -> void:
	"""Called when player levels up - applies stat bonuses"""
	var xp_manager = ServiceLocator.get_xp_manager()
	if not xp_manager:
		DebugLogger.warning("Player: XPManager not found, cannot apply level up bonuses", "Player")
		return

	# Get stat bonuses
	var hp_bonus = xp_manager.get_hp_bonus()
	var _damage_bonus = xp_manager.get_damage_bonus()

	# Calculate old max HP before applying bonus
	var old_max_hp = Max_Health

	# Apply HP bonus (base HP + level bonuses)
	Max_Health = Starting_Health + hp_bonus

	# Heal player by the HP increase amount
	var hp_increase = Max_Health - old_max_hp
	current_health = min(current_health + hp_increase, Max_Health)

	# Контракт CombatBody2D: будь-яка зміна HP/Max_Health емітує health_changed.
	# Без цього HUD не бачив підвищення максимуму на новому рівні.
	health_changed.emit(current_health, Max_Health, true)

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
