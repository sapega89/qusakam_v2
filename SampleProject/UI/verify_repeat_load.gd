extends SceneTree

## B195: «після третього завантаження гри або під час нього гра зависає» (Sapega, 2026-10-27).
## Один сейв, потім п'ять завантажень поспіль справжнім шляхом гравця: меню слотів (як Continue і Load на
## екрані смерті) → клік по слоту → згасання → SceneLoader → кімната сейву світлішає. Між завантаженнями —
## назад у меню слотів зі сцени гри (game_over_screen._leave). Кожне завантаження має дійти до світла за
## LOAD_FRAMES кадрів фізики (B186: кадри, не годинник), а вузли, сироти й підписки на EventBus — не рости.
## Потім те саме з екрана смерті (Resume from last save point), коли ворог поруч саме замахується: клік приходить
## до кроку фізики (як у вікні — події ОС обробляються на початку кадру), стара сцена вже поза деревом, а
## EnemyLogic.wind_up() крутив `await get_tree().physics_frame` → get_tree() == null → await не чекав нічого, і
## цикл по таймеру, що вже не тікав, вішав головний потік (B195) — так у релізній збірці гравця. У
## налагоджувальній (тут) доступ до null — SCRIPT ERROR, що обриває корутину, тож тест ловить помилки ворога поза
## деревом (ErrorTap); справжнє зависання ловить сторожовий потік.
## Пише лише в user://verify_repeat_load/.
##   godot --headless --path . --script res://SampleProject/UI/verify_repeat_load.gd

const Kit := preload("res://SampleProject/UI/input_kit.gd")
const TEST_DIR := "user://verify_repeat_load/"
const TEST_SLOT := 1
const LOADS := 5
const LOAD_FRAMES := 900
## Скільки секунд без жодного кадру — це вже зависання (сторожовий потік: годинник тут єдиний свідок, кадри стоять).
const FROZEN_SEC := 15
const GAME_PATH := "res://SampleProject/Game.tscn"
const LOAD_MENU := "res://SampleProject/Scenes/Menus/LoadGameMenu.tscn"

var fails: Array[String] = []
var _physics_frames: int = 0
var _watchdog := Thread.new()
var _done: bool = false
var _tap := ErrorTap.new()

## Рахує помилки, кинуті з EnemyLogic: корутина ворога старої сцени, що питає get_tree() поза деревом.
class ErrorTap extends Logger:
	var count: int = 0
	func _log_error(_function: String, file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, _error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var from_enemy := file.ends_with("EnemyLogic.gd")
		for bt: ScriptBacktrace in script_backtraces:
			for i in bt.get_frame_count():
				from_enemy = from_enemy or bt.get_frame_file(i).ends_with("EnemyLogic.gd")
		if from_enemy:
			count += 1

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _event_bus_connections() -> int:
	var bus: Node = root.get_node("EventBus")
	var n := 0
	for s: Dictionary in bus.get_signal_list():
		n += bus.get_signal_connection_list(s.name).size()
	return n

## Кадри фізики до світла в кімнаті сейву, або -1, якщо не дійшло за LOAD_FRAMES.
func _load_from_menu() -> int:
	change_scene_to_file(LOAD_MENU)
	for i in 10: await process_frame
	var menu: Node = current_scene
	var entered: Array = [false]
	root.get_node("EventBus").room_entered.connect(func(_r: String) -> void: entered[0] = true, CONNECT_ONE_SHOT)
	var start := _physics_frames
	await Kit.mouse(self, menu._cards[TEST_SLOT - 1].card)
	while _physics_frames - start < LOAD_FRAMES:
		await process_frame
		var in_game: bool = current_scene != null and current_scene.scene_file_path == GAME_PATH
		if in_game and entered[0] and not ScreenFade.is_on(root):
			return _physics_frames - start
	return -1

## Кадри фізики не рухаються FROZEN_SEC с — головний потік завис: звіт і вихід, щоб тест не висів сам.
func _watch() -> void:
	var seen := -1
	var still := 0
	while not _done:
		OS.delay_msec(1000)
		still = still + 1 if _physics_frames == seen else 0
		seen = _physics_frames
		if still >= FROZEN_SEC:
			print("  FAIL the main thread froze: no physics frame for %d s (B195)" % FROZEN_SEC)
			print("RESULT: %d FAIL: the game froze (B195)" % (fails.size() + 1))
			OS.kill(OS.get_process_id())
			return

## Ворог поруч з героєм замахується, герой гине, Game Over → клік по Resume. Кадри фізики до світла в кімнаті
## сейву, або -1.
func _load_from_game_over(game: Node) -> int:
	var point := EnemySpawnPoint.new()
	point.spawn_on_load = false
	game.map.add_child(point)
	point.global_position = game.player.global_position + Vector2(60, 0)
	var enemy: Node2D = point.spawn_enemy()
	for i in 10: await physics_frame
	enemy.enemy_logic.wind_up(30.0)  # довгий замах: цикл стеження по таймеру крутиться
	for i in 3: await physics_frame
	ck(enemy.enemy_logic.winding_up, "the enemy is winding up when the hero dies")
	GameOverScreen.present(game.player)
	for i in 10: await process_frame
	var resume: Button = get_first_node_in_group(&"game_over_screen").get_node(^"%ResumeButton")
	var entered: Array = [false]
	root.get_node("EventBus").room_entered.connect(func(_r: String) -> void: entered[0] = true, CONNECT_ONE_SHOT)
	var start := _physics_frames
	# Клік через Input, як від ОС: черга подій спорожнюється на початку кадру, до кроку фізики.
	var pos: Vector2 = resume.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		Input.parse_input_event(ev)
	while _physics_frames - start < LOAD_FRAMES:
		await process_frame
		var in_game: bool = current_scene != null and current_scene.scene_file_path == GAME_PATH \
				and current_scene != game
		if in_game and entered[0] and not ScreenFade.is_on(root):
			return _physics_frames - start
	return -1

func _initialize() -> void:
	physics_frame.connect(func() -> void: _physics_frames += 1)
	_watchdog.start(_watch)
	OS.add_logger(_tap)
	await process_frame
	await process_frame
	root.size = Vector2i(1920, 1080)  # headless-вікно 64×64: картка поза ним не ловить мишу
	var save_system: Node = root.get_node("SaveSystem")
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(TEST_SLOT)

	print("[1] New game, save in the first room")
	var game: Node = await Kit.boot(self)
	ck(game.save_game(), "save_game() wrote slot %d" % TEST_SLOT)
	while game.room_preloader.busy():
		await process_frame
	game.queue_free()
	current_scene = null
	for i in 4: await process_frame

	print("[2] Load the save %d times in a row" % LOADS)
	var first: Dictionary = {}
	for n in LOADS:
		var frames: int = await _load_from_menu()
		var stats := {
			"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
			"bus": _event_bus_connections(),
		}
		print("  load %d: %d physics frames, %s" % [n + 1, frames, stats])
		ck(frames >= 0, "load %d reaches the lit saved room within %d physics frames" % [n + 1, LOAD_FRAMES])
		if frames < 0:
			break
		if n == 0:
			first = stats
		elif n == LOADS - 1:
			ck(stats.nodes <= first.nodes, "node count does not grow (%d → %d)" % [first.nodes, stats.nodes])
			ck(stats.orphans <= first.orphans, "orphans do not pile up (%d → %d)" % [first.orphans, stats.orphans])
			ck(stats.bus <= first.bus, "EventBus connections do not pile up (%d → %d)" % [first.bus, stats.bus])

	print("[3] Die next to an enemy mid-swing and Resume from the last save, %d times" % LOADS)
	for n in LOADS:
		var errors_before: int = _tap.count
		var frames: int = await _load_from_game_over(current_scene)
		print("  game over load %d: %d physics frames" % [n + 1, frames])
		ck(frames >= 0, "game over load %d reaches the lit saved room within %d physics frames" % [n + 1, LOAD_FRAMES])
		ck(_tap.count == errors_before, "game over load %d: the swinging enemy's coroutine stops with its scene (%d errors from EnemyLogic)"
				% [n + 1, _tap.count - errors_before])
		if frames < 0:
			break

	_done = true
	_watchdog.wait_to_finish()
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
