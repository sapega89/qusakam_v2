extends Node2D

## Темрява згори екрана в печерах і підвалах (room_art_audit, Tails of Iron: «там темніше зверху»): смуга
## top_shade.tres завжди біля верхнього краю того, що бачить камера, на всю ширину. Розмітка — top_shade.tscn.

@onready var sprite: Sprite2D = $Sprite


func _process(_delta: float) -> void:
	var view := get_viewport().get_canvas_transform().affine_inverse()
	global_position = view.origin
	sprite.scale.x = get_viewport_rect().size.x * view.get_scale().x / sprite.texture.get_width()
