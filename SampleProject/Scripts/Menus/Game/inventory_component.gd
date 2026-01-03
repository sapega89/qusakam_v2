extends BaseMenuComponent

# Основные узлы (обязательные) - ищем через find_child для независимости от структуры
var hbox_container: HBoxContainer = null
var item_list: Table = null
# Опциональные узлы для отображения деталей предмета (могут отсутствовать)
var vbox_container: VBoxContainer = null
var icon_rect: TextureRect = null
var name_label: Label = null
var desc_label: RichTextLabel = null

# Динамически создаваемые узлы (опциональные)
var main_vbox: VBoxContainer = null
var filter_container: HBoxContainer = null

var items: Array = []  # Array of items for display
var all_items: Array = []  # All items (unfiltered)

# Filter system
enum FilterType {
	ALL,      # Все предмети (AllPanel)
	ARMOR,    # Тільки армор (ArmorPanel)
	WEAPON,   # Тільки зброя (WeaponPanel)
	MISC      # Інші предмети - potions, herbs, resources, materials (MiscPanel)
}

var current_filter: FilterType = FilterType.ALL
var filter_buttons: Array[Button] = []

# Equipment selection mode
var equipment_selection_mode: bool = false
var equipment_slot_id: String = ""  # Which slot to equip (e.g., "sword", "head")
var equipment_component: Node = null  # Reference to equipment component

func _find_nodes():
	"""Находит все необходимые узлы независимо от структуры родительской сцены"""
	# Ищем HBoxContainer (может быть прямым дочерним элементом или найден через поиск)
	hbox_container = get_node_or_null("HBoxContainer")
	if not hbox_container:
		hbox_container = find_child("HBoxContainer", true, false)
	
	# Ищем ItemList (Table) - может быть в HBoxContainer или найден через поиск
	# Сначала ищем "ItemList"
	if hbox_container:
		item_list = hbox_container.get_node_or_null("ItemList")
	if not item_list:
		item_list = find_child("ItemList", true, false)
	
	# Если не нашли ItemList, ищем InventoryTable в активной панели
	if not item_list:
		# Ищем PanelManager для определения активной панели
		var panel_manager = get_node_or_null("PanelManager")
		if panel_manager:
			var hbox = panel_manager.get_node_or_null("HBoxContainer")
			if hbox:
				# Ищем видимую панель (AllPanel, ArmorPanel, WeaponPanel, MiscPanel)
				for child in hbox.get_children():
					if child is PanelContainer and child.visible:
						# Ищем InventoryTable в видимой панели
						var table = child.get_node_or_null("InventoryTable")
						if table and table is Table:
							item_list = table
							print("📦 InventoryComponent: Found InventoryTable in visible panel: ", child.name)
							break
		
		# Если все еще не нашли, ищем любой InventoryTable
		if not item_list:
			var all_tables = find_children("*", "InventoryTable", true, false)
			for table in all_tables:
				if table is Table:
					item_list = table
					print("📦 InventoryComponent: Found InventoryTable: ", table.get_path())
					break
	
	# Если нашли через поиск, пытаемся найти родительский HBoxContainer
	if item_list and not hbox_container:
		var parent = item_list.get_parent()
		if parent is HBoxContainer:
			hbox_container = parent
	
	# Ищем опциональные узлы для отображения деталей предмета
	if hbox_container:
		vbox_container = hbox_container.get_node_or_null("VBoxContainer")
		if vbox_container:
			icon_rect = vbox_container.get_node_or_null("TextureRect")
			name_label = vbox_container.get_node_or_null("Label")
			desc_label = vbox_container.get_node_or_null("RichTextLabel")
	
	# Если не нашли через прямые пути, ищем через поиск
	if not vbox_container:
		vbox_container = find_child("VBoxContainer", true, false)
	if not icon_rect:
		icon_rect = find_child("TextureRect", true, false)
	if not name_label:
		name_label = find_child("Label", true, false)
	if not desc_label:
		desc_label = find_child("RichTextLabel", true, false)

func _validate_scene_structure():
	"""Валидация структуры сцены инвентаря"""
	# Сначала находим узлы
	_find_nodes()
	
	# Проверяем только обязательные узлы
	if not hbox_container:
		push_error("❌ InventoryComponent: Missing required node: HBoxContainer")
		return false
	
	if not item_list:
		push_error("❌ InventoryComponent: Missing required node: ItemList (Table)")
		return false
	
	# Проверяем, что item_list является Table
	if not item_list is Table:
		push_error("❌ InventoryComponent: ItemList must be a Table! Current type: " + item_list.get_class())
		return false
	
	# Опциональные узлы - только предупреждение, не ошибка
	if not vbox_container:
		push_warning("⚠️ InventoryComponent: VBoxContainer not found - item details panel will not be available")
	if not icon_rect:
		push_warning("⚠️ InventoryComponent: TextureRect not found - item icon will not be displayed")
	if not name_label:
		push_warning("⚠️ InventoryComponent: Label not found - item name will not be displayed")
	if not desc_label:
		push_warning("⚠️ InventoryComponent: RichTextLabel not found - item description will not be displayed")
	
	return true

func _initialize_component():
	"""Инициализация компонента инвентаря (вызывается из BaseMenuComponent._ready)"""
	# BaseMenuComponent уже получил game_manager и item_database
	
	# Находим узлы перед использованием
	_find_nodes()
	
	# Настраиваем Table (может быть несколько, настраиваем все)
	_setup_all_tables()
	
	# Убеждаемся, что item_list указывает на активную панель
	_update_item_list_from_active_panel()
	
	# Настраиваем Table, если он найден
	if item_list:
		# Настраиваем режим выбора (ряд)
		item_list.table_select_mode = Table.select_mode.ROW
		# Настраиваем заголовки колонок
		item_list.header_row = ["Name", "On Hand"]
		# Настраиваем ширину колонок (0 = автоматически)
		item_list.header_width = [0, 100]
		
		# Подключаем сигналы Table
		if not item_list.CLICK_ROW_INDEX.is_connected(_on_item_selected):
			item_list.CLICK_ROW_INDEX.connect(_on_item_selected)
		if not item_list.DOUBLE_CLICK.is_connected(_on_item_double_clicked):
			item_list.DOUBLE_CLICK.connect(_on_item_double_clicked)
	
	# Create filter buttons
	_create_filter_buttons()
	
	# Ensure Table expands to fill available height
	if item_list:
		item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Ensure HBoxContainer expands if it exists in MainVBox
	# MainVBox создается динамически в _create_filter_buttons, поэтому используем find_child
	main_vbox = find_child("MainVBox", false, false)
	if main_vbox:
		var main_hbox = main_vbox.get_node_or_null("HBoxContainer")
		if main_hbox:
			main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Load items from inventory
	_load_inventory_items()
	
	# Встановлюємо фільтр для поточної панелі (за замовчуванням AllPanel)
	_on_panel_changed()
	
	# Update display
	_refresh_display()

func _create_filter_buttons():
	"""Find existing filter buttons (AllButton, ArmorButton, WeaponButton, MiscButton) in TabButtons"""
	# Знаходимо існуючі кнопки в TabButtons (вони вже є в сцені)
	var tab_buttons = get_node_or_null("PanelManager/HBoxContainer/TabButtons")
	if not tab_buttons:
		push_warning("⚠️ InventoryComponent: TabButtons not found!")
		return
	
	# Знаходимо кнопки по іменам і додаємо їх до filter_buttons в правильному порядку
	var all_btn = tab_buttons.get_node_or_null("AllButton")
	var armor_btn = tab_buttons.get_node_or_null("ArmorButton")
	var weapon_btn = tab_buttons.get_node_or_null("WeaponButton")
	var misc_btn = tab_buttons.get_node_or_null("MiscButton")
	
	# Додаємо кнопки в порядку FilterType: ALL, ARMOR, WEAPON, MISC
	if all_btn:
		filter_buttons.append(all_btn)
		all_btn.button_pressed = true  # AllPanel активна за замовчуванням
		print("📦 InventoryComponent: Found AllButton")
	if armor_btn:
		filter_buttons.append(armor_btn)
		print("📦 InventoryComponent: Found ArmorButton")
	if weapon_btn:
		filter_buttons.append(weapon_btn)
		print("📦 InventoryComponent: Found WeaponButton")
	if misc_btn:
		filter_buttons.append(misc_btn)
		print("📦 InventoryComponent: Found MiscButton")
	
	# PanelManager вже підключений до кнопок, тому нам не потрібно підключати сигнали тут
	# Але ми можемо підключитися до зміни панелей через PanelManager
	
	# Insert filter container at the top
	# Check if MainVBox already exists (to avoid recreating it)
	# Используем find_child вместо get_node_or_null для поиска только прямых детей
	if not main_vbox:
		main_vbox = find_child("MainVBox", false, false)
	
	# Create local_filter_container if it doesn't exist
	var local_filter_container: HBoxContainer = null
	if not filter_container:
		local_filter_container = HBoxContainer.new()
		local_filter_container.name = "FilterContainer"
	else:
		local_filter_container = filter_container
	
	if main_vbox:
		# MainVBox already exists, just add filter container if not present
		var existing_filter = main_vbox.find_child("FilterContainer", false, false)
		if not existing_filter:
			# Сохраняем ссылку в переменную класса
			filter_container = local_filter_container
			main_vbox.add_child(local_filter_container)
			main_vbox.move_child(local_filter_container, 0)
		else:
			# Если контейнер уже существует, используем его
			filter_container = existing_filter
		
		# Ensure HBoxContainer expands to fill available space
		var filter_hbox = main_vbox.find_child("HBoxContainer", false, false)
		if filter_hbox:
			filter_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		return
	
	# Check if HBoxContainer exists (используем @onready переменную)
	if hbox_container:
		# Create MainVBox wrapper
		main_vbox = VBoxContainer.new()
		main_vbox.name = "MainVBox"
		main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		main_vbox.set_offsets_preset(Control.PRESET_FULL_RECT)
		
		# Remove hbox from current parent (InventoryComponent)
		var parent = hbox_container.get_parent()
		if parent:
			parent.remove_child(hbox_container)
		
		# Set HBoxContainer to expand vertically to fill available space
		hbox_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# Create local_filter_container if it doesn't exist
		if not local_filter_container:
			local_filter_container = HBoxContainer.new()
			local_filter_container.name = "FilterContainer"
		
		# Сохраняем ссылку в переменную класса
		filter_container = local_filter_container
		
		# Add filter container first
		main_vbox.add_child(local_filter_container)
		
		# Add hbox with items (will expand to fill remaining space)
		main_vbox.add_child(hbox_container)
		
		# Add main_vbox to InventoryComponent
		add_child(main_vbox)
		move_child(main_vbox, 0)
	else:
		# Fallback: add to root
		# Create local_filter_container if it doesn't exist
		if not local_filter_container:
			local_filter_container = HBoxContainer.new()
			local_filter_container.name = "FilterContainer"
		
		# Сохраняем ссылку в переменную класса
		filter_container = local_filter_container
		add_child(local_filter_container)

func _load_inventory_items():
	"""Loads items from InventoryManager"""
	all_items.clear()
	
	if not game_manager or not item_database:
		return
	
	# Use InventoryManager if available
	var inventory_manager = game_manager.inventory_manager
	if not inventory_manager:
		return
	
	# Add potions - always show
	var potion_count = inventory_manager.get_item_count("potion")
	print("📦 InventoryComponent: Loading potions - count: ", potion_count)
	# Always show potions so user can see them in inventory
	all_items.append({
		"id": "potion",
		"name": item_database.get_item_name("potion", "en"),
		"desc": item_database.get_item_description("potion", "en"),
		"icon": item_database.get_item_icon("potion"),
		"count": potion_count,
		"item_data": item_database.get_item("potion")
	})
	print("📦 InventoryComponent: Added potion to items list, total items: ", all_items.size())
	
	# Add items from inventory manager
	var items_dict = inventory_manager.get_items_dict()
	for item_id in items_dict:
		var count = items_dict[item_id]
		if count > 0:
			var item = item_database.get_item(item_id)
			if not item.is_empty():
				all_items.append({
					"id": item_id,
					"name": item_database.get_item_name(item_id, "en"),
					"desc": item_database.get_item_description(item_id, "en"),
					"icon": item_database.get_item_icon(item_id),
					"count": count,
					"item_data": item
				})
	
	# Apply current filter
	_apply_filter()

func _setup_all_tables():
	"""Настраивает все InventoryTable в компоненте"""
	var panel_manager = get_node_or_null("PanelManager")
	if not panel_manager:
		return
	
	var hbox = panel_manager.get_node_or_null("HBoxContainer")
	if not hbox:
		return
	
	# Находим все панели и настраиваем их InventoryTable
	for child in hbox.get_children():
		if child is PanelContainer:
			var table = child.get_node_or_null("InventoryTable")
			if table and table is Table:
				# Настраиваем Table
				table.table_select_mode = Table.select_mode.ROW
				table.header_row = ["Name", "On Hand"]
				table.header_width = [0, 100]
				# Подключаем сигналы
				if not table.CLICK_ROW_INDEX.is_connected(_on_item_selected):
					table.CLICK_ROW_INDEX.connect(_on_item_selected)
				if not table.DOUBLE_CLICK.is_connected(_on_item_double_clicked):
					table.DOUBLE_CLICK.connect(_on_item_double_clicked)
				print("📦 InventoryComponent: Setup InventoryTable in panel: ", child.name)

func _update_item_list_from_active_panel():
	"""Обновляет item_list на основе активной панели"""
	# Ищем PanelManager для определения активной панели
	var panel_manager = get_node_or_null("PanelManager")
	if not panel_manager:
		return
	
	var hbox = panel_manager.get_node_or_null("HBoxContainer")
	if not hbox:
		return
	
	# Ищем видимую панель (AllPanel, ArmorPanel, WeaponPanel, MiscPanel)
	for child in hbox.get_children():
		if child is PanelContainer and child.visible:
			# Ищем InventoryTable в видимой панели
			var table = child.get_node_or_null("InventoryTable")
			if table and table is Table:
				# Обновляем item_list
				if item_list != table:
					item_list = table
					print("📦 InventoryComponent: Updated item_list to active panel: ", child.name)
				break

func _apply_filter():
	"""Apply current filter to items based on panel type"""
	items.clear()
	
	for item in all_items:
		var item_data = item.get("item_data", {})
		var item_type = item_data.get("type", "")
		var item_category = item_data.get("category", "")
		
		var should_show = false
		
		match current_filter:
			FilterType.ALL:
				# Показуємо всі предмети
				should_show = true
			FilterType.ARMOR:
				# Показуємо тільки армор (armor)
				should_show = (item_type == "armor")
			FilterType.WEAPON:
				# Показуємо тільки зброю (weapon)
				should_show = (item_type == "weapon")
			FilterType.MISC:
				# Показуємо інші предмети: potions, herbs, resources, materials
				should_show = (
					item_type == "consumable" or 
					item_type == "material" or 
					item_category == "plant" or 
					item.get("id") == "potion" or
					(item_type != "weapon" and item_type != "armor")
				)
		
		if should_show:
			items.append(item)
	
	_refresh_display()

func _on_filter_button_toggled(pressed: bool, filter_type: FilterType):
	"""Handle filter button toggle"""
	if pressed:
		set_filter(filter_type)

func set_filter(filter_type: FilterType):
	"""Set active filter"""
	current_filter = filter_type
	
	# Update button states
	for i in range(filter_buttons.size()):
		if i < FilterType.size():
			filter_buttons[i].button_pressed = (i == filter_type)
	
	# Apply filter
	_apply_filter()

func set_filter_by_panel(filter_type: FilterType):
	"""Set filter by panel type (called when panel changes)"""
	current_filter = filter_type
	_apply_filter()

func _refresh_display():
	"""Updates item list display as a table with Name and On Hand columns"""
	# Обновляем item_list перед использованием (может измениться активная панель)
	_update_item_list_from_active_panel()
	
	if not item_list:
		push_warning("⚠️ InventoryComponent: item_list is null, cannot refresh display")
		return
	
	# Создаем данные таблицы: [Name, On Hand]
	var table_data: Array[Array] = []
	var item_ids: Array[String] = []  # Сохраняем item_id для каждого ряда
	
	for item in items:
		# Добавляем ряд в таблицу: [Name, On Hand]
		table_data.append([item.name, str(item.count)])
		item_ids.append(item.get("id", ""))
	
	# Сохраняем item_ids для доступа после выбора
	item_list.set_meta("item_ids", item_ids)
	
	# Устанавливаем таблицу (Table автоматически использует header_row, который мы установили в _initialize_component)
	item_list.set_table(table_data)
	
	# Показываем таблицу, если она была скрыта
	if item_list and not item_list.visible:
		item_list.visible = true
		print("📦 InventoryComponent: Made InventoryTable visible")
	
	# Обновляем информацию о первом предмете, если есть
	if items.size() > 0:
		_update_info(0)
	else:
		# If inventory is empty, clear detailed info
		if icon_rect:
			icon_rect.texture = null
		if name_label:
			if equipment_selection_mode:
				name_label.text = "No items available for this slot"
			else:
				name_label.text = "Inventory Empty"
		if desc_label:
			if equipment_selection_mode:
				desc_label.text = "Select an item to equip"
			else:
				desc_label.text = "Buy items from the shop"

func _update_info(index: int) -> void:
	"""Updates detailed information about selected item"""
	if index < 0 or index >= items.size():
		return
	
	var item = items[index]
	if icon_rect:
		icon_rect.texture = item.icon
	if name_label:
		name_label.text = item.name
	if desc_label:
		# Use bbcode for proper text wrapping
		var desc_text = "[color=white]" + item.desc + "[/color]"
		if equipment_selection_mode:
			desc_text += "\n\n[color=yellow]Double-click to equip[/color]"
		desc_label.text = desc_text

func _on_item_selected(index: int):
	"""Handle item selection from Table (CLICK_ROW_INDEX signal)"""
	if index < 0 or index >= items.size():
		return
	
	_update_info(index)
	
	# In equipment selection mode, allow single-click to equip
	if equipment_selection_mode:
		# Show hint that user can double-click or press Enter to equip
		if desc_label:
			var item = items[index]
			var desc_text = "[color=white]" + item.desc + "[/color]"
			desc_text += "\n\n[color=yellow]Double-click or press Enter to equip[/color]"
			desc_label.text = desc_text
	else:
		# Show hint if item can be equipped and equipment tab is open
		var item = items[index]
		var slot_id = _get_slot_for_item(item)
		if slot_id != "" and _is_equipment_tab_open():
			if desc_label:
				var desc_text = "[color=white]" + item.desc + "[/color]"
				desc_text += "\n\n[color=yellow]Double-click to equip in " + _get_slot_display_name(slot_id) + " slot[/color]"
				desc_label.text = desc_text

func _on_item_double_clicked(pos: Vector2i, _key: Key):
	"""Handle item double-click/activation from Table (DOUBLE_CLICK signal)"""
	# Получаем индекс строки из позиции (pos.y - это индекс строки в Table)
	var index = pos.y
	if index < 0 or index >= items.size():
		return
	
	if equipment_selection_mode:
		# Equip the item
		var item = items[index]
		_equip_item(item.id)
	else:
		# Normal selection - check if we can auto-equip when equipment tab is open
		var item = items[index]
		_try_auto_equip(item)
		_update_info(index)

func set_equipment_selection_mode(enabled: bool, slot_id: String = "", equipment_comp: Node = null):
	"""Enable/disable equipment selection mode"""
	equipment_selection_mode = enabled
	equipment_slot_id = slot_id
	equipment_component = equipment_comp
	
	# If enabled, filter to show only equipment that matches the slot
	if enabled and slot_id != "":
		# Set filter to all (slot filtering will handle the rest)
		set_filter(FilterType.ALL)
		# Further filter by slot category
		_filter_by_equipment_slot(slot_id)
	else:
		# Reset to all items
		set_filter(FilterType.ALL)
	
	_refresh_display()

func _filter_by_equipment_slot(slot_id: String):
	"""Filter items to show only those that can be equipped in the specified slot"""
	var filtered_items = []
	
	for item in items:
		var item_data = item.get("item_data", {})
		var item_category = item_data.get("category", "")
		
		# Map slot_id to item category
		var can_equip = false
		match slot_id:
			"sword":
				can_equip = (item_category == "sword")
			"polearm":
				can_equip = (item_category == "polearm")
			"dagger":
				can_equip = (item_category == "dagger")
			"axe":
				can_equip = (item_category == "axe")
			"bow":
				can_equip = (item_category == "bow")
			"staff":
				can_equip = (item_category == "staff")
			"shield":
				can_equip = (item_category == "shield")
			"head":
				can_equip = (item_category == "helmet" or item_category == "hat")
			"body":
				can_equip = (item_category == "armor" or item_category == "vest")
			"accessory_1", "accessory_2":
				can_equip = (item_category == "accessory" or item_category == "ring")
		
		if can_equip:
			filtered_items.append(item)
	
	items = filtered_items

func _equip_item(item_id: String):
	"""Equip an item to the selected slot"""
	if not equipment_selection_mode or equipment_slot_id == "":
		return
	
	if not game_manager:
		return
	
	# Get item data
	var item_data = item_database.get_item(item_id)
	if item_data.is_empty():
		return
	
	# Check if item can be equipped in this slot
	var item_category = item_data.get("category", "")
	var can_equip = false
	
	match equipment_slot_id:
		"sword":
			can_equip = (item_category == "sword")
		"polearm":
			can_equip = (item_category == "polearm")
		"dagger":
			can_equip = (item_category == "dagger")
		"axe":
			can_equip = (item_category == "axe")
		"bow":
			can_equip = (item_category == "bow")
		"staff":
			can_equip = (item_category == "staff")
		"shield":
			can_equip = (item_category == "shield")
		"head":
			can_equip = (item_category == "helmet" or item_category == "hat")
		"body":
			can_equip = (item_category == "armor" or item_category == "vest")
		"accessory_1", "accessory_2":
			can_equip = (item_category == "accessory" or item_category == "ring")
	
	if not can_equip:
		print("⚠️ InventoryComponent: Item ", item_id, " cannot be equipped in slot ", equipment_slot_id)
		return
	
	# Equip the item
	game_manager.player_state.equipment[equipment_slot_id] = {
		"id": item_id,
		"name": item_database.get_item_name(item_id, "en"),
		"data": item_data
	}
	
	# Update active character equipment and bonuses
	if game_manager.active_character:
		game_manager.active_character.equipment[equipment_slot_id] = game_manager.player_state.equipment[equipment_slot_id]
		game_manager.active_character.update_equipment_bonuses()
	
	print("✅ InventoryComponent: Equipped ", item_id, " to slot ", equipment_slot_id)
	
	# Эмитим сигнал экипировки предмета через метод базового класса
	emit_item_equipped(item_id, equipment_slot_id)
	
	# Update player stats in scene if player exists
	if game_manager:
		var player = game_manager.get_current_player()
		if player and player.has_method("apply_stats_from_game_manager"):
			player.apply_stats_from_game_manager()
	
	# Exit equipment selection mode
	set_equipment_selection_mode(false)
	
	# Запрашиваем открытие вкладки equipment через сигнал (вместо прямого вызова)
	# Проверяем, открыта ли уже вкладка equipment
	var game_menu = get_tree().get_first_node_in_group("game_menu")
	if game_menu:
		var equipment_content = game_menu.find_child("EquipmentContent", true, false)
		if not equipment_content or not equipment_content.visible:
			request_tab.emit("equipment")
			print("✅ InventoryComponent: Requested equipment tab via signal")
	else:
		# Fallback: используем сигнал напрямую
		request_tab.emit("equipment")

func _get_slot_for_item(item: Dictionary) -> String:
	"""Determine which equipment slot an item can be equipped in"""
	var item_data = item.get("item_data", {})
	var item_category = item_data.get("category", "")
	var item_type = item_data.get("type", "")
	
	# Only equipment items can be equipped
	if item_type != "weapon" and item_type != "armor":
		return ""
	
	# Map category to slot
	match item_category:
		"sword":
			return "sword"
		"polearm":
			return "polearm"
		"dagger":
			return "dagger"
		"axe":
			return "axe"
		"bow":
			return "bow"
		"staff":
			return "staff"
		"shield":
			return "shield"
		"helmet", "hat":
			return "head"
		"armor", "vest":
			return "body"
		"accessory", "ring":
			# Try accessory_1 first, then accessory_2
			if not game_manager or not game_manager.player_state.equipment.get("accessory_1", null):
				return "accessory_1"
			else:
				return "accessory_2"
	
	return ""

func _get_slot_display_name(slot_id: String) -> String:
	"""Get display name for slot"""
	match slot_id:
		"sword":
			return "Sword"
		"polearm":
			return "Polearm"
		"dagger":
			return "Dagger"
		"axe":
			return "Axe"
		"bow":
			return "Bow"
		"staff":
			return "Staff"
		"shield":
			return "Shield"
		"head":
			return "Head"
		"body":
			return "Body"
		"accessory_1", "accessory_2":
			return "Accessory"
		_:
			return slot_id

func _is_equipment_tab_open() -> bool:
	"""Check if equipment tab is currently open"""
	var game_menu = get_node_or_null("../../..")
	if not game_menu:
		game_menu = get_node_or_null("../..")
	if not game_menu:
		return false
	
	# Check if equipment content is visible
	var equipment_content = game_menu.get_node_or_null("HBoxContainer/CentralPanel/Panel/ContentContainer/EquipmentContent")
	return equipment_content != null and equipment_content.visible

func _try_auto_equip(item: Dictionary):
	"""Try to auto-equip item when equipment tab is open"""
	if not game_manager or not item_database:
		return
	
	# Check if equipment tab is currently open
	if not _is_equipment_tab_open():
		return
	
	# Get slot for this item
	var slot_id = _get_slot_for_item(item)
	if slot_id == "":
		return
	
	# Equip the item
	var item_id = item.get("id", "")
	if item_id == "":
		return
	
	# Get equipment component reference
	var game_menu = get_node_or_null("../../..")
	if not game_menu:
		game_menu = get_node_or_null("../..")
	
	var equipment_content = null
	var equipment_comp = null
	if game_menu:
		equipment_content = game_menu.get_node_or_null("HBoxContainer/CentralPanel/Panel/ContentContainer/EquipmentContent")
		if equipment_content:
			equipment_comp = equipment_content.get_node_or_null("EquipmentComponent")
	
	# Use existing equip function
	var old_selection_mode = equipment_selection_mode
	var old_slot_id = equipment_slot_id
	var old_component = equipment_component
	
	equipment_selection_mode = true
	equipment_slot_id = slot_id
	self.equipment_component = equipment_comp
	_equip_item(item_id)
	
	# Restore previous state (equip_item will reset it anyway, but just in case)
	equipment_selection_mode = old_selection_mode
	equipment_slot_id = old_slot_id
	equipment_component = old_component
	
	print("✅ InventoryComponent: Auto-equipped ", item_id, " to slot ", slot_id)

func _unhandled_input(event):
	"""Handle keyboard input for equipment selection"""
	if not visible:
		return
	
	# Allow Enter key to equip selected item
	# Table обрабатывает Enter через DOUBLE_CLICK сигнал, но мы можем добавить дополнительную обработку
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.is_action_pressed("ui_accept"):
			# Table автоматически обрабатывает Enter через DOUBLE_CLICK сигнал
			# Но мы можем добавить дополнительную логику здесь, если нужно
			get_viewport().set_input_as_handled()

func _notification(what):
	"""Updates inventory when shown"""
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		# Обновляем item_list при показе компонента
		_update_item_list_from_active_panel()
		_load_inventory_items()
		_refresh_display()
	
	# Также обновляем при изменении дерева сцены (когда панели переключаются)
	if what == NOTIFICATION_READY:
		# Подключаемся к PanelManager для отслеживания переключения панелей
		var panel_manager = get_node_or_null("PanelManager")
		if panel_manager and panel_manager.has_signal("panel_changed"):
			if not panel_manager.panel_changed.is_connected(_on_panel_changed):
				panel_manager.panel_changed.connect(_on_panel_changed)

func _on_panel_changed():
	"""Вызывается при переключении панели в PanelManager"""
	# Определяем активную панель и устанавливаем соответствующий фильтр
	var panel_manager = get_node_or_null("PanelManager")
	if not panel_manager:
		return
	
	var hbox = panel_manager.get_node_or_null("HBoxContainer")
	if not hbox:
		return
	
	# Находим видимую панель и устанавливаем фильтр
	for child in hbox.get_children():
		if child is PanelContainer and child.visible:
			var panel_name = child.name
			match panel_name:
				"AllPanel":
					set_filter_by_panel(FilterType.ALL)
				"ArmorPanel":
					set_filter_by_panel(FilterType.ARMOR)
				"WeaponPanel":
					set_filter_by_panel(FilterType.WEAPON)
				"MiscPanel":
					set_filter_by_panel(FilterType.MISC)
			break
	
	# Обновляем item_list и обновляем отображение
	_update_item_list_from_active_panel()
	_refresh_display()

