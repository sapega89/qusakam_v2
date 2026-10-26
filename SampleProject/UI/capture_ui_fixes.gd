extends SceneTree

## Знімки гілки cloud/ui-fixes: вікно діалогу (B112 — ім'я над текстом, не поверх нього) і вкладки Game Menu,
## переведені на шаблони рядків (D117: Status, Equipment).
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 \
##       --script res://SampleProject/UI/capture_ui_fixes.gd -- <tag> [dialogue|menu]
## Пише design/shots/ui_fixes_<кадр>_<tag>.png. Вікно обов'язкове (--headless дає чорні кадри).

const Kit = preload("res://SampleProject/UI/input_kit.gd")

var _tag := "now"
## Другий аргумент — лише ця група кадрів: "dialogue" або "menu".
var _only := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_tag = args[0]
	if args.size() > 1:
		_only = args[1]
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: no «?» tips in this run
	root.size = Vector2i(1920, 1080)
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await Kit.drain(self)
	if _only != "menu":
		await _dialogue(sl.get_dialogue_manager())
	if _only != "dialogue":
		await _menu(sl)
	quit(0)


## B112: репліка з мовцем (ім'я над текстом) і репліка оповідача (без порожнього рядка).
func _dialogue(dm: Node) -> void:
	dm.start_dialogue("res://dialogue_quest/OldMan_Decision.dqd")
	await Kit.frames(self, 5)
	dm.current_dialogue_box.finish()
	await Kit.frames(self, 30)
	await _save("dialogue")
	await Kit.drain(self)
	dm.start_dialogue("res://dialogue_quest/OldMan_Outside.dqd")
	await Kit.frames(self, 5)
	dm.current_dialogue_box.finish()
	await Kit.frames(self, 30)
	await _save("dialogue_narration")
	await Kit.drain(self)


func _menu(sl: Node) -> void:
	var ui: Node = sl.get_ui_manager()
	ui.open_game_menu()
	await Kit.frames(self, 20)
	var menu: Node = get_first_node_in_group("game_menu")
	for tab: String in ["Status", "Equipment"]:
		menu.switch_to_tab(tab)
		await Kit.frames(self, 20)
		await _save("menu_" + tab.to_lower())


func _save(name: String) -> void:
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://design/shots/ui_fixes_%s_%s.png" % [name, _tag]
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("capture saved: %s (%dx%d)" % [path, img.get_width(), img.get_height()])
