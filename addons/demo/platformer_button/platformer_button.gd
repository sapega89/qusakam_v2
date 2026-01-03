extends Activator
class_name PlatformerButton

@onready var area_2d: Area2D = $Area2D

func _ready():
	area_2d.body_entered.connect(_on_body_entered)
	area_2d.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D):
	activate()

func _on_body_exited(body: Node2D):
	deactivate()
