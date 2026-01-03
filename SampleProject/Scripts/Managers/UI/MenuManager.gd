extends ManagerBase
class_name MenuManager

## 📋 MenuManager - Управление игровым меню
## Отвечает только за управление игровым меню
## Согласно SRP: одна ответственность - управление меню

# Load game menu scene for use in CanvasLayer
var game_menu_scene = preload("res://SampleProject/Scenes/Menus/Game/game_menu.tscn")
var game_menu_instance = null

# Camera and UI state (saved when opening menu)
var camera_state = {
	"position": {"x": 0, "y": 0},
	"zoom": {"x": 1.0, "y": 1.0}
}
var ui_state = {
	"hp_bar_visible": true,
	"potion_ui_visible": true,
	"skill_points_visible": true
}

# Сигналы
signal menu_opened()
signal menu_closed()

func _initialize():
	"""Инициализация MenuManager"""
	pass  # No initialization needed

func toggle_game_menu():
	"""Переключает состояние игрового меню"""
	# Защита от рекурсии: проверяем, не обрабатываем ли мы уже это событие
	if has_meta("_processing_toggle"):
		push_warning("⚠️ MenuManager: toggle_game_menu() уже обрабатывается, пропускаем для предотвращения рекурсии")
		return
	
	set_meta("_processing_toggle", true)
	
	if game_menu_instance == null or not is_instance_valid(game_menu_instance):
		open_game_menu()
	else:
		close_game_menu()
	
	# Снимаем флаг после обработки
	remove_meta("_processing_toggle")

func open_game_menu():
	"""Открывает игровое меню"""
	# Защита от рекурсии: проверяем, не обрабатываем ли мы уже открытие
	if has_meta("_processing_open"):
		push_warning("⚠️ MenuManager: open_game_menu() уже обрабатывается, пропускаем для предотвращения рекурсии")
		return
	
	set_meta("_processing_open", true)
	
	if game_menu_instance != null and is_instance_valid(game_menu_instance):
		print("🎮 MenuManager: Menu already open")
		remove_meta("_processing_open")
		return
	
	# Сохраняем состояние камеры и UI
	save_camera_state()
	save_ui_state()
	
	# Проверяем, что сцена загружена
	if not game_menu_scene:
		push_error("❌ MenuManager: game_menu_scene is null! Cannot instantiate game menu.")
		return
	
	# Создаем CanvasLayer для меню
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 12  # Выше карты (layer = 11) и UICanvas (layer = 10)
	canvas_layer.name = "MenuCanvasLayer"
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS  # Не призупиняється
	
	# Создаем экземпляр меню
	game_menu_instance = game_menu_scene.instantiate()
	if not game_menu_instance:
		push_error("❌ MenuManager: Failed to instantiate game menu scene!")
		canvas_layer.queue_free()
		return
	game_menu_instance.name = "GameMenuInstance"
	
	# Добавляем к текущей сцене (не к root)
	get_tree().current_scene.add_child(canvas_layer)
	canvas_layer.add_child(game_menu_instance)
	
	# Ставим игру на паузу
	get_tree().paused = true
	
	# НЕ скрываем игровую сцену здесь - она будет скрыта только при открытии карты
	# Игровая сцена скрывается в game_menu.gd при открытии карты
	
	# Скрываем UI элементы
	hide_ui_elements()
	
	menu_opened.emit()
	print("🎮 MenuManager: Game menu opened")
	
	# Снимаем флаг после обработки
	remove_meta("_processing_open")

func close_game_menu():
	"""Закрывает игровое меню"""
	# Защита от рекурсии: проверяем, не обрабатываем ли мы уже закрытие
	if has_meta("_processing_close"):
		push_warning("⚠️ MenuManager: close_game_menu() уже обрабатывается, пропускаем для предотвращения рекурсии")
		return
	
	set_meta("_processing_close", true)
	
	if game_menu_instance == null or not is_instance_valid(game_menu_instance):
		print("🎮 MenuManager: Menu already closed")
		remove_meta("_processing_close")
		return
	
	# Сохраняем ссылку на canvas_layer перед удалением
	var canvas_layer = game_menu_instance.get_parent()
	
	# Очищаем ссылку на game_menu_instance ДО удаления, чтобы избежать рекурсии
	# если game_menu_instance вызывает close_game_menu() при уничтожении
	game_menu_instance = null
	
	# Удаляем меню
	if canvas_layer and is_instance_valid(canvas_layer):
		canvas_layer.queue_free()
	
	# Снимаем паузу
	get_tree().paused = false
	
	# Показываем игровую сцену обратно (если она была скрыта)
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.visible = true
		current_scene.show()
		print("🎮 MenuManager: Game scene shown")
	
	# Показываем UI элементы обратно
	show_ui_elements()
	
	# Приховуємо курсор (CursorIndicator), якщо він є
	_hide_cursor_indicators()
	
	# Эмитим сигнал ПОСЛЕ всех операций, чтобы избежать рекурсии
	menu_closed.emit()
	print("🎮 MenuManager: Game menu closed")
	
	# Снимаем флаг после обработки
	remove_meta("_processing_close")

func save_camera_state():
	"""Сохраняет состояние камеры"""
	var player = GameGroups.get_first_node_in_group(GameGroups.PLAYER)
	if player:
		var camera = player.get_node_or_null("Camera2D")
		if camera:
			camera_state.position = camera.global_position
			camera_state.zoom = camera.zoom

func save_ui_state():
	"""Сохраняет состояние UI"""
	# Сохраняем видимость UI элементов
	var hp_bar = GameGroups.get_first_node_in_group(GameGroups.HEALTH_BAR)
	if hp_bar:
		ui_state.hp_bar_visible = hp_bar.visible
	
	var potion_ui = GameGroups.get_first_node_in_group(GameGroups.POTION_UI)
	if potion_ui:
		ui_state.potion_ui_visible = potion_ui.visible
	
	var skill_points_ui = GameGroups.get_first_node_in_group(GameGroups.SKILL_POINTS_UI)
	if skill_points_ui:
		ui_state.skill_points_visible = skill_points_ui.visible

func hide_ui_elements():
	"""Скрывает UI элементы"""
	# Використовуємо UIManager для отримання UI елементів, щоб уникнути рекурсії
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		var ui_manager = service_locator.get_ui_manager() if service_locator and service_locator.has_method("get_ui_manager") else null
		if ui_manager:
			var ui_canvas = ui_manager.get_ui_canvas()
			if ui_canvas:
				ui_canvas.visible = false
				print("🎮 MenuManager: Hidden UICanvas (skill panel)")
		else:
			# Fallback - шукаємо напряму, але тільки один раз
			var ui_canvas = GameGroups.get_first_node_in_group(GameGroups.UI_CANVAS)
			if not ui_canvas:
				var current_scene = get_tree().current_scene
				if current_scene:
					ui_canvas = current_scene.get_node_or_null("UICanvas")
			
			if ui_canvas:
				ui_canvas.visible = false
				print("🎮 MenuManager: Hidden UICanvas (skill panel)")
	
	# Використовуємо UIManager для отримання UI елементів
	if Engine.has_singleton("ServiceLocator"):
		var ui_manager = ServiceLocator.get_ui_manager()
		if ui_manager:
			var health_bar = ui_manager.get_health_bar()
			if health_bar:
				health_bar.visible = false
			
			var potion_ui = ui_manager.get_potion_ui()
			if potion_ui:
				potion_ui.visible = false
		else:
			# Fallback - шукаємо напряму, але тільки один раз для кожної групи
			var groups_to_hide = [GameGroups.HEALTH_BAR, GameGroups.SKILL_POINTS_UI, GameGroups.POTION_UI]
			for group_name in groups_to_hide:
				var elements = GameGroups.get_nodes_in_group(group_name)
				for element in elements:
					if element and is_instance_valid(element):
						element.visible = false
						print("🎮 MenuManager: Hidden UI element from group '", group_name, "': ", element.name)

func show_ui_elements():
	"""Показывает UI элементы"""
	# Використовуємо UIManager для отримання UI елементів, щоб уникнути рекурсії
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		var ui_manager = service_locator.get_ui_manager() if service_locator and service_locator.has_method("get_ui_manager") else null
		if ui_manager:
			var ui_canvas = ui_manager.get_ui_canvas()
			if ui_canvas:
				ui_canvas.visible = true
				print("🎮 MenuManager: Shown UICanvas (skill panel)")
		else:
			# Fallback - шукаємо напряму, але тільки один раз
			var ui_canvas = GameGroups.get_first_node_in_group(GameGroups.UI_CANVAS)
			if not ui_canvas:
				var current_scene = get_tree().current_scene
				if current_scene:
					ui_canvas = current_scene.get_node_or_null("UICanvas")
			
			if ui_canvas:
				ui_canvas.visible = true
				print("🎮 MenuManager: Shown UICanvas (skill panel)")
	
	# Використовуємо UIManager для отримання UI елементів
	if Engine.has_singleton("ServiceLocator"):
		var ui_manager = ServiceLocator.get_ui_manager()
		if ui_manager:
			var health_bar = ui_manager.get_health_bar()
			if health_bar:
				health_bar.visible = true
			
			var potion_ui = ui_manager.get_potion_ui()
			if potion_ui:
				potion_ui.visible = true
		else:
			# Fallback - шукаємо напряму, але тільки один раз для кожної групи
			var groups_to_show = [GameGroups.HEALTH_BAR, GameGroups.SKILL_POINTS_UI, GameGroups.POTION_UI]
			for group_name in groups_to_show:
				var elements = GameGroups.get_nodes_in_group(group_name)
				for element in elements:
					if element and is_instance_valid(element):
						element.visible = true
						print("🎮 MenuManager: Shown UI element from group '", group_name, "': ", element.name)

func is_menu_open() -> bool:
	"""Проверяет, открыто ли меню"""
	return game_menu_instance != null and is_instance_valid(game_menu_instance)

func _hide_cursor_indicators() -> void:
	"""Приховує всі CursorIndicator при закритті меню"""
	# Шукаємо всі CursorIndicator в сцені
	var cursor_indicators = []
	
	# Шукаємо в поточній сцені
	var current_scene = get_tree().current_scene
	if current_scene:
		cursor_indicators = current_scene.find_children("*", "CursorIndicator", true, false)
	
	# Також шукаємо в CursorLayer, якщо він існує
	var cursor_layer = get_tree().root.get_node_or_null("CursorLayer")
	if not cursor_layer:
		cursor_layer = get_tree().get_first_node_in_group("cursor_layer")
	
	if cursor_layer:
		for child in cursor_layer.get_children():
			if child is CursorIndicator:
				cursor_indicators.append(child)
	
	# Приховуємо всі знайдені курсори
	for cursor in cursor_indicators:
		if cursor and is_instance_valid(cursor):
			if cursor.has_method("hide_cursor"):
				cursor.hide_cursor()
			else:
				cursor.visible = false
			print("🎮 MenuManager: Приховано CursorIndicator: ", cursor.name)
