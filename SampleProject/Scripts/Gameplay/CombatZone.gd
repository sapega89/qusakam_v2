extends Area2D
class_name CombatZone

## Combat Zone Trigger
## Shows narrative context when player enters combat area

@export var context_key: String = "generic"
@export var one_shot: bool = true  # Only trigger once

var has_triggered: bool = false

func _ready() -> void:
	"""Setup collision detection"""
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	"""Player entered combat zone"""
	if has_triggered and one_shot:
		return

	# Check if it's the player
	if not body.is_in_group(GameGroups.PLAYER):
		return

	has_triggered = true
	_show_combat_context()

func _show_combat_context() -> void:
	"""Displays the combat context message"""
	# Find CombatContextDisplay in the scene tree
	var context_display = _find_combat_context_display()
	if context_display and context_display.has_method("show_context"):
		context_display.show_context(context_key)
		DebugLogger.verbose("CombatZone: Showing context '%s'" % context_key, "CombatZone")
	else:
		DebugLogger.warning("CombatZone: CombatContextDisplay not found in scene", "CombatZone")

func _find_combat_context_display() -> Node:
	"""Finds CombatContextDisplay in scene tree"""
	# Try to find in Game scene
	var game = get_tree().current_scene
	if game:
		# Check direct children first
		for child in game.get_children():
			if child is CombatContextDisplay:
				return child
			# Check CanvasLayer children (UI layer)
			if child is CanvasLayer:
				for ui_child in child.get_children():
					if ui_child is CombatContextDisplay:
						return ui_child

	# Fallback: search entire tree
	return get_tree().get_first_node_in_group("combat_context_display")

func reset() -> void:
	"""Resets the trigger (for testing/debugging)"""
	has_triggered = false
