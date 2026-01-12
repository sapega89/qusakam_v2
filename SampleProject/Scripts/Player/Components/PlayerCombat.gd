extends Node
class_name PlayerCombat

## Component handling player combat logic extracted from Player.gd
## Following SRP: This class only cares about attacking and damage state.

# External references
@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer
@export var hitbox: Area2D
@export var damage_applier: Node # DamageApplier

# Combat parameters
@export var attack_cooldown_time: float = 0.5
var attack_cooldown: float = 0.0
var is_attacking: bool = false

# Parent reference (for getting direction and signals)
@onready var player = get_parent()

func _ready() -> void:
	_set_hitbox_active(false, 1) # Ensure hitbox is disabled on start
	if Engine.has_singleton("EventBus"):
		var bus = Engine.get_singleton("EventBus")
		if bus.has_signal("player_leveled_up"):
			bus.player_leveled_up.connect(_on_player_leveled_up)

func _on_player_leveled_up(new_level: int, _old_level: int) -> void:
	if not damage_applier: return
	
	if Engine.has_singleton("ServiceLocator"):
		var loc = Engine.get_singleton("ServiceLocator")
		var xp_manager = loc.get_xp_manager()
		if xp_manager:
			var damage_bonus = xp_manager.get_damage_bonus()
			if "current_damage" in damage_applier and "base_damage" in damage_applier:
				damage_applier.current_damage = damage_applier.base_damage + damage_bonus
				DebugLogger.info("PlayerCombat: Applied level %d bonus. Damage: %d" % [new_level, damage_applier.current_damage], "Player")

func _process(delta: float) -> void:
	if attack_cooldown > 0:
		attack_cooldown -= delta

func perform_attack(last_direction: int) -> void:
	if is_attacking or attack_cooldown > 0:
		return
	
	is_attacking = true
	attack_cooldown = attack_cooldown_time
	
	# Current direction logic (extracted from Player.gd)
	_update_attack_direction(last_direction)
	
	# Play animation
	if animation_player and animation_player.has_animation("Attack"):
		animation_player.play("Attack")
		if player:
			player.animation = "Attack"
	
	# Spawn VFX
	if player.has_method("_spawn_attack_vfx"):
		player._spawn_attack_vfx()

	# Signals
	if Engine.has_singleton("EventBus"):
		var bus = Engine.get_singleton("EventBus")
		if bus.has_signal("player_attacked"):
			bus.player_attacked.emit(player, last_direction)
	
	# Activate Hitbox
	_set_hitbox_active(true, last_direction)
	
	# Wait for animation completion
	if animation_player and animation_player.has_animation("Attack"):
		await animation_player.animation_finished
	else:
		await get_tree().create_timer(0.2).timeout
	
	# Cleanup
	_set_hitbox_active(false, last_direction)
	is_attacking = false
	
	# Note: Animating back to Idle/Run is handled by Player's main loop
	# but we should notify if needed.

func _update_attack_direction(last_direction: int) -> void:
	if not sprite: return
	
	# Logic from Player.gd: attack flips differently than movement
	if last_direction > 0:
		sprite.flip_h = false
	else:
		sprite.flip_h = true

func _set_hitbox_active(active: bool, last_direction: int) -> void:
	if hitbox:
		if active:
			var hitbox_offset = Vector2(20, 0) if last_direction > 0 else Vector2(-20, 0)
			hitbox.position = hitbox_offset
			hitbox.monitoring = true
			hitbox.monitorable = true
		else:
			hitbox.monitoring = false
			hitbox.monitorable = false
			
	if damage_applier:
		if active:
			if damage_applier.has_method("enable_damage"):
				damage_applier.enable_damage()
		else:
			if damage_applier.has_method("disable_damage"):
				damage_applier.disable_damage()
