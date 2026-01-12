extends ManagerBase
class_name UIManager

const UI_ROOT_SCENE = preload("res://SampleProject/Scenes/UI/ui_root.tscn")
const STATE_SCENES = {
	"MainMenuState": "res://SampleProject/Scenes/UI/States/main_menu_state.tscn",
	"GameMenuState": "res://SampleProject/Scenes/UI/States/game_menu_state.tscn",
	"OptionsState": "res://SampleProject/Scenes/UI/States/options_state.tscn",
	"LoadGameState": "res://SampleProject/Scenes/UI/States/load_game_state.tscn",
	"SaveGameState": "res://SampleProject/Scenes/UI/States/save_game_state.tscn",
	"ModalState": "res://SampleProject/Scenes/UI/States/modal_state.tscn",
	"NullState": "res://SampleProject/Scenes/UI/States/null_state.tscn"
}

## 🎨 UIManager - Централізований доступ до UI елементів
## Замінює прямі виклики get_tree().get_first_node_in_group()
## Дотримується принципу Single Responsibility

# Кешовані посилання на UI елементи
var _ui_elements_cache: Dictionary[String, Node] = {}

var ui_root: Node = null
var state_machine: Node = null
var state_root: Control = null
var modal_layer: Node = null
var current_state: Node = null
var current_state_name: String = ""
var allow_pause_during_dialogue: bool = true
var _localization_connected: bool = false

# Сигнали для оновлення UI
signal ui_element_found(element_name: String, element: Node)
signal ui_element_not_found(element_name: String)
signal ui_refresh_requested()

func _initialize():
	_ensure_ui_root()
	_try_connect_localization()
	"""Ініціалізація UIManager"""
	print("🎨 UIManager: Initialized")
	# Очищаємо кеш при зміні сцени
	# Підписуємося на події зміни сцени через EventBus (Godot 4 не має current_scene_changed)
	if Engine.has_singleton("EventBus"):
		EventBus.scene_loaded.connect(_on_scene_changed)
		EventBus.scene_transition_completed.connect(_on_scene_changed)
		print("🎨 UIManager: Connected to EventBus signals")
		# НЕ використовуємо tree_changed, щоб уникнути рекурсії при русі

func _on_scene_changed(scene_name: String = ""):
	"""Очищає кеш при зміні сцени"""
	_ui_elements_cache.clear()
	print("🎨 UIManager: Scene changed: ", scene_name, ", cache cleared")
	_try_connect_localization()
func _try_connect_localization() -> void:
	if _localization_connected:
		return
	var localization_manager = null
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_localization_manager"):
			localization_manager = service_locator.get_localization_manager()
		if service_locator and service_locator.has_signal("services_ready") and not service_locator.services_ready.is_connected(_try_connect_localization):
			service_locator.services_ready.connect(_try_connect_localization, CONNECT_ONE_SHOT)
	if localization_manager and localization_manager.has_signal("language_changed"):
		if not localization_manager.language_changed.is_connected(_on_language_changed):
			localization_manager.language_changed.connect(_on_language_changed)
		_localization_connected = true


var _last_scene: Node = null
var _check_timer: float = 0.0
var _check_interval: float = 0.5  # Перевіряємо зміну сцени кожні 0.5 секунди

func get_potion_ui() -> Control:
	"""Отримує UI елемент для зілля"""
	return _get_ui_element("potion_ui", "potion")

func get_health_bar() -> Control:
	"""Отримує панель здоров'я"""
	return _get_ui_element("health_bar", "HpBar")

func get_gold_display() -> Control:
	"""Отримує відображення золота"""
	return _get_ui_element("gold_display", "GoldDisplay")

func get_ui_canvas() -> CanvasLayer:
	"""Отримує UICanvas"""
	return _get_ui_element("ui_canvas", "UICanvas")

func get_dialogue_system() -> Node:
	"""Отримує систему діалогів"""
	return _get_ui_element("dialogue_system", "DialogueSystem")

func get_game_menu() -> Control:
	"""Отримує ігрове меню"""
	return _get_ui_element("game_menu", "GameMenu")

# ============================================
# ДОПОМІЖНІ МЕТОДИ
# ============================================

func _get_ui_element(group_name: String, node_name: String = "") -> Node:
	"""Універсальний метод для отримання UI елементів з кешуванням"""
	# Перевіряємо кеш
	if _ui_elements_cache.has(group_name):
		var cached = _ui_elements_cache[group_name]
		if is_instance_valid(cached):
			return cached
		else:
			# Якщо елемент видалено, видаляємо з кешу
			_ui_elements_cache.erase(group_name)
	
	# Шукаємо через групу напряму
	# Використовуємо прямий виклик, але тільки один раз для кожної групи
	var tree = get_tree()
	if not tree:
		return null
	
	var element = tree.get_first_node_in_group(group_name)
	
	if element:
		# Кешуємо знайдений елемент
		_ui_elements_cache[group_name] = element
		ui_element_found.emit(group_name, element)
		return element
	
	# Якщо не знайдено через групу, шукаємо по імені
	if node_name != "":
		# Шукаємо ui_elements групу напряму (тільки один раз)
		var ui_elements_group = GameGroups.get_first_node_in_group(GameGroups.UI_ELEMENTS)
		if ui_elements_group:
			# Шукаємо дочірній елемент
			var child = ui_elements_group.get_node_or_null(node_name)
			if child:
				_ui_elements_cache[group_name] = child
				ui_element_found.emit(group_name, child)
				return child
		
		# Якщо не знайдено, шукаємо в UICanvas напряму (тільки один раз)
		var ui_canvas_direct = GameGroups.get_first_node_in_group(GameGroups.UI_CANVAS)
		if ui_canvas_direct:
			var child = ui_canvas_direct.get_node_or_null(node_name)
			if child:
				_ui_elements_cache[group_name] = child
				ui_element_found.emit(group_name, child)
				return child
	
	# Елемент не знайдено
	ui_element_not_found.emit(group_name)
	return null

func clear_cache():
	"""Очищає кеш UI елементів"""
	_ui_elements_cache.clear()
	print("🎨 UIManager: Cache cleared")

func is_ui_element_available(group_name: String) -> bool:
	"""Перевіряє, чи доступний UI елемент"""
	var element = _get_ui_element(group_name)
	return element != null

# ============================================
# МАСОВІ ОПЕРАЦІЇ
# ============================================

func show_all_ui_elements():
	"""Показує всі UI елементи"""
	# Отримуємо ui_canvas напряму, щоб уникнути рекурсії
	var ui_canvas = GameGroups.get_first_node_in_group(GameGroups.UI_CANVAS)
	if ui_canvas:
		ui_canvas.visible = true
		print("🎨 UIManager: All UI elements shown")

func hide_all_ui_elements():
	"""Приховує всі UI елементи"""
	# Отримуємо ui_canvas напряму, щоб уникнути рекурсії
	var ui_canvas = GameGroups.get_first_node_in_group(GameGroups.UI_CANVAS)
	if ui_canvas:
		ui_canvas.visible = false
		print("🎨 UIManager: All UI elements hidden")

func get_all_ui_elements() -> Array[Node]:
	"""Отримує всі UI елементи"""
	var elements: Array[Node] = []
	# Отримуємо ui_canvas напряму, щоб уникнути рекурсії через get_ui_canvas()
	var ui_canvas = GameGroups.get_first_node_in_group(GameGroups.UI_CANVAS)
	if ui_canvas:
		_get_all_children_recursive(ui_canvas, elements, 0, [])
	return elements

func _get_all_children_recursive(node: Node, result: Array[Node], depth: int = 0, visited: Array = []):
	"""Рекурсивно збирає всі дочірні ноди з обмеженням глибини"""
	# Захист від нескінченної рекурсії
	const MAX_DEPTH = 50
	if depth > MAX_DEPTH:
		push_warning("⚠️ UIManager: Maximum recursion depth reached in _get_all_children_recursive")
		return
	
	# Захист від циклічних посилань
	if node in visited:
		push_warning("⚠️ UIManager: Circular reference detected in _get_all_children_recursive")
		return
	
	visited.append(node)
	
	for child in node.get_children():
		if child.visible:
			result.append(child)
		_get_all_children_recursive(child, result, depth + 1, visited)

func _exit_tree() -> void:
	"""Відписується від всіх сигналів при видаленні вузла (запобігання витоків пам'яті)"""
	_disconnect_all_signals()

func _disconnect_all_signals() -> void:
	"""Відписується від всіх сигналів EventBus для запобігання витоків пам'яті"""
	if not Engine.has_singleton("EventBus"):
		return
	
	# Перевіряємо та відписуємося від сигналів сцен
	if EventBus.scene_loaded.is_connected(_on_scene_changed):
		EventBus.scene_loaded.disconnect(_on_scene_changed)
	if EventBus.scene_transition_completed.is_connected(_on_scene_changed):
		EventBus.scene_transition_completed.disconnect(_on_scene_changed)
	
	print("🎨 UIManager: Disconnected from all EventBus signals")


# ============================================
# UI ROOT / FSM
# ============================================

func _ensure_ui_root() -> void:
	if _should_skip_ui_root():
		print("UIManager: _ensure_ui_root skipped for scene=%s" % (get_tree().current_scene.scene_file_path if get_tree() and get_tree().current_scene else "null"))
		return
	if ui_root and is_instance_valid(ui_root):
		return
	ui_root = UI_ROOT_SCENE.instantiate()
	ui_root.name = "UIRoot"
	add_child(ui_root)
	print("UIManager: UIRoot created for scene=%s" % (get_tree().current_scene.scene_file_path if get_tree() and get_tree().current_scene else "null"))
	if ui_root.has_method("get_state_machine"):
		state_machine = ui_root.get_state_machine()
	if ui_root.has_method("get_state_root"):
		state_root = ui_root.get_state_root()
	if ui_root.has_method("get_modal_layer"):
		modal_layer = ui_root.get_modal_layer()
	if state_machine:
		current_state = state_machine.get("state")
		current_state_name = current_state.name if current_state else ""

func _should_skip_ui_root() -> bool:
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return false
	var path = tree.current_scene.scene_file_path
	if path.ends_with("MainMenu.tscn"):
		return true
	if path.find("/Menus/") != -1:
		return true
	return false

func get_state_root() -> Control:
	return state_root

func get_modal_layer() -> Node:
	return modal_layer

func change_state(state_name: String, payload: Dictionary = {}, return_state_name: String = "", return_payload: Dictionary = {}) -> void:
	_ensure_ui_root()
	print("UIManager: change_state requested=%s current_scene=%s ui_root=%s" % [
		state_name,
		get_tree().current_scene.scene_file_path if get_tree() and get_tree().current_scene else "null",
		ui_root != null
	])
	var scene_path = STATE_SCENES.get(state_name, "")
	if scene_path.is_empty():
		push_error("UIManager: Unknown state: %s" % state_name)
		return
	var packed = load(scene_path)
	if not packed:
		push_error("UIManager: Failed to load state scene: %s" % scene_path)
		return
	var new_state = packed.instantiate()
	if not new_state:
		push_error("UIManager: Failed to instantiate state scene: %s" % scene_path)
		return
	state_machine.add_child(new_state)
	if new_state.has_method("setup"):
		new_state.setup(self, payload, return_state_name, return_payload)
	if new_state.has_signal("finished"):
		new_state.finished.connect(_on_state_finished.bind(new_state), CONNECT_ONE_SHOT)
	var previous_state = null
	if state_machine:
		previous_state = state_machine.get("state")
	state_machine._change_state(new_state)
	if previous_state and is_instance_valid(previous_state):
		previous_state.queue_free()
	current_state = new_state
	current_state_name = state_name

func close_state() -> void:
	if current_state_name == "NullState":
		return
	change_state("NullState")

func _on_state_finished(payload: Dictionary, state_node: Node) -> void:
	var target = ""
	var return_payload = {}
	if state_node:
		var value = state_node.get("return_state")
		if value is String:
			target = value
		var payload_value = state_node.get("return_payload")
		if payload_value is Dictionary:
			return_payload = payload_value
	if not target.is_empty():
		change_state(target, payload, return_payload)
	else:
		close_state()

func open_game_menu() -> void:
	print("UIManager: open_game_menu current_scene=%s" % (get_tree().current_scene.scene_file_path if get_tree() and get_tree().current_scene else "null"))
	if not can_open_pause_menu():
		return
	change_state("GameMenuState")

func close_game_menu() -> void:
	if current_state_name == "GameMenuState":
		close_state()

func toggle_game_menu() -> void:
	if current_state_name == "GameMenuState":
		close_game_menu()
	else:
		open_game_menu()

func open_options() -> void:
	change_state("OptionsState", {}, current_state_name)

func open_load_game() -> void:
	change_state("LoadGameState", {}, current_state_name)

func open_save_game() -> void:
	change_state("SaveGameState", {}, current_state_name)

func show_modal(data: Dictionary) -> void:
	_ensure_ui_root()
	if modal_layer and modal_layer.has_method("show_modal"):
		modal_layer.show_modal(data)

func is_ui_active() -> bool:
	return current_state_name != ""

func is_gameplay_input_allowed() -> bool:
	if current_state_name != "":
		return false
	if modal_layer and modal_layer.get("active_modal"):
		return false
	return true

func can_open_pause_menu() -> bool:
	if not allow_pause_during_dialogue:
		var dialogue_manager = null
		if Engine.has_singleton("ServiceLocator"):
			var service_locator = Engine.get_singleton("ServiceLocator")
			if service_locator and service_locator.has_method("get_dialogue_manager"):
				dialogue_manager = service_locator.get_dialogue_manager()
		if dialogue_manager and dialogue_manager.has_method("is_dialogue_active"):
			return not dialogue_manager.is_dialogue_active()
	return true

func _on_language_changed(_language: String) -> void:
	ui_refresh_requested.emit()
