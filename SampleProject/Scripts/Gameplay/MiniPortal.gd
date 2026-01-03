# A portal object that transports to another room.
extends Area2D

# The target map after entering the portal.
@export var target_map: String
# Spawn offset from portal position (prevents player from re-entering portal immediately)
@export var spawn_offset: Vector2 = Vector2(150, 0)

# Simple cooldown tracking - shared across all portal instances via static variable
static var last_teleport_time: float = -999.0
static var cooldown_duration: float = 3.0

func _on_body_entered(body: Node2D) -> void:
	# If player entered and isn't doing an event (event in this case is entering the portal).
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last_teleport = current_time - last_teleport_time

	if body.is_in_group(&"player") and not body.event and time_since_last_teleport >= cooldown_duration:
		body.event = true
		last_teleport_time = current_time

		# Teleport player to the exit portal position after the room has changed.
		Game.get_singleton().room_loaded.connect(move_to_portal, CONNECT_ONE_SHOT)
		# Load the new room.
		Game.get_singleton().load_room(target_map)

# Needs to be static, because the old portal disappears before the new scene is loaded.
static func move_to_portal():
	var map := Game.get_singleton().map
	# Get the portal node.
	var portal = map.get_node(^"MiniPortal")

	# Get spawn offset (use property if exists, otherwise default)
	var offset := Vector2(50, 0)
	if "spawn_offset" in portal:
		offset = portal.spawn_offset

	# Move the player to portal with configured spawn offset (prevents re-entry loop)
	var player = Game.get_singleton().player
	player.position = portal.position + offset

	# CRITICAL: Clear event flag IMMEDIATELY after positioning
	# This allows player to move and use other portals right away
	player.event = false

	print("🌀 Portal: Spawned player at %s (offset: %s from portal)" % [player.position, offset])

	# Disable portal monitoring for 3 seconds to prevent immediate re-entry
	# Use set_deferred to avoid "locked" errors
	portal.set_deferred("monitoring", false)
	map.get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(portal):
			portal.set_deferred("monitoring", true)
			print("🌀 Portal: Monitoring re-enabled, portal is active again")
	)
