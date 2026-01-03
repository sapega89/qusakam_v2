extends ManagerBase
class_name UIUpdateManager

## 🎨 UIUpdateManager - Автоматичне оновлення UI через EventBus
## Централізує всі UI оновлення на основі подій
## Дотримується принципу Observer Pattern та Single Responsibility

# Кеш UI елементів
var ui_elements_cache: Dictionary[String, Node] = {}


func _initialize():
	"""Ініціалізація UIUpdateManager"""
	print("🎨 UIUpdateManager: Initialized")

	# Підписуємося на події EventBus
	if Engine.has_singleton("EventBus"):
		_connect_event_bus_signals()
	else:
		print("⚠️ UIUpdateManager: EventBus not found, will retry on next frame")
		await get_tree().process_frame
		_connect_event_bus_signals()

func _connect_event_bus_signals():
	"""Підключає сигнали EventBus"""
	if not Engine.has_singleton("EventBus"):
		return
	
	# Player events
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_respawned.connect(_on_player_respawned)
	
	# Inventory events
	EventBus.inventory_updated.connect(_on_inventory_updated)
	
	# Combat events
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.damage_received.connect(_on_damage_received)
	
	# Scene events
	EventBus.scene_loaded.connect(_on_scene_loaded)
	
	print("🎨 UIUpdateManager: Connected to EventBus signals")

# ============================================
# PLAYER EVENTS
# ============================================

func _on_player_health_changed(new_health: int, max_health: int):
	"""Оновлює UI при зміні здоров'я гравця"""
	update_health_bar(new_health, max_health)

func _on_player_died():
	"""Обробляє смерть гравця"""
	print("🎨 UIUpdateManager: Player died, updating UI")
	# Можна додати логіку для показу екрану смерті

func _on_player_respawned():
	"""Обробляє воскресіння гравця"""
	print("🎨 UIUpdateManager: Player respawned, updating UI")
	update_health_bar(100, 100)  # Відновлюємо повне здоров'я

# ============================================
# INVENTORY EVENTS
# ============================================


func _on_inventory_updated():
	"""Оновлює UI при оновленні інвентаря"""
	update_potion_ui()

# ============================================
# COMBAT EVENTS
# ============================================

func _on_damage_dealt(_source: Node, _target: Node, _amount: int):
	"""Обробляє нанесення ушкоджень"""
	# Можна додати візуальні ефекти або анімації
	pass

func _on_damage_received(target: Node, _source: Node, _amount: int):
	"""Обробляє отримання ушкоджень"""
	if target.is_in_group(GameGroups.PLAYER):
		# UI вже оновлюється через player_health_changed
		pass

# ============================================
# SCENE EVENTS
# ============================================

func _on_scene_loaded(scene_name: String):
	"""Оновлює UI при завантаженні сцени"""
	print("🎨 UIUpdateManager: Scene loaded: ", scene_name)
	# Очищаємо кеш при зміні сцени
	ui_elements_cache.clear()
	# Оновлюємо всі UI елементи
	refresh_all_ui()

# ============================================
# UI UPDATE METHODS
# ============================================

func update_health_bar(current_health: int, max_health: int):
	"""Оновлює health bar"""
	var health_bar = get_health_bar()
	if not health_bar:
		return
	
	if health_bar.has_method("set_health"):
		health_bar.set_health(current_health, max_health)
	elif health_bar.has_method("update_health"):
		health_bar.update_health(current_health, max_health)
	else:
		# Fallback - спробуємо знайти ProgressBar
		var progress_bar = health_bar.get_node_or_null("ProgressBar")
		if progress_bar:
			progress_bar.value = float(current_health) / float(max_health) * 100.0

func update_potion_ui():
	"""Оновлює potion UI"""
	var potion_ui = get_potion_ui()
	if not potion_ui:
		return
	
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		var game_manager = service_locator.get_game_manager() if service_locator and service_locator.has_method("get_game_manager") else null
		if not game_manager:
			return
		
		var potion_count = 0
		if game_manager.has_method("get_inventory_count"):
			potion_count = game_manager.get_inventory_count("potion")
		elif game_manager.has("player_state") and game_manager.player_state.has("current_potions"):
			potion_count = game_manager.player_state.current_potions
		
		if potion_ui.has_method("set_potion_count"):
			potion_ui.set_potion_count(potion_count)
		elif potion_ui.has_method("update_potion_count_from_game_manager"):
			potion_ui.update_potion_count_from_game_manager()
		elif "current_potions" in potion_ui:
			potion_ui.current_potions = potion_count
			if potion_ui.has_method("_update_count"):
				potion_ui._update_count()

func refresh_all_ui():
	"""Оновлює всі UI елементи"""
	# Оновлюємо health bar
	var player = GameGroups.get_first_node_in_group(GameGroups.PLAYER)
	if player:
		var current_health = player.current_health if "current_health" in player else 100
		var max_health = player.Max_Health if "Max_Health" in player else 100
		update_health_bar(current_health, max_health)
	
	# Оновлюємо potion UI
	update_potion_ui()

# ============================================
# UI ELEMENT GETTERS
# ============================================

func get_health_bar() -> Node:
	"""Отримує health bar з кешу або знаходить його"""
	if ui_elements_cache.has("health_bar"):
		var cached = ui_elements_cache["health_bar"]
		if is_instance_valid(cached):
			return cached
	
	# Шукаємо через UIManager
	if Engine.has_singleton("ServiceLocator"):
		var ui_manager = ServiceLocator.get_ui_manager()
		if ui_manager:
			var health_bar_from_manager = ui_manager.get_health_bar()
			if health_bar_from_manager:
				ui_elements_cache["health_bar"] = health_bar_from_manager
				return health_bar_from_manager
	
	# Fallback - шукаємо вручну
	var health_bar_from_tree = GameGroups.get_first_node_in_group(GameGroups.HEALTH_BAR)
	if health_bar_from_tree:
		ui_elements_cache["health_bar"] = health_bar_from_tree
		return health_bar_from_tree
	
	return null

func get_potion_ui() -> Node:
	"""Отримує potion UI з кешу або знаходить його"""
	if ui_elements_cache.has("potion_ui"):
		var cached = ui_elements_cache["potion_ui"]
		if is_instance_valid(cached):
			return cached
	
	# Шукаємо через UIManager
	if Engine.has_singleton("ServiceLocator"):
		var ui_manager = ServiceLocator.get_ui_manager()
		if ui_manager:
			var potion_ui_from_manager = ui_manager.get_potion_ui()
			if potion_ui_from_manager:
				ui_elements_cache["potion_ui"] = potion_ui_from_manager
				return potion_ui_from_manager
	
	# Fallback - шукаємо вручну
	var potion_ui_from_tree = GameGroups.get_first_node_in_group(GameGroups.POTION_UI)
	if potion_ui_from_tree:
		ui_elements_cache["potion_ui"] = potion_ui_from_tree
		return potion_ui_from_tree
	
	return null

func clear_cache():
	"""Очищає кеш UI елементів"""
	ui_elements_cache.clear()
	print("🎨 UIUpdateManager: Cache cleared")

func _exit_tree() -> void:
	"""Відписується від всіх сигналів при видаленні вузла (запобігання витоків пам'яті)"""
	_disconnect_all_signals()

func _disconnect_all_signals() -> void:
	"""Відписується від всіх сигналів EventBus для запобігання витоків пам'яті"""
	if not Engine.has_singleton("EventBus"):
		return
	
	# Перевіряємо та відписуємося від сигналів гравця
	if EventBus.player_health_changed.is_connected(_on_player_health_changed):
		EventBus.player_health_changed.disconnect(_on_player_health_changed)
	if EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)
	if EventBus.player_respawned.is_connected(_on_player_respawned):
		EventBus.player_respawned.disconnect(_on_player_respawned)
	
	# Перевіряємо та відписуємося від сигналів інвентаря
	if EventBus.inventory_updated.is_connected(_on_inventory_updated):
		EventBus.inventory_updated.disconnect(_on_inventory_updated)
	
	# Перевіряємо та відписуємося від сигналів бою
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)
	if EventBus.damage_received.is_connected(_on_damage_received):
		EventBus.damage_received.disconnect(_on_damage_received)
	
	# Перевіряємо та відписуємося від сигналів сцен
	if EventBus.scene_loaded.is_connected(_on_scene_loaded):
		EventBus.scene_loaded.disconnect(_on_scene_loaded)
	
	print("🎨 UIUpdateManager: Disconnected from all EventBus signals")

