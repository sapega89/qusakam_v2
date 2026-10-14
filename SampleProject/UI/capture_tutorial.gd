extends SceneTree

## Туторіал (D126): список тем у меню і тема на весь екран → design/shots/.
## Потрібне ВІКНО. godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_tutorial.gd

func _shot(name: String) -> void:
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://design/shots/%s_1920.png" % name)
	root.get_texture().get_image().save_png(path)
	print("shot %s" % path)


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var ui: Node = root.get_node("ServiceLocator").get_ui_manager()
	ui.open_game_menu()
	for i in 20: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu._on_misc_tutorial_selected()
	await _shot("tutorial_list")
	menu.get_node("%TutorialComponent").open_topic(1)
	await _shot("tutorial_topic")
	quit()
