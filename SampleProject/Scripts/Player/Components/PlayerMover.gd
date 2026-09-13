extends Node
class_name PlayerMover

## Component handling player movement physics, extracted from Player.gd.
## Following SRP: this class only cares about gravity, jumping, horizontal
## movement and landing detection. Animation state is decided by Player.gd,
## which reads `last_direction` / `jump_direction` from this component.
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

var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

# --- Movement state ---
# Public on purpose: Player.gd reads last_direction/jump_direction to decide
# which animation/flip to show, and VFX/save code reads last_direction too
# (via Player's forwarding property).
var speed: float = 0.0        # seeded from speed_min in _ready()
var last_direction: int = 1   # 1 = right, -1 = left
var jump_direction: int = 1   # direction locked at jump time, used for Fall animation
var double_jump: bool = false
var airtime: float = 0.0
var prev_on_floor: bool = false
var fall_start_height: float = 0.0

# Parent reference: the CharacterBody2D that owns this component (the Player).
@onready var player: CharacterBody2D = get_parent()


func _ready() -> void:
	# speed can't be initialised from speed_min at declaration (exported vars are
	# not assigned yet at that point), so seed it here.
	speed = speed_min

## Runs one physics step of movement: gravity, jump, horizontal movement,
## move_and_slide() and landing detection. Call once per Player._physics_process.
func physics_move(delta: float) -> void:
	_apply_gravity_and_track_fall(delta)
	_handle_jump()

	if player.is_on_wall():
		speed = speed_min

	_handle_horizontal_movement(delta)

	var was_in_air := not prev_on_floor
	prev_on_floor = player.is_on_floor()

	player.move_and_slide()

	if OS.is_debug_build() and absf(player.velocity.x) > 10:
		if player.is_on_wall() and absf(player.velocity.x) > 1:
			DebugLogger.physics_warning("PlayerMover: Рух блокується стіною (is_on_wall = true)", "player_wall")

	_handle_landing(was_in_air, player.is_on_floor())


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
	if Input.is_action_just_pressed("jump") and (on_floor_ct or double_jump) and not Input.is_key_pressed(KEY_ESCAPE):
		if not on_floor_ct:
			double_jump = false

		if Input.is_action_pressed("move_down"):
			player.position.y += 8
		else:
			player.velocity.y = jump_velocity

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

	if absf(player.velocity.x) > 1:
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

	if EventBus and EventBus.has_signal("player_landed"):
		DebugLogger.physics_verbose("PlayerMover: Emitting player_landed signal with fall_height = %.1f" % fall_height, "player_landing")
		EventBus.player_landed.emit(fall_height)
