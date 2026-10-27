extends "res://SampleProject/Scripts/Gameplay/Scenes/RoomStoryFlow.gd"

## 🌳 Laboratory Outside Scene Manager
## States: EXIT_LAB, DEMO_CLOSING
## Машина станів — RoomStoryFlow.

enum State {
	EXIT_LAB,
	DEMO_CLOSING
}

func _dialogue_flags() -> Dictionary:
	return {"Demo_End": "demo_end_complete"}

func _apply_state_logic(state: int, run_id: int) -> void:
	var game = Game.get_singleton()
	match state:
		State.EXIT_LAB:
			# Перевіряємо, чи діалог вже був прочитаний
			# B66: гілка «вже прочитано» мусить вести далі (як у Village): голий return лишав машину в EXIT_LAB,
			# і після повернення в лабораторію та нового виходу кінця демо не було ніколи.
			# D437: розмови Laboratory_Outside (лише слова автора) більше немає — вихід із лабораторії і є цей біт.
			if not game.get_quest_flag("lab_outside_complete", false):
				game.set_quest_flag("lab_outside_complete", true)
			advance_state()
		State.DEMO_CLOSING:
			# Перевіряємо, чи діалог вже був прочитаний
			if game.get_quest_flag("demo_end_complete", false):
				DebugLogger.info("🌳 LabOutside: ⏭️ Діалог Demo_End вже був прочитаний, показуємо екран завершення", "Scene")
				_show_demo_end_screen()
				return
			_set_objective("Finish the demo")
			_dialogue_then_advance("Demo_End", run_id)

## Після DEMO_CLOSING — екран завершення.
func _on_story_end() -> void:
	_show_demo_end_screen()

func _show_demo_end_screen() -> void:
	"""Показує екран завершення демо"""
	DebugLogger.info("🌳 LabOutside: Показуємо екран завершення демо", "Scene")

	# Оновлюємо GameFlow
	# Engine.get_singleton() автозавантажень у Godot 4 не бачить — виклик не спрацьовував ніколи (B43).
	var flow = ServiceLocatorHelper.get_manager("get_game_flow")
	if flow:
		flow.sync_story_state()  # усі підетапи пройдено → StoryState.DEMO_END

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
	demo_end.return_to_menu.connect(_on_return_to_menu)
	demo_end.play_finale($Music, $HighSky.global_position.y)  # D473: HUD гасне, камера в небо, титул

	DebugLogger.info("🌳 LabOutside: Екран завершення показано", "Scene")

func _on_return_to_menu() -> void:
	"""Обробник повернення до головного меню"""
	_transition_to_main_menu()

func _transition_to_main_menu() -> void:
	"""Перехід до головного меню"""
	var main_menu_path = "res://SampleProject/MainMenu.tscn"
	get_tree().change_scene_to_file(main_menu_path)
	DebugLogger.info("🌳 LabOutside: Перехід до головного меню виконано", "Scene")
