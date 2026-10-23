extends Node
class_name PlayerMover

## Component handling player movement physics, extracted from Player.gd.
## Following SRP: this class only cares about gravity, jumping, horizontal
## movement and landing detection. Animation state is decided by Player.gd,
## which reads `last_direction` from this component.
##
## Mirrors the PlayerCombat pattern: a plain Node child that operates on
## its parent CharacterBody2D.

# --- Tuning (game feel: adjust on the PlayerMover node in Player.tscn) ---
# Values match the originals from Player.gd; exported so balance can be tuned
# in the inspector without touching code.
@export var speed_min := 300.0
@export var speed_max := 400.0
@export var accel := 50.0
@export var jump_velocity := -450.0  # negative = upwards (Godot Y grows down)
@export var max_fall_speed := 900.0
@export var coyote_time := 0.1
@export var short_hop := 0.5
@export var min_fall_height_for_event := 20.0
## Перекат (D200, мок): тривалість, відстань, пауза після нього.
@export var roll_duration := 0.30
@export var roll_distance := 170.0
@export var roll_cooldown := 0.6
## Подвійний ривок (D264): стільки ривків підряд, і в повітрі теж; обидва повертаються через roll_cooldown
## після останнього. Наступний — не раніше, ніж через dash_chain_after с від початку попереднього.
@export var dash_charges_max := 2
@export var dash_chain_after := 0.1
## Драбини (D225): швидкість лазіння, px/s; стрибок з драбини — така частка звичайного.
@export var climb_speed := 170.0
@export var ladder_jump_factor := 0.6
## Кроки (D276): крок — кожні стільки px по підлозі і по драбині; звук — за поверхнею кімнати.
@export var step_distance := 95.0
@export var ladder_step_distance := 40.0

var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

# --- Movement state ---
# Public on purpose: Player.gd reads last_direction to decide
# which animation/flip to show, and VFX/save code reads last_direction too
# (via Player's forwarding property).
var speed: float = 0.0        # seeded from speed_min in _ready()
var last_direction: int = 1   # 1 = right, -1 = left
var double_jump: bool = false
var airtime: float = 0.0
var prev_on_floor: bool = false
var fall_start_height: float = 0.0
var roll_time_left: float = 0.0
var roll_ready_in: float = 0.0  # до повернення ривків: останній ривок + roll_cooldown
var dash_charges: int = 2
var roll_direction: int = 1
## Драбина, по якій зараз лізе герой (Ladder.gd), або null. Скидає Player.on_enter при переході кімнати.
var climbing: Node2D = null
## Рух вимкнено боєм (збій, D264) — Player ставить щокадру з PlayerCombat.locks_movement().
var locked: bool = false
## Погляд не змінюється (D504, B136): удар ще не вийшов — Player ставить щокадру з PlayerCombat.locks_facing().
var facing_locked: bool = false
## Буфер стрибка (D504): натиснутий завчасно (в ударі, за мить до приземлення) чекає стільки секунд.
const JUMP_BUFFER := 0.1
var _jump_buffer: float = 0.0
## Поштовх від удару по герою (D264): швидкість і скільки ще триває.
var _push_speed: float = 0.0
var _push_left: float = 0.0
## Пройдено від останнього кроку, px.
var _stride: float = 0.0
## Вороги, крізь яких герой зараз проходить перекатом (D443).
var _passing: Array[Node] = []

# Parent reference: the CharacterBody2D that owns this component (the Player).
@onready var player: CharacterBody2D = get_parent()


func _ready() -> void:
	# speed can't be initialised from speed_min at declaration (exported vars are
	# not assigned yet at that point), so seed it here.
	speed = speed_min

## Поштовх на [param distance] px за [param duration] с (збій від удару).
func push(distance: float, duration: float) -> void:
	_push_speed = distance / duration
	_push_left = duration


func is_rolling() -> bool:
	return roll_time_left > 0.0


func is_climbing() -> bool:
	return climbing != null


## Ривок можна почати зараз: не на драбині, є заряд, а посеред ривка — уже минуло dash_chain_after.
func can_roll() -> bool:
	return not is_climbing() and dash_charges > 0 and not (is_rolling() and roll_time_left > roll_duration - dash_chain_after)


## Удар повертає героя туди, куди тиснуть (D504: між ударами серії можна розвернутись); нічого не тиснуть —
## [param fallback]. Повертає новий погляд.
func face_input(fallback: int) -> int:
	var held := Input.get_axis(&"move_left", &"move_right")
	last_direction = (1 if held > 0.0 else -1) if absf(held) > 0.1 else fallback
	return last_direction


## Стрибок натиснуто щойно і він ще чекає (D504).
func jump_buffered() -> bool:
	return _jump_buffer > 0.0


## Перекат-ривок (D200, D264): dash_charges_max підряд, з землі й у повітрі (у повітрі — рівно, без падіння).
## Невразливість — на весь ривок. Напрямок — куди тиснуть, інакше куди дивиться герой. Повертає, чи ривок почався.
func start_roll() -> bool:
	if not can_roll():
		return false
	var held := Input.get_axis(&"move_left", &"move_right")
	roll_direction = (1 if held > 0.0 else -1) if absf(held) > 0.1 else last_direction
	last_direction = roll_direction
	roll_time_left = roll_duration
	dash_charges -= 1
	roll_ready_in = roll_duration + roll_cooldown
	player.set_invulnerable(true, roll_duration)
	_pass_through_enemies()
	AudioManager.play(&"dash")
	return true


## D443: ворог зупиняє героя, а перекат проходить крізь нього. Виняток тіл на весь ривок; знімається, щойно герой
## уже не всередині ворога (_release_passed) — інакше фізика розштовхувала б їх і могла б поставити когось нагору.
func _pass_through_enemies() -> void:
	for enemy in player.get_tree().get_nodes_in_group(GameGroups.ENEMIES):
		if enemy not in _passing:
			player.add_collision_exception_with(enemy)
			_passing.append(enemy)


func _release_passed() -> void:
	for enemy in _passing.duplicate():
		if not is_instance_valid(enemy):
			_passing.erase(enemy)
		elif not player.body_rect().intersects(enemy.body_rect()):
			player.remove_collision_exception_with(enemy)
			_passing.erase(enemy)


## Runs one physics step of movement: gravity, jump, horizontal movement,
## move_and_slide() and landing detection. Call once per Player._physics_process.
func physics_move(delta: float) -> void:
	if roll_ready_in > 0.0:
		roll_ready_in -= delta
		if roll_ready_in <= 0.0:
			dash_charges = dash_charges_max
	if not is_climbing():
		_apply_gravity_and_track_fall(delta)
	_jump_buffer = JUMP_BUFFER if Input.is_action_just_pressed(&"jump") else maxf(0.0, _jump_buffer - delta)

	if _push_left > 0.0:
		_push_left -= delta
		player.velocity.x = _push_speed
	elif locked:
		player.velocity.x = 0.0
	elif is_rolling():
		# Під час перекату — рівна швидкість, без стрибка й керування
		roll_time_left -= delta
		player.velocity.x = roll_direction * roll_distance / roll_duration
		if not player.is_on_floor():
			player.velocity.y = 0.0  # ривок у повітрі — рівно, без падіння
	elif is_climbing() or _grab_ladder():
		_climb()
	else:
		_handle_jump()
		if player.is_on_wall():
			speed = speed_min
		_handle_horizontal_movement(delta)

	var was_in_air := not prev_on_floor
	prev_on_floor = player.is_on_floor()

	player.move_and_slide()
	if not is_rolling():
		_release_passed()
	player.slide_off_bodies(delta)

	if OS.is_debug_build() and absf(player.velocity.x) > 10:
		if player.is_on_wall() and absf(player.velocity.x) > 1:
			DebugLogger.physics_warning("PlayerMover: Рух блокується стіною (is_on_wall = true)", "player_wall")

	_handle_landing(was_in_air, player.is_on_floor())
	_footsteps(delta)


## Крок звучить кожні step_distance px бігу по підлозі (ривок — без кроків), на драбині — кожні ladder_step_distance.
func _footsteps(delta: float) -> void:
	var on_ladder := is_climbing()
	if not (on_ladder or (player.is_on_floor() and not is_rolling())):
		_stride = 0.0
		return
	_stride += absf(player.velocity.y if on_ladder else player.velocity.x) * delta
	var every: float = ladder_step_distance if on_ladder else step_distance
	if _stride < every:
		return
	_stride -= every
	if on_ladder:
		AudioManager.play(&"ladder")
		return
	var map: Node = Game.get_singleton().map
	if map == null:
		return  # між кімнатами (teleport_to_room)
	var room: String = map.scene_file_path.get_file().get_basename()
	AudioManager.play(StringName("step_" + AudioManager.room(room).surface))


## Драбина, на якій зараз центр героя, або null.
func _ladder_at() -> Node2D:
	for ladder in get_tree().get_nodes_in_group(GameGroups.LADDERS):
		if ladder.contains(player.global_position):
			return ladder
	return null


## Ставати на драбину: знизу чи посередині — ↑; стоячи на містку над нею — ↓ (крізь односторонній місток).
## ↑ має перевагу над стрибком: W — і стрибок, і «вгору».
func _grab_ladder() -> bool:
	var ladder := _ladder_at()
	if ladder == null:
		return false
	var on_top: bool = player.is_on_floor() and player.global_position.y < ladder.global_position.y
	if Input.is_action_pressed(&"move_down") and on_top:
		player.position.y += 8.0  # під поверхню містка — односторонній більше не тримає
	elif not (Input.is_action_pressed(&"move_up") and not on_top):
		return false
	climbing = ladder
	player.velocity = Vector2.ZERO
	airtime = 0.0
	fall_start_height = 0.0
	return true


## На драбині: ↑/↓ лізе, герой по центру драбини; стрибок без ↑ — зіскок; ↓ на підлозі внизу — зійти;
## вище верху драбини — сходить на місток.
func _climb() -> void:
	if not climbing.contains(player.global_position):
		climbing = null
		return
	var axis := Input.get_axis(&"move_up", &"move_down")
	player.global_position.x = climbing.global_position.x
	player.velocity = Vector2(0.0, axis * climb_speed)
	if Input.is_action_just_pressed(&"jump") and not Input.is_action_pressed(&"move_up"):
		climbing = null
		_jump_buffer = 0.0  # це вже стрибок — не ще один з буфера
		player.velocity.y = jump_velocity * ladder_jump_factor
		AudioManager.play(&"jump")
	elif axis > 0.0 and player.is_on_floor() and player.global_position.y > climbing.global_position.y:
		climbing = null  # унизу, на підлозі під драбиною (на містку згори — це ще початок спуску)


func _apply_gravity_and_track_fall(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y = min(player.velocity.y + gravity * delta, max_fall_speed)
		airtime += delta
		# Зберігаємо висоту початку падіння (тільки якщо падаємо вниз і ще не зберегли)
		if player.velocity.y > 50.0 and fall_start_height == 0.0:
			fall_start_height = player.global_position.y
	elif not prev_on_floor and &"double_jump" in player.abilities:
		# Some simple double jump implementation.
		double_jump = true
		airtime = 0


func _handle_jump() -> void:
	var on_floor_ct: bool = player.is_on_floor() or airtime < coyote_time

	# Jump with Space or W. Ігноруємо, якщо натиснуто Escape (щоб не стрибати при відкритті меню).
	if _jump_buffer > 0.0 and (on_floor_ct or double_jump) and not Input.is_key_pressed(KEY_ESCAPE):
		_jump_buffer = 0.0
		if not on_floor_ct:
			double_jump = false

		if Input.is_action_pressed("move_down"):
			player.position.y += 8
		else:
			player.velocity.y = jump_velocity
			# Кнопку вже відпустили, поки стрибок чекав у буфері, — короткий стрибок
			if not Input.is_action_pressed("jump"):
				player.velocity.y -= jump_velocity * short_hop
			AudioManager.play(&"jump")

	if Input.is_action_just_released("jump"):
		if not player.is_on_floor() and player.velocity.y < 0:
			player.velocity.y = min(0, player.velocity.y - jump_velocity * short_hop)


func _handle_horizontal_movement(delta: float) -> void:
	# Move with A/D or Arrow keys. Клавіатура має пріоритет над джойстиком.
	var direction := 0.0

	if Input.is_action_pressed("move_left"):
		direction -= 1.0
	if Input.is_action_pressed("move_right"):
		direction += 1.0

	if direction == 0.0 and Input.get_connected_joypads().size() > 0:
		var joypad_direction = Input.get_axis("move_left", "move_right")
		if abs(joypad_direction) > 0.1:
			direction = joypad_direction

	if direction:
		speed = min(speed_max, speed + accel * delta)
		player.velocity.x = direction * speed
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, speed_min)
		speed = speed_min

	if absf(player.velocity.x) > 1 and not facing_locked:
		last_direction = sign(player.velocity.x)


func _handle_landing(was_in_air: bool, now_on_floor: bool) -> void:
	if not (was_in_air and now_on_floor):
		return

	# В Godot Y росте вниз, тому кінцева позиція більша за початкову.
	var fall_height: float = 0.0
	if fall_start_height > 0.0:
		fall_height = player.global_position.y - fall_start_height
		DebugLogger.physics_verbose("PlayerMover: Landing! Fall height = %.1f pixels (start: %.1f, end: %.1f)" % [fall_height, fall_start_height, player.global_position.y], "player_landing")
	else:
		DebugLogger.physics_verbose("PlayerMover: Landing but no fall_start_height recorded (probably small jump)", "player_landing")

	fall_start_height = 0.0
	airtime = 0

	if fall_height < min_fall_height_for_event:
		DebugLogger.physics_verbose("PlayerMover: Fall height too small (%.1f < %.1f), skipping effect" % [fall_height, min_fall_height_for_event], "player_landing")
		return

	DebugLogger.physics_verbose("PlayerMover: Emitting player_landed signal with fall_height = %.1f" % fall_height, "player_landing")
	EventBus.player_landed.emit(fall_height)
