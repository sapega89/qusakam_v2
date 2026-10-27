extends Control

## Лінії дерева навичок (D333, D674): з-під підпису рангу передумови — вниз, уздовж проміжку між рядами, вниз у навичку.
## Лежить під клітинками (раніше в дереві), мишу не ловить. Що з'єднувати, каже skills_component.

## [[Control від, Control до, bool світиться]] — золота, коли передумову вивчено або позначено.
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
		# Горизонталь — посередині проміжку над рядом навички, щоб не перетинати клітинки того ж ряду.
		var bend_y := end.y - UITokens.SKILL_GRID_GAP_V / 2.0
		var color: Color = UITokens.SKILL_LINK_LEARNED if bool(link[2]) else UITokens.SKILL_LINK_IDLE
		draw_polyline(PackedVector2Array([start, Vector2(start.x, bend_y), Vector2(end.x, bend_y), end]), color,
				UITokens.SKILL_LINK_WIDTH)


func _local_rect(node: Control) -> Rect2:
	return Rect2(node.global_position - global_position, node.size)
