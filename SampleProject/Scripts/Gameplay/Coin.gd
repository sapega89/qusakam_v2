extends Area2D
class_name Coin

## Coin Collectible
## Automatically flies toward player and awards coins on collection

var coin_value: int = 1
var collection_speed: float = 300.0
var is_collected: bool = false
var collect_distance: float = 50.0  # Distance to trigger collection

var target_player: Node2D = null

func _ready() -> void:
	"""Initialize coin and start collection"""
	add_to_group("collectibles")
	body_entered.connect(_on_body_entered)

	# Find player
	var players = get_tree().get_nodes_in_group(GameGroups.PLAYER)
	if players.size() > 0:
		target_player = players[0]
		# Start moving toward player after short delay
		await get_tree().create_timer(0.2).timeout
		if is_instance_valid(self):
			_start_collection()

	DebugLogger.verbose("Coin: Created at %s" % global_position, "Coin")

func _physics_process(delta: float) -> void:
	"""Move coin toward player"""
	if not is_collected:
		return

	if not target_player or not is_instance_valid(target_player):
		queue_free()
		return

	# Check if close enough to collect
	var distance = global_position.distance_to(target_player.global_position)
	if distance < collect_distance:
		_collect()
		return

	# Move toward player
	var direction = (target_player.global_position - global_position).normalized()
	global_position += direction * collection_speed * delta

	# Speed up as we get closer
	collection_speed += 150 * delta

func _on_body_entered(body: Node2D) -> void:
	"""Collect coin when player touches it"""
	if body.is_in_group(GameGroups.PLAYER) and not is_collected:
		_collect()

func _start_collection() -> void:
	"""Start moving toward player"""
	is_collected = true

func _collect() -> void:
	"""Collect the coin and add to inventory"""
	if not is_instance_valid(self):
		return

	# Add coins to inventory
	var inventory = ServiceLocator.get_inventory_manager()
	if inventory:
		inventory.add_coins(coin_value)
		DebugLogger.verbose("Coin: Collected! Value: %d" % coin_value, "Coin")
	else:
		DebugLogger.warning("Coin: InventoryManager not found", "Coin")

	# Emit EventBus signal (InventoryManager should emit, but as fallback)
	EventBus.coins_changed.emit(inventory.get_coins() if inventory else 0)

	# Spawn collection particle effect
	_spawn_collection_particle()

	# Remove coin
	queue_free()

func _spawn_collection_particle() -> void:
	"""Creates a small particle burst on collection"""
	var particles = CPUParticles2D.new()

	# Add to scene root so it persists after coin is freed
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(particles)
	else:
		get_parent().add_child(particles)

	particles.global_position = global_position

	# Particle properties
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 8
	particles.lifetime = 0.6
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180
	particles.initial_velocity_min = 60
	particles.initial_velocity_max = 120
	particles.gravity = Vector2(0, 300)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0

	# Yellow color for coins
	particles.color = Color(1.0, 0.9, 0.3, 1.0)

	# Auto-delete after emission
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()
