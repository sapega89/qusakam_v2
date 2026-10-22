extends SceneTree

## Коридори лабораторії (D303, D306, [[lab_story_plan]] зріз 7) у справжній грі, справжнім вводом:
##   1. Кімната: три бої Fight_Upper / Fight_Middle / Fight_Lower (свій ключ стану в кожного, D152), старих
##      EnemySpawner / StateChangeTrigger_Fight немає; приховані тайли тримають героя на кожному поверсі (D246).
##   2. Маршрут: герой сам (move_right / move_left / jump / move_down) іде з LabCells у коридори, верхнім поверхом
##      на схід, драбиною вниз, середнім на захід, драбиною вниз, нижнім на схід — у LabBoss. Кожен бій чекає героя
##      (ворогів немає, доки він не зайшов у зону бою), вороги стають на підлогу свого поверху, реальне F кличе асист
##      (усі три асисти з LabCells, D305). Три бої добито → lab_corridors_complete, ціль «Go deeper into the laboratory».
##   3. Сейв перед нижнім боєм → завантаження: два добиті бої не повертаються, нижній чекає героя й починається.
##   4. Сейв після всіх трьох → завантаження: жоден бій не повертається, хоч герой проходить крізь усі зони.
##   5. B83: кожен місток — 96 px над тим, звідки на нього стрибають; герой стає на нього одним справжнім стрибком.
## Пише лише в user://verify_laboratory/ (set_save_dir) — справжні сейви не чіпає.
##   godot --headless --path . --script res://SampleProject/UI/verify_laboratory.gd

const CELLS := "res://SampleProject/Maps/LabCells.tscn"
const LAB := "res://SampleProject/Maps/Laboratory.tscn"
const TEST_DIR := "user://verify_laboratory/"
const TEST_SLOT := 1
## Бій → [скільки ворогів, підлога поверху (y)].
const FIGHTS := {"Fight_Upper": [3, 384.0], "Fight_Middle": [4, 864.0], "Fight_Lower": [4, 1344.0]}
const UNLOCKS: Array[String] = ["lab_companion_01_complete", "lab_companion_02_complete", "lab_companion_03_complete"]
## Ступні героя — на стільки нижче його центру.
const FEET := 24.0
## Найвищий підйом, на який стає один стрибок (~103 px, без подвійного).
const JUMP_RISE := 96.0
## Містки коридорів: [назва, x від, x до, верх (y), звідки стрибають: точка старту героя (ступні)].
const BRIDGES := [
	["floor A bridge", 768.0, 960.0, 256.0, Vector2(680, 320)],  # з блоку 512–704 (верх 320)
	["floor B bridge", 896.0, 1088.0, 768.0, Vector2(992, 864)],
	["floor C west bridge", 896.0, 1056.0, 1248.0, Vector2(976, 1344)],
	["floor C east bridge", 1376.0, 1536.0, 1248.0, Vector2(1456, 1344)],
]
## Односторонні тайли над драбинами — не містки для стрибка (рядок, колонка).
const LADDER_HOLES := [Vector2i(46, 12), Vector2i(47, 12), Vector2i(6, 27), Vector2i(7, 27)]

var fails: Array[String] = []
var game: Node
var sl: Node
var assists: Array[String] = []
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
	if game.map == null or _room() != "Laboratory":
		return
	for fight: String in FIGHTS:
		var spawner: Node = game.map.get_node(fight)
		for enemy: Node in _alive(spawner):
			if not started_at.has(fight):
				started_at[fight] = game.player.global_position.x
				Input.parse_input_event(_key(KEY_F, true))
				f_held = true
			if enemy.is_on_floor():
				var floor_y: float = FIGHTS[fight][1]
				if enemy.global_position.y < floor_y and enemy.global_position.y > floor_y - 64.0:
					landed.get_or_add(fight, []).append(enemy.name)
				enemy.die()

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

## Справжнє ↓ над драбиною — вниз до підлоги поверху під нею.
func _climb_down(label: String) -> void:
	var y0: float = game.player.global_position.y
	Input.action_press(&"move_down")
	var grabbed := false
	for i in 400:
		await physics_frame
		_fight_frame()
		grabbed = grabbed or game.player.mover.is_climbing()
		if grabbed and not game.player.mover.is_climbing():
			break
	Input.action_release(&"move_down")
	for i in 20: await physics_frame
	ck(grabbed and game.player.is_on_floor() and game.player.global_position.y > y0 + 350.0,
			"%s: down the ladder to the storey below (y %.0f → %.0f)" % [label, y0, game.player.global_position.y])

## Пройти крізь зону бою [param fight] (справжній ввід) і переконатися, що добитий бій не повертається.
func _stays_cleared(fight: String) -> void:
	var trigger: Node2D = game.map.get_node(fight).trigger_area
	game.player.global_position = Vector2(trigger.global_position.x - 120.0, FIGHTS[fight][1] - FEET - 8.0)
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
	ck(started_at.has(fight) and absf(started_at[fight] - trigger.global_position.x) < 60.0,
			"%s waited for the hero: the first enemy came when he reached its zone (hero x %s, zone x %.0f)"
			% [fight, started_at.get(fight, "never"), trigger.global_position.x])
	ck(landed.get(fight, []).size() == count, "%s: all %d enemies landed on the storey floor (y %.0f) — %s"
			% [fight, count, FIGHTS[fight][1], landed.get(fight, [])])
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
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289: hints as banners, the game never pauses under a window
	await process_frame
	await process_frame
	var save_system: Node = root.get_node("SaveSystem")
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(TEST_SLOT)
	var slot_path: String = save_system.get_slot_path(TEST_SLOT)
	sl = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
	root.get_node("EventBus").assist_called.connect(func(id: String) -> void: assists.append(id))
	set_meta("start_new_game", true)
	await _boot()
	var dm: Node = sl.get_dialogue_manager()
	# Камери пройдено (D304/D305, verify_lab_cells.gd): двері відчинено, три асисти в загоні.
	for f in ["lab_cells_cutscene_complete", "lab_acquaintance_complete"] + UNLOCKS:
		game.set_quest_flag(f, true)
	for f in UNLOCKS:
		sl.get_companion_manager().join_on_unlock(f)
	ck(sl.get_companion_manager().get_party().size() == 3, "three companions in the party (%s)" % [sl.get_companion_manager().get_party()])

	print("[1] The room: three storey fights, nothing of the old story")
	game.teleport_to_room(LAB, ^"SavePoint_Entrance")
	for i in 20: await physics_frame
	var lab: Node = game.map
	var keys := {}
	for fight: String in FIGHTS:
		var spawner: Node = lab.get_node_or_null(fight)
		ck(spawner != null and spawner.has_method(&"fight_cleared") and spawner.trigger_area != null and not spawner.auto_spawn_on_ready,
				"%s: a spawner with its own trigger zone" % fight)
		ck(spawner.spawn_points.size() == FIGHTS[fight][0], "%s: %d spawn points (%d)" % [fight, FIGHTS[fight][0], spawner.spawn_points.size()])
		keys[spawner.state_key] = true
	ck(keys.size() == 3 and not keys.has("enemies"), "each fight remembers itself under its own key (%s)" % [keys.keys()])
	for node_name in ["EnemySpawner", "StateChangeTrigger_Fight", "CompanionNPC_alisia", "StateChangeTrigger_LimitTest"]:
		ck(not lab.has_node(node_name), "no %s" % node_name)
	ck(game.get_objective() == "Fight through the laboratory", "objective (%s)" % game.get_objective())
	ck(not lab.get_node("TileMap/Foreground").visible, "the collision tiles are hidden — the drawn surfaces show")
	for floor_y in [384.0, 864.0, 1344.0]:
		game.player.global_position = Vector2(1150, floor_y - 40)  # не на блоках поверхів
		for i in 30: await physics_frame
		ck(game.player.is_on_floor() and absf(game.player.global_position.y - floor_y + FEET) < 4,
				"the hero stands on the floor at y %d (%s)" % [floor_y, game.player.global_position])
	var far: Node2D = lab.get_node("Atmosphere/Far1/Sprite")
	game.player.global_position = Vector2(300, 344)
	for i in 60: await physics_frame
	var camera: Camera2D = root.get_camera_2d()
	var far_x := far.global_position.x
	var cam_x := camera.get_screen_center_position().x
	game.player.global_position = Vector2(900, 344)
	for i in 60: await physics_frame
	var cam_moved := camera.get_screen_center_position().x - cam_x
	# шар зсувається на (1 − 0.4) руху камери; повтор кожні 864 px перескакує — тому за модулем
	var off := fposmod(far.global_position.x - far_x - 0.6 * cam_moved, 864.0)
	ck(cam_moved > 300.0 and minf(off, 864.0 - off) < 4.0,
			"the far plane follows the camera at 0.6 of its move (camera %.0f, off %.1f)" % [cam_moved, off])
	for fight: String in FIGHTS:
		ck(_alive(lab.get_node(fight)).is_empty() and not lab.get_node(fight).fight_in_progress(),
				"%s: not started — nobody walked into it (the far-plane check stays west of every zone)" % fight)

	print("[2] The route with real input: LabCells → three storeys → LabBoss")
	game.teleport_to_room(CELLS, ^"Arrival")
	for i in 30: await physics_frame
	await _drain(dm)
	ck(_room() == "LabCells", "start in the cells (%s)" % _room())
	Input.action_press(&"move_right")
	for i in 600:
		await physics_frame
		if _room() == "Laboratory":
			break
	Input.action_release(&"move_right")
	for i in 20: await physics_frame
	ck(_room() == "Laboratory" and game.player.global_position.y < 400.0, "walked east into the corridors' top storey (%s, %s)" % [_room(), game.player.global_position])
	for fight: String in FIGHTS:
		ck(_alive(game.map.get_node(fight)).is_empty(), "%s: no enemy before the hero comes" % fight)
	assists.clear()
	ck(await _go(1504.0), "top storey east to the ladder (%s)" % game.player.global_position)
	await _fought("Fight_Upper")
	await _climb_down("top → middle")
	ck(await _go(224.0, 1200), "middle storey west to the ladder (%s)" % game.player.global_position)
	await _fought("Fight_Middle")
	ck(not game.get_quest_flag("lab_corridors_complete"), "two of three — the corridors are not done yet")
	await _climb_down("middle → bottom")
	for i in 30: await physics_frame
	ck(game.save_game(), "saved on the bottom storey before its fight")
	var hero_at: Vector2 = game.player.global_position
	ck(await _go(1600.0, 1200), "bottom storey east (%s)" % game.player.global_position)
	await _fought("Fight_Lower")
	for i in 5: await physics_frame
	ck(assists.size() == 3, "a real F press in each fight sent an assist (%s)" % [assists])
	ck(game.get_quest_flag("lab_corridors_complete"), "all three fights won → lab_corridors_complete")
	ck(game.get_objective() == "Go deeper into the laboratory", "objective (%s)" % game.get_objective())
	ck(game.player.is_alive(), "the hero lived through the corridors")
	Input.action_press(&"move_right")
	for i in 300:
		await physics_frame
		if _room() == "LabBoss":
			break
	Input.action_release(&"move_right")
	ck(_room() == "LabBoss", "walked east out of the bottom storey into LabBoss (%s)" % _room())
	for i in 20: await physics_frame

	print("[3] Load the save made before the bottom fight: the two won fights stay won, the third waits")
	game.teleport_to_room(LAB, ^"SavePoint_PreBoss")  # не в LabBoss: туди сейв веде вже після бою
	for i in 20: await physics_frame
	await _load_slot(slot_path)
	ck(_room() == "Laboratory" and game.player.global_position.distance_to(hero_at) < 8.0,
			"back on the bottom storey where he saved (%s, %s)" % [_room(), game.player.global_position])
	ck(not game.get_quest_flag("lab_corridors_complete"), "the corridors are not done in that save")
	await _stays_cleared("Fight_Upper")
	await _stays_cleared("Fight_Middle")
	game.player.global_position = hero_at + Vector2(0, -8)
	game.player.velocity = Vector2.ZERO
	for i in 20: await physics_frame
	started_at.clear()
	landed.clear()
	assists.clear()
	ck(_alive(game.map.get_node("Fight_Lower")).is_empty(), "Fight_Lower: no enemy before the hero comes")
	ck(await _go(1600.0, 1200), "bottom storey east again (%s)" % game.player.global_position)
	await _fought("Fight_Lower")
	ck(assists.size() == 1, "the loaded party still sends an assist (%s)" % [assists])
	ck(game.get_quest_flag("lab_corridors_complete"), "→ lab_corridors_complete")

	print("[4] Save with all three won, load: none comes back")
	ck(game.save_game(), "saved with the corridors cleared")
	await _load_slot(slot_path)
	ck(_room() == "Laboratory", "loaded into the corridors (%s)" % _room())
	for fight: String in FIGHTS:
		await _stays_cleared(fight)
	ck(game.get_objective() == "Go deeper into the laboratory", "objective after the load (%s)" % game.get_objective())

	print("[5] B83: every bridge is one real jump up")
	var fg: TileMapLayer = game.map.get_node("TileMap/Foreground")
	var bridge_cells := 0
	var stray: Array[Vector2i] = []
	for cell: Vector2i in fg.get_used_cells():
		if fg.get_cell_atlas_coords(cell).y == 0 and not LADDER_HOLES.has(cell):
			bridge_cells += 1
			var hit := BRIDGES.filter(func(b: Array) -> bool:
				return cell.x * 32 >= b[1] and cell.x * 32 < b[2] and cell.y * 32 == b[3])
			if hit.size() != 1:
				stray.append(cell)
	ck(stray.is_empty(), "every one-way tile belongs to a listed bridge (stray %s)" % [stray])
	var listed := 0
	for b: Array in BRIDGES:
		listed += int((b[2] - b[1]) / 32.0)
	ck(bridge_cells == listed, "the listed bridges are all there is (%d tiles, listed %d)" % [bridge_cells, listed])
	for b: Array in BRIDGES:
		var from: Vector2 = b[4]
		ck(from.y - b[3] <= JUMP_RISE, "%s: %.0f px above where the hero jumps from" % [b[0], from.y - b[3]])
		var p: CharacterBody2D = game.player
		p.global_position = from - Vector2(0, FEET + 4.0)
		p.velocity = Vector2.ZERO
		for i in 30: await physics_frame
		var mid: float = (b[1] + b[2]) / 2.0
		var on_top := false
		Input.action_press(&"jump")
		for i in 120:
			await physics_frame
			if i == 18:
				Input.action_release(&"jump")
			_steer(&"move_right", p.global_position.x < mid - 40.0)
			_steer(&"move_left", p.global_position.x > mid + 40.0)
			if i > 10 and p.is_on_floor():
				on_top = absf(p.global_position.y + FEET - b[3]) < 4.0
				break
		_release_all()
		ck(on_top, "%s: one jump lands on top (y %.0f)" % [b[0], p.global_position.y + FEET])

	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	save_system.set_save_dir(save_system.SAVE_DIR)
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
