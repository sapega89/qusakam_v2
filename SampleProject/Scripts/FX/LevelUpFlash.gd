extends ColorRect
class_name LevelUpFlash

## Level Up Flash VFX
## Full-screen white flash effect on level up

func _ready() -> void:
	"""Auto-play flash animation and cleanup"""
	# Start fully transparent
	modulate = Color.TRANSPARENT

	# Play flash animation
	_play_flash()

func _play_flash() -> void:
	"""Plays quick white flash animation"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

	# Flash to white (0.1s)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	# Fade out (0.4s)
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.4)

	# Wait for animation to finish, then cleanup
	await tween.finished
	queue_free()
