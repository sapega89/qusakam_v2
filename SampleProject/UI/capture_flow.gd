extends SceneTree

## Візуальний обхід флоу: справжні кліки мишею + скриншот на кожному кроці.
## Потрібне ВІКНО — під --headless кадри чорні.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_flow.gd
##
## Кадри йдуть у design/shots/flow/. Далі їх читає людина або агент — саме так
## ловиться клас багів «виглядає не так», який жоден ck() не побачить.
## Клікає push_input(), а не pressed.emit(): це єдиний шлях, що проходить
## mouse_filter, порядок дерева, паузу й перекриття (див. B4/B6 у BUGS.md).

const OUT := "res://design/shots/flow/"

var step := 0
var notes: Array[String] = []


func _click(node: Control) -> void:
	if node == null or not node.is_visible_in_tree():
		notes.append("SKIP click: node missing or hidden")
		return
	var vp: Viewport = node.get_viewport()
	var pos: Vector2 = node.get_global_rect().get_center()
	var hovered_before: Control = null
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	hovered_before = vp.gui_get_hovered_control()
	if hovered_before != node:
		notes.append("BLOCKED: %s is covered by %s" % [node.name,
				hovered_before.get_path() if hovered_before else "<nothing>"])
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)
		await process_frame
	for i in 10: await process_frame


func _shot(label: String) -> void:
	step += 1
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s%02d_%s.png" % [OUT, step, label]
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("shot %s" % path)


## Скільки нод зараз мають «увімкнений» вигляд курсора/виділення.
## Інваріант: не більше одного. Ловить B3 без ока.
func _active_count(node: Node) -> int:
	var n := 0
	if node is Control:
		var v := String(node.theme_type_variation)
		if v.ends_with("On") or v.ends_with("Selected"):
			n += 1
	for c in node.get_children():
		n += _active_count(c)
	return n


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame

	var sl: Node = root.get_node_or_null("ServiceLocator")
	var ui: Node = sl.get_ui_manager()
	var layer: Node = ui.get_modal_layer()

	ui.open_game_menu()
	for i in 20: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	await _shot("game_menu_open")

	print("--- tabs ---")
	## Рахуємо ТІЛЬКИ в сайдбарі: підсвічена вкладка + вибраний рядок списку —
	## це два різні контейнери й цілком нормально. Баг — коли світиться
	## більше однієї вкладки.
	var sidebar: Node = menu.find_child("Sidebar", true, false)
	if sidebar == null:
		sidebar = menu
	for tab in ["Inventory", "Equipment", "Status", "Skills", "World Map", "Journal", "Misc"]:
		menu.switch_to_tab(tab)
		for i in 12: await process_frame
		var lit: Array[String] = []
		for n in sidebar.find_children("*", "Button", true, false):
			var v := String(n.theme_type_variation)
			if v.ends_with("On") or v.ends_with("Selected"):
				lit.append(n.name)
		print("tab %-10s lit sidebar items: %s" % [tab, lit])
		if lit.size() > 1:
			notes.append("tab %s: %d sidebar items lit at once %s"
					% [tab, lit.size(), lit])
		var vis: Array[String] = []
		for p in menu.find_children("*Panel*", "Control", true, false):
			if p.is_visible_in_tree():
				vis.append(p.name)
		print("            visible panels: %s" % [vis])
		await _shot("tab_" + tab.to_lower())

	print("--- misc modal, opened and closed 3x (B3 repro) ---")
	for pass_i in 3:
		await _click(menu.misc_button)
		var modal: Node = layer.active_modal
		if modal == null:
			notes.append("pass %d: Misc click did not open the modal" % (pass_i + 1))
			break
		var active := _active_count(modal)
		print("open %d: active-looking rows in modal: %d" % [pass_i + 1, active])
		if active > 1:
			notes.append("misc modal open %d: %d rows look active (expected 1)"
					% [pass_i + 1, active])
		await _shot("misc_open_%d" % (pass_i + 1))
		if modal.has_signal("chosen"):
			modal.chosen.emit("cancel")
		for i in 12: await process_frame
		var stray := _active_count(menu)
		print("after close %d: active-looking nodes in menu: %d" % [pass_i + 1, stray])
		await _shot("misc_closed_%d" % (pass_i + 1))

	print("")
	print("=== NOTES ===")
	if notes.is_empty():
		print("(none)")
	for n in notes:
		print("! " + n)
	print("RESULT: %d observation(s)" % notes.size())
	quit(0)
