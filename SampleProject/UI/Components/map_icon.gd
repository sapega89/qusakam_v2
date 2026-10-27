extends Control

## Значок карти локації (World Map, рівень 2; design/world_map_spec.md, Figma 539:6615): коло з чорнильною рамкою
## і білим знаком — герой, медитація, скриня, замкнено, завдання, вихід, знайдений секрет; або зразок кімнати в легенді.
## Знаки намальовано лініями, не шрифтом: у Cormorant Garamond немає ☗ ✦ ⚿. Розмір — менша сторона вузла.

const FILL := {
	&"hero": UITokens.MAP_ICON_HERO,
	&"save": UITokens.MAP_ICON_SAVE,
	&"chest": UITokens.MAP_ICON_CHEST,
	&"locked": UITokens.MAP_ICON_LOCKED,
	&"quest": UITokens.MAP_ICON_QUEST,
	&"exit": UITokens.MAP_ICON_EXIT,
	&"secret": UITokens.MAP_ICON_SECRET,
}
## Знак намальовано в клітинці 26×26 (Figma); [member size] його масштабує.
const GRID := 26.0

## hero / save / chest / locked / quest / exit / secret — значок; room / room_seen — зразок кімнати в легенді.
@export var kind: StringName = &"hero":
	set(value):
		kind = value
		queue_redraw()
## Відкрита скриня приглушена.
@export var dimmed: bool = false:
	set(value):
		dimmed = value
		modulate.a = UITokens.MAP_ICON_OPENED_ALPHA if value else 1.0


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	var c: Vector2 = size / 2.0
	if kind == &"room":
		var swatch := Rect2(c - Vector2.ONE * side / 2.0, Vector2.ONE * side)
		draw_rect(swatch, UITokens.MAP_ROOM_FILL)
		draw_rect(swatch, UITokens.MAP_INK, false, UITokens.MAP_ICON_BORDER)
		return
	if kind == &"room_seen":
		dashed_rect(self, Rect2(c - Vector2.ONE * side / 2.0, Vector2.ONE * side),
				Color(UITokens.MAP_INK, UITokens.MAP_SEEN_ALPHA), UITokens.MAP_SEEN_BORDER, side / 4.0, side / 5.0)
		return
	var u: float = side / GRID
	var radius: float = side / 2.0 - UITokens.MAP_ICON_BORDER / 2.0
	draw_circle(c, radius, FILL[kind])
	draw_arc(c, radius, 0.0, TAU, 32, UITokens.MAP_INK, UITokens.MAP_ICON_BORDER, true)
	var g := UITokens.MAP_ICON_GLYPH
	match kind:
		&"hero":
			draw_circle(c + Vector2(0, -4) * u, 3.5 * u, g)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 7) * u, c + Vector2(6, 7) * u,
					c + Vector2(0, -2) * u]), g)
		&"save":
			var star := PackedVector2Array()
			for i in 8:
				var r: float = (7.5 if i % 2 == 0 else 2.5) * u
				star.append(c + Vector2.UP.rotated(i * TAU / 8.0) * r)
			draw_colored_polygon(star, g)
		&"chest":
			draw_rect(Rect2(c - Vector2(5, 5) * u, Vector2(10, 10) * u), g, false, 1.5 * u)
			draw_rect(Rect2(c - Vector2(1.5, 1.5) * u, Vector2(3, 3) * u), g)
		&"locked":
			draw_arc(c + Vector2(0, -1) * u, 3.5 * u, PI, TAU, 12, g, 1.5 * u)
			draw_rect(Rect2(c + Vector2(-5, -1) * u, Vector2(10, 8) * u), g)
		&"quest":
			draw_line(c + Vector2(0, -7) * u, c + Vector2(0, 2) * u, g, 2.5 * u)
			draw_circle(c + Vector2(0, 6) * u, 1.5 * u, g)
		&"exit":
			draw_line(c + Vector2(-6, 0) * u, c + Vector2(6, 0) * u, g, 2.0 * u)
			draw_polyline(PackedVector2Array([c + Vector2(1, -5) * u, c + Vector2(6, 0) * u, c + Vector2(1, 5) * u]),
					g, 2.0 * u)
		&"secret":
			# Замкова шпарина: не зірка (✦ — медитація) і не дужка замка (⚿ — замкнено).
			draw_circle(c + Vector2(0, -3) * u, 3.5 * u, g)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-1.5, -1) * u, c + Vector2(1.5, -1) * u,
					c + Vector2(3, 7) * u, c + Vector2(-3, 7) * u]), g)


## Пунктирна рамка: штрих [param dash], проміжок [param gap] (Figma 10/8; draw_dashed_line дає лише рівні).
static func dashed_rect(item: CanvasItem, r: Rect2, color: Color, width: float, dash: float, gap: float) -> void:
	var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in corners.size():
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % corners.size()]
		var length: float = a.distance_to(b)
		var dir: Vector2 = (b - a) / length
		var t := 0.0
		while t < length:
			item.draw_line(a + dir * t, a + dir * minf(t + dash, length), color, width)
			t += dash + gap
