extends RefCounted

## Вертикальний список кнопок з клавіатури й геймпада (D721, критик раунду 13: «Меню NPC — треба дати можливість з
## клавіатури перемикатись по ньому (W/S або вгору/вниз)»): W/S (move_up / move_down), стрілки й хрестовина
## (ui_up / ui_down) ведуть фокус на сусідню кнопку. Стік — ні: він лишається героєві. Тримання повторює крок.
##   const MenuNavKeys = preload("res://SampleProject/UI/Components/menu_nav_keys.gd")
##   var by := MenuNavKeys.step(event)
##   if by != 0: get_viewport().set_input_as_handled(); MenuNavKeys.move_focus(list, by)


## -1 — угору, 1 — униз, 0 — подія не навігація списку.
static func step(event: InputEvent) -> int:
	if event is InputEventJoypadMotion or event is InputEventMouse or not event.is_pressed():
		return 0
	if event.is_action_pressed(&"ui_up", true) or event.is_action_pressed(&"move_up", true):
		return -1
	if event.is_action_pressed(&"ui_down", true) or event.is_action_pressed(&"move_down", true):
		return 1
	return 0


## Лише W/S: для екранів, де стрілки й хрестовину вже веде штатна навігація фокусу Godot (магазин, кузня, крафт).
static func letter_step(event: InputEvent) -> int:
	if event.is_action(&"ui_up") or event.is_action(&"ui_down"):
		return 0
	return step(event)


## [param list] містить кнопку у фокусі.
static func has_focus_in(list: Control) -> bool:
	var focused := list.get_viewport().gui_get_focus_owner()
	return focused != null and list.is_ancestor_of(focused)


## Видимі кнопки [param list] у порядку дітей.
static func buttons(list: Node) -> Array[Button]:
	var out: Array[Button] = []
	for child in list.get_children():
		if child is Button and (child as Button).visible:
			out.append(child)
	return out


## Фокус на сусідню кнопку на [param by] (без кола: на краю стоїть); нічого не у фокусі — перша кнопка.
static func move_focus(list: Node, by: int) -> void:
	var row := buttons(list)
	if row.is_empty():
		return
	var at := row.find(list.get_viewport().gui_get_focus_owner())
	row[clampi(at + by, 0, row.size() - 1) if at >= 0 else 0].grab_focus()
