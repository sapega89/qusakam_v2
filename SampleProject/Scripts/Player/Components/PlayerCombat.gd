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
	# EventBus і ServiceLocator — autoload'и (/root/EventBus), а не Engine-синглтони.
	# Engine.has_singleton() для них ЗАВЖДИ повертав false, тож жодна з трьох гілок
	# у цьому файлі не виконувалась: підписка на левел-ап не ставилась, бонус до
	# шкоди не застосовувався, а player_attacked не емітився (див. perform_attack).
	# Та сама бага, що вже виправлена у Village.gd і DesertRoad.gd.
	EventBus.player_leveled_up.connect(_on_player_leveled_up)

func _on_player_leveled_up(new_level: int, _old_level: int) -> void:
	damage_applier.current_damage = damage_applier.base_damage + ServiceLocator.get_xp_manager().get_damage_bonus()
	DebugLogger.info("PlayerCombat: Applied level %d bonus. Damage: %d" % [new_level, damage_applier.current_damage], "Player")

func _process(delta: float) -> void:
	if attack_cooldown > 0:
		attack_cooldown -= delta

func perform_attack(last_direction: int) -> void:
	if is_attacking or attack_cooldown > 0:
		return

	is_attacking = true
	attack_cooldown = attack_cooldown_time

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
	while animation_player.current_animation == &"Attack":
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
