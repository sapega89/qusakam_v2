extends Control

@onready var label = %Label
@onready var panel = %Panel

func _ready():
	visible = false
	# Wait for Game singleton to be ready/available logic
	# Using deferred or direct check.
	_connect_to_game.call_deferred()

func _connect_to_game():
	var game = Game.get_singleton()
	if game:
		game.objective_updated.connect(_on_objective_updated)
		# Update if already set
		if not game.current_objective.is_empty():
			_on_objective_updated(game.current_objective)
	else:
		push_warning("ObjectiveHUD: Game singleton not found")

func _on_objective_updated(text: String):
	if text.is_empty():
		visible = false
	else:
		label.text = text
		visible = true
		
		# Optional: Animation or Sound
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 1.0, 0.5).from(0.0)
