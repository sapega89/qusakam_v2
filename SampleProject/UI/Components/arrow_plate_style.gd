@tool
extends StyleBox

## Табличка-стрілка бічної панелі Game Menu (Figma UI/Sidebar Tab 386:6642, D493): прямокутник,
## правий край якого сходиться в тупий кут. Кольори й розміри задає build_game_ui_theme.gd з UITokens.

@export var bg_color: Color = Color(0, 0, 0, 0)
@export var border_color: Color = Color(0, 0, 0, 0)
@export var border_width: int = 0
## Довжина носика стрілки, px.
@export var tip_width: int = 0


func _points(rect: Rect2) -> PackedVector2Array:
	var tip_x := rect.end.x - tip_width
	return PackedVector2Array([
		rect.position,
		Vector2(tip_x, rect.position.y),
		Vector2(rect.end.x, rect.get_center().y),
		Vector2(tip_x, rect.end.y),
		Vector2(rect.position.x, rect.end.y),
	])


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var points := _points(rect)
	if bg_color.a > 0.0:
		RenderingServer.canvas_item_add_polygon(to_canvas_item, points, PackedColorArray([bg_color]))
	if border_width > 0 and border_color.a > 0.0:
		# Рамка всередині прямокутника, як у StyleBoxFlat: контур зсунуто на півтовщини.
		var inner := _points(rect.grow(-border_width * 0.5))
		inner.append(inner[0])
		RenderingServer.canvas_item_add_polyline(to_canvas_item, inner, PackedColorArray([border_color]), border_width, true)
