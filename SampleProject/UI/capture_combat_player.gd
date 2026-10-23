extends SceneTree

## Кадри D504 / D502 у справжньому вікні: панель героя з рядком ST під SP і швидким слотом зілля;
## герой п'є зілля поруч із бандитом, над яким немає смужки HP.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_combat_player.gd -- <тека>

var game: Node
var out_dir: String


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://design/shots")
	root.size = Vector2i(1920, 1080)
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await create_timer(2.5).timeout
	await _finish_dialogue(sl.get_dialogue_manager())
	var hero: Node = game.player
	var target: Node = null
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.set_physics_process(false)
			node.detection_area.monitoring = false
			if target == null:
				target = node
			else:
				node.global_position.x += 2000.0
	target.take_damage(20, hero)  # поранений — смужки все одно немає (D502)
	hero.global_position = Vector2(target.global_position.x - 120.0, target.global_position.y)
	sl.get_inventory_manager().add_item("potion", 3)
	await create_timer(0.8).timeout
	hero.current_health = hero.Max_Health - 40
	hero.drink_potion()
	await create_timer(0.3).timeout
	var img: Image = root.get_texture().get_image()
	img.save_png(out_dir.path_join("combat_player_full.png"))
	img.get_region(Rect2i(0, 0, 520, 300)).save_png(out_dir.path_join("combat_player_hud.png"))
	print("CAPTURED")
	quit()


func _finish_dialogue(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return
