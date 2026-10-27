extends SceneTree

## D815: вікно «Your Skills», що відкривається на першій медитації (вершина каньйону) → design/shots/starting_skills.png.
## Той самий шлях, що й verify_starting_skills [3]: нова гра, справжній MeditationTrigger.
## Потрібне ВІКНО. godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_starting_skills.gd

const TEST_DIR := "user://capture_starting_skills/"


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var save_system: Node = root.get_node("SaveSystem")
	save_system.set_save_dir(TEST_DIR)
	save_system.settings_module.settings.hints = true  # D744
	set_meta("start_new_game", true)
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	var flags: Dictionary = game.get_quest_flags().duplicate()
	flags["canyon_intro_complete"] = true
	game.set_quest_flags(flags)
	await game.teleport_to_room("res://SampleProject/Maps/Canyon.tscn", ^"Arrival")
	for i in 20: await process_frame
	var layer: Node = sl.get_ui_manager().get_modal_layer()
	game.map.get_node(^"MeditationTrigger")._on_body_entered(game.player)
	var start := Time.get_ticks_msec()
	while layer.active_modal == null and Time.get_ticks_msec() - start < 20000:
		if dm.is_dialogue_active():
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		await process_frame
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://design/shots/starting_skills.png")
	root.get_texture().get_image().save_png(path)
	print("shot %s (modal: %s)" % [path, layer.active_modal != null])
	quit()
