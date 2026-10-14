extends SceneTree

## Slice 8: екрани Runtime UI Completion у вікні 1280×720 (перевірка масштабування).
##   godot --path . --resolution 1280x720 --script res://SampleProject/UI/capture_small.gd
## Сейви для знімка — в окремій теці; справжні не чіпаються.
## Розмір вікна зберігається аддоном меню (player_config.cfg → ScreenResolution) і
## застосовується при наступних запусках, тому наприкінці повертаємо попередній.

const DIR := "user://capture_small_saves/"


func _initialize() -> void:
	var previous_size := DisplayServer.window_get_size()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	await process_frame
	var sl: Node = root.get_node("ServiceLocator")
	var ss: Node = sl.get_save_system()
	ss.set_save_dir(DIR)
	ss.set_current_slot(4)
	var f := FileAccess.open(ss.get_slot_path(1), FileAccess.WRITE)
	f.store_string(var_to_str({"current_room": "Canyon"}))
	f.close()
	ss.set_slot_metadata(1, {"timestamp": "2026-09-23T00:05:12", "location": "Canyon", "level": 7, "character_name": "Kael"})

	set_meta("show_title_screen", false)
	var mm: Node = load("res://SampleProject/MainMenu.tscn").instantiate()
	root.add_child(mm)
	await _save("main_menu")
	mm.queue_free()

	var load_menu: Node = load("res://SampleProject/Scenes/Menus/LoadGameMenu.tscn").instantiate()
	load_menu.set_use_state_navigation(true)
	load_menu.load_target_scene = ""
	root.add_child(load_menu)
	await _save("save_load")
	load_menu.queue_free()

	sl.get_inventory_manager().add_item("coin", 500)
	var j := JSON.new()
	j.parse(FileAccess.open("res://SampleProject/Resources/Data/merchants.json", FileAccess.READ).get_as_text())
	var shop: Control = load("res://SampleProject/Scenes/Shop/shop_menu.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	shop.setup_shop(j.data.merchants.default.items)
	await _save("shop")
	shop.queue_free()

	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var dead := Node2D.new()
	world.add_child(dead)
	GameOverScreen.present(dead)
	await _save("game_over")

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + file)
	DirAccess.remove_absolute(DIR)
	ss.set_save_dir(ss.SAVE_DIR)
	DisplayServer.window_set_size(previous_size)
	await process_frame
	quit(0)


func _save(name: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://design/shots/%s_1280.png" % name
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("capture saved: %s (%dx%d)" % [path, img.get_width(), img.get_height()])
