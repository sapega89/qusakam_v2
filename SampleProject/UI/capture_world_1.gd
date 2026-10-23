extends SceneTree

## Гілки з секретами (D583, D604–D621) під камерою гри, кадр — увесь екран, зменшений удвічі. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_world_1.gd -- <out_dir>
## Файли в <out_dir>: road_shop_roof (дах крамниці: трави й брила), road_shop_roof_broken (брилу розбито),
## road_tower (ґрати схованки на вежі), road_tower_open (ґрати відімкнено ключем), elder_house (драбина за килимом,
## ляда зачинена), elder_attic (горище після розмови з дідом).

const ROAD := "res://SampleProject/Maps/DesertRoad.tscn"
const ELDER := "res://SampleProject/Maps/ElderHouse.tscn"

var game: Node
var dm: Node
var out_dir := ""

func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1920, 1080)
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	await process_frame
	set_meta("start_new_game", true)
	dm = root.get_node("ServiceLocator").get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain()
	for hint in get_nodes_in_group(&"tutorial_hint_display"):
		hint.visible = false

	await game.teleport_to_room(ROAD, ^"Arrival_Start")
	await _stand(Vector2(1330, 129))
	await _shot("road_shop_roof")
	game.map.get_node(^"Rubble_ShopRoof").smash()
	await create_timer(1.0).timeout
	await _shot("road_shop_roof_broken")
	await _stand(Vector2(2316, 134))
	await _shot("road_tower")
	root.get_node("ServiceLocator").get_inventory_manager().add_item("bandit_key", 1)
	game.map.get_node(^"Cage_TowerStash/Area/Interactable").interacted.emit()
	await create_timer(1.0).timeout
	await _stand(Vector2(2380, 134))
	await _shot("road_tower_open")

	await game.teleport_to_room(ELDER, ^"Arrival")
	await _stand(Vector2(300, 840))
	await _shot("elder_house")
	game.set_quest_flag("village_oldman_complete", true)
	await create_timer(0.6).timeout
	await _stand(Vector2(460, 424))
	await _shot("elder_attic")
	quit()

func _stand(at: Vector2) -> void:
	game.place_player(at)
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
