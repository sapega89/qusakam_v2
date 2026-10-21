extends SceneTree

## Скріншоти з гри для тем туторіалу (D126) → SampleProject/Assets/UI/Tutorial/.
## Потрібне ВІКНО — під --headless кадри чорні. Після запуску: godot --headless --import.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_tutorial_shots.gd

const OUT := "res://SampleProject/Assets/UI/Tutorial/"


func _shot(name: String) -> void:
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(OUT + name + ".png")
	root.get_texture().get_image().save_png(path)
	print("shot %s" % path)


func _key(code: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		root.push_input(ev)
		await process_frame


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1920, 1080)
	await process_frame
	set_meta("start_new_game", true)  # нова гра, а не slot_01 з user://
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 90: await process_frame

	# Для «Basic Controls» — гравець посеред кімнати, без підказки збереження.
	var hero: Node2D = get_first_node_in_group(&"player")
	var spawn: Vector2 = hero.global_position if hero else Vector2.ZERO
	if hero:
		hero.global_position = spawn + Vector2(-900, 0)
		for i in 30: await process_frame
	await _shot("basic_controls")
	if hero:
		hero.global_position = spawn

	await _key(KEY_M)
	await _shot("the_map")
	await _key(KEY_M)

	# Гравця — до першої точки збереження поточної кімнати, щоб з'явилась підказка Save.
	var player: Node2D = get_first_node_in_group(&"player")
	var save_point: Node2D = null
	for node in root.find_children("*", "Area2D", true, false):
		if node.get_script() and String(node.get_script().resource_path).ends_with("SavePoint.gd"):
			save_point = node
			break
	print("player=%s save_point=%s" % [player, save_point])
	if player and save_point:
		player.global_position = save_point.global_position
		for i in 30: await process_frame
	await _shot("saving")

	var flags := {}
	for flag in ["canyon_intro_complete", "canyon_exploration_complete", "canyon_abduction_complete",
			"village_abduction_complete", "village_arrival_complete"]:
		flags[flag] = true
	game.set_quest_flags(flags)
	game.set_objective("Defeat the bandit in the street")
	var ui: Node = root.get_node("ServiceLocator").get_ui_manager()
	ui.open_game_menu()
	for i in 20: await process_frame
	get_first_node_in_group("game_menu").switch_to_tab("Journal")
	await _shot("journal")
	quit()
