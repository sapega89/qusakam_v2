extends SceneTree

## Бічні кімнати D643 під камерою гри, кадр — увесь екран, зменшений удвічі. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_rooms_batch1.gd -- <out_dir>
## Файли в <out_dir>: входи з головних кімнат (canyon_cave_mouth, canyon_mural_wall, canyon_mural_crack, road_camp_path,
## road_mesa_ladder, road_camp_shortcut, gates_cellar_door) і кожна кімната: lizard_cave (відкрита частина),
## lizard_shrine (за ґратами), bandit_camp, bandit_camp_stockade, mesa_climb_bottom, mesa_climb_top, dragon_mural,
## gatehouse_cellar, gatehouse_cellar_chest.

const MAPS := "res://SampleProject/Maps/%s.tscn"

var game: Node
var dm: Node
var out_dir := ""

func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1920, 1080)
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	await process_frame
	set_meta("start_new_game", true)
	dm = root.get_node("ServiceLocator").get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain()

	await _room("Canyon", ^"LizardCaveDoor")
	await _stand(Vector2(1010, 300))
	await _shot("canyon_cave_mouth")
	await _stand(Vector2(1380, 180))
	await _shot("canyon_mural_wall")
	game.map.get_node(^"Wall_Mural").smash()
	await create_timer(1.0).timeout
	await _stand(Vector2(1420, 180))
	await _shot("canyon_mural_crack")
	await _room("DesertRoad", ^"BanditCampDoor")
	await _stand(Vector2(1990, 200))
	await _shot("road_camp_path")
	await _stand(Vector2(2740, 280))
	await _shot("road_mesa_ladder")
	await _stand(Vector2(4700, 340))
	await _shot("road_camp_shortcut")
	await _room("CityGates", ^"CellarDoor")
	await _stand(Vector2(1000, 340))
	await _shot("gates_cellar_door")

	await _room("LizardCave", ^"ExitDoor")
	await _stand(Vector2(400, 360))
	await _shot("lizard_cave")
	await _stand(Vector2(1400, 360))
	await _shot("lizard_shrine")
	await _room("BanditCamp", ^"ExitDoor")
	await _stand(Vector2(300, 360))
	await _shot("bandit_camp")
	await _stand(Vector2(1500, 360))
	await _shot("bandit_camp_stockade")
	await _room("MesaClimb", ^"ExitDoor")
	await _stand(Vector2(200, 860))
	await _shot("mesa_climb_bottom")
	await _stand(Vector2(700, 140))
	await _shot("mesa_climb_top")
	await _room("DragonMural", ^"ExitDoor")
	await _stand(Vector2(300, 360))
	await _shot("dragon_mural")
	await _room("GatehouseCellar", ^"ExitDoor")
	await _stand(Vector2(500, 360))
	await _shot("gatehouse_cellar")
	await _stand(Vector2(1500, 360))
	await _shot("gatehouse_cellar_chest")
	quit()

func _room(room: String, at: NodePath) -> void:
	await game.teleport_to_room(MAPS % room, at)
	for i in 10: await physics_frame
	# Кадр — про кімнату, а не про бій: вороги кімнати не встають.
	for spawner in game.map.get_children().filter(func(n: Node) -> bool: return n.has_signal(&"all_enemies_defeated") and n.trigger_area != null):
		spawner.trigger_area.monitoring = false

func _stand(at: Vector2) -> void:
	game.place_player(at)
	game.player.velocity = Vector2.ZERO
	for i in 45: await physics_frame
	await _drain()

func _shot(name: String) -> void:
	var cam: Camera2D = game.player.get_node(^"Camera2D")
	cam.top_level = false  # пролог нової гри лишає камеру top_level
	cam.position = Vector2.ZERO
	cam.reset_smoothing()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(960, 540, Image.INTERPOLATE_BILINEAR)
	image.save_png("%s/%s.png" % [out_dir, name])
	print("shot %s hero %s" % [name, game.player.global_position])

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
