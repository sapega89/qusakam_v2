extends Area2D
class_name EnemyTrigger

signal player_entered

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group(GameGroups.PLAYER):
		player_entered.emit()

func _exit_tree() -> void:
	"""Відключаємося від сигналів при видаленні"""
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)

