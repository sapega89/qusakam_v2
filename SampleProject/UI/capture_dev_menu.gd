extends SceneTree

## Знімок меню розробника (D943) на Пустельній дорозі: design/shots/dev_menu.png. Потрібне вікно, не --headless:
##   godot --path . --script res://SampleProject/UI/capture_dev_menu.gd

const OUT := "res://design/shots/dev_menu.png"

func _initialize() -> void:
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	for i in 400:
		if not dm.is_dialogue_active():
			break
		dm.current_dialogue_box.finish()
		dm.current_dialogue_player.accept()
		await process_frame
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"SavePoint_RoadStart")
	for i in 60: await process_frame
	game.get_node("UICanvas/DevMenu").toggle()
	for i in 10: await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT))
	print("saved ", OUT)
	quit()
