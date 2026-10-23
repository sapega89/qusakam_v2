extends SceneTree

## Кадри будинків NPC (BACKLOG 29) і дому старости (BACKLOG 38): каплиця, хатина відьми, намет дервіша в City,
## хата діда і дім старости у Village, кімната ElderHouse зсередини. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_buildings.gd -- <out_dir>
## Файли: <out_dir>/buildings_<shot>.png

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const CITY := "res://SampleProject/Maps/City.tscn"
const VILLAGE := "res://SampleProject/Maps/Village.tscn"
const HOUSE := "res://SampleProject/Maps/ElderHouse.tscn"

var game: Node
var out_dir := ""

func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	game = await Kit.boot(self)
	for flag in ["village_abduction_complete", "village_arrival_complete", "village_fight_complete",
			"village_afterfight_complete", "village_oldman_met", "village_oldman_healed",
			"village_oldman_complete", "village_left_complete", "city_gates_fight_complete"]:
		game.set_quest_flag(flag, true)

	await _visit(CITY, ^"SavePoint")
	for shot: Array in [["forge_chapel", 1400.0], ["hut", 1900.0], ["tent", 2300.0]]:
		await _stand(shot[1])
		_shot(shot[0])
	await _visit(VILLAGE, ^"Arrival")
	await _stand(1500.0)
	_shot("grandpa_house")
	await _stand(2300.0)
	_shot("elder_house")
	await _visit(HOUSE, ^"Arrival")
	await _stand(300.0)
	_shot("elder_inside")
	quit()

func _visit(room: String, marker: NodePath) -> void:
	game.teleport_to_room(room, marker)
	for i in 30: await physics_frame
	await Kit.drain(self)

func _stand(x: float) -> void:
	game.player.global_position = Vector2(x, 340.0)
	for i in 60: await physics_frame
	await Kit.drain(self)
	await create_timer(0.3).timeout

func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s/buildings_%s.png" % [out_dir, name])
