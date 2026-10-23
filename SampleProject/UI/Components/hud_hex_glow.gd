extends Control

## М'яке золоте світіння навколо шестикутника HUD v2: готовий слот хотбара і пульс асисту (D525).
## SVG-фільтр Figma рушій не читає, тож світіння малюємо самі (еталон — design/shots/figma_hotbar_slot_ready_2x.png):
## обвід контуру кількома шарами, від найширшого до найвужчого; прозорі шари складаються в спад до краю.
## Контур — у px цього вузла, з Figma-шляху ассета (slot.svg, chip.svg). Колір і ширина — UITokens.

@export var outline := PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if outline.size() < 3:
		return
	var closed := outline.duplicate()
	closed.append(outline[0])
	var color := UITokens.HUD_GLOW_COLOR
	for i in UITokens.HUD_GLOW_LAYERS:
		var width: float = UITokens.HUD_GLOW_WIDTH * float(UITokens.HUD_GLOW_LAYERS - i) / UITokens.HUD_GLOW_LAYERS
		draw_polyline(closed, Color(color, UITokens.HUD_GLOW_ALPHA), width, true)
