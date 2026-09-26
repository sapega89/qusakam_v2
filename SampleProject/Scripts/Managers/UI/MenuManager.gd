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
	print("MenuManager: toggle_game_menu")
	var ui_manager = _get_ui_manager()
	print("MenuManager: ui_manager=%s" % (ui_manager != null))
	if ui_manager and ui_manager.has_method("toggle_game_menu"):
		ui_manager.toggle_game_menu()
		return
	if is_menu_open():
		close_game_menu()
	else:
		open_game_menu()

func open_game_menu():
	print("MenuManager: open_game_menu")
	var ui_manager = _get_ui_manager()
	print("MenuManager: ui_manager=%s" % (ui_manager != null))
	if ui_manager and ui_manager.has_method("open_game_menu"):
		if ui_manager.current_state_name == "GameMenuState":
			return
		save_camera_state()
		save_ui_state()
		hide_ui_elements()
		ui_manager.open_game_menu()
		menu_opened.emit()
		return
	# Fallback to legacy behavior
	pass

func close_game_menu():
	print("MenuManager: close_game_menu")
	var ui_manager = _get_ui_manager()
	print("MenuManager: ui_manager=%s" % (ui_manager != null))
	if ui_manager and ui_manager.has_method("close_game_menu"):
		ui_manager.close_game_menu()
		show_ui_elements()
		_hide_cursor_indicators()
		menu_closed.emit()
		return
	# Fallback to legacy behavior
	pass

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
	var service_locator = ServiceLocatorHelper.get_service_locator()
	if service_locator:
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
	if ServiceLocatorHelper.get_service_locator():
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
	var service_locator = ServiceLocatorHelper.get_service_locator()
	if service_locator:
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
	if ServiceLocatorHelper.get_service_locator():
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

func _hide_cursor_indicators() -> void:
	var indicators = get_tree().get_nodes_in_group("cursor_indicators")
	for node in indicators:
		if node and is_instance_valid(node) and node.has_method("hide_cursor"):
			node.hide_cursor()

func is_menu_open() -> bool:
	var ui_manager = _get_ui_manager()
	if ui_manager:
		return ui_manager.get("current_state_name") == "GameMenuState"
	return game_menu_instance != null and is_instance_valid(game_menu_instance)

func _get_ui_manager() -> Node:
	var ui_manager = null
	var service_locator = _get_service_locator()
	if service_locator and service_locator.has_method("get_ui_manager"):
		ui_manager = service_locator.get_ui_manager()
	print("MenuManager: _get_ui_manager service_locator=%s ui_manager=%s" % [
		service_locator != null,
		ui_manager != null
	])
	return ui_manager

func _get_service_locator() -> Node:
	if typeof(ServiceLocator) != TYPE_NIL:
		return ServiceLocator
	var root = get_tree().root if get_tree() else null
	if root:
		return root.get_node_or_null("ServiceLocator")
	return null
