extends SceneTree

## Камінь медитації на точках збереження (D447, D764): герой сидить на ньому. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_meditation_stones.gd -- <out_dir>
## Файли: <out_dir>/meditation_<кімната>_<точка>.png

const SHOTS := [
	["City", ^"SavePoint"],
	["DesertRoad", ^"SavePoint_BeforeCity"],
	["Laboratory", ^"SavePoint_Entrance"],
	["Laboratory", ^"SavePoint_PreBoss"],
]

var game: Node
var out_dir := ""

func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	for shot: Array in SHOTS:
		await game.teleport_to_room("res://SampleProject/Maps/%s.tscn" % shot[0], shot[1])
		for i in 60: await physics_frame
		game.player.set_movement_enabled(false)
		game.player.play_body(&"Meditate")
		await create_timer(1.5).timeout
		root.get_texture().get_image().save_png("%s/meditation_%s_%s.png" % [out_dir, shot[0], shot[1]])
		game.player.set_movement_enabled(true)
	quit()
