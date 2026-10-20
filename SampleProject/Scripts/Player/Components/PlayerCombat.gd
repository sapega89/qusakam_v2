extends Node
class_name PlayerCombat

## Component handling player combat logic extracted from Player.gd
## Following SRP: This class only cares about attacking and damage state.
## Стан бою souls-lite (D264): удар, збій від ворожого удару. Таймери — у _physics_process, а не await анімації.

enum State { READY, SWING, STAGGER }

# External references
@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer
@export var hitbox: Area2D
@export var damage_applier: DamageApplier

# Combat parameters. Голі руки: кулдаун тут, хітбокс — Player.tscn (Hitbox 40×32); зброя в руці
# перезаписує обидва своїм weapon_profile з items.json (D203).
@export var attack_cooldown_time: float = 0.5
## Тривалість одного удару — довжина анімації Attack у Player.tscn.
@export var swing_time: float = 0.3
## Збій героя (D264): на скільки px його відносить від того, хто вдарив, і за який час.
@export var stagger_push: float = 50.0
@export var stagger_push_time: float = 0.15
## Відкидання ворога від удару, px (булава, D203).
var knockback: float = 0.0
var _bare_size: Vector2
var _bare_cooldown: float
var attack_cooldown: float = 0.0

var state: State = State.READY
var _state_left: float = 0.0
var _direction: int = 1

var is_attacking: bool:
	get:
		return state == State.SWING

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

## Влучання: відкидання (булава) і стійкість ворога (D265).
func _on_damage_applied(target: Node, _damage: int) -> void:
	if knockback > 0.0:
		target.knockback(signf(target.global_position.x - player.global_position.x) * knockback)
	target.take_poise(1, player.global_position.x)

## Сила удару = Phys. Atk. з меню (D199): сила, зброя, бонус рівня. Береться на кожен удар,
## тож зміна спорядження чи рівня діє одразу, без підписок.
func hit_damage() -> int:
	return ServiceLocator.get_game_manager().calculate_physical_damage()

func _process(delta: float) -> void:
	if attack_cooldown > 0:
		attack_cooldown -= delta

func _physics_process(delta: float) -> void:
	if state == State.READY:
		return
	_state_left -= delta
	if _state_left > 0.0:
		return
	if state == State.SWING:
		_set_hitbox_active(false, _direction)
	state = State.READY

## Гравець вийшов з дерева посеред дії (зміна сцени, вихід у меню) — дія скінчилась, а не застигла до повернення.
func _exit_tree() -> void:
	damage_applier.disable_damage()
	state = State.READY

## Анімацію героя зараз веде бій, а не рух (Player._physics_process її не перемикає).
func owns_animation() -> bool:
	return state != State.READY

## Рух вимкнено: героя збито.
func locks_movement() -> bool:
	return state == State.STAGGER

func is_staggered() -> bool:
	return state == State.STAGGER

func perform_attack(last_direction: int) -> void:
	if state != State.READY or attack_cooldown > 0:
		return
	state = State.SWING
	_state_left = swing_time
	_direction = last_direction
	attack_cooldown = attack_cooldown_time
	damage_applier.current_damage = hit_damage()

	# flip_h більше не чіпаємо: єдине джерело — Player._update_facing().
	animation_player.play(&"Attack")
	player.animation = &"Attack"

	# Signals — без цього VFXHooks._on_player_attacked() не спрацьовував жодного разу
	EventBus.player_attacked.emit(player, last_direction)
	_set_hitbox_active(true, last_direction)

## Удар ворога збив героя (D264): дія, що йшла, зірвана, герой відлітає від [param from_x] і [param duration] с
## не керується. «Вороги інколи заморожують героя» (D253) — довгий збій від tank і фінішера серії.
func stagger(duration: float, from_x: float) -> void:
	if state == State.SWING:
		_set_hitbox_active(false, _direction)
	state = State.STAGGER
	_state_left = duration
	animation_player.play(&"Hurt")
	player.animation = &"Hurt"
	var away: float = signf(player.global_position.x - from_x)
	player.mover.push(away * stagger_push, stagger_push_time)
	EventBus.player_staggered.emit(duration)

func _set_hitbox_active(active: bool, last_direction: int) -> void:
	if active:
		# Хітбокс починається біля героя й тягнеться на довжину зброї вперед. Ту саму зону бʼють навички (D142).
		hitbox.position = Vector2(_hitbox_shape().size.x / 2.0 * signi(last_direction), 0)
	# Відкладено: збій героя приходить із body_entered хітбокса ворога, посеред фізичного запиту.
	hitbox.set_deferred(&"monitoring", active)
	hitbox.set_deferred(&"monitorable", active)

	if active:
		damage_applier.enable_damage()
	else:
		damage_applier.disable_damage()
