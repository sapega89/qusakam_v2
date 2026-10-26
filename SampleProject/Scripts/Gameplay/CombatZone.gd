extends Area2D
class_name CombatZone

## Combat Zone Trigger
## Shows narrative context when player enters combat area

@export var context_key: String = "generic"
@export var one_shot: bool = true  # Only trigger once

var has_triggered: bool = false

func _ready() -> void:
	"""Setup collision detection"""
	# Проверяем, не подключен ли сигнал уже (чтобы избежать ошибки при повторном вызове _ready)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	"""Player entered combat zone"""
	if has_triggered and one_shot:
		return

	# Check if it's the player
	if not body.is_in_group(GameGroups.PLAYER):
		return

	has_triggered = true
	# D737: текст зони бою не лягає на розмову — після неї, якщо герой ще тут; вийшов — зона знову чекає входу.
	ServiceLocator.get_dialogue_manager().when_story_free_inside(self, _show_combat_context,
			func() -> void: has_triggered = false)

func _show_combat_context() -> void:
	"""Displays the combat context message"""
	# Find CombatContextDisplay in the scene tree
	# CombatContextDisplay — у Game.tscn (UICanvas), у групі combat_context_display.
	var context_display: CombatContextDisplay = get_tree().get_first_node_in_group(&"combat_context_display")
	context_display.show_context(context_key)
	DebugLogger.verbose("CombatZone: Showing context '%s'" % context_key, "CombatZone")

func reset() -> void:
	"""Resets the trigger (for testing/debugging)"""
	has_triggered = false
