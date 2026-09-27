extends SceneTree

## Візуальні знімки slice 5: Game Over (Figma 41:83) та інвентар після FILTER (D9).
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_slice5.gd


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var dead := Node2D.new()
	world.add_child(dead)
	GameOverScreen.present(dead)
	await _save("res://design/shots/game_over_1920.png")
	(get_first_node_in_group(&"game_over_screen") as Node).get_parent().queue_free()
	paused = false

	var sl: Node = root.get_node("ServiceLocator")
	sl.get_inventory_manager().add_item("iron_ore", 3)
	sl.get_inventory_manager().add_item("potion", 2)
	sl.get_ui_manager().open_game_menu()
	for i in 12:
		await process_frame
	var inv: Node = get_first_node_in_group("game_menu").find_child("InventoryComponent", true, false)
	inv._select_category(&"equipment")
	inv.find_child("FilterButton", true, false).pressed.emit()
	await _save("res://design/shots/inventory_filter_key_items_1920.png")
	quit(0)


func _save(path: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("capture saved: %s" % path)
