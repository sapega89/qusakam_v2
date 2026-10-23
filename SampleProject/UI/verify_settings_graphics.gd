extends SceneTree

## BACKLOG 41: Resolution і Frame Rate Limit у Settings → Display.
##   godot --headless --path . --script res://SampleProject/UI/verify_settings_graphics.gd
## Кожне значення застосовується (DisplayManager / Engine.max_fps) і переживає перезапуск
## SettingsModule (новий модуль читає слот із диска). Елементи керування — шеврони рядка,
## натиск ті самі, що дають миша, Enter і кнопка A геймпада (BaseButton.pressed).

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

const TEST_DIR := "user://verify_settings_graphics/"


func _row(opts: Node, title: String) -> Node:
	for margin in opts._list.get_children():
		if margin.get_child_count() > 0 and margin.get_child(0).name == title:
			return margin.get_child(0)
	return null


func _stepper(opts: Node, title: String, part: String) -> Node:
	var row: Node = _row(opts, title)
	return row.get_node_or_null(NodePath("Stepper/" + part)) if row else null


func _initialize() -> void:
	await process_frame
	var save_system: Node = root.get_node("SaveSystem")
	var display: Node = root.get_node("DisplayManager")
	# Тест не чіпає справжні налаштування гравця (B118: один файл на інсталяцію, у теці сейвів).
	save_system.set_save_dir(TEST_DIR)
	var settings_path: String = save_system.get_settings_path()
	var module: Node = save_system.settings_module
	module.settings = module.default_settings.duplicate()
	module.apply_settings()

	print("[1] defaults match project.godot")
	ck(module.settings["resolution"] == "1920x1080", "default resolution 1920x1080")
	ck(module.settings["fps_limit"] == 60, "default FPS limit 60")
	ck(display.resolution == Vector2i(1920, 1080), "DisplayManager applied 1920x1080")
	ck(Engine.max_fps == 60, "Engine.max_fps 60")

	var opts: Node = load("res://SampleProject/Scenes/Menus/Game/options_component.tscn").instantiate()
	opts.mode = "main_menu"
	root.add_child(opts)
	for i in 4: await process_frame
	opts.switch_to_tab("display")
	for i in 3: await process_frame

	print("[2] Display tab rows in Figma order")
	var order: Array = []
	for margin in opts._list.get_children():
		if margin is MarginContainer:
			order.append(String(margin.get_child(0).name))
	ck(order == ["Display Mode", "Resolution", "VSync", "Frame Rate Limit", "Quality", "Screen Brightness"], "rows: %s" % str(order))  # Quality — D554
	var res_value: Label = _stepper(opts, "Resolution", "Value")
	var fps_value: Label = _stepper(opts, "Frame Rate Limit", "Value")
	ck(res_value != null and res_value.text == "1920 × 1080", "Resolution shows 1920 × 1080")
	ck(fps_value != null and fps_value.text == "60 FPS", "Frame Rate Limit shows 60 FPS")
	if res_value == null or fps_value == null:
		_done()
		return
	var res_next: Button = _stepper(opts, "Resolution", "Next")
	var res_prev: Button = _stepper(opts, "Resolution", "Prev")
	var fps_next: Button = _stepper(opts, "Frame Rate Limit", "Next")
	for b in [res_next, res_prev, fps_next]:
		ck(b.focus_mode == Control.FOCUS_ALL, "%s reachable by keyboard / gamepad focus" % b.get_path())

	print("[3] every resolution applies")
	# Next від 1920x1080: 2560x1440, по колу 1280x720, 1600x900, 1920x1080.
	for expected in ["2560x1440", "1280x720", "1600x900", "1920x1080"]:
		res_next.grab_focus()
		res_next.pressed.emit()
		await process_frame
		ck(module.settings["resolution"] == expected, "stored %s" % expected)
		ck(display.resolution == display.parse_resolution(expected), "applied %s" % expected)
		ck(res_value.text == expected.replace("x", " × "), "label %s" % res_value.text)
		if DisplayServer.get_name() != "headless":
			ck(DisplayServer.window_get_size() == display.resolution, "window is %s" % expected)
	ck(res_next.has_focus(), "focus stays on the chevron (row not rebuilt)")
	res_prev.pressed.emit()
	await process_frame
	ck(module.settings["resolution"] == "1600x900", "Prev steps back to 1600x900")

	print("[4] every FPS limit applies")
	for expected in [120, 144, 0, 30, 60]:
		fps_next.pressed.emit()
		await process_frame
		ck(module.settings["fps_limit"] == expected, "stored %d" % expected)
		ck(Engine.max_fps == expected, "Engine.max_fps %d" % Engine.max_fps)
	fps_next.pressed.emit()
	fps_next.pressed.emit()
	await process_frame
	ck(fps_value.text == "144 FPS", "label 144 FPS")
	var labels: Array[String] = opts._fps_limit_names()
	ck(labels.has("Unlimited"), "0 is shown as Unlimited")

	print("[5] Fullscreen locks the resolution row")
	for cell in _row(opts, "Display Mode").get_node(^"Segments").get_child(0).get_children():
		if String(cell.text).ends_with("Fullscreen"):
			cell.pressed.emit()
	for i in 3: await process_frame
	ck((_stepper(opts, "Resolution", "Next") as Button).disabled, "chevrons disabled in Fullscreen")
	ck(module.settings["resolution"] == "1600x900", "resolution kept while fullscreen")
	for cell in _row(opts, "Display Mode").get_node(^"Segments").get_child(0).get_children():
		if String(cell.text).ends_with("Windowed"):
			cell.pressed.emit()
	for i in 3: await process_frame
	ck(not (_stepper(opts, "Resolution", "Next") as Button).disabled, "chevrons back in Windowed")
	ck(display.resolution == Vector2i(1600, 900), "Windowed reapplies 1600x900")

	print("[6] both survive a restart of the settings module")
	var on_disk: Dictionary = str_to_var(FileAccess.get_file_as_string(settings_path))
	ck(on_disk["resolution"] == "1600x900", "settings file holds 1600x900")
	ck(on_disk["fps_limit"] == 144, "settings file holds 144")
	opts.queue_free()
	await process_frame
	# Скидаємо живий стан, щоб відновлення було видно саме з файла.
	display.set_resolution("1920x1080")
	display.set_fps_limit(60)
	var old_module: Node = save_system.settings_module
	var module_script: Script = old_module.get_script()
	save_system.remove_child(old_module)
	old_module.free()
	var fresh: Node = module_script.new()
	save_system.settings_module = fresh
	save_system.add_child(fresh)
	await process_frame
	ck(fresh.settings["resolution"] == "1920x1080", "fresh module starts at defaults")
	save_system.load_game_settings()
	ck(fresh.settings["resolution"] == "1600x900", "reloaded resolution 1600x900")
	ck(fresh.settings["fps_limit"] == 144, "reloaded FPS limit 144")
	ck(display.resolution == Vector2i(1600, 900), "applied on load: 1600x900")
	ck(Engine.max_fps == 144, "applied on load: Engine.max_fps 144")

	print("[7] option lists are the BACKLOG 41 values")
	ck(display.RESOLUTIONS == ["1280x720", "1600x900", "1920x1080", "2560x1440"], "resolution list")
	ck(display.FPS_LIMITS == [30, 60, 120, 144, 0], "FPS list")

	print("[8] D418 / D429: the list is cut to what the monitor fits")
	ck(display.resolutions_for_screen(Vector2i(2560, 1440)) == display.RESOLUTIONS, "2560×1440 monitor: all four")
	ck(display.resolutions_for_screen(Vector2i(1920, 1080)) == ["1280x720", "1600x900", "1920x1080"],
			"1920×1080 monitor: no 2560×1440")
	ck(display.resolutions_for_screen(Vector2i(1366, 768)) == ["1280x720"], "1366×768 monitor: 1280×720 only")
	ck(display.resolutions_for_screen(Vector2i(1024, 768)) == ["1280x720"], "a monitor under 720p still gets the smallest")
	ck(display.available_resolutions() == (display.RESOLUTIONS if DisplayServer.get_name() == "headless"
			else display.resolutions_for_screen(DisplayServer.screen_get_size())), "the row lists this screen's sizes")

	DirAccess.remove_absolute(settings_path)
	_done()


func _done() -> void:
	print("RESULT: %s" % ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit(0 if fails.is_empty() else 1)
