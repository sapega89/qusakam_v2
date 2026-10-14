extends SceneTree

## Візуальні знімки slice 1c для порівняння з Figma 258:5140 / 9:26 (вікно обов'язкове):
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_main_menu.gd


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	set_meta("show_title_screen", true)
	var menu: Control = load("res://SampleProject/MainMenu.tscn").instantiate()
	root.add_child(menu)
	await _save("res://design/shots/splash_1920.png")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	ev.pressed = true
	menu._input(ev)
	for i in 90:
		await process_frame
	await _save("res://design/shots/main_menu_1920.png")
	quit(0)


func _save(path: String) -> void:
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("capture saved: %s" % path)
