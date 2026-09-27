@tool
extends Control
class_name GothicCorner

## Кутова прикраса рамки Game Over. Figma: gothic-corner 48×48 у game-over-screen 41:83:
## дві лінії 48×2, внутрішні 30×2 (50%) і коло Ø8. Інші кути — віддзеркалення через scale.


func _ready() -> void:
	custom_minimum_size = Vector2(UITokens.GAME_OVER_CORNER, UITokens.GAME_OVER_CORNER)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := UITokens.GAME_OVER_FRAME
	var half := Color(c, 0.5)
	var n := float(UITokens.GAME_OVER_CORNER)
	draw_rect(Rect2(0, 0, n, 2), c)
	draw_rect(Rect2(0, 0, 2, n), c)
	draw_rect(Rect2(6, 6, 30, 2), half)
	draw_rect(Rect2(6, 6, 2, 30), half)
	draw_circle(Vector2(16, 16), 4.0, c)
