extends SceneTree

## Знімки екрана Settings (усі 4 вкладки) у 1920×1080 і 1280×720 для порівняння з Figma
## settings-display 17:280, settings-audio 17:409, settings-gameplay 17:632, settings-controls 17:756.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_settings.gd
## Вікно обов'язкове (--headless дає чорні кадри). Розмір вікна наприкінці повертаємо попередній.

const TABS := ["display", "audio", "game", "controls"]


func _initialize() -> void:
	var previous_size := DisplayServer.window_get_size()
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	# Вступ Canyon — діалог; під час діалогу меню не відкривається (D136).
	var dm: Node = sl.get_dialogue_manager()
	for round_i in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
	sl.get_ui_manager().open_game_menu()
	for i in 14: await process_frame
	get_first_node_in_group("game_menu").switch_to_tab("Misc")
	for i in 10: await process_frame
	var opts: Node = get_first_node_in_group("settings_screen")
	for res in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(res)
		for i in 6: await process_frame
		for tab in TABS:
			opts.switch_to_tab(tab)
			await _save("res://design/shots/settings_%s_%d.png" % [tab, res.x])
	DisplayServer.window_set_size(previous_size)
	await process_frame
	quit(0)


func _save(path: String) -> void:
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("capture saved: %s (%dx%d)" % [path, img.get_width(), img.get_height()])
