extends Node
class_name PlayerCombat

## Component handling player combat logic extracted from Player.gd
## Following SRP: This class only cares about attacking and damage state.

# External references
@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer
@export var hitbox: Area2D
@export var damage_applier: DamageApplier

# Combat parameters. Голі руки: кулдаун тут, хітбокс — Player.tscn (Hitbox 40×32); зброя в руці
# перезаписує обидва своїм weapon_profile з items.json (D203).
@export var attack_cooldown_time: float = 0.5
## Відкидання ворога від удару, px (булава, D203).
var knockback: float = 0.0
var _bare_size: Vector2
var _bare_cooldown: float
var attack_cooldown: float = 0.0
var is_attacking: bool = false

# Parent reference (for getting direction and signals)
@onready var player = get_parent()

func _ready() -> void:
	_bare_size = _hitbox_shape().size
	_bare_cooldown = attack_cooldown_time
	_set_hitbox_active(false, 1) # Ensure hitbox is disabled on start
	EventBus.weapon_in_hand_changed.connect(func(_slot: String) -> void: apply_weapon_profile())
	damage_applier.damage_applied.connect(_on_damage_applied)
	apply_weapon_profile()

## Профіль удару зброї в руці (D202/D203): довжина й висота хітбокса, кулдаун, відкидання.
func apply_weapon_profile() -> void:
	var item: Dictionary = ServiceLocator.get_equipment_manager().get_weapon_item_in_hand()
	if item.is_empty():
		_hitbox_shape().size = _bare_size
		attack_cooldown_time = _bare_cooldown
		knockback = 0.0
		return
	var profile: Dictionary = item.weapon_profile
	_hitbox_shape().size = Vector2(profile.reach, profile.height)
	attack_cooldown_time = profile.cooldown
	knockback = profile.knockback

func _hitbox_shape() -> RectangleShape2D:
	return hitbox.get_node(^"CollisionShape2D").shape

## Булава відкидає того, по кому влучила, — геть від героя.
func _on_damage_applied(target: Node, _damage: int) -> void:
	if knockback > 0.0:
		target.knockback(signf(target.global_position.x - player.global_position.x) * knockback)

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
		# Хітбокс починається біля героя й тягнеться на довжину зброї вперед. Ту саму зону бʼють навички (D142).
		hitbox.position = Vector2(_hitbox_shape().size.x / 2.0 * signi(last_direction), 0)
	hitbox.monitoring = active
	hitbox.monitorable = active

	if active:
		damage_applier.enable_damage()
	else:
		damage_applier.disable_damage()
