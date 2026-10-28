extends SceneTree

## Кадри живого Міста (D740): жителі на вулиці, речі, які можна тикнути, черга біля брами. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_city_life.gd -- <out_dir>
## Файли: <out_dir>/city_life_<shot>.png

## [кімната, мітка входу, x героя, y героя, кадр].
const SHOTS := [
	["City", ^"SavePoint", 420.0, 380.0, "a"],
	["City", ^"SavePoint", 1100.0, 380.0, "b"],
	["City", ^"SavePoint", 1750.0, 380.0, "c"],
	["City", ^"SavePoint", 2250.0, 380.0, "d"],
	["CityGates", ^"Arrival", 1300.0, 340.0, "gates"],
]

var game: Node
var dm: Node
var out_dir := ""

func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false
	await process_frame
	set_meta("start_new_game", true)
	dm = root.get_node("ServiceLocator").get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain()
	# Брама вже пройдена (бій і перепис позаду): черга біля неї стоїть лише тоді.
	for flag: String in ["city_gates_intro_complete", "city_gates_fight_complete", "city_gates_after_fight_complete"]:
		game.set_quest_flag(flag, true)
	for shot: Array in SHOTS:
		if not game.map.scene_file_path.ends_with("/" + shot[0] + ".tscn"):
			await game.teleport_to_room("res://SampleProject/Maps/%s.tscn" % shot[0], shot[1])
			for i in 30: await physics_frame
		game.player.global_position = Vector2(shot[2], shot[3])
		for i in 60: await physics_frame
		await _drain()
		await create_timer(2.5).timeout
		root.get_texture().get_image().save_png("%s/city_life_%s.png" % [out_dir, shot[4]])
	quit()

func _drain() -> void:
	for i in 400:
		if not dm.is_dialogue_active():
			for f in 10: await process_frame
			if not dm.is_dialogue_active():
				return
		else:
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		await process_frame
