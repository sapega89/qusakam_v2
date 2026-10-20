extends Area2D
class_name CanyonExitTrigger

## 🚪 Тригер спуску з каньйону — на краю плато біля містка в Canyon.tscn (D255).
## Гравець, що повернувся з села, заходить сюди → кат-сцена спуску (Canyon.gd) → дорога.

var has_triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if has_triggered or not body.is_in_group(GameGroups.PLAYER):
		return
	# owner — кімната Canyon, у сцені якої стоїть тригер. Раніше тут брали current_scene,
	# а це завжди Game, тож кат-сцена не запускалась ніколи. Canyon сам вирішує, чи вже час
	# (до повернення з села край — просто край, місток стоїть).
	has_triggered = owner.trigger_exit_cutscene()
