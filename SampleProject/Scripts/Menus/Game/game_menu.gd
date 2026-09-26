extends Control

## GameMenu - головне меню гри
## Використовує таку ж логіку як vertical_menu: одночасно тільки одна панель видима

# Посилання на вузли (могут быть в разных местах в зависимости от структуры сцены)
@onready var tab_buttons_container: VBoxContainer = get_node_or_null("VBoxContainer")
@onready var content_container: Control = get_node_or_null("ContentContainer")
@onready var game_menu_content = get_node_or_null("GameMenuContent")
@onready var vertical_menu = get_node_or_null("GameMenuContent/VerticalMenu")
@onready var focus_router = get_node_or_null("GameMenuContent/VerticalMenu/FocusRouter")
@onready var misc_button: Button = get_node_or_null("GameMenuContent/VerticalMenu/PanelManager/HBoxContainer/TabButtons/MiscButton")

const MiscMenuModalScene = preload("res://SampleProject/Scenes/Menus/Game/misc_menu_modal.tscn")
const OptionsMenuScene = "res://SampleProject/Scenes/Menus/Game/options_component.tscn"
const TutorialMenuScene = "res://SampleProject/Scenes/Menus/Game/tutorial_menu.tscn"
const MODAL_TEMPLATES = preload("res://SampleProject/Scripts/UI/modal_templates.gd")

var _pending_exit_action: String = ""

# Масив кнопок та панелей контенту
var tab_buttons: Array[Button] = []
var content_panels: Array[Dictionary] = []  # [{"name": "Inventory", "content": Control}, ...]

# Поточна активна вкладка
var current_tab_name: String = "Inventory":
	set(value):
		if value != current_tab_name:
			current_tab_name = value
			_update_visibility()
			_update_button_states()

func _ready() -> void:
	add_to_group("game_menu")
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Проверяем доступность ServiceLocator
	# ServiceLocator - это autoload, доступен напрямую через имя
	# В Godot autoload доступен напрямую через имя, а не через Engine.get_singleton()
	var service_locator = null
	# Пробуємо прямий доступ до autoload через ім'я (найнадійніший спосіб)
	if has_node("/root/ServiceLocator"):
		service_locator = get_node("/root/ServiceLocator")
	elif get_tree().root.has_node("ServiceLocator"):
		service_locator = get_tree().root.get_node("ServiceLocator")
	else:
		# Fallback: пытаемся получить через Engine (для совместимости)
		if Engine.has_singleton("ServiceLocator"):
			service_locator = Engine.get_singleton("ServiceLocator")
	
	if not service_locator:
		# Використовуємо push_warning замість push_error, щоб не блокувати роботу меню
		push_warning("⚠️ GameMenu: ServiceLocator not found! Make sure it's in autoload. Continuing without ServiceLocator...")
		# Не возвращаемся, продолжаем работу без ServiceLocator
	
	# Ищем VerticalMenu через GameMenuContent (правильная структура: BaseMenu -> CentralPanel -> GameMenuContent -> VerticalMenu)
	if game_menu_content:
		var content_vertical_menu = game_menu_content.get_node_or_null("VerticalMenu")
		if content_vertical_menu:
			vertical_menu = content_vertical_menu
			print("🎮 GameMenu: Found VerticalMenu through GameMenuContent")
	
	# Если VerticalMenu не найден через @onready, пробуем найти через BaseMenu
	if not vertical_menu:
		var base_menu = get_node_or_null("BaseMenu")
		if base_menu:
			var central_panel = base_menu.get_node_or_null("HBoxContainer/CentralPanel")
			if central_panel:
				var game_menu_content_node = central_panel.get_node_or_null("GameMenuContent")
				if game_menu_content_node:
					vertical_menu = game_menu_content_node.get_node_or_null("VerticalMenu")
					if vertical_menu:
						print("🎮 GameMenu: Found VerticalMenu through BaseMenu -> CentralPanel -> GameMenuContent")
	
	# Если используется GameMenuContent с VerticalMenu, находим кнопки через VerticalMenu
	if vertical_menu:
		var panel_manager = vertical_menu.get_node_or_null("PanelManager")
		if panel_manager:
			var buttons_container = panel_manager.get_node_or_null("HBoxContainer/TabButtons")
			if buttons_container:
				for child in buttons_container.get_children():
					if child is Button:
						tab_buttons.append(child)
						print("🎮 GameMenu: Found button: ", child.name)
	
	# Собираем кнопки и панели из основной структуры
	_collect_tab_buttons()
	_collect_content_panels()
	_connect_ui_refresh()
	_apply_localized_labels()
	_connect_misc_button()
	
	# ВАЖНО: Убеждаемся, что все панели скрыты перед установкой начального состояния
	# Но сначала показываем InventoryPanel в VerticalMenu
	if vertical_menu:
		var panel_manager = vertical_menu.get_node_or_null("PanelManager")
		if panel_manager:
			var hbox = panel_manager.get_node_or_null("HBoxContainer")
			if hbox:
				# Скрываем все панели
				for child in hbox.get_children():
					if child is PanelContainer:
						child.visible = false
				# Показываем InventoryPanel
				var inventory_panel = hbox.get_node_or_null("InventoryPanel")
				if inventory_panel:
					inventory_panel.visible = true
					print("🎮 GameMenu: Made InventoryPanel visible")
	
	for panel_data in content_panels:
		if panel_data.content:
			panel_data.content.visible = false
	
	# Встановлюємо початковий стан (это покажет только Inventory - первая вкладка)
	current_tab_name = "Inventory"
	_update_visibility()
	_update_button_states()
	if focus_router:
		focus_router.set_active_tab(current_tab_name)
		focus_router.focus_tabs()
	
	print("🎮 GameMenu: Initialized with ", tab_buttons.size(), " buttons and ", content_panels.size(), " panels")
	print("🎮 GameMenu: First tab is Inventory")

func _connect_ui_refresh() -> void:
	var ui_manager = null
	var service_locator = ServiceLocatorHelper.get_service_locator()
	if service_locator:
		if service_locator and service_locator.has_method("get_ui_manager"):
			ui_manager = service_locator.get_ui_manager()
	if ui_manager and ui_manager.has_signal("ui_refresh_requested"):
		if not ui_manager.ui_refresh_requested.is_connected(_on_ui_refresh_requested):
			ui_manager.ui_refresh_requested.connect(_on_ui_refresh_requested)

func _on_ui_refresh_requested() -> void:
	_apply_localized_labels()

func _apply_localized_labels() -> void:
	if not vertical_menu:
		return
	var panel_manager = vertical_menu.get_node_or_null("PanelManager")
	if not panel_manager:
		return
	var buttons_container = panel_manager.get_node_or_null("HBoxContainer/TabButtons")
	if not buttons_container:
		return
	var label_map = {
		"InventoryButton": "Inventory",
		"EquipmentButton": "Equipment",
		"WorldMapButton": "World Map",
		"MiscButton": "Misc",
		"JournalButton": "Journal",
		"SkillsButton": "Skills",
		"StatusButton": "Status"
	}
	for child in buttons_container.get_children():
		if child is Button and label_map.has(child.name):
			child.text = tr(label_map[child.name])

func _connect_misc_button() -> void:
	if misc_button and not misc_button.pressed.is_connected(_on_misc_button_pressed):
		misc_button.pressed.connect(_on_misc_button_pressed)

func _on_misc_button_pressed() -> void:
	var ui_manager = null
	if has_node("/root/ServiceLocator"):
		var service_locator = get_node("/root/ServiceLocator")
		if service_locator and service_locator.has_method("get_ui_manager"):
			ui_manager = service_locator.get_ui_manager()
	if ui_manager and ui_manager.has_method("get_modal_layer"):
		var modal_layer = ui_manager.get_modal_layer()
		if modal_layer and modal_layer.has_method("show_custom_modal"):
			modal_layer.show_custom_modal(MiscMenuModalScene)
			var modal = modal_layer.active_modal
			if modal:
				if modal.has_signal("settings_selected"):
					modal.settings_selected.connect(_on_misc_settings_selected, CONNECT_ONE_SHOT)
				if modal.has_signal("tutorial_selected"):
					modal.tutorial_selected.connect(_on_misc_tutorial_selected, CONNECT_ONE_SHOT)
				if modal.has_signal("exit_main_menu_selected"):
					modal.exit_main_menu_selected.connect(_on_misc_exit_main_menu_selected, CONNECT_ONE_SHOT)
				if modal.has_signal("exit_game_selected"):
					modal.exit_game_selected.connect(_on_misc_exit_game_selected, CONNECT_ONE_SHOT)

func _on_misc_settings_selected() -> void:
	get_tree().change_scene_to_file(OptionsMenuScene)

func _on_misc_tutorial_selected() -> void:
	get_tree().change_scene_to_file(TutorialMenuScene)

func _on_misc_exit_main_menu_selected() -> void:
	_pending_exit_action = "exit_main_menu"
	_show_exit_confirm()

func _on_misc_exit_game_selected() -> void:
	_pending_exit_action = "exit_game"
	_show_exit_confirm()

func _show_exit_confirm() -> void:
	var ui_manager = null
	if has_node("/root/ServiceLocator"):
		var service_locator = get_node("/root/ServiceLocator")
		if service_locator and service_locator.has_method("get_ui_manager"):
			ui_manager = service_locator.get_ui_manager()
	if not ui_manager or not ui_manager.has_method("show_modal") or not ui_manager.has_method("get_modal_layer"):
		return
	var modal_layer = ui_manager.get_modal_layer()
	if modal_layer and modal_layer.has_signal("modal_closed"):
		modal_layer.modal_closed.connect(_on_exit_confirm_closed, CONNECT_ONE_SHOT)
	var data = MODAL_TEMPLATES.confirm_exit_to_main_menu() if _pending_exit_action == "exit_main_menu" else MODAL_TEMPLATES.confirm_exit_game_unsaved()
	ui_manager.show_modal(data)

func _on_exit_confirm_closed(result: String) -> void:
	if result != "confirm":
		_pending_exit_action = ""
		return
	if _pending_exit_action == "exit_main_menu":
		get_tree().set_meta("show_title_screen", true)
		get_tree().change_scene_to_file("res://SampleProject/MainMenu.tscn")
	elif _pending_exit_action == "exit_game":
		get_tree().quit()
	_pending_exit_action = ""

func _on_inventory_button_pressed() -> void:
	"""Обработчик нажатия на кнопку Inventory в VerticalMenu"""
	switch_to_tab("Inventory")

## Збирає всі кнопки з GameMenuContent/VerticalMenu
func _collect_tab_buttons() -> void:
	tab_buttons.clear()
	
	# Ищем кнопки в VerticalMenu через PanelManager
	if vertical_menu:
		var panel_manager = vertical_menu.get_node_or_null("PanelManager")
		if panel_manager:
			var buttons_container = panel_manager.get_node_or_null("HBoxContainer/TabButtons")
			if buttons_container:
				for child in buttons_container.get_children():
					if child is Button:
						tab_buttons.append(child)
						print("🎮 GameMenu: Found button: ", child.name)
	
	# Fallback: проверяем старую структуру (для обратной совместимости)
	if tab_buttons.is_empty() and tab_buttons_container:
		for child in tab_buttons_container.get_children():
			if child is Button:
				tab_buttons.append(child)
				print("🎮 GameMenu: Found button: ", child.name)

## Збирає всі панелі контенту з GameMenuContent/VerticalMenu
func _collect_content_panels() -> void:
	content_panels.clear()
	
	# Маппинг имен компонентов к именам вкладок
	var component_to_tab = {
		"InventoryComponent": "Inventory",
		"JournalComponent": "Journal",
		"EquipmentComponent": "Equipment",
		"MetSysMapComponent": "World Map",
		"ScrollContainer": "Status",  # ScrollContainer содержит StatsComponent
		"OptionsComponent": "Misc"
	}
	
	# Ищем компоненты в VerticalMenu через PanelManager
	if vertical_menu:
		var panel_manager = vertical_menu.get_node_or_null("PanelManager")
		if panel_manager:
			var hbox_container = panel_manager.get_node_or_null("HBoxContainer")
			if hbox_container:
				# Ищем панели контента в HBoxContainer
				for child in hbox_container.get_children():
					if child is PanelContainer:
						# Ищем компоненты внутри панели
						for panel_child in child.get_children():
							if panel_child.name in component_to_tab:
								var tab_name = component_to_tab[panel_child.name]
								content_panels.append({"name": tab_name, "content": panel_child})
								print("🎮 GameMenu: Found panel: ", tab_name, " (", panel_child.name, ")")
								# Сразу скрываем все панели
								panel_child.visible = false
							elif panel_child.name == "ScrollContainer":
								# ScrollContainer содержит StatsComponent
								var stats_component = panel_child.get_node_or_null("StatsComponent")
								if stats_component:
									content_panels.append({"name": "Status", "content": panel_child})
									print("🎮 GameMenu: Found Status panel (ScrollContainer)")
									panel_child.visible = false
	
	# Fallback: проверяем старую структуру ContentContainer (для обратной совместимости)
	if content_container and content_panels.is_empty():
		for child in content_container.get_children():
			if child.name in component_to_tab:
				var tab_name = component_to_tab[child.name]
				content_panels.append({"name": tab_name, "content": child})
				print("🎮 GameMenu: Found panel: ", tab_name, " (", child.name, ")")
				child.visible = false
	
	# MetSysMapComponent теперь находится в VerticalMenu/PanelManager/HBoxContainer/WorldMapPanel
	# Проверяем через vertical_menu
	if vertical_menu:
		var panel_manager = vertical_menu.get_node_or_null("PanelManager")
		if panel_manager:
			var map_panel = panel_manager.get_node_or_null("HBoxContainer/WorldMapPanel/MetSysMapComponent")
			if map_panel:
				content_panels.append({"name": "World Map", "content": map_panel})
				print("🎮 GameMenu: Found MetSysMapComponent in WorldMapPanel")
				map_panel.visible = false

## Оновлює видимість панелей контенту
func _update_visibility() -> void:
	print("🎮 GameMenu: _update_visibility() called, current_tab_name: ", current_tab_name)
	print("🎮 GameMenu: content_panels size: ", content_panels.size())
	
	# Сначала показываем/скрываем панели в VerticalMenu через PanelManager
	if vertical_menu:
		var panel_manager = vertical_menu.get_node_or_null("PanelManager")
		if panel_manager:
			var hbox = panel_manager.get_node_or_null("HBoxContainer")
			if hbox:
				# Находим панель, соответствующую текущей вкладке
				var target_panel_name = ""
				match current_tab_name:
					"Inventory":
						target_panel_name = "InventoryPanel"
					"Equipment":
						target_panel_name = "EquipmentPanel"
					"World Map":
						target_panel_name = "WorldMapPanel"
					"Misc":
						target_panel_name = "MiscPanel"
					"Journal":
						target_panel_name = "JournalPanel"
					"Status":
						target_panel_name = "StatusPanel"
				
				# Показываем нужную панель, скрываем остальные
				for child in hbox.get_children():
					if child is PanelContainer:
						if child.name == target_panel_name:
							child.visible = true
							print("  ✅ Showing panel: ", child.name)
						else:
							child.visible = false
							print("  ❌ Hiding panel: ", child.name)
	
	# Затем обновляем видимость компонентов внутри панелей
	for panel_data in content_panels:
		if panel_data.content:
			var should_be_visible = (panel_data.name == current_tab_name)
			panel_data.content.visible = should_be_visible
			
			if should_be_visible:
				print("  ✅ Showing component: ", panel_data.name, " (", panel_data.content.name, ")")
			else:
				print("  ❌ Hiding component: ", panel_data.name, " (", panel_data.content.name, ")")
			
			# Специальная обработка для MapComponent
			if panel_data.name == "World Map" and panel_data.content.has_method("set_map_active"):
				# ВАЖНО: Сначала устанавливаем видимость, потом вызываем set_map_active
				# Это гарантирует, что CanvasLayer не будет влиять на layout других элементов
				panel_data.content.visible = should_be_visible
				panel_data.content.set_map_active(should_be_visible)
				if should_be_visible and panel_data.content.has_method("update_map_visibility"):
					panel_data.content.update_map_visibility()

## Оновлює візуальний стан кнопок
	if focus_router:
		focus_router.set_active_tab(current_tab_name)

func _update_button_states() -> void:
	# Маппинг имен кнопок к именам вкладок
	var button_to_tab = {
		"InventoryButton": "Inventory",
		"JournalButton": "Journal",
		"EquipmentButton": "Equipment",
		"WorldMapButton": "World Map",
		"MiscButton": "Misc",
		"StatusButton": "Status",
		"SkillsButton": "Skills"
	}
	
	for button in tab_buttons:
		if button and button.name in button_to_tab:
			var tab_name = button_to_tab[button.name]
			button.button_pressed = (tab_name == current_tab_name)

## Обробники натискання кнопок (підключені в сцені)
func _on_old_inventory_pressed() -> void:
	switch_to_tab("Inventory")

func _on_old_journal_pressed() -> void:
	switch_to_tab("Journal")

func _on_old_equipment_pressed() -> void:
	switch_to_tab("Equipment")

func _on_old_map_pressed() -> void:
	switch_to_tab("Map")

func _on_old_misc_pressed() -> void:
	switch_to_tab("Miscellaneous")

func _on_old_settings_pressed() -> void:
	# Settings открывается через SettingsManager
	var service_locator = get_node_or_null("/root/ServiceLocator")
	var settings_manager = null
	if service_locator and service_locator.has_method("get_settings_manager"):
		settings_manager = service_locator.get_settings_manager()
	if settings_manager:
		settings_manager.open_settings(get_tree().root, true)  # true = popup режим
	else:
		# Fallback до звичайного перемикання
		push_warning("⚠️ GameMenu: SettingsManager not found, falling back to tab switch")
		switch_to_tab("Settings")

## Перемикає на вкладку за ім'ям
func switch_to_tab(tab_name: String) -> void:
	print("🎮 GameMenu: Switching to tab: ", tab_name)
	current_tab_name = tab_name

## Закриває меню
func close_menu() -> void:
	var service_locator = get_node_or_null("/root/ServiceLocator")
	var menu_manager = null
	if service_locator and service_locator.has_method("get_menu_manager"):
		menu_manager = service_locator.get_menu_manager()
	if menu_manager:
		menu_manager.close_game_menu()
	else:
		push_warning("⚠️ GameMenu: MenuManager not found, cannot close menu properly")
		# Fallback: просто скрываем меню
		visible = false
		get_tree().paused = false

func _check_managers() -> void:
	"""Проверяет доступность менеджеров и выводит предупреждения"""
	var service_locator = get_node_or_null("/root/ServiceLocator")
	var menu_manager = null
	if service_locator and service_locator.has_method("get_menu_manager"):
		menu_manager = service_locator.get_menu_manager()
	if not menu_manager:
		push_warning("⚠️ GameMenu: MenuManager not available yet")
	
	var settings_manager = null
	if service_locator and service_locator.has_method("get_settings_manager"):
		settings_manager = service_locator.get_settings_manager()
	if not settings_manager:
		push_warning("⚠️ GameMenu: SettingsManager not available yet")

func _input(event: InputEvent) -> void:
	# Обробка Escape для закриття меню
	# Оскільки меню має process_mode = PROCESS_MODE_WHEN_PAUSED, воно може обробляти ввід навіть на паузі
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		print("🎮 GameMenu: Escape натиснуто, закриваємо меню...")
		close_menu()
		get_viewport().set_input_as_handled()
		return
	
	# ВАЖНО: НЕ викликаємо super._input() з BaseMenu, щоб уникнути рекурсії
	# BaseMenu._input() також обробляє Escape, але ми обробляємо його тут напряму
