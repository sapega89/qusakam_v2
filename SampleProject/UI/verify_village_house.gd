extends SceneTree

## Дім старости в кінці села (BACKLOG 38): герой сам іде (справжнє «праворуч») до дверей, E відкриває їх — кімната
## ElderHouse, камера в її межах; усередині стоїть староста; стіни не випускають крізь край; ліворуч до виходу,
## pad Y — назад у Village біля дверей, камера знову в межах села. Будинки діда й старости стоять у селі за героєм.
##   godot --headless --path . --script res://SampleProject/UI/verify_village_house.gd

const Kit = preload("res://SampleProject/UI/input_kit.gd")
## Двері — Area2D, а не RoomDoor: class_name тягне Game.gd, а той звертається до автозавантаження-сцени MetSys,
## якої ще немає, коли компілюється --script: "Identifier not found: MetSys" (B93).
const VILLAGE := "res://SampleProject/Maps/Village.tscn"

var fails: Array[String] = []
var game: Node

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _until(cond: Callable, max_s: float) -> void:
	var deadline := Time.get_ticks_msec() + int(max_s * 1000)
	while not cond.call() and Time.get_ticks_msec() < deadline:
		await physics_frame

func _room() -> String:
	return game.map.scene_file_path.get_file().get_basename() if game.map else ""

## Межі камери збігаються з розміром кімнати, а центр кадру — в її межах.
func _check_camera(label: String) -> void:
	var cam: Camera2D = game.player.get_node(^"Camera2D")
	var size: Vector2 = game.map.get_node(^"RoomInstance").get_size()
	var origin: Vector2 = game.map.global_position
	ck(cam.limit_left == int(origin.x) and cam.limit_right == int(origin.x + size.x),
			"%s: camera limits x %d..%d = the room %.0f..%.0f" % [label, cam.limit_left, cam.limit_right, origin.x, origin.x + size.x])
	var centre := cam.get_screen_center_position()
	ck(centre.x >= origin.x and centre.x <= origin.x + size.x, "%s: the camera looks inside the room (x %.0f)" % [label, centre.x])

## Тримає [param action], доки герой не стане біля [param door] (підказка показана), тоді відпускає.
func _walk_to_door(action: StringName, door: Area2D) -> void:
	Input.action_press(action)
	await _until(func() -> bool: return door.get_node(^"Interactable").player_nearby, 10.0)
	Input.action_release(action)
	for i in 30: await physics_frame

func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	game = await Kit.boot(self)
	# Сюжет села пройдено: кімната не запускає своїх розмов, перевіряємо лише двері.
	for flag in ["village_abduction_complete", "village_arrival_complete", "village_fight_complete",
			"village_afterfight_complete", "village_oldman_met", "village_oldman_healed",
			"village_oldman_complete", "village_left_complete"]:
		game.set_quest_flag(flag, true)

	print("[1] The village: the grandfather's and the elder's houses stand behind the hero")
	await game.teleport_to_room(VILLAGE, ^"Arrival")
	for i in 30: await physics_frame
	await Kit.drain(self)
	ck(_room() == "Village", "in the Village (%s)" % _room())
	var hero_z: int = game.player.z_index
	for n in ["GrandpaHouse", "ElderHouse"]:
		var house: Sprite2D = game.map.get_node(n)
		ck(house.z_index < hero_z and house.get_index() < game.map.get_node(^"Terrain").get_index(),
				"%s is drawn behind the hero, before the terrain (z %d)" % [n, house.z_index])
	var grandfather: Node2D = game.map.get_node(^"OldManQuest")
	var gp: Sprite2D = game.map.get_node(^"GrandpaHouse")
	ck(gp.get_rect().has_point(gp.to_local(grandfather.global_position + Vector2(0, -40))),
			"the grandfather stands in front of his house (x %.0f)" % grandfather.global_position.x)
	var door: Area2D = game.map.get_node(^"ElderDoor")
	var house: Sprite2D = game.map.get_node(^"ElderHouse")
	ck(house.get_rect().has_point(house.to_local(door.global_position)), "the door is on the elder's house (x %.0f)" % door.global_position.x)
	_check_camera("Village")

	print("[2] Walk east to the door (real input), E opens it")
	game.player.global_position = Vector2(door.global_position.x - 300.0, 344.0)
	for i in 20: await physics_frame
	ck(not door.get_node(^"Interactable").get_prompt().visible, "no prompt away from the door")
	await _walk_to_door(&"move_right", door)
	ck(door.get_node(^"Interactable").get_prompt().visible, "the Enter prompt shows at the door")
	await Kit.key(self, KEY_E)
	await _until(func() -> bool: return _room() == "ElderHouse", 5.0)
	for i in 30: await physics_frame
	ck(_room() == "ElderHouse", "E at the door → ElderHouse (%s)" % _room())
	ck(game.player.is_on_floor(), "the hero stands on the floor inside (%s)" % game.player.global_position)
	var exit: Area2D = game.map.get_node(^"ExitDoor")
	ck(game.player.global_position.distance_to(exit.global_position) < 48.0, "the hero arrives at the exit door")
	_check_camera("ElderHouse")
	var elder: Node2D = game.map.get_node(^"VillageElder")
	var elder_sprite: Sprite2D = elder.get_node(^"Sprite2D")
	ck(elder.visible and elder.z_index + elder_sprite.z_index < hero_z + 1, "the village elder stands inside, behind the hero (D291)")

	print("[3] The house walls hold: walk to each end")
	Input.action_press(&"move_right")
	await create_timer(4.0).timeout
	Input.action_release(&"move_right")
	for i in 20: await physics_frame
	ck(_room() == "ElderHouse" and game.player.position.x < 864.0, "east wall holds (x %.0f)" % game.player.position.x)
	Input.action_press(&"move_left")
	await create_timer(4.0).timeout
	Input.action_release(&"move_left")
	for i in 20: await physics_frame
	ck(_room() == "ElderHouse" and game.player.position.x > 0.0, "west wall holds (x %.0f)" % game.player.position.x)

	print("[4] Back to the exit (real input), pad Y leaves")
	game.player.global_position = Vector2(400.0, exit.global_position.y)  # дім — нижня клітинка кімнати, над ним горище (D606)
	for i in 20: await physics_frame
	await _walk_to_door(&"move_left", exit)
	ck(exit.get_node(^"Interactable").get_prompt().visible, "the Leave prompt shows at the exit")
	await Kit.pad(self, JOY_BUTTON_Y)
	await _until(func() -> bool: return _room() == "Village", 5.0)
	for i in 30: await physics_frame
	await Kit.drain(self)
	ck(_room() == "Village", "pad Y at the exit → Village (%s)" % _room())
	door = game.map.get_node(^"ElderDoor")
	ck(game.player.global_position.distance_to(door.global_position) < 48.0 and game.player.is_on_floor(),
			"the hero is back outside the elder's door, on the floor (%s)" % game.player.global_position)
	_check_camera("Village again")

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
