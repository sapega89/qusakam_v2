extends RefCounted

## D117: рядки списку з шаблону, що лежить у сцені. Перший рядок — сам шаблон,
## решта — його копії; зайві звільняються, при нулі шаблон ховається.
## Повертає рівно `count` видимих рядків. duplicate() копіює й meta шаблону —
## тож сигнали рядків під'єднуйте не за meta-прапорцем.
static func fill(container: Node, template: Control, count: int) -> Array:
	while container.get_child_count() > maxi(count, 1):
		var extra := container.get_child(container.get_child_count() - 1)
		container.remove_child(extra)
		extra.queue_free()
	while container.get_child_count() < count:
		container.add_child(template.duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS))
	template.visible = count > 0
	var rows: Array = container.get_children().slice(0, count)
	for row in rows:
		row.visible = true
	return rows
