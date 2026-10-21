extends Control

## Лінії дерева навичок (D333): від передумови до навички — вниз, уздовж ряду, вниз у навичку.
## Лежить під вузлами (раніше в дереві), мишу не ловить. Що з'єднувати, каже skills_component.

const WIDTH := 2.0

## [[Control від, Control до, bool світиться]] — світиться, коли передумову вивчено або позначено.
var links: Array = []


func set_links(new_links: Array) -> void:
	links = new_links
	queue_redraw()


func _draw() -> void:
	for link in links:
		var from: Rect2 = _local_rect(link[0])
		var to: Rect2 = _local_rect(link[1])
		var start := Vector2(from.get_center().x, from.end.y)
		var end := Vector2(to.get_center().x, to.position.y)
		# Горизонталь — у проміжку над рядком навички, щоб не перетинати вузли того ж ряду.
		var bend_y := end.y - UITokens.SPACE_XS
		var color: Color = UITokens.ACCENT if bool(link[2]) else UITokens.BORDER
		draw_polyline(PackedVector2Array([start, Vector2(start.x, bend_y), Vector2(end.x, bend_y), end]), color, WIDTH)


func _local_rect(node: Control) -> Rect2:
	return Rect2(node.global_position - global_position, node.size)
