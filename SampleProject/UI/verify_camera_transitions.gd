extends SceneTree

## TIMEOUT: 480

## Камера на переходах між кімнатами (B153, Sapega 2026-10-26: «камера скаче багато де, передивись переходи між
## кімнатами»). Герой справжнім вводом проходить КОЖЕН прохід крізь край (MetSys borders ≥ 1) і КОЖНІ двері
## (RoomDoor, E) в обидва боки; кожен кадр від початку переходу до 1,5 с після повної появи пишемо центр екрана камери,
## її межі, прозорість затемнення й позицію героя. Стрибок — видима камера зсунулась більш ніж на JUMP_PX за кадр,
## або ще повзе після кінця появи, або межі змінились, коли екран видно. Потім завантаження сейву й усередині
## кожної кімнати (verify_camera_rooms.gd): біг і стрибки з кожної клітинки, падіння з уступів — кадри, де камера
## рушила набагато більше героя.
##   godot --headless --path . --script res://SampleProject/UI/verify_camera_transitions.gd [-- 12345 dump]

const Kit := preload("res://SampleProject/UI/input_kit.gd")
## Шляхи, а не preload: class_name RoomDoor тягне ServiceLocator, якого компілятор SceneTree-скрипта ще не бачить.
const ROOM_DOOR := "res://SampleProject/Scripts/Gameplay/RoomDoor.gd"
const GATE := "res://SampleProject/Scripts/Gameplay/GateController.gd"
const SCREEN_FADE := "res://SampleProject/Scripts/Systems/Cutscenes/ScreenFade.gd"
const TEST_DIR := "user://verify_camera_transitions/"
const TEST_SLOT := 1
const JUMP_PX := 12.0
const SETTLE_TIME := 1.5
## Після появи камера мусить стояти на своїй цілі (герой + межі) — не далі, ніж на стільки пікселів.
const SLIDE_PX := 4.0
## Кінець демо: кімната одразу запускає фінальний екран (DemoEndScreen забирає камеру й HUD), назад ходу немає.
## Перехід у неї — останнім, перед [5]; усередині неї не бігаємо.
const DEMO_END_ROOM := "LaboratoryOutside.tscn"
const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const DIR_NAMES: Array[String] = ["right", "down", "left", "up"]

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

var game: Node
var metsys: Node
var camera: Camera2D
var cell: Vector2
var rows: Array[String] = []


func _initialize() -> void:
	Engine.max_fps = 60
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D289: підказки банерами, гра не стає
	game = await Kit.boot(self)
	metsys = root.get_node("MetSys")
	camera = game.player.get_node(^"Camera2D")
	cell = metsys.settings.in_game_cell_size
	game.player.set_invulnerable(true)

	var only := "".join(OS.get_cmdline_user_args())  # -- 2 : лише розділ [2] (налагодження)
	if only == "" or only == "dump":
		only = _sections() + only
	if only.contains("1"):
		await _edges()
	if only.contains("2"):
		await _all_doors()
	if only.contains("3"):
		print("[3] Inside rooms: run, jump, drop")
		for room: String in _rooms():
			if room != DEMO_END_ROOM:
				await _inside(room)
	if only.contains("4"):
		print("[4] Cutscenes that end in another room")
		await _cutscenes()
	if only.contains("5"):
		print("[5] New game and loading a save, from the menu's black screen")
		await _boots()
	if only.contains("1"):
		print("[6] Into the demo-end room, last")
		for p: Dictionary in _edge_passages():
			if p.to == DEMO_END_ROOM:
				await _edge(p)

	print("")
	print("passage | biggest visible one-frame move px | slide after the fade s | limits changed while visible")
	for r in rows:
		print(r)
	_done()


## Розділи цього файлу. Біг усередині кімнат ([3]) — у verify_camera_rooms.gd: разом вони довші за 180 с
## run_verify.sh.
func _sections() -> String:
	return "1245"


func _edges() -> void:
	print("[1] Edge passages, real input")
	# Сюжет лабораторії пройдено: камери не відбирає кат-сцена прибуття, герой ходить сам (як при поверненні).
	game.set_quest_flag("lab_cells_cutscene_complete", true)
	game.set_quest_flag("lab_acquaintance_complete", true)
	var passages := _edge_passages()
	ck(passages.size() >= 14, "found %d edge passages (both directions)" % passages.size())
	for p: Dictionary in passages:
		if p.room == DEMO_END_ROOM:
			print("  --  %s %s: the demo ends in this room, there is no way back" % [_short(p.room), DIR_NAMES[p.dir]])
		elif p.to != DEMO_END_ROOM:
			await _edge(p)



func _all_doors() -> void:
	print("[2] Doors, E")
	for room: String in _rooms():
		# Двері шукаємо в незапущеній копії сцени: кімнати без дверей не вантажимо.
		var copy: Node = (load(_scene(room)) as PackedScene).instantiate()
		var names: Array[NodePath] = []
		for node in _doors(copy):
			names.append(copy.get_path_to(node))
		copy.free()
		for door_path in names:
			await _door(room, door_path)


## Усі проходи крізь край: клітинка кімнати з border ≥ 1, а за ним клітинка іншої кімнати.
func _edge_passages() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var data = metsys.map_data
	for coords: Vector3i in data.cells:
		var here: String = data.get_assigned_scene_at(coords)
		if here == "":
			continue
		for i in 4:
			if data.get_cell_at(coords).borders[i] < 1:  # як намальовано на мапі; брами відчиняє _open_gates()
				continue
			var next := coords + Vector3i(DIRS[i].x, DIRS[i].y, 0)
			if data.get_cell_at(next) == null:
				continue
			var there: String = data.get_assigned_scene_at(next)
			if there == "" or there == here:
				continue
			out.append({"room": here, "to": there, "coords": coords, "dir": i})
	return out


func _rooms() -> Array[String]:
	var out: Array[String] = []
	var data = metsys.map_data
	for coords: Vector3i in data.cells:
		var room: String = data.get_assigned_scene_at(coords)
		if room != "" and not out.has(room):
			out.append(room)
	out.sort()
	return out


func _doors(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child in node.get_children():
		if child.get_script() != null and (child.get_script() as Script).resource_path == ROOM_DOOR:
			out.append(child)
		out.append_array(_doors(child))
	return out


func _of_script(node: Node, path: String) -> Array[Node]:
	var out: Array[Node] = []
	for child in node.get_children():
		if child.get_script() != null and (child.get_script() as Script).resource_path == path:
			out.append(child)
		out.append_array(_of_script(child, path))
	return out


func _short(room: String) -> String:
	return room.get_file().get_basename()


func _room_name() -> String:
	return "" if game.map == null else game.map.scene_file_path.get_file().get_basename()


## Підготовка (не вимірюється): кімната [param room], герой на [param pos] (або лишається), камера на ньому.
func _go(room: String, pos: Vector2, place: bool = true) -> void:
	if game.map.scene_file_path != _scene(room):
		await game.load_room(room)
		if game.map.has_node(^"QueueTrigger"):
			# Зала мера: черга й бій — кат-сцена, що рухає героя й після виходу з кімнати; тут вона не потрібна.
			(game.map.get_node(^"QueueTrigger") as Area2D).monitoring = false
		if not place:
			# Біля перших дверей (вони стоять там, де стоїть герой) або в центрі першої клітинки кімнати: центр її
			# прямокутника буває в чужій клітинці (Canyon → LizardCave), а з висоти герой чіпляється за драбину (MesaClimb).
			var doors := _doors(game.map)
			var first: Vector3i = metsys.map_data.get_cells_assigned_to(room)[0]
			game.place_player(doors[0].global_position if not doors.is_empty() else _local_origin(first) + cell / 2.0)
	if place:
		game.place_player(pos)
	while game.room_changing:
		await process_frame
	await Kit.drain(self)
	game.player.velocity = Vector2.ZERO
	camera.reset_smoothing()
	await Kit.frames(self, 20)


func _scene(room: String) -> String:
	return metsys.get_full_room_path(room) if not room.begins_with("res://") else room


## Підлога під точкою: перший удар променя вниз від [param top] до [param bottom] (герой стає на 48 px вище).
func _floor_at(x: float, top: float, bottom: float) -> Variant:
	var body: CharacterBody2D = game.player
	await physics_frame
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, top), Vector2(x, bottom), body.collision_mask, [body.get_rid()])
	var hit: Dictionary = body.get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	return Vector2(x, (hit["position"] as Vector2).y - 48.0)


func _local_origin(coords: Vector3i) -> Vector2:
	var base: Vector2i = metsys.get_current_room_instance().get_base_coords()
	return Vector2(Vector2i(coords.x, coords.y) - base) * cell


func _edge(p: Dictionary) -> void:
	var label := "%s %s → %s" % [_short(p.room), DIR_NAMES[p.dir], _short(p.to)]
	await _go(p.room, Vector2.ZERO, false)
	var o := _local_origin(p.coords)
	var action := &""
	var start: Vector2
	match p.dir:
		0, 2:
			var x: float = o.x + cell.x - 60.0 if p.dir == 0 else o.x + 60.0
			var f: Variant = await _floor_at(x, o.y + 8.0, o.y + cell.y - 8.0)
			start = f if f != null else Vector2(x, o.y + cell.y * 0.5)
			action = &"move_right" if p.dir == 0 else &"move_left"
		1:
			start = Vector2.ZERO
			for k in range(1, 16):
				var x: float = o.x + cell.x * k / 16.0
				if await _floor_at(x, o.y + 8.0, o.y + cell.y + 60.0) == null:
					start = Vector2(x, o.y + cell.y - 100.0)
					break
			if start == Vector2.ZERO:
				print("  --  %s: no hole in the floor — the way down is the descent cutscene, [4]" % label)
				return
		3:
			start = Vector2(o.x + cell.x * 0.5, o.y + 40.0)
	await _go(p.room, start)
	for gate in _of_script(game.map, GATE):
		gate.open_gate()
	await Kit.frames(self, 3)
	var samples := await _record(func() -> void:
		if action != &"":
			Input.action_press(action)
		elif p.dir == 3:
			game.player.velocity.y = -900.0
	, func() -> void:
		if action != &"":
			Input.action_release(action)
	, p.to)
	if action != &"":
		Input.action_release(action)
	_judge(label, samples, p.to)


func _door(room: String, door_path: NodePath) -> void:
	await _go(room, Vector2.ZERO, false)
	var door: Node2D = game.map.get_node(door_path)
	var label := "%s door %s → %s" % [_room_name(), door.name, (door.target_room as String).get_file().get_basename()]
	if door.gate_id != "":
		game.set_quest_flag(door._gate.flag, true)
	door.interactable.enabled = true
	# Герой стає за 40 px від дверей на їхній висоті (двері стоять там, де стоїть герой) і сам доходить до них:
	# Area2D не бачить тіла, поставленого просто на неї.
	var side: float = -1.0 if door.global_position.x > 200.0 else 1.0
	await _go(room, door.global_position + Vector2(side * 40.0, 0.0))
	var interactable: Node = door.get_node(^"Interactable")
	var walk := &"move_right" if side < 0.0 else &"move_left"
	Input.action_press(walk)
	for i in 180:
		if interactable.player_nearby:
			break
		await physics_frame
	Input.action_release(walk)
	await Kit.frames(self, 10)
	var target: String = door.target_room
	if not interactable.player_nearby or not interactable.enabled:
		print("  ..  %s: nearby %s, enabled %s, hero %s, door %s, event %s, paused %s, ui %s" % [label, interactable.player_nearby, interactable.enabled, game.player.global_position, door.global_position, game.player.event, paused, root.get_node("ServiceLocator").get_ui_manager().current_state_name])
	var samples := await _record(func() -> void: Kit.key(self, KEY_E), Callable(), target)
	_judge(label, samples, target)


## Кадри від [param start] (ввід) до SETTLE_TIME після повної появи в [param to]. Перший кадр переходу — коли
## з'являється чорний шар; кадри до нього (герой іде до краю) не пишемо.
func _record(start: Callable, on_transition: Callable, to: String) -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	var target_scene := _scene(to)
	start.call()
	var t0 := Time.get_ticks_msec()
	var began := false
	var visible_since := -1
	var nudged := false
	var dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	while Time.get_ticks_msec() - t0 < 20000:
		await process_frame
		if dm.is_dialogue_active():
			dm.current_dialogue_box.finish()  # D254
			dm.current_dialogue_player.accept()
		if game.map == null:
			continue
		var alpha := _alpha()
		if not began:
			if alpha <= 0.0 and not game.room_changing:
				if not nudged and not game.player.event and Time.get_ticks_msec() - t0 > 3000:
					nudged = true  # стіна краю не пускає — як verify_quiet_transitions, за край
					var dir: float = signf(Input.get_axis(&"move_left", &"move_right"))
					game.player.global_position.x += dir * 120.0
				continue
			began = true
			if on_transition.is_valid():
				on_transition.call()
		if camera.top_level and game.map.scene_file_path == target_scene:
			break  # кат-сцена нової кімнати забрала камеру (DemoEndScreen, Cutscene.detach_camera) — далі її кадр
		samples.append(_sample(alpha))
		if game.map.scene_file_path == target_scene and not game.room_changing and alpha <= 0.0:
			if visible_since < 0:
				visible_since = Time.get_ticks_msec()
			elif Time.get_ticks_msec() - visible_since > SETTLE_TIME * 1000.0:
				break
	return samples


func _alpha() -> float:
	var layer := root.get_node_or_null(^"ScreenFade")
	if layer == null or not layer.is_inside_tree():
		return 0.0
	return (layer.get_child(0) as ColorRect).color.a


func _sample(alpha: float) -> Dictionary:
	return {
		"t": Time.get_ticks_msec(),
		"room": _room_name(),
		"center": camera.get_screen_center_position(),
		"aim": _aim(),
		"limits": Rect2i(camera.limit_left, camera.limit_top, camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top),
		"alpha": alpha,
		"hero": game.player.global_position,
		"changing": game.room_changing,
		"detached": camera.top_level,
	}


## Куди камера мала б стати без згладжування: ціль у межах.
func _aim() -> Vector2:
	var half := camera.get_viewport_rect().size / camera.zoom / 2.0
	var aim := camera.get_target_position()
	aim.x = clampf(aim.x, camera.limit_left + half.x, maxf(camera.limit_left + half.x, camera.limit_right - half.x))
	aim.y = clampf(aim.y, camera.limit_top + half.y, maxf(camera.limit_top + half.y, camera.limit_bottom - half.y))
	return aim


func _judge(label: String, samples: Array[Dictionary], to: String) -> void:
	if samples.is_empty() or (samples[-1].room as String) != _short_of(to):
		ck(false, "%s: the transition never finished (in %s)" % [label, _room_name()])
		rows.append("| %s | — | — | — |" % label)
		return
	var biggest := 0.0
	var biggest_at := -1
	var limit_frames: Array[int] = []
	var lit_at := -1
	var slide_until := -1.0
	for i in range(1, samples.size()):
		var a: Dictionary = samples[i - 1]
		var b: Dictionary = samples[i]
		# Видно лише зміну між двома видимими кадрами: що сталося під суцільним чорним, гравець не бачить.
		var seen: bool = a.alpha < 0.98 and b.alpha < 0.98
		var move: float = (b.center as Vector2).distance_to(a.center)
		if seen and move > biggest:
			biggest = move
			biggest_at = i
		if seen and b.limits != a.limits:
			limit_frames.append(i)
		if lit_at < 0 and b.alpha <= 0.0 and not b.changing and b.room == samples[-1].room:
			lit_at = i
		if lit_at >= 0 and (b.center as Vector2).distance_to(b.aim) > SLIDE_PX:
			slide_until = (b.t - samples[lit_at].t) / 1000.0 + 1.0 / 60.0
	var slide := maxf(slide_until, 0.0)
	rows.append("| %s | %.1f (frame %d) | %.2f | %s |" % [label, biggest, biggest_at, slide, "frames %s" % str(limit_frames) if not limit_frames.is_empty() else "no"])
	ck(biggest <= JUMP_PX, "%s: biggest visible one-frame move %.1f px at frame %d (≤ %.0f)%s" % [label, biggest, biggest_at, JUMP_PX, _around(samples, biggest_at)])
	ck(slide_until < 0.0, "%s: the camera still slides %.2f s after the fade (frame %d lit)" % [label, slide, lit_at])
	if not limit_frames.is_empty() and OS.get_cmdline_user_args().has("dump"):
		for k in range(maxi(0, limit_frames[0] - 6), mini(samples.size(), limit_frames[0] + 3)):
			print("    %d %s" % [k, samples[k]])
	ck(limit_frames.is_empty(), "%s: limits change while the screen is visible, frames %s%s" % [label, str(limit_frames),
			"" if limit_frames.is_empty() else " (α %.2f, %s → %s, camera detached %s)" % [samples[limit_frames[0]].alpha, samples[limit_frames[0] - 1].limits, samples[limit_frames[0]].limits, samples[limit_frames[0]].detached]])


func _short_of(room: String) -> String:
	return _scene(room).get_file().get_basename()


func _around(samples: Array[Dictionary], at: int) -> String:
	if at < 0 or (samples[at].center as Vector2).distance_to(samples[at - 1].center) <= JUMP_PX:
		return ""
	var s: Dictionary = samples[at]
	var a: Dictionary = samples[at - 1]
	return " [%s α %.2f: centre %s → %s, hero %s → %s, limits %s → %s]" % [s.room, s.alpha, a.center, s.center, a.hero, s.hero, a.limits, s.limits]


## Усередині кімнати: з кожної клітинки біг праворуч зі стрибком і назад; камера не має рвонути більше за героя.
func _inside(room: String) -> void:
	await _go(room, Vector2.ZERO, false)
	var name := _room_name()
	var worst := 0.0
	var worst_note := ""
	var limit_changes := 0
	for coords: Vector3i in metsys.map_data.get_cells_assigned_to(room):
		var o := _local_origin(coords)
		var x := o.x + cell.x * 0.5
		var f: Variant = await _floor_at(x, o.y + 8.0, o.y + cell.y - 8.0)
		await _go(room, f if f != null else Vector2(x, o.y + cell.y * 0.5))
		if game.map.scene_file_path != _scene(room):
			continue
		for action: StringName in [&"move_right", &"move_left"]:
			Input.action_press(action)
			var prev := _sample(0.0)
			for i in 45:
				if i == 5:
					Input.action_press(&"jump")
				if i == 20:
					Input.action_release(&"jump")
				await process_frame
				var now := _sample(0.0)
				if now.room != prev.room:
					break
				var excess: float = (now.center as Vector2).distance_to(prev.center) - (now.hero as Vector2).distance_to(prev.hero)
				if excess > worst:
					worst = excess
					worst_note = "cell %s %s frame %d: centre %s → %s, hero %s → %s" % [Vector2i(coords.x, coords.y), action, i, prev.center, now.center, prev.hero, now.hero]
				if now.limits != prev.limits:
					limit_changes += 1
				prev = now
			Input.action_release(action)
			Input.action_release(&"jump")
	rows.append("| %s inside | %.1f more than the hero | — | %d |" % [name, worst, limit_changes])
	ck(worst <= JUMP_PX, "%s inside: the camera moves at most %.1f px more than the hero in a frame (≤ %.0f) %s" % [name, worst, JUMP_PX, worst_note if worst > JUMP_PX else ""])
	ck(limit_changes == 0, "%s inside: limits never change (%d)" % [name, limit_changes])


## Спуск з Каньйону (D256) і програш у залі мера (D300): кат-сцена гасить екран сама, телепорт, cs.end().
func _cutscenes() -> void:
	# Як verify_canyon_exit [2]: після села Каньйон чекає в RELIC_PICKUP, герой сам іде до краю мосту.
	await _go("Village.tscn", Vector2.ZERO, false)
	var flags: Dictionary = game.get_quest_flags().duplicate()
	flags.merge({"canyon_intro_complete": true, "canyon_abduction_complete": true, "village_abduction_complete": true,
			"village_arrival_complete": true, "village_fight_complete": true, "village_left_complete": true}, true)
	game.set_quest_flags(flags)
	await _go("Canyon.tscn", Vector2(1000, 370))
	var samples := await _record(func() -> void: Input.action_press(&"move_left"),
			func() -> void: Input.action_release(&"move_left"), "DesertRoad.tscn")
	Input.action_release(&"move_left")
	_judge("Canyon descent cutscene → DesertRoad", samples, "DesertRoad.tscn")
	game.set_quest_flag("lab_cells_cutscene_complete", false)  # після залу мера — сама кат-сцена прибуття
	game.set_quest_flag("lab_acquaintance_complete", false)
	await _go("MayorHall.tscn", Vector2.ZERO, false)
	var hall: Node = game.map
	samples = await _record(func() -> void: hall._on_hero_defeated(), Callable(), "LabCells.tscn")
	_judge("MayorHall defeat cutscene → LabCells", samples, "LabCells.tscn")


## Нова гра й завантаження сейву так, як їх запускає меню: екран уже чорний, Game.tscn додається, кімната світлішає.
func _boots() -> void:
	var save_system: Node = root.get_node("SaveSystem")
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(TEST_SLOT)
	await _go("DesertRoad.tscn", Vector2.ZERO, false)
	var f: Variant = await _floor_at(1500.0, 8.0, cell.y - 8.0)
	await _go("DesertRoad.tscn", f)
	ck(game.save_game(), "saved on the Desert Road at %s" % game.player.global_position)
	var slot_path: String = save_system.get_slot_path(TEST_SLOT)
	for which in ["new game", "load"]:
		game.queue_free()
		await Kit.frames(self, 4)
		await load(SCREEN_FADE).to_black(root, 0.01)
		if which == "new game":
			set_meta("start_new_game", true)
		else:
			set_meta("save_file_path", slot_path)
		game = load("res://SampleProject/Game.tscn").instantiate()
		camera = game.get_node(^"Player/Camera2D")
		var to := "Canyon.tscn" if which == "new game" else "DesertRoad.tscn"
		var samples := await _record(func() -> void:
			root.add_child(game)
			current_scene = game
		, Callable(), to)
		_judge("%s → %s" % [which, to.get_basename()], samples, to)
		game.player.set_invulnerable(true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path))


func _done() -> void:
	print("")
	if fails.is_empty():
		print("RESULT: ALL PASS")
	else:
		print("RESULT: %d FAIL" % fails.size())
	quit()
