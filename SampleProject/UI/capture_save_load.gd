extends SceneTree

## Візуальні знімки slice 1b для порівняння з Figma 150:1278 / 17:5 (вікно обов'язкове):
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_save_load.gd
## Слоти пишуться в окрему теку user://capture_saves — справжні сейви не чіпаються.

const MENU_SCENE := "res://SampleProject/Scenes/Menus/LoadGameMenu.tscn"
const DIR := "user://capture_saves/"

var ss: Node


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	var sl: Node = root.get_node("ServiceLocator")
	ss = sl.get_save_system()
	ss.set_save_dir(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	ss.set_save_dir(DIR)
	ss.set_current_slot(4)
	_slot(1, "Canyon", {"timestamp": "2026-09-23T00:05:12", "location": "Canyon",
			"level": 7, "character_name": "Kael", "playtime_sec": 39900.0})
	_slot(2, "Village", {"timestamp": "2026-09-22T17:27:00", "location": "Village",
			"level": 3, "character_name": "Kael", "playtime_sec": 14340.0})

	var menu: Node = load(MENU_SCENE).instantiate()
	menu.set_use_state_navigation(true)
	menu.load_target_scene = ""
	menu.set_mode("load")
	root.add_child(menu)
	await _save("res://design/shots/save_load_load_mode_1920.png")
	menu.queue_free()

	menu = load(MENU_SCENE).instantiate()
	menu.set_use_state_navigation(true)
	menu.save_handler = func() -> bool: return true
	menu.set_mode("save")
	root.add_child(menu)
	await _save("res://design/shots/save_load_save_mode_1920.png")
	menu._on_slot_activated(1)
	await _save("res://design/shots/save_load_overwrite_1920.png")

	ss.set_save_dir(ss.SAVE_DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	DirAccess.remove_absolute(DIR)
	quit(0)


func _slot(slot: int, room: String, meta: Dictionary) -> void:
	var f := FileAccess.open(ss.get_slot_path(slot), FileAccess.WRITE)
	f.store_string(var_to_str({"current_room": room}))
	f.close()
	ss.set_slot_metadata(slot, meta)


func _save(path: String) -> void:
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("capture saved: %s" % path)
