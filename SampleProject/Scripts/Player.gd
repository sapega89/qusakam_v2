# Player controller with WASD/Arrow keys support
extends CombatBody2D

# Preloaded VFX scenes
const LEVEL_UP_FLASH_SCENE = preload("res://SampleProject/Scenes/FX/LevelUpFlash.tscn")
const LEVEL_UP_PARTICLES_SCENE = preload("res://SampleProject/Scenes/FX/LevelUpParticles.tscn")

var animation: String

## Прозорість спрайта під час перекату — видно, що герой невразливий (D200).
const ROLL_ALPHA := 0.55
## D284: пасивки навичок знімають щонайбільше 75 % удару (окремо щит і загальне зниження).
const MAX_SKILL_REDUCTION := 0.75

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
## Поразка в сюжетному бою (D301/D302): якщо задано, смерть кличе його замість екрана Game Over
## (програний бій з Brass Collector — у Лабораторію). Кімната ставить і сама ж знімає; оживляє героя теж вона.
var defeat_handler: Callable

# Components — дочірні вузли Player.tscn (а не створені через .new()), щоб їхні
# @export-параметри були доступні для налаштування в інспекторі.
@onready var combat: PlayerCombat = $PlayerCombat
@onready var mover: PlayerMover = $PlayerMover

# Рух винесено в PlayerMover (speed_min/max, jump_velocity, gravity тощо).
# last_direction лишаємо тут як forwarding-властивість, бо на нього посилаються
# ззовні (Systems/VFXHooks.gd, save-система через abilities).
var last_direction: int:
	get:
		return mover.last_direction

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

	# Max HP — з GameManager (D205): витривалість, броня, рівень, пасивки
	Max_Health = ServiceLocator.get_game_manager().calculate_max_health()
	current_health = Max_Health
	for changed in [EventBus.equipment_equipped, EventBus.equipment_unequipped, EventBus.skill_unlocked, EventBus.skill_upgraded, EventBus.skills_reset, EventBus.attributes_changed]:
		changed.connect(func(_a = null, _b = null, _c = null) -> void: refresh_max_health())

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
	mover.locked = combat.locks_movement()
	mover.physics_move(delta)

	# Оновлюємо затримку для переключення анімацій
	if animation_change_cooldown > 0:
		animation_change_cooldown -= delta

	# Обновляем кулдаун kill()
	if kill_cooldown > 0:
		kill_cooldown -= delta

	# Перекат (D200): анімацію Roll не перебиваємо; напівпрозорість — поки герой невразливий
	if mover.is_rolling():
		_update_facing()
		return
	$Sprite2D.modulate.a = 1.0

	# Драбина (D225): кадри лазіння йдуть, лише поки герой рухається по ній
	if mover.is_climbing():
		animation = &"Climb"
		if absf(velocity.y) < 1.0:
			$AnimationPlayer.pause()
		elif not $AnimationPlayer.is_playing() or $AnimationPlayer.current_animation != &"Climb":
			$AnimationPlayer.play(&"Climb")
		return

	# Атака обробляється в _unhandled_input(), а не тут: опитування Input.* не знає,
	# чи клік уже спожив елемент інтерфейсу.

	# Удар доходить до кінця і в повітрі (раніше стрибок/падіння скасовували його — у стрибку шкоди не було);
	# так само збій, важкий удар, блок (D264) — їхню анімацію веде PlayerCombat.
	if combat.owns_animation():
		_update_facing()
		return

	# Определяем новую анимацию (можем прервать текущую анимацию, если нужно)
	new_animation = &"Idle"
	if velocity.y < 0:
		new_animation = &"Jump"
	elif velocity.y >= 0 and not is_on_floor():
		new_animation = &"Fall"
	elif absf(velocity.x) > 1:
		new_animation = &"Run"  # біг усюди, і в містах (D266 скасовано, Sapega 2026-10-21)

	# Переключаем анимацию, если она изменилась (з затримкою для плавності)
	if new_animation != animation and animation_change_cooldown <= 0:
		var previous_animation: String = animation
		animation = new_animation
		animation_change_cooldown = 0.05  # Невелика затримка для плавності
		# Використовуємо плавне переключення анімацій
		# Перехідні кадри (feedback 20): вершина стрибка перед падінням, присід після приземлення
		var lead_in: StringName = &""
		if new_animation == &"Fall" and previous_animation == &"Jump":
			lead_in = &"Apex"
		elif previous_animation == &"Fall" and new_animation == &"Idle":
			lead_in = &"Land"
		if lead_in != &"":
			$AnimationPlayer.play(lead_in)
			$AnimationPlayer.queue(new_animation)
		elif $AnimationPlayer.current_animation != new_animation:
			$AnimationPlayer.play(new_animation)

	_update_facing()

## Кнопка асисту зараз натиснута (для фронту натискання тригера).
var _assist_down := false

func _unhandled_input(ev: InputEvent) -> void:
	"""Атака.

	Саме _unhandled_input, а не опитування Input.is_mouse_button_pressed() у
	_physics_process: до цього методу подія доходить ЛИШЕ якщо її не спожив
	жоден Control. Тому кліки по діалоговому вікну та UI більше не б'ють мечем.

	Ім'я параметра `ev` — бо зайняті обидва очевидні варіанти: `event` — це поле
	цього класу (ознака катсцени), а `input_event` — сигнал CollisionObject2D.
	"""
	# D209: асист компаньйона — наступний готовий
	# Тригер LT — вісь: is_action_pressed true на кожен її рух, тож кличемо лише на переході «відпущено → натиснуто».
	if ev.is_action(&"assist"):
		var down := ev.is_action_pressed(&"assist")
		if down and not _assist_down and not event and ServiceLocator.get_ui_manager().is_gameplay_input_allowed() and not ServiceLocator.get_dialogue_manager().is_dialogue_active():
			ServiceLocator.get_companion_manager().call_next()
		_assist_down = down
		return
	# D202: перемкнути зброю в руці (не посеред удару)
	if ev.is_action_pressed(&"weapon_next") or ev.is_action_pressed(&"weapon_prev"):
		if not event and not combat.is_attacking:
			ServiceLocator.get_equipment_manager().cycle_weapon(1 if ev.is_action_pressed(&"weapon_next") else -1)
		return
	if ev.is_action_pressed(&"dodge") and not event and not combat.owns_animation():
		if mover.start_roll():
			animation = &"Roll"
			$AnimationPlayer.play(&"Roll")
			$Sprite2D.modulate.a = ROLL_ALPHA
		return
	# Блок / парирування (D264): поки кнопку тримають; починається, щойно герой вільний (PlayerCombat).
	if ev.is_action(&"block"):
		combat.block_held = ev.is_pressed() and not event
		return
	var light := ev.is_action_pressed(&"attack")
	if (light or ev.is_action_pressed(&"heavy_attack")) and not mover.is_rolling() and not mover.is_climbing():
		if event:
			return  # під час катсцени не б'ємо
		if ev is InputEventMouseButton and get_tree().paused:
			return
		# Посеред удару натискання лягає в чергу серії — тож тут не перевіряємо, чи бій вільний.
		if light:
			combat.perform_attack(last_direction)
		else:
			combat.heavy_attack(last_direction)

func _update_facing() -> void:
	"""Єдине місце, де виставляється flip_h.

	Спрайт намальований обличчям ПРАВОРУЧ, тому дзеркалимо лише при русі ліворуч.
	Усі анімації, Jump і Fall теж, дивляться туди ж, куди герой іде: раніше Fall брав
	напрямок, зафіксований у момент стрибка, і при сході з краю без стрибка падав обличчям праворуч.
	"""
	$Sprite2D.flip_h = last_direction < 0

func die() -> void:
	"""Override CombatBody2D.die() to call kill() for player respawn"""
	# Вызываем родительский die() для установки is_dead и эмита сигналов
	super.die()

	if defeat_handler.is_valid():
		defeat_handler.call()
		return

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
	# HP-бар живе в Game.tscn → UICanvas/PlayerHealthBar; без нього — помилка, не запасний бар зі скрипта.
	health_bar = scene.get_node(^"UICanvas/PlayerHealthBar") as HealthBar

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
	mover.climbing = null  # драбина лишилась у старій кімнаті (D225)

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

func _spawn_level_up_vfx() -> void:
	"""Spawns level up celebration VFX (flash + particles)"""
	# Spawn full-screen white flash
	if LEVEL_UP_FLASH_SCENE:
		var flash = LEVEL_UP_FLASH_SCENE.instantiate()
		if flash:
			# Add to UI layer (z_index high to be on top)
			get_tree().current_scene.add_child(flash)
			flash.z_index = 300  # Above all other UI

	# Spawn golden particle burst from player
	if LEVEL_UP_PARTICLES_SCENE:
		var particles = LEVEL_UP_PARTICLES_SCENE.instantiate()
		if particles:
			# Add to scene root (not player child, so it persists if player moves)
			get_tree().current_scene.add_child(particles)
			particles.global_position = global_position
			particles.z_index = 200  # Above gameplay, below flash

	DebugLogger.verbose("Player: Spawned level up VFX", "Player")

## Max HP за формулою меню (D205). Підвищення лікує на різницю, зниження лише обрізає поточне HP.
func refresh_max_health() -> void:
	var old_max := Max_Health
	Max_Health = ServiceLocator.get_game_manager().calculate_max_health()
	current_health = clampi(current_health + maxi(0, Max_Health - old_max), 0, Max_Health)
	health_changed.emit(current_health, Max_Health, true)
	if health_bar:
		health_bar.max_value = Max_Health
		health_bar.current_value = current_health
		if health_bar.bar:
			health_bar.bar.max_value = Max_Health
			health_bar.bar.value = current_health
		health_bar.update_health_text()
		health_bar.update_health_color(current_health)


## Ушкодження героєві: спершу захист у відсотках (D206), далі Shield Block зі щитом (D207). Щонайменше 1.
## Souls-lite (D264): удар ворога, що справді поранив, збиває героя — на stagger_time ворога, фінішер серії довше.
## Блок спереду (4b) шкоди не завдає й не збиває; удар, що збив би на GUARD_BREAK і довше (tank, фінішер серії),
## пробиває блок — повна шкода і збій. Парирування в перші PARRY_WINDOW с блоку — без шкоди, збиває самого ворога.
func take_damage(damage: int, source: Node = null) -> void:
	if is_invulnerable or is_dead:
		return
	var guard := combat.guard_against(source)
	if guard == &"parry":
		source.parried(self)
		EventBus.player_parried.emit(source)
		return
	if guard == &"block":
		EventBus.player_blocked.emit(source)
		if source.hit_stagger_time() < PlayerCombat.GUARD_BREAK:
			return
	var before := current_health
	super.take_damage(mitigated_damage(damage), source)
	if current_health >= before or is_dead or not source is DefaultEnemy:
		return
	combat.stagger(source.hit_stagger_time(), source.global_position.x)


func mitigated_damage(damage: int) -> int:
	var gm := ServiceLocator.get_game_manager()
	var result: float = damage * 100.0 / (100.0 + gm.calculate_physical_defense())
	var skills: SkillManager = ServiceLocator.get_skill_manager()
	# Щит працює, лише якщо в руках не дворучна зброя (D267)
	if gm.player_state.equipment.get("shield") != null and combat.grip != &"two_handed":
		result *= 1.0 - minf(MAX_SKILL_REDUCTION, skills.passive_value("shield_block"))
	result *= 1.0 - minf(MAX_SKILL_REDUCTION, skills.passive_value("damage_reduction"))  # D284
	return maxi(1, roundi(result))


func _on_player_leveled_up(new_level: int, _old_level: int) -> void:
	"""Called when player levels up - applies stat bonuses"""
	var old_max_hp := Max_Health
	refresh_max_health()
	DebugLogger.info("Player: Level %d! HP: %d->%d" % [new_level, old_max_hp, Max_Health], "Player")

	# === LEVEL UP VFX ===
	_spawn_level_up_vfx()
