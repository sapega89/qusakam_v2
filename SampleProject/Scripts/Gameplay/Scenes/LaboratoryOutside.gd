extends Node2D

## 🌳 Laboratory Outside Scene Manager
## States: EXIT_LAB, DEMO_CLOSING
## Follows Robust State-Flow Pattern

enum State {
	EXIT_LAB,
	DEMO_CLOSING
}

enum StepType { DIALOGUE, COMBAT, LOOP, TRANSITION }

@export var current_state: State = State.EXIT_LAB:
	set(val):
		current_state = val
		_on_state_changed(val)

var state_run_id: int = 0
signal state_complete(state: State)

func _ready() -> void:
	if Engine.has_singleton("ServiceLocator"):
		var loc = Engine.get_singleton("ServiceLocator")
		if not loc.is_node_ready():
			await loc.ready
	
	_on_state_changed(current_state)

func _on_state_changed(new_state: State) -> void:
	state_run_id += 1
	var run_id = state_run_id
	DebugLogger.info("🌳 LabOutside: Entering state %s (RunID: %d)" % [State.keys()[new_state], run_id], "Scene")
	
	_apply_state_logic(new_state, run_id)

func _apply_state_logic(state: State, run_id: int) -> void:
	var game = Game.get_singleton()
	match state:
		State.EXIT_LAB:
			# Перевіряємо, чи діалог вже був прочитаний
			if game and game.get_quest_flag("lab_outside_complete", false):
				DebugLogger.info("🌳 LabOutside: ⏭️ Діалог Laboratory_Outside вже був прочитаний, пропускаємо", "Scene")
				_set_objective("Завершити демо")
				return
			_set_objective("Вийти з лабораторії")
			_execute_step(StepType.DIALOGUE, "Laboratory_Outside", run_id)
		State.DEMO_CLOSING:
			# Перевіряємо, чи діалог вже був прочитаний
			if game and game.get_quest_flag("demo_end_complete", false):
				DebugLogger.info("🌳 LabOutside: ⏭️ Діалог Demo_End вже був прочитаний, показуємо екран завершення", "Scene")
				_show_demo_end_screen()
				return
			_set_objective("Завершити демо")
			_execute_step(StepType.DIALOGUE, "Demo_End", run_id)

func _execute_step(type: StepType, dialogue_id: String, run_id: int) -> void:
	match type:
		StepType.DIALOGUE:
			await _play_dialogue(dialogue_id, run_id)
		StepType.COMBAT:
			await _play_dialogue(dialogue_id, run_id)
		StepType.LOOP:
			await get_tree().create_timer(1.0).timeout
		StepType.TRANSITION:
			await get_tree().create_timer(0.5).timeout
	
	if run_id != state_run_id: return
	
	# Після DEMO_CLOSING показуємо екран завершення
	if current_state == State.DEMO_CLOSING:
		_show_demo_end_screen()
	else:
		advance_state()

func _play_dialogue(dialogue_id: String, run_id: int) -> void:
	var dm = _get_dialogue_manager()
	if not dm: 
		await get_tree().create_timer(0.5).timeout
		return

	var path = "res://dialogue_quest/" + dialogue_id + ".dqd"
	var started = await dm.start_dialogue(path)
	if not started:
		DebugLogger.warning("🌳 LabOutside: Не вдалося запустити діалог: %s" % dialogue_id, "Scene")
		return
	
	if Engine.has_singleton("EventBus"):
		while true:
			var finished_id = await EventBus.dialogue_finished
			if finished_id == path or finished_id == dialogue_id:
				DebugLogger.info("🌳 LabOutside: Діалог %s завершено" % dialogue_id, "Scene")
				# Завершуємо квест після діалогу
				_complete_quest_for_dialogue(dialogue_id)
				break
			if run_id != state_run_id: return

func _complete_quest_for_dialogue(dialogue_id: String) -> void:
	"""Встановлює квестові флаги для діалогів"""
	var game = Game.get_singleton()
	if not game: return
	
	match dialogue_id:
		"Laboratory_Outside":
			game.set_quest_flag("lab_outside_complete", true)
		"Demo_End":
			game.set_quest_flag("demo_end_complete", true)

func advance_state() -> void:
	state_complete.emit(current_state)
	if current_state < State.DEMO_CLOSING:
		current_state = (current_state + 1) as State
	else:
		_show_demo_end_screen()

func _show_demo_end_screen() -> void:
	"""Показує екран завершення демо"""
	DebugLogger.info("🌳 LabOutside: Показуємо екран завершення демо", "Scene")
	
	# Оновлюємо GameFlow
	if Engine.has_singleton("ServiceLocator"):
		var flow = Engine.get_singleton("ServiceLocator").get_game_flow()
		if flow:
			flow.advance_story() # StoryState.DEMO_END
	
	# Завантажуємо екран завершення
	var demo_end_scene_path = "res://SampleProject/Scenes/UI/DemoEndScreen.tscn"
	
	# Спробуємо завантажити файл (load() поверне null, якщо файл не існує)
	var demo_end_scene = load(demo_end_scene_path)
	if not demo_end_scene:
		DebugLogger.warning("🌳 LabOutside: DemoEndScreen.tscn не знайдено або не вдалося завантажити за шляхом: %s" % demo_end_scene_path, "Scene")
		DebugLogger.warning("🌳 LabOutside: Переходимо до головного меню без екрану завершення", "Scene")
		_transition_to_main_menu()
		return
	
	if not demo_end_scene is PackedScene:
		DebugLogger.error("🌳 LabOutside: Завантажений ресурс не є PackedScene (тип: %s)" % typeof(demo_end_scene), "Scene")
		_transition_to_main_menu()
		return
	
	var demo_end = demo_end_scene.instantiate()
	if not demo_end:
		DebugLogger.error("🌳 LabOutside: Не вдалося створити екземпляр DemoEndScreen", "Scene")
		_transition_to_main_menu()
		return
	
	# Додаємо до UI слою
	var ui_canvas = get_tree().current_scene.get_node_or_null("UICanvas")
	if not ui_canvas:
		ui_canvas = CanvasLayer.new()
		ui_canvas.name = "UICanvas"
		get_tree().current_scene.add_child(ui_canvas)
	
	ui_canvas.add_child(demo_end)
	demo_end.z_index = 1000  # Найвищий z_index
	
	# Підключаємо сигнал повернення до меню
	if demo_end.has_signal("return_to_menu"):
		demo_end.return_to_menu.connect(_on_return_to_menu)
	
	DebugLogger.info("🌳 LabOutside: Екран завершення показано", "Scene")

func _on_return_to_menu() -> void:
	"""Обробник повернення до головного меню"""
	_transition_to_main_menu()

func _transition_to_main_menu() -> void:
	"""Перехід до головного меню"""
	var main_menu_path = "res://SampleProject/MainMenu.tscn"
	get_tree().change_scene_to_file(main_menu_path)
	DebugLogger.info("🌳 LabOutside: Перехід до головного меню виконано", "Scene")

func _set_objective(text: String) -> void:
	"""Встановлює об'єктив для гравця"""
	var game = Game.get_singleton()
	if game and game.has_method("set_objective"):
		game.set_objective(text)

func _get_dialogue_manager() -> Node:
	if Engine.has_singleton("ServiceLocator"):
		return Engine.get_singleton("ServiceLocator").get_dialogue_manager()
	return null
