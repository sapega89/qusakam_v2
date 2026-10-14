extends SceneTree

## Знімок діалогового вікна (D134: вигляд із GameUITheme) — вступний монолог Canyon нової гри.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_dialogue_box.gd

func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	set_meta("start_new_game", true)
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	for i in 600:
		await process_frame
		if dm.is_dialogue_active() and i > 120:
			break
	for i in 60:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://design/shots/dialogue_box_1920.png")
	root.get_texture().get_image().save_png(path)
	print("capture saved: res://design/shots/dialogue_box_1920.png (dialogue active: %s)" % dm.is_dialogue_active())
	quit(0)
