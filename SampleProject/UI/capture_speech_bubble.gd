extends SceneTree

## Облачко монологу над Кусакамом на старті гри (D178): Canyon_Intro — монолог, тож іде облачком.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_speech_bubble.gd

func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	set_meta("start_new_game", true)
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	for i in 600:
		if dm.is_bubble_playing(): break
		await process_frame
	print("bubble playing: %s, box visible: %s" % [dm.is_bubble_playing(), dm.current_dialogue_box != null and dm.current_dialogue_box.visible])
	for i in 30: await process_frame
	for b in game.player.get_children():
		if b.has_method(&"show_line"):
			var panel: Control = b.get_child(0)
			var label: Label = panel.get_child(0)
			print("bubble scale=%s gscale=%s panel=%s label=%s text='%s' canvas=%s" % [b.scale, b.global_scale, panel.size, label.size, label.text.left(40), b.get_viewport().get_canvas_transform().get_scale()])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://design/shots/speech_bubble_intro.png"))
	quit(0)
