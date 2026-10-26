extends SceneTree

## Знімки гілки cloud/rows-2: вкладки Game Menu, переведені на шаблони рядків (D117: Skills, Inventory + нижня панель).
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 \
##       --script res://SampleProject/UI/capture_rows_2.gd -- <tag>
## Пише design/shots/rows_2_menu_<вкладка>_<tag>.png. Вікно обов'язкове (--headless дає чорні кадри).

const Kit = preload("res://SampleProject/UI/input_kit.gd")

var _tag := "now"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_tag = args[0]
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: no «?» tips in this run
	root.size = Vector2i(1920, 1080)
	set_meta("start_new_game", true)
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await Kit.drain(self)
	var ui: Node = root.get_node("ServiceLocator").get_ui_manager()
	ui.open_game_menu()
	await Kit.frames(self, 20)
	var menu: Node = get_first_node_in_group("game_menu")
	for tab: String in ["Skills", "Inventory"]:
		menu.switch_to_tab(tab)
		await Kit.frames(self, 20)
		await _save("menu_" + tab.to_lower())
	quit(0)


func _save(name: String) -> void:
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://design/shots/rows_2_%s_%s.png" % [name, _tag]
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("capture saved: %s (%dx%d)" % [path, img.get_width(), img.get_height()])
