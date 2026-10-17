extends Node
class_name PlayerCombat

## Component handling player combat logic extracted from Player.gd
## Following SRP: This class only cares about attacking and damage state.

# External references
@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer
@export var hitbox: Area2D
@export var damage_applier: DamageApplier

## Зсув хітбокса атаки від центру гравця в бік погляду. Ту саму зону б'ють навички (D142).
const HITBOX_OFFSET_X := 20

# Combat parameters
@export var attack_cooldown_time: float = 0.5
var attack_cooldown: float = 0.0
var is_attacking: bool = false

# Parent reference (for getting direction and signals)
@onready var player = get_parent()

func _ready() -> void:
	_set_hitbox_active(false, 1) # Ensure hitbox is disabled on start

## Сила удару = Phys. Atk. з меню (D199): сила, зброя, бонус рівня. Береться на кожен удар,
## тож зміна спорядження чи рівня діє одразу, без підписок.
func hit_damage() -> int:
	return ServiceLocator.get_game_manager().calculate_physical_damage()

func _process(delta: float) -> void:
	if attack_cooldown > 0:
		attack_cooldown -= delta

func perform_attack(last_direction: int) -> void:
	if is_attacking or attack_cooldown > 0:
		return

	is_attacking = true
	attack_cooldown = attack_cooldown_time
	damage_applier.current_damage = hit_damage()

	# flip_h більше не чіпаємо: єдине джерело — Player._update_facing().
	# Раніше тут була протилежна домовленість, ніж у Player.gd, тож спрайт під час
	# атаки дивився не в той бік, що під час бігу.

	# Play animation
	animation_player.play("Attack")
	player.animation = "Attack"

	# Spawn VFX
	player._spawn_attack_vfx()

	# Signals — без цього VFXHooks._on_player_attacked() не спрацьовував жодного разу
	EventBus.player_attacked.emit(player, last_direction)

	# Activate Hitbox
	_set_hitbox_active(true, last_direction)

	# Чекаємо, поки Attack перестане грати — дограла або її перебили (діалог вмикає Idle).
	# animation_finished на перебиту анімацію не приходить, і is_attacking лишався true назавжди.
	# Гравець може вийти з дерева посеред атаки (зміна сцени / вихід у меню) — тоді
	# get_tree() == null, а AnimationPlayer поза деревом не грає, тож чекати нічого.
	while is_inside_tree() and animation_player.current_animation == &"Attack":
		await get_tree().process_frame

	# Cleanup
	_set_hitbox_active(false, last_direction)
	is_attacking = false

	# Note: Animating back to Idle/Run is handled by Player's main loop
	# but we should notify if needed.

func _set_hitbox_active(active: bool, last_direction: int) -> void:
	if active:
		hitbox.position = Vector2(HITBOX_OFFSET_X * signi(last_direction), 0)
	hitbox.monitoring = active
	hitbox.monitorable = active

	if active:
		damage_applier.enable_damage()
	else:
		damage_applier.disable_damage()
