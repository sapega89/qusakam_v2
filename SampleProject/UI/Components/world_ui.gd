extends RefCounted

## Інтерфейс, що живе у світі (підказка взаємодії, меню NPC), а не на CanvasLayer:
## камера збільшує світ (Game.tscn, zoom 2.25 — D170), тож такий вузол масштабується назад,
## щоб його розмір лишався екранним (токени, D166). Позиція лишається світовою — над спрайтом.

static func screen_scale(item: CanvasItem) -> Vector2:
	return Vector2.ONE / item.get_viewport().get_canvas_transform().get_scale()
