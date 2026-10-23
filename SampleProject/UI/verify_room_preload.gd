extends SceneTree

## Самоперевірка performance_plan, slice 2–3 і D434: сусідні кімнати й цілі дверей вантажаться у фоні, а зміна кімнати
## гасить екран, міняє кімнату під чорним і світлішає — без жодного завислого кадру.
##   godot --headless --path . --script res://SampleProject/UI/verify_room_preload.gd

const Kit := preload("res://SampleProject/UI/input_kit.gd")
const MAPS := "res://SampleProject/Maps/%s.tscn"

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

var game: Node
var metsys: Node


func _initialize() -> void:
	game = await Kit.boot(self)
	metsys = root.get_node("MetSys")
	game.player.set_invulnerable(true)

	print("[1] In Canyon the neighbour (Village) loads in the background, a far room does not")
	ck(await _held_within(MAPS % "Village", 3.0), "Village is held within 3 s of Canyon")
	ck(game.room_preloader.is_held(MAPS % "Canyon"), "the current room (Canyon) is held")
	ck(not ResourceLoader.has_cached(MAPS % "LabBoss"), "a non-neighbour (LabBoss) is not loaded")

	print("[2] Walking east with a real D hold: fade to black, swap under black, light again (D434)")
	var walk: Dictionary = await _walk_east()
	ck(_in("Village"), "the room is Village (%s, %s)" % [game.map.scene_file_path.get_file(), walk["how"]])
	ck(walk["black_at_swap"], "the screen is black when the rooms swap")
	ck(walk["longest_ms"] < 100.0, "no frame freezes during the change (longest %.0f ms)" % walk["longest_ms"])
	ck(walk["change_ms"] < 900.0, "fade out + swap + fade in take %.0f ms (preloaded: about 0.5 s)" % walk["change_ms"])
	ck(not root.has_node(^"ScreenFade") and not paused, "light again and the game runs")
	ck(game.room_preloader.is_held(MAPS % "Canyon"), "Canyon is still held (neighbour of Village)")
	ck(not ResourceLoader.has_cached(MAPS % "LabBoss"), "LabBoss is still not loaded")

	print("[3] Slice 3: a door's target is held; the door fades like a walk")
	ck(await _held_within(MAPS % "ElderHouse", 3.0), "ElderHouse (the Village door's target) is held")
	var t0: int = Time.get_ticks_msec()
	await game.teleport_to_room(MAPS % "ElderHouse", ^"Arrival")
	ck(_in("ElderHouse") and not root.has_node(^"ScreenFade"), "teleport_to_room → ElderHouse, light again")
	ck(Time.get_ticks_msec() - t0 >= 400, "the teleport faded out and in (%d ms)" % (Time.get_ticks_msec() - t0))
	game.preload_room(MAPS % "DesertRoad")
	ck(await _held_within(MAPS % "DesertRoad", 3.0), "a story teleport's target (DesertRoad) is held after preload_room()")

	print("[4] A cutscene that darkened the screen itself: no second fade, the room change lifts its black")
	await ScreenFade.to_black(game)
	var swapped_black: Array = [false]
	game.room_swapping.connect(func() -> void: swapped_black[0] = ScreenFade.is_black(game), CONNECT_ONE_SHOT)
	game.teleport_to_room(MAPS % "DesertRoad", ^"ArrivalFromCanyon")  # як Canyon.gd: без await
	ck(_in("DesertRoad") and swapped_black[0], "a held room swaps at once, still black")
	await game.room_change_finished
	ck(not root.has_node(^"ScreenFade"), "the cutscene's black is lifted by the room change")

	_done()


func _in(room: String) -> bool:
	return game.map.scene_file_path == MAPS % room


func _held_within(path: String, secs: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		if game.room_preloader.is_held(path):
			return true
		await process_frame
	return false


## Герой біля східного краю на підлозі, затиснута D; якщо стіна не пускає — ставимо за край (як measure_performance).
func _walk_east() -> Dictionary:
	var cell: Vector2 = metsys.settings.in_game_cell_size
	var size: Vector2 = metsys.get_current_room_instance().get_size()
	var body: CharacterBody2D = game.player as CharacterBody2D
	var x: float = size.x - 40.0
	await physics_frame
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, 8.0), Vector2(x, cell.y - 8.0), body.collision_mask, [body.get_rid()])
	var hit: Dictionary = body.get_world_2d().direct_space_state.intersect_ray(q)
	var y: float = 0.5 * cell.y if hit.is_empty() else (hit["position"] as Vector2).y - 48.0
	game.place_player(Vector2(x, y))
	await Kit.frames(self, 10)

	var result := {"how": "walked", "black_at_swap": false, "longest_ms": 0.0, "change_ms": 0.0}
	game.room_swapping.connect(func() -> void: result["black_at_swap"] = ScreenFade.is_black(game), CONNECT_ONE_SHOT)
	var changed: Array = [0]
	metsys.room_changed.connect(func(_r: String) -> void: changed[0] = Time.get_ticks_msec(), CONNECT_ONE_SHOT)
	_key(KEY_D, true)
	var t0: int = Time.get_ticks_msec()
	var last: int = Time.get_ticks_usec()
	var done: Array = [false]
	game.room_change_finished.connect(func() -> void: done[0] = true, CONNECT_ONE_SHOT)
	while not done[0] and Time.get_ticks_msec() - t0 < 6000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		if changed[0] > 0:  # лише кадри самої зміни кімнати: від клітинки сусіда до кінця появи
			result["longest_ms"] = maxf(result["longest_ms"], (now - last) / 1000.0)
		last = now
		if changed[0] == 0 and Time.get_ticks_msec() - t0 > 2500 and result["how"] == "walked":
			result["how"] = "nudged across the edge"
			body.global_position.x = size.x + 8.0
	_key(KEY_D, false)
	result["change_ms"] = float(Time.get_ticks_msec() - changed[0]) if changed[0] > 0 else -1.0
	await Kit.frames(self, 10)
	return result


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _done() -> void:
	print("")
	if fails.is_empty():
		print("RESULT: ALL PASS")
	else:
		print("RESULT: %d FAIL" % fails.size())
	quit()
