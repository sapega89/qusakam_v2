# A portal object that transports to another world layer.
extends Area2D
# The target map after entering the portal.
@export var target_map: String

# Simple cooldown tracking - shared across all portal instances via static variable
static var last_teleport_time: float = -999.0
static var cooldown_duration: float = 3.0

func _on_body_entered(body: Node2D) -> void:
	# Check cooldown before allowing teleport
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last_teleport = current_time - last_teleport_time

	# If player entered and isn't doing an event (event in this case is entering the portal).
	if body.is_in_group(&"player") and not body.event and time_since_last_teleport >= cooldown_duration:
		body.event = true
		last_teleport_time = current_time
		body.velocity = Vector2()

		# Disable this portal's monitoring to prevent re-entry during animation
		# Use set_deferred because we're inside the body_entered signal
		set_deferred("monitoring", false)

		# Tween the player position into the portal.
		var tween := create_tween()
		tween.tween_property(body, ^"position", position, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
		await tween.finished
		# After tween finished, change the map.
		Game.get_singleton().load_room(target_map)

		# CRITICAL: Clear event flag IMMEDIATELY after loading room
		if body and is_instance_valid(body):
			body.event = false

		# Delta vector feature again.
		Game.get_singleton().reset_map_starting_coords()

		# Re-enable monitoring after 3 seconds to prevent immediate re-entry
		await get_tree().create_timer(3.0).timeout
		set_deferred("monitoring", true)
		print("🌀 Portal: Monitoring re-enabled, portal is active again")
		
