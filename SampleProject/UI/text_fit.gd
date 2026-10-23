extends RefCounted

## Тестова перевірка D474 «коробки ростуть під текст»: жоден видимий текст у [param box] не стиснутий
## нижче свого мінімуму і не виходить за межі [param box]. Повертає шлях першого порушника або "".

static func clipped(box: Control) -> String:
	var bounds := box.get_global_rect().grow(1.0)
	for node in box.find_children("*", "Control", true, false):
		var c := node as Control
		if not c.is_visible_in_tree() or not (c is Label or c is RichTextLabel or c is Button):
			continue
		if (c is Label and (c as Label).text == "") or (c is Button and (c as Button).text == ""):
			continue
		var min_size := c.get_combined_minimum_size()
		if c.size.x + 0.5 < min_size.x or c.size.y + 0.5 < min_size.y:
			return "%s: %s < min %s" % [box.get_path_to(c), c.size, min_size]
		if not bounds.encloses(c.get_global_rect()):
			return "%s: %s outside %s" % [box.get_path_to(c), c.get_global_rect(), bounds]
	return ""
