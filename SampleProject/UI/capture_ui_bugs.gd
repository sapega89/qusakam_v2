extends SceneTree

## Знімки для відкритих UI-багів (B8, B10, B14, B19, B22, B90, B96) — до й після виправлення.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 \
##       --script res://SampleProject/UI/capture_ui_bugs.gd -- <tag>
## Пише design/shots/ui_bugs_<кадр>_<tag>.png. Вікно обов'язкове (--headless дає чорні кадри).
## Слоти — в окремій теці user://capture_ui_bugs/, справжні сейви не чіпаються.

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const DIR := "user://capture_ui_bugs/"

var _tag := "now"
## Другий аргумент "dialogue" — лише кадр діалогового вікна.
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
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false
	root.size = Vector2i(1920, 1080)
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await Kit.drain(self)
	# B10: діалогове вікно з портретом, репліка набрана повністю (тоді аддон показує маркер «далі»).
	var dm: Node = sl.get_dialogue_manager()
	dm.start_dialogue("res://dialogue_quest/OldMan_Decision.dqd")
	await Kit.frames(self, 5)
	dm.current_dialogue_box.finish()
	await Kit.frames(self, 30)
	await _save("dialogue")
	await Kit.drain(self)
	if _only == "dialogue":
		quit(0)
		return

	var ss: Node = sl.get_save_system()
	ss.set_save_dir(DIR)
	var ui: Node = sl.get_ui_manager()
	ui.open_game_menu()
	await Kit.frames(self, 14)
	var menu: Node = get_first_node_in_group("game_menu")
	for tab in ["Inventory", "Skills"]:
		menu.switch_to_tab(tab)
		await _save("menu_%s" % tab.to_lower())
	# B90: вибраний рядок списку з фокусом на ньому (журнал: рядок під фокусом стає вибраним).
	menu.switch_to_tab("Journal")
	await Kit.frames(self, 6)
	menu.focus_router.focus_content()
	(menu.find_child("Entry_*", true, false) as Button).grab_focus()
	await _save("journal_focus")
	menu.switch_to_tab("Misc")
	await Kit.frames(self, 10)
	var opts: Node = get_first_node_in_group("settings_screen")
	for tab in ["audio", "controls"]:
		opts.switch_to_tab(tab)
		await _save("settings_%s" % tab)
	# B19 / D193: вкладка Gamepad.
	opts._input_menu.show_device(true)
	await _save("settings_controls_pad")
	opts._input_menu.show_device(false)
	ui.close_game_menu()
	await Kit.frames(self, 8)

	# B8: збереження з наявним слотом і підтвердження перезапису.
	ss.set_current_slot(1)
	ss.set_slot_metadata(1, {"timestamp": "2026-09-23T00:05:12", "location": "Canyon",
			"level": 7, "character_name": "Kael", "playtime_sec": 39900.0})
	var f := FileAccess.open(ss.get_slot_path(1), FileAccess.WRITE)
	f.store_string(var_to_str({"current_room": "Canyon"}))
	f.close()
	ui.open_save_game()
	await Kit.frames(self, 10)
	await _save("save")
	ui.current_state.menu_instance._on_slot_activated(1)
	await _save("save_overwrite")
	var modals: Node = ui.get_modal_layer()
	modals._on_cancelled(modals.active_modal)
	ui.close_state()
	await Kit.frames(self, 8)
	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + file)

	# B14: екран Game Over.
	GameOverScreen.present(get_first_node_in_group(&"player"))
	await Kit.frames(self, 30)
	get_first_node_in_group(&"game_over_screen").change_scenes = false
	await _save("game_over")
	quit(0)


func _save(name: String) -> void:
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://design/shots/ui_bugs_%s_%s.png" % [name, _tag]
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("capture saved: %s (%dx%d)" % [path, img.get_width(), img.get_height()])
