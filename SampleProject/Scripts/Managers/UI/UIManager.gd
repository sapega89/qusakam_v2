extends ManagerBase
class_name UIManager

## 🎨 UIManager - Централізований доступ до UI елементів
## Замінює прямі виклики get_tree().get_first_node_in_group()
## Дотримується принципу Single Responsibility

# Кешовані посилання на UI елементи
var _ui_elements_cache: Dictionary[String, Node] = {}

# Сигнали для оновлення UI
signal ui_element_found(element_name: String, element: Node)
signal ui_element_not_found(element_name: String)

func _initialize():
	"""Ініціалізація UIManager"""
	print("🎨 UIManager: Initialized")
	# Очищаємо кеш при зміні сцени
	# Підписуємося на події зміни сцени через EventBus (Godot 4 не має current_scene_changed)
	if Engine.has_singleton("EventBus"):
		EventBus.scene_loaded.connect(_on_scene_changed)
		EventBus.scene_transition_completed.connect(_on_scene_changed)
		print("🎨 UIManager: Connected to EventBus signals")
		# НЕ використовуємо tree_changed, щоб уникнути рекурсії при русі
	else:
		# Fallback - використовуємо періодичну перевірку замість tree_changed
		# tree_changed спрацьовує занадто часто (при кожній зміні дерева)
		call_deferred("_check_scene_change_periodically")

func _on_scene_changed(scene_name: String = ""):
	"""Очищає кеш при зміні сцени"""
	_ui_elements_cache.clear()
	print("🎨 UIManager: Scene changed: ", scene_name, ", cache cleared")

var _last_scene: Node = null
var _check_timer: float = 0.0
var _check_interval: float = 0.5  # Перевіряємо зміну сцени кожні 0.5 секунди

func _process(delta):
	"""Періодично перевіряє зміну сцени (fallback, якщо EventBus недоступний)"""
	if Engine.has_singleton("EventBus"):
		# Якщо EventBus доступний, не використовуємо fallback
		return
	
	_check_timer += delta
	if _check_timer >= _check_interval:
		_check_timer = 0.0
		_check_scene_change()

func _check_scene_change():
	"""Перевіряє, чи змінилася сцена"""
	# Використовуємо call_deferred, щоб уникнути рекурсії
	var tree = get_tree()
	if not tree:
		return
	
	# Отримуємо current_scene через call_deferred, щоб уникнути tree_changed
	var current_scene = tree.current_scene
	if current_scene != _last_scene:
		_last_scene = current_scene
		# Очищаємо кеш через call_deferred
		call_deferred("_clear_cache_safe")
		print("🎨 UIManager: Scene changed, cache cleared (fallback)")

func _clear_cache_safe():
	"""Безпечно очищає кеш"""
	_ui_elements_cache.clear()

func _check_scene_change_periodically():
	"""Ініціалізує періодичну перевірку зміни сцени"""
	_last_scene = get_tree().current_scene

# ============================================
# ОСНОВНІ UI ЕЛЕМЕНТИ
# ============================================

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

