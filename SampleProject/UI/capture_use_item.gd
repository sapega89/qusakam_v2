extends SceneTree

## Випити зілля (D127): вибір персонажа і підтвердження → design/shots/.
## Потрібне ВІКНО. godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_use_item.gd

func _shot(name: String) -> void:
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://design/shots/%s_1920.png" % name)
	root.get_texture().get_image().save_png(path)
	print("shot %s" % path)


func _accept() -> void:
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = &"ui_accept"
		ev.pressed = down
		root.push_input(ev)
		await process_frame


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_inventory_manager().add_item("potion", 3)
	sl.get_game_manager().get_current_player().current_health = 40
	sl.get_ui_manager().open_game_menu()
	for i in 20: await process_frame
	var inv: Node = get_first_node_in_group("game_menu").find_child("InventoryComponent", true, false)
	(inv._item_list.get_child(0) as Control).grab_focus()
	await process_frame
	await _accept()
	await _shot("use_item_choose")
	await _accept()
	await _shot("use_item_confirm")
	quit()
