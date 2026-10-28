extends SceneTree

## Поверхи лабораторії (D303, D306; граф v3 — D863, D865) у справжній грі, справжнім вводом:
##   1. Кімнати: три поверхи (Laboratory — нижній, LabMiddleFloor, LabTopFloor), на кожному свій бій — Fight_Upper /
##      Fight_Middle / Fight_Lower (імена — порядок зустрічі, свій ключ стану в кожного, D152) і проклятий шакал
##      Fight_Cursed на середньому; старих EnemySpawner / StateChangeTrigger_Fight немає; приховані тайли тримають героя
##      на підлозі кожного поверху (D246).
##   2. Маршрут угору (D863): герой сам (move_right / move_left / jump, E біля дверей) іде з LabCells на нижній поверх,
##      на схід суцільним бігом на великі сходи схід, маршем угору до дверей, на середній поверх, на захід на великі
##      сходи захід, маршем угору до дверей, на верхній поверх, на схід — дверима вгору в LabBoss. Кожен бій чекає героя
##      (ворогів немає, доки він не зайшов у зону бою), вороги стають на підлогу свого поверху, реальне F кличе асист
##      (усі три асисти з LabCells, D305). Три бої добито → lab_corridors_complete, ціль «Climb up out of the laboratory».
##   3. Сейв на верхньому поверсі перед його боєм → завантаження: два добиті бої (на інших поверхах) не повертаються,
##      верхній чекає героя й починається.
##   4. Сейв після всіх трьох → завантаження: жоден бій не повертається, хоч герой проходить крізь усі зони.
##   5. D832 / B201: у поверхах і на сходах немає містків, блоків, люків і драбин — кожен поверх порожній від підлоги до
##      стелі; сходи — пандус (D834) від підлоги до майданчика з дверима нагору, угору в бік графа.
## Що змінилось проти до-v3 (три поверхи в одній кімнаті, драбини): переходи між поверхами — не «↓ драбиною на поверх
## нижче», а сходи вгору й двері; бої не в одній кімнаті, тож «добитий бій не вертається» перевіряється в кімнаті бою;
## «немає містків» перевіряється в кожному поверсі, а не в рядках трьох поверхів однієї схеми, і люків драбин більше
## немає (LADDER_HOLES зник).
## Пише лише в user://verify_laboratory/ (set_save_dir) — справжні сейви не чіпає.
##   godot --headless --path . --script res://SampleProject/UI/verify_laboratory.gd

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const CELLS := "res://SampleProject/Maps/LabCells.tscn"
const MAPS := "res://SampleProject/Maps/%s.tscn"
const TEST_DIR := "user://verify_laboratory/"
const TEST_SLOT := 1
## Бій → [скільки ворогів, кімната]. Підлога кожного поверху — y 384.
const FIGHTS := {"Fight_Upper": [3, "Laboratory"], "Fight_Cursed": [1, "LabMiddleFloor"], "Fight_Middle": [4, "LabMiddleFloor"],
		"Fight_Lower": [4, "LabTopFloor"]}
const FLOOR_Y := 384.0
const FLOORS := ["Laboratory", "LabMiddleFloor", "LabTopFloor"]
## Поверх → вузол, куди туди переноситься тест.
const ENTRY := {"Laboratory": ^"SavePoint_Entrance", "LabMiddleFloor": ^"StairsDoor", "LabTopFloor": ^"StairsDoor"}
## Великі сходи → у який бік марш іде вгору.
const STAIRS := {"LabStairsEast": 1.0, "LabStairsWest": -1.0}
const UNLOCKS: Array[String] = ["lab_companion_01_complete", "lab_companion_02_complete", "lab_companion_03_complete"]
## Ступні героя — на стільки нижче його центру.
const FEET := 24.0

var fails: Array[String] = []
var game: Node
var sl: Node
var assists: Array[String] = []
## D515: натискання, поки компаньйон на полі чи йде спільний кулдаун, — відмова, не асист.
var denied: Array[String] = []
## Бій → x героя, коли зʼявився перший ворог; бій → вороги, що стали на підлогу свого поверху.
var started_at := {}
var landed := {}
## Справжнє F натиснуто — відпускаємо на наступному кадрі.
var f_held := false

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
			dm.current_dialogue_player.accept()
			for f in 6: await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return

func _room() -> String:
	return game.map.scene_file_path.get_file().get_basename() if game.map else ""

func _alive(spawner: Node) -> Array:
	return spawner.get_children().filter(func(n: Node) -> bool: return n.is_in_group(&"enemies") and n.is_alive())

func _key(code: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev

func _steer(action: StringName, on: bool) -> void:
	if on: Input.action_press(action)
	else: Input.action_release(action)

func _release_all() -> void:
	for action: StringName in [&"move_right", &"move_left", &"move_down", &"move_up", &"jump"]:
		Input.action_release(action)

## Кадр бою: ворог, що став на підлогу, записується й добивається; на перший — справжнє F (асист).
func _fight_frame() -> void:
	if f_held:
		Input.parse_input_event(_key(KEY_F, false))
		f_held = false
	if game.map == null:
		return
	for fight: String in FIGHTS:
		if FIGHTS[fight][1] != _room():
			continue
		var spawner: Node = game.map.get_node(fight)
		for enemy: Node in _alive(spawner):
			if not started_at.has(fight):
				started_at[fight] = game.player.global_position.x
				Input.parse_input_event(_key(KEY_F, true))
				f_held = true
			if enemy.is_on_floor():
				if enemy.global_position.y < FLOOR_Y and enemy.global_position.y > FLOOR_Y - 64.0:
					landed.get_or_add(fight, []).append(enemy.name)
				enemy.die()

## Справжнім вводом до дверей [param door] (бої по дорозі добиваються), E — у кімнату [param room].
func _door(door: NodePath, room: String) -> void:
	var node: Area2D = game.map.get_node(door)
	await _go(node.global_position.x)
	for i in 20: await physics_frame
	await Kit.key(self, KEY_E)
	for i in 300:
		await physics_frame
		if _room() == room:
			break
	for i in 20: await physics_frame

## Справжнім «праворуч» / «ліворуч» ([param dir]) крізь край кімнати — суцільним бігом у [param room].
func _cross(dir: float, room: String) -> bool:
	var action: StringName = &"move_right" if dir > 0 else &"move_left"
	for i in 900:
		await physics_frame
		_fight_frame()
		Input.action_press(action)
		if _room() == room:
			break
	_release_all()
	for i in 20: await physics_frame
	return _room() == room

## Герой іде (справжній ввід) до x [param target]; стіна — стрибок. Бої по дорозі добиваються (_fight_frame).
func _go(target: float, max_frames := 900) -> bool:
	var jump_left := 0
	for i in max_frames:
		await physics_frame
		_fight_frame()
		var p: Node2D = game.player
		if absf(p.global_position.x - target) < 12.0:
			_release_all()
			return true
		_steer(&"move_right", p.global_position.x < target)
		_steer(&"move_left", p.global_position.x > target)
		if jump_left > 0:
			jump_left -= 1
			if jump_left == 0:
				Input.action_release(&"jump")
		elif p.is_on_floor() and p.is_on_wall():
			Input.action_press(&"jump")
			jump_left = 18
	_release_all()
	return false

## Пройти крізь зону бою [param fight] у його кімнаті (справжній ввід) і переконатися, що добитий бій не повертається.
func _stays_cleared(fight: String) -> void:
	if _room() != FIGHTS[fight][1]:
		await game.teleport_to_room(MAPS % FIGHTS[fight][1], ENTRY[FIGHTS[fight][1]])
		for i in 20: await physics_frame
	var trigger: Node2D = game.map.get_node(fight).trigger_area
	game.player.global_position = Vector2(trigger.global_position.x - 120.0, FLOOR_Y - FEET - 8.0)
	game.player.velocity = Vector2.ZERO
	for i in 20: await physics_frame
	await _go(trigger.global_position.x + 120.0)
	for i in 120:  # хвилі по 2, через 1.5 с
		await physics_frame
		if not _alive(game.map.get_node(fight)).is_empty():
			break
	ck(_alive(game.map.get_node(fight)).is_empty() and game.map.is_fight_cleared(NodePath(fight)),
			"%s: walked through its zone — the cleared fight does not come back" % fight)

## Перевірка бою, який пройшов маршрут: чекав героя, вороги стали на підлогу, усіх добито.
func _fought(fight: String) -> void:
	var trigger: Node2D = game.map.get_node(fight).trigger_area
	var count: int = FIGHTS[fight][0]
	# Хвилі по 2 через 1.5 с: рівним поверхом (D832) герой доходить до краю раніше за останню хвилю — чекаємо її.
	for i in 300:
		if game.map.is_fight_cleared(NodePath(fight)):
			break
		await physics_frame
		_fight_frame()
	ck(started_at.has(fight) and absf(started_at[fight] - trigger.global_position.x) < 60.0,
			"%s waited for the hero: the first enemy came when he reached its zone (hero x %s, zone x %.0f)"
			% [fight, started_at.get(fight, "never"), trigger.global_position.x])
	ck(landed.get(fight, []).size() == count, "%s: all %d enemies landed on the storey floor (y %.0f) — %s"
			% [fight, count, FLOOR_Y, landed.get(fight, [])])
	ck(game.map.is_fight_cleared(NodePath(fight)), "%s: cleared" % fight)

func _boot() -> void:
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 60: await physics_frame
	await _drain(sl.get_dialogue_manager())

func _load_slot(slot_path: String) -> void:
	game.queue_free()
	for i in 4: await process_frame
	set_meta("save_file_path", slot_path)
	set_meta("start_new_game", false)
	await _boot()

func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	await process_frame
	await process_frame
	var save_system: Node = root.get_node("SaveSystem")
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(TEST_SLOT)
	var slot_path: String = save_system.get_slot_path(TEST_SLOT)
	sl = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
	root.get_node("EventBus").assist_called.connect(func(id: String) -> void: assists.append(id))
	root.get_node("EventBus").assist_denied.connect(func(id: String) -> void: denied.append(id))
	set_meta("start_new_game", true)
	await _boot()
	var dm: Node = sl.get_dialogue_manager()
	# Камери пройдено (D304/D305, verify_lab_cells.gd): двері відчинено, три асисти в загоні.
	for f in ["lab_cells_cutscene_complete", "lab_acquaintance_complete"] + UNLOCKS:
		game.set_quest_flag(f, true)
	for id in ["alisia", "astrit", "urizen"]:  # D464: у загін їх бере гравець у Status
		sl.get_companion_manager().toggle_party(id)
	ck(sl.get_companion_manager().get_party().size() == 3, "three companions in the party (%s)" % [sl.get_companion_manager().get_party()])

	print("[1] The rooms: three floors, a fight on each, nothing of the old story")
	var keys := {}
	for room: String in FLOORS:
		await game.teleport_to_room(MAPS % room, ENTRY[room])
		for i in 20: await physics_frame
		var floor_room: Node = game.map
		for fight: String in FIGHTS:
			if FIGHTS[fight][1] != room:
				continue
			var spawner: Node = floor_room.get_node_or_null(fight)
			ck(spawner != null and spawner.has_method(&"fight_cleared") and spawner.trigger_area != null and not spawner.auto_spawn_on_ready,
					"%s/%s: a spawner with its own trigger zone" % [room, fight])
			ck(spawner.spawn_points.size() == FIGHTS[fight][0], "%s: %d spawn points (%d)" % [fight, FIGHTS[fight][0], spawner.spawn_points.size()])
			keys[spawner.state_key] = true
			ck(_alive(spawner).is_empty() and not spawner.fight_in_progress(), "%s: not started — nobody walked into it" % fight)
		for node_name in ["EnemySpawner", "StateChangeTrigger_Fight", "CompanionNPC_alisia", "StateChangeTrigger_LimitTest"]:
			ck(not floor_room.has_node(node_name), "%s: no %s" % [room, node_name])
		ck(not floor_room.get_node("TileMap/Foreground").visible, "%s: the collision tiles are hidden — the drawn surfaces show" % room)
		game.player.global_position = Vector2(1150, FLOOR_Y - 40)
		for i in 30: await physics_frame
		ck(game.player.is_on_floor() and absf(game.player.global_position.y - FLOOR_Y + FEET) < 4,
				"%s: the hero stands on the floor at y %d (%s)" % [room, FLOOR_Y, game.player.global_position])
	ck(keys.size() == FIGHTS.size() and not keys.has("enemies"), "each fight remembers itself under its own key (%s)" % [keys.keys()])
	ck(game.get_objective() == "Fight through the laboratory", "objective (%s)" % game.get_objective())
	await game.teleport_to_room(MAPS % "Laboratory", ^"SavePoint_Entrance")
	for i in 20: await physics_frame
	var far: Node2D = game.map.get_node("Atmosphere/Far1/Sprite")
	game.player.global_position = Vector2(300, 344)
	for i in 60: await physics_frame
	var camera: Camera2D = root.get_camera_2d()
	var far_x := far.global_position.x
	var cam_x := camera.get_screen_center_position().x
	game.player.global_position = Vector2(800, 344)
	for i in 60: await physics_frame
	var cam_moved := camera.get_screen_center_position().x - cam_x
	# шар зсувається на (1 − 0.4) руху камери; повтор кожні 864 px перескакує — тому за модулем
	var off := fposmod(far.global_position.x - far_x - 0.6 * cam_moved, 864.0)
	ck(cam_moved > 300.0 and minf(off, 864.0 - off) < 4.0,
			"the far plane follows the camera at 0.6 of its move (camera %.0f, off %.1f)" % [cam_moved, off])
	ck(_alive(game.map.get_node("Fight_Upper")).is_empty() and not game.map.get_node("Fight_Upper").fight_in_progress(),
			"Fight_Upper: not started — the far-plane check stays west of its zone")

	print("[2] The route up with real input: LabCells → lowest floor → great stairs → middle → great stairs → top → LabBoss")
	await game.teleport_to_room(CELLS, ^"Arrival")
	for i in 30: await physics_frame
	await _drain(dm)
	ck(_room() == "LabCells", "start in the cells (%s)" % _room())
	await _door(^"CorridorDoor", "Laboratory")
	ck(_room() == "Laboratory" and game.player.global_position.x < 300.0,
			"through the iron door onto the lowest floor, at its west end (%s, %s)" % [_room(), game.player.global_position])
	assists.clear()
	denied.clear()
	ck(await _go(3600.0, 1500), "lowest floor east (%s)" % game.player.global_position)
	await _fought("Fight_Upper")
	ck(await _cross(1.0, "LabStairsEast"), "on east through the room's edge onto the great stairs, no door (%s)" % _room())
	var y_foot: float = game.player.global_position.y
	ck(await _go(1590.0), "up the stairs east (%s)" % game.player.global_position)
	ck(game.player.is_on_floor() and game.player.global_position.y < y_foot - 150.0,
			"climbed the flight to the landing (y %.0f → %.0f)" % [y_foot, game.player.global_position.y])
	await _door(^"FloorDoor", "LabMiddleFloor")
	ck(_room() == "LabMiddleFloor" and game.player.global_position.x > 3700.0,
			"through «вихід на поверх» onto the middle floor, at its east end (%s, %s)" % [_room(), game.player.global_position])
	ck(await _go(1000.0, 1500), "middle floor west (%s)" % game.player.global_position)
	await _fought("Fight_Cursed")  # проклятий шакал сам-на-сам (D582); до lab_corridors_complete не лічиться, як і муха
	await _fought("Fight_Middle")
	ck(not game.get_quest_flag("lab_corridors_complete"), "two of three — the corridors are not done yet")
	ck(await _cross(-1.0, "LabStairsWest"), "on west through the room's edge onto the second great stairs (%s)" % _room())
	y_foot = game.player.global_position.y
	ck(await _go(138.0), "up the stairs west (%s)" % game.player.global_position)
	ck(game.player.is_on_floor() and game.player.global_position.y < y_foot - 150.0,
			"climbed the flight to the landing (y %.0f → %.0f)" % [y_foot, game.player.global_position.y])
	await _door(^"FloorDoor", "LabTopFloor")
	ck(_room() == "LabTopFloor" and game.player.global_position.x < 500.0,
			"through «вихід на поверх» onto the top floor, at its west end (%s, %s)" % [_room(), game.player.global_position])
	for i in 30: await physics_frame
	ck(game.save_game(), "saved on the top floor before its fight")
	var hero_at: Vector2 = game.player.global_position
	ck(await _go(3200.0, 1500), "top floor east (%s)" % game.player.global_position)
	await _fought("Fight_Lower")
	for i in 5: await physics_frame
	# Бої йдуть один за одним швидше за спільний кулдаун (D515): частину натискань відмовлено — це правило, не збій.
	ck(assists.size() >= 1 and assists.size() + denied.size() == FIGHTS.size(),
			"a real F press in each fight sent an assist or was refused under the shared cooldown (%s / denied %s)" % [assists, denied])
	ck(game.get_quest_flag("lab_corridors_complete"), "all three fights won → lab_corridors_complete")
	ck(game.get_objective() == "Climb up out of the laboratory", "objective (%s)" % game.get_objective())
	ck(game.player.is_alive(), "the hero lived through the floors")
	await _door(^"BossDoor", "LabBoss")
	ck(_room() == "LabBoss", "east to the iron door and up through it into LabBoss (%s)" % _room())
	for i in 20: await physics_frame

	print("[3] Load the save made before the top fight: the two won fights stay won, the third waits")
	await game.teleport_to_room(MAPS % "LabTopFloor", ^"SavePoint_PreBoss")  # не в LabBoss: туди сейв веде вже після бою
	for i in 20: await physics_frame
	await _load_slot(slot_path)
	ck(_room() == "LabTopFloor" and game.player.global_position.distance_to(hero_at) < 8.0,
			"back on the top floor where he saved (%s, %s)" % [_room(), game.player.global_position])
	ck(not game.get_quest_flag("lab_corridors_complete"), "the corridors are not done in that save")
	await _stays_cleared("Fight_Upper")
	await _stays_cleared("Fight_Middle")
	await game.teleport_to_room(MAPS % "LabTopFloor", ^"StairsDoor")
	for i in 20: await physics_frame
	game.player.global_position = hero_at + Vector2(0, -8)
	game.player.velocity = Vector2.ZERO
	for i in 20: await physics_frame
	started_at.clear()
	landed.clear()
	assists.clear()
	ck(_alive(game.map.get_node("Fight_Lower")).is_empty(), "Fight_Lower: no enemy before the hero comes")
	ck(await _go(3200.0, 1500), "top floor east again (%s)" % game.player.global_position)
	await _fought("Fight_Lower")
	ck(assists.size() == 1, "the loaded party still sends an assist (%s)" % [assists])
	ck(game.get_quest_flag("lab_corridors_complete"), "→ lab_corridors_complete")

	print("[4] Save with all three won, load: none comes back")
	ck(game.save_game(), "saved with the corridors cleared")
	await _load_slot(slot_path)
	ck(_room() == "LabTopFloor", "loaded onto the top floor (%s)" % _room())
	for fight: String in FIGHTS:
		await _stays_cleared(fight)
	ck(game.get_objective() == "Climb up out of the laboratory", "objective after the load (%s)" % game.get_objective())

	print("[5] D832 / B201 / D834: no platforms, hatches or ladders; the stairs are a ramp up to a door")
	for room: String in FLOORS + STAIRS.keys():
		var scene: Node = (load(MAPS % room) as PackedScene).instantiate()
		var fg: TileMapLayer = scene.get_node("TileMap/Foreground")
		var cols: int = fg.get_used_rect().size.x
		var inside: Array[Vector2i] = []
		var one_way: Array[Vector2i] = []
		for cell: Vector2i in fg.get_used_cells():
			if fg.get_cell_atlas_coords(cell).y == 0:
				one_way.append(cell)
			if cell.x > 0 and cell.x < cols - 1 and cell.y >= 2 and cell.y <= 11:
				inside.append(cell)
		ck(one_way.is_empty(), "%s: no one-way tile — no bridge, no hatch (%s)" % [room, one_way])
		ck(inside.is_empty(), "%s: nothing stands between the floor and the ceiling (%s)" % [room, inside])
		ck(scene.get_children().all(func(n: Node) -> bool: return not n.name.begins_with("Ladder")), "%s: no ladder" % room)
		if STAIRS.has(room):
			var ramp: CollisionPolygon2D = scene.get_node("Stairs/Ramp")
			var width := float(cols * 32)
			var foot := Vector2.INF
			var landing := Vector2(0, INF)
			for p: Vector2 in ramp.polygon:
				if p.y >= FLOOR_Y and absf(p.x - width * 0.5) < absf(foot.x - width * 0.5):
					foot = p
				if p.y < landing.y or (p.y == landing.y and absf(p.x - width * 0.5) < absf(landing.x - width * 0.5)):
					landing = p
			ck(signf(landing.x - foot.x) == STAIRS[room] and FLOOR_Y - landing.y >= 150.0,
					"%s: the ramp rises %s from the floor (%s) to the landing (%s)" % [room, "east" if STAIRS[room] > 0 else "west", foot, landing])
			var door: Node2D = scene.get_node("FloorDoor")
			ck(signf(door.position.x - landing.x) == STAIRS[room] and door.position.y < landing.y,
					"%s: «вихід на поверх» stands on the landing (%s)" % [room, door.position])
		scene.free()

	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	save_system.set_save_dir(save_system.SAVE_DIR)
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
