extends SceneTree

## Продовження capture_pause_input.gd: Esc при відкритій модалці + подвійне відкриття.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_pause_esc.gd

const OUT := "res://design/shots/verify_b6/"

var fails: Array[String] = []
var notes: Array[String] = []
var step := 10


func ck(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _shot(label: String) -> void:
	step += 1
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s%02d_%s.png" % [OUT, step, label]
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("    shot %s" % path)


func _click(node: Control) -> void:
	if node == null or not is_instance_valid(node):
		notes.append("SKIP click: node gone")
		return
	var vp: Viewport = node.get_viewport()
	var pos: Vector2 = node.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)
		await process_frame
	for i in 10: await process_frame


func _key(code: Key) -> void:
	var vp: Viewport = root
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		vp.push_input(ev)
		await process_frame
	for i in 8: await process_frame


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame

	var sl: Node = root.get_node_or_null("ServiceLocator")
	var ui: Node = sl.get_ui_manager()
	var layer: Node = ui.get_modal_layer()

	print("[A] Esc while the Misc modal is open — who wins, modal or menu?")
	ui.open_game_menu()
	for i in 20: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	await _click(menu.misc_button)
	print("    modal open = %s   menu alive = %s" % [layer.active_modal, is_instance_valid(menu)])
	ck(layer.active_modal != null, "Misc modal open before Esc")
	await _key(KEY_ESCAPE)
	var menu_alive: bool = is_instance_valid(menu) and menu.is_inside_tree()
	var modal_after: Node = layer.active_modal
	var modal_visible: bool = modal_after != null and is_instance_valid(modal_after) \
			and modal_after.is_inside_tree() and modal_after.is_visible_in_tree()
	print("    after Esc: menu_alive=%s  active_modal=%s  modal_visible_in_tree=%s"
			% [menu_alive, modal_after, modal_visible])
	ck(modal_after == null, "Esc closed the modal (not the whole menu)")
	if not menu_alive and modal_visible:
		notes.append("Esc closed the MENU and left the modal on screen (orphaned overlay)")
	await _shot("after_esc")

	print("[B] Re-open the menu — does the stale modal interfere?")
	ui.open_game_menu()
	for i in 20: await process_frame
	var menu2: Node = get_first_node_in_group("game_menu")
	print("    menu2=%s  active_modal=%s" % [menu2, layer.active_modal])
	ck(menu2 != null, "Game Menu reopens after the Esc orphan")
	await _shot("reopen_after_esc")

	print("[C] Click Misc twice in a row — double-open guard?")
	if menu2:
		await _click(menu2.misc_button)
		var first: Node = layer.active_modal
		print("    first  modal = %s" % first)
		await _click(menu2.misc_button)
		var second: Node = layer.active_modal
		print("    second modal = %s" % second)
		ck(second != null, "a modal is still registered after the second click")
		if second != first:
			notes.append("second Misc click REPLACED the modal (%s -> %s); no double-open guard"
					% [first, second])
		var stack := 0
		for c in layer.get_node("Container").get_children():
			if c is Control and c.is_visible_in_tree(): stack += 1
		print("    visible modals stacked in Container = %d" % stack)
		if stack > 1:
			notes.append("%d modals visible at once in ModalLayer/Container" % stack)
		await _shot("double_open")

	print("")
	print("=== NOTES ===")
	if notes.is_empty(): print("(none)")
	for n in notes: print("! " + n)
	print("RESULT: " + ("ALL PASS" if fails.is_empty()
			else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0)
