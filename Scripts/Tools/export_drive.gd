extends Node

## Прогін зібраної гри (B145): експортований шаблон не виконує --script, тож сценарій іде автолоадом, який
## додає override.cfg поруч із бінарником (Scripts/Tools/export_drive.sh). Без override.cfg цей файл гра не вантажить.
## Сценарій — після «++» у командному рядку: cutscene | fall | walk | mash (кат-сцена, а гравець тисне все підряд). Кожен крок друкує «DRIVE t=… …», кінець —
## «DRIVE: DONE»; падіння процесу видно з того, що DONE немає, а останній рядок DRIVE каже, де саме.

const GAME_PATH := "res://SampleProject/Game.tscn"
const CANYON := "res://SampleProject/Maps/Canyon.tscn"
const VILLAGE := "res://SampleProject/Maps/Village.tscn"
const DESERT_ROAD := "res://SampleProject/Maps/DesertRoad.tscn"
## Прапорці «повернувся з села»: Canyon чекає в RELIC_PICKUP, край біля містка запускає спуск (D256).
const AFTER_VILLAGE := {"canyon_intro_complete": true, "canyon_exploration_complete": true,
		"canyon_abduction_complete": true, "village_abduction_complete": true, "village_arrival_complete": true,
		"village_fight_complete": true, "village_left_complete": true}
## Скільки секунд гра живе в кімнаті, куди герой спустився.
const RUN_BELOW := 20.0

var _t0: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	var scenario: String = args[0] if not args.is_empty() else "cutscene"
	_run.call_deferred(scenario)


func _log(text: String) -> void:
	print("DRIVE t=%.1f %s" % [(Time.get_ticks_msec() - _t0) / 1000.0, text])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _until(cond: Callable, max_s: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(max_s * 1000)
	while not cond.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await get_tree().process_frame
	return true


## Кат-сцена йде сама; діалоги в ній гортаємо одразу, доки гра не опиниться в кімнаті [param path].
func _drain_until_room(game: Game, path: String, max_s: float) -> bool:
	var dm: Node = ServiceLocator.get_dialogue_manager()
	return await _until(func() -> bool:
		if dm.is_dialogue_active():
			dm.current_dialogue_box.finish()  # D254: не чекаємо набору репліки
			dm.current_dialogue_player.accept()
		return game.map.scene_file_path == path, max_s)


func _drain_dialogue() -> void:
	var dm: Node = ServiceLocator.get_dialogue_manager()
	for i in 600:
		if dm.is_dialogue_active():
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		await get_tree().process_frame


func _run(scenario: String) -> void:
	_log("scenario %s" % scenario)
	SaveSystem.settings_module.settings.tutorial_windows = false
	await _frames(30)
	# Як кнопка «Нова гра» в MainMenu: прапорець, SceneLoader.
	get_tree().set_meta("start_new_game", true)
	SceneLoader.load_scene(GAME_PATH)
	var started := await _until(func() -> bool: return get_tree().current_scene is Game and (get_tree().current_scene as Game).map != null, 60.0)
	_log("game up %s" % started)
	var game: Game = Game.get_singleton()
	await _drain_dialogue()  # вступ Canyon
	var flags: Dictionary = game.get_quest_flags().duplicate()
	flags.merge(AFTER_VILLAGE, true)
	game.set_quest_flags(flags)
	match scenario:
		"cutscene":
			await _cutscene(game)
		"fall":
			await _fall(game)
		"walk":
			await _walk(game)
		"mash":
			await _cutscene_by_keys(game)
	_log("below in %s" % game.map.scene_file_path)
	await _live_below(game)
	_log("DONE")
	print("DRIVE: DONE")
	get_tree().quit()


## Спуск кат-сценою: герой іде до краю біля містка (CanyonExitTrigger) → Canyon_ExitCutscene → DesertRoad.
func _cutscene(game: Game) -> void:
	await game.teleport_to_room(CANYON, ^"Arrival")
	await _frames(30)
	_log("canyon state %s" % game.map.get_current_state_name())
	game.player.global_position = Vector2(1000, 370)
	await _frames(30)
	Input.action_press(&"move_left")
	var hit := await _until(func() -> bool: return game.player.event, 8.0)
	Input.action_release(&"move_left")
	_log("edge reached %s, state %s" % [hit, game.map.get_current_state_name()])
	var arrived := await _drain_until_room(game, DESERT_ROAD, 60.0)
	_log("arrived %s" % arrived)


## Клавіші, які гравець тисне під час спуску: бій, ухил, навички, пропуск кат-сцени, «далі» в діалозі, меню.
const MASH_ACTIONS: Array[StringName] = [&"attack", &"heavy_attack", &"jump", &"dodge", &"block", &"assist",
		&"skill_slot_1", &"skill_slot_2", &"quick_potion", &"interact", &"cutscene_skip", &"dq_accept", &"ui_accept",
		&"game_menu", &"move_right", &"move_left"]
var _mash_tick: int = 0
var _mash_held: StringName = &""


## Кожні 7 кадрів — інша клавіша: натиснути, через 3 кадри відпустити (game_menu — ще раз, щоб закрити).
func _mash() -> void:
	_mash_tick += 1
	if _mash_tick % 7 == 0:
		_mash_held = MASH_ACTIONS[(_mash_tick / 7) % MASH_ACTIONS.size()]
		_key(_mash_held, true)
	elif _mash_tick % 7 == 3 and _mash_held != &"":
		_key(_mash_held, false)
		if _mash_held == &"game_menu":
			_key(&"game_menu", true)
			_key(&"game_menu", false)


## Як справжня клавіша: InputEventAction іде в _input/_unhandled_input, а не лише в Input.is_action_pressed.
func _key(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


## Кат-сцена спуску без програмного гортання діалогів: лише клавіші з _mash.
func _cutscene_by_keys(game: Game) -> void:
	await game.teleport_to_room(CANYON, ^"Arrival")
	await _frames(30)
	game.player.global_position = Vector2(1000, 370)
	await _frames(30)
	Input.action_press(&"move_left")
	var hit := await _until(func() -> bool: return game.player.event, 8.0)
	Input.action_release(&"move_left")
	_log("edge reached %s, state %s" % [hit, game.map.get_current_state_name()])
	get_tree().process_frame.connect(_mash)
	var arrived := await _until(func() -> bool: return game.map.scene_file_path == DESERT_ROAD, 90.0)
	_log("arrived %s" % arrived)


## Спуск без кат-сцени: прохід MetSys униз із нижньої лівої клітинки Canyon (0,2) у DesertRoad (0,3).
func _fall(game: Game) -> void:
	await game.teleport_to_room(CANYON, ^"Arrival")
	await _frames(30)
	game.player.global_position = Vector2(430, 900)
	var arrived := await _until(func() -> bool: return game.map.scene_file_path == DESERT_ROAD, 10.0)
	_log("fell through %s" % arrived)


## Справжній шлях гри: із села пішки в Canyon (прохід MetSys), далі до краю — і кат-сцена.
func _walk(game: Game) -> void:
	await game.teleport_to_room(VILLAGE, ^"Arrival")
	await _frames(30)
	Input.action_press(&"move_left")
	var in_canyon := await _until(func() -> bool: return game.map.scene_file_path == CANYON, 20.0)
	# Затиснута клавіша не переживає зміну кімнати (пауза під чорним) — натискаємо знову, як гравець.
	Input.action_release(&"move_left")
	await _frames(90)
	_log("walked into canyon %s, state %s" % [in_canyon, game.map.get_current_state_name() if in_canyon else "-"])
	Input.action_press(&"move_left")
	var hit := await _until(func() -> bool:
		# Тераси скелі (PrideRock) — стрибками, як гравець.
		if Engine.get_process_frames() % 30 == 0:
			Input.action_press(&"jump")
		if Engine.get_process_frames() % 30 == 12:
			Input.action_release(&"jump")
		if Engine.get_process_frames() % 60 == 0:
			_log("walking: hero %s vel %s on floor %s" % [game.player.global_position.round(), game.player.velocity.round(), game.player.is_on_floor()])
		return game.player.event, 40.0)
	Input.action_release(&"move_left")
	_log("edge reached %s" % hit)
	var arrived := await _drain_until_room(game, DESERT_ROAD, 60.0)
	_log("arrived %s" % arrived)


## Кімната внизу живе RUN_BELOW секунд: герой іде праворуч (спавнери, вороги, торговець), стрибає й б'є.
func _live_below(game: Game) -> void:
	var end := Time.get_ticks_msec() + int(RUN_BELOW * 1000)
	var room := game.map.scene_file_path
	Input.action_press(&"move_right")
	var tick := 0
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
		tick += 1
		if tick % 40 == 0:
			Input.action_press(&"jump")
		if tick % 40 == 5:
			Input.action_release(&"jump")
		if tick % 120 == 0:
			_log("below: room %s hero %s hp %d" % [game.map.scene_file_path.get_file(), game.player.global_position.round(), game.player.current_health])
		if game.map.scene_file_path != room:
			room = game.map.scene_file_path
			_log("room changed to %s" % room)
	Input.action_release(&"move_right")

