extends SceneTree

## Самоперевірка performance_plan, slice 1: зміна кімнати не друкує діагностику (19–57 рядків до виправлення,
## 0,6–1,5 мс на рядок у debug). Рахує рядки логу (print, push_warning, push_error) за телепорт і за прохід пішки.
##   godot --headless --path . --script res://SampleProject/UI/verify_quiet_transitions.gd

const Kit := preload("res://SampleProject/UI/input_kit.gd")
const MAPS := "res://SampleProject/Maps/%s.tscn"
const MAX_LINES := 5


class LineCounter extends Logger:
	var mutex := Mutex.new()
	var lines: Array[String] = []

	func _log_message(message: String, _error: bool) -> void:
		mutex.lock()
		lines.append(message.strip_edges().left(90))
		mutex.unlock()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		mutex.lock()
		lines.append("push: " + (rationale if rationale != "" else code).left(84))
		mutex.unlock()


var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

var game: Node
var metsys: Node
var counter := LineCounter.new()


func _initialize() -> void:
	game = await Kit.boot(self)
	metsys = root.get_node("MetSys")
	game.player.set_invulnerable(true)
	ck(DebugLogger.current_level == DebugLogger.LogLevel.WARNING, "Game no longer forces the INFO log level")
	OS.add_logger(counter)

	print("[1] Teleport Canyon → Village")
	var lines: Array[String] = await _count(func() -> void: await game.teleport_to_room(MAPS % "Village", ^"Arrival"))
	ck(game.map.scene_file_path == MAPS % "Village", "in Village")
	ck(lines.size() <= MAX_LINES, "the teleport printed %d lines (≤ %d)%s" % [lines.size(), MAX_LINES, _show(lines)])
	await Kit.drain(self)

	print("[2] Walk back west into Canyon")
	lines = await _count(_walk_west)
	ck(game.map.scene_file_path == MAPS % "Canyon", "in Canyon (%s)" % game.map.scene_file_path.get_file())
	ck(lines.size() <= MAX_LINES, "the walk printed %d lines (≤ %d)%s" % [lines.size(), MAX_LINES, _show(lines)])

	OS.remove_logger(counter)
	_done()


## Рядки логу за час дії [param action] і ще 30 кадрів після неї (init_room, _ready кімнати).
func _count(action: Callable) -> Array[String]:
	counter.mutex.lock()
	counter.lines.clear()
	counter.mutex.unlock()
	await action.call()
	await Kit.frames(self, 30)
	counter.mutex.lock()
	var got: Array[String] = counter.lines.duplicate()
	counter.mutex.unlock()
	return got


func _show(lines: Array[String]) -> String:
	return "" if lines.size() <= MAX_LINES else ": " + " | ".join(lines.slice(0, 8))


## Герой біля західного краю Village на підлозі, затиснута A, до кінця зміни кімнати; стіна не пускає — за край.
func _walk_west() -> void:
	var cell: Vector2 = metsys.settings.in_game_cell_size
	var body: CharacterBody2D = game.player as CharacterBody2D
	await physics_frame
	var q := PhysicsRayQueryParameters2D.create(Vector2(40.0, 8.0), Vector2(40.0, cell.y - 8.0), body.collision_mask, [body.get_rid()])
	var hit: Dictionary = body.get_world_2d().direct_space_state.intersect_ray(q)
	var y: float = 0.5 * cell.y if hit.is_empty() else (hit["position"] as Vector2).y - 48.0
	game.place_player(Vector2(40.0, y))
	await Kit.frames(self, 10)
	var done: Array = [false]
	game.room_change_finished.connect(func() -> void: done[0] = true, CONNECT_ONE_SHOT)
	_key(KEY_A, true)
	var t0: int = Time.get_ticks_msec()
	var nudged := false
	while not done[0] and Time.get_ticks_msec() - t0 < 6000:
		await process_frame
		if not nudged and not game.room_changing and Time.get_ticks_msec() - t0 > 2500:
			nudged = true
			body.global_position.x = -8.0
	_key(KEY_A, false)


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
