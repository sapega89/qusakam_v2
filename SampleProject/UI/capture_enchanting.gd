extends SceneTree

## Зачарування (design/enchanting_plan.md slice 2): список, підтвердження, помилка → design/shots/.
## Потрібне ВІКНО. godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_enchanting.gd

func _shot(name: String) -> void:
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://design/shots/%s_1920.png" % name)
	root.get_texture().get_image().save_png(path)
	print("shot %s" % path)

func _initialize() -> void:
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
	var inv: Node = sl.get_inventory_manager()
	inv.add_item("iron_dagger", 2)
	inv.add_item("iron_sword+2", 2)
	inv.add_item("iron_helmet", 1)
	inv.add_item("coin", 120)
	var ui: Node = sl.get_ui_manager()
	var layer := CanvasLayer.new()
	layer.layer = 13
	root.add_child(layer)
	var menu: Control = load("res://SampleProject/Scenes/Enchanting/enchanting_menu.tscn").instantiate()
	layer.add_child(menu)
	paused = true
	await _shot("enchanting_list")
	var row = menu.get_rows().filter(func(r): return r.data.id == "iron_dagger")[0]
	row.row_activated.emit(row.data)
	await _shot("enchanting_confirm")
	ui.get_modal_layer().active_modal.cancelled.emit()
	for i in 4: await process_frame
	inv.remove_item("coin", inv.get_item_count("coin"))
	row = menu.get_rows().filter(func(r): return r.data.id == "iron_sword+2")[0]
	row.row_activated.emit(row.data)
	await _shot("enchanting_error")
	quit()
