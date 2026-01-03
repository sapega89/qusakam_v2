extends BaseMenuComponent

# Game manager и item_database доступны из BaseMenuComponent

# Equipment categories and their display names
var equipment_categories = [
	{"id": "sword", "name": "Swords", "icon_path": "res://release/assets/textures/ui/items/lorc/crossed-swords.png"},
	{"id": "polearm", "name": "Polearms", "icon_path": "res://release/assets/textures/ui/items/lorc/stone-spear.png"},
	{"id": "dagger", "name": "Daggers", "icon_path": "res://release/assets/textures/ui/items/delapouite/sword-brandish.png"},
	{"id": "axe", "name": "Axes", "icon_path": "res://release/assets/textures/ui/items/lorc/crossed-swords.png"},
	{"id": "bow", "name": "Bows", "icon_path": "res://release/assets/textures/ui/items/lorc/crossed-swords.png"},
	{"id": "staff", "name": "Staves", "icon_path": "res://release/assets/textures/ui/items/lorc/crystal-wand.png"},
	{"id": "shield", "name": "Shields", "icon_path": "res://release/assets/textures/ui/items/delapouite/armored-boomerang.png"},
	{"id": "head", "name": "Head", "icon_path": "res://release/assets/textures/ui/items/delapouite/armored-boomerang.png"},
	{"id": "body", "name": "Body", "icon_path": "res://release/assets/textures/ui/items/delapouite/armored-boomerang.png"},
	{"id": "accessory_1", "name": "Accessories", "icon_path": "res://release/assets/textures/ui/items/delapouite/mineral-pearls.svg"},
	{"id": "accessory_2", "name": "Accessories", "icon_path": "res://release/assets/textures/ui/items/delapouite/mineral-pearls.svg"}
]

# UI elements
@onready var character_name_label: Label
@onready var category_list: VBoxContainer
@onready var equipped_list: VBoxContainer
@onready var optimize_button: Button
@onready var unequip_all_button: Button
@onready var attributes_panel: Panel

# Selected category
var selected_category_index: int = 0
var category_rows: Array[Control] = []
var equipped_rows: Array[Control] = []

func _initialize_component():
	"""Инициализация компонента экипировки (вызывается из BaseMenuComponent._ready)"""
	# BaseMenuComponent уже получил game_manager и item_database
	
	# Create UI structure
	create_equipment_ui()
	
	# Update display
	update_display()

func create_equipment_ui():
	"""Create the equipment UI structure matching the reference image"""
	# Main container
	var main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.set_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 5)
	add_child(main_container)
	
	# Top section: Character name and icon
	var top_section = HBoxContainer.new()
	top_section.name = "TopSection"
	top_section.custom_minimum_size = Vector2(0, 35)
	
	character_name_label = Label.new()
	character_name_label.name = "CharacterNameLabel"
	character_name_label.text = "Character Name"
	character_name_label.add_theme_font_size_override("font_size", 20)
	character_name_label.add_theme_color_override("font_color", Color.WHITE)
	character_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_section.add_child(character_name_label)
	
	# Equipment icon (shield with sword)
	var equipment_icon = TextureRect.new()
	equipment_icon.name = "EquipmentIcon"
	equipment_icon.custom_minimum_size = Vector2(24, 24)
	equipment_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	equipment_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Use a simple icon or placeholder
	var icon_texture = null
	var icon_path = "res://release/assets/textures/ui/items/delapouite/armored-boomerang.png"
	if ResourceLoader.exists(icon_path):
		icon_texture = load(icon_path)
	else:
		# Виводимо попередження тільки в debug режимі, щоб не засмічувати консоль
		if OS.is_debug_build():
			push_warning("EquipmentComponent: Icon file not found: " + icon_path)
	if icon_texture:
		equipment_icon.texture = icon_texture
	top_section.add_child(equipment_icon)
	
	main_container.add_child(top_section)
	
	# Middle section: Two columns (Categories left, Equipped items right)
	var middle_section = HBoxContainer.new()
	middle_section.name = "MiddleSection"
	middle_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle_section.add_theme_constant_override("separation", 10)
	
	# Left: Category list
	var left_panel = Panel.new()
	left_panel.name = "CategoryPanel"
	left_panel.custom_minimum_size = Vector2(200, 0)
	left_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	
	# Remove ScrollContainer - use direct VBoxContainer
	category_list = VBoxContainer.new()
	category_list.name = "CategoryList"
	category_list.set_anchors_preset(Control.PRESET_FULL_RECT)
	category_list.set_offsets_preset(Control.PRESET_FULL_RECT)
	category_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_list.add_theme_constant_override("separation", 1)
	
	left_panel.add_child(category_list)
	middle_section.add_child(left_panel)
	
	# Right: Equipped items list
	var right_panel = Panel.new()
	right_panel.name = "EquippedPanel"
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Remove ScrollContainer - use direct VBoxContainer
	equipped_list = VBoxContainer.new()
	equipped_list.name = "EquippedList"
	equipped_list.set_anchors_preset(Control.PRESET_FULL_RECT)
	equipped_list.set_offsets_preset(Control.PRESET_FULL_RECT)
	equipped_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipped_list.add_theme_constant_override("separation", 1)
	
	right_panel.add_child(equipped_list)
	middle_section.add_child(right_panel)
	
	main_container.add_child(middle_section)
	
	# Bottom section: Buttons and Attributes
	var bottom_section = VBoxContainer.new()
	bottom_section.name = "BottomSection"
	bottom_section.add_theme_constant_override("separation", 5)
	
	# Buttons
	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.name = "ButtonsHBox"
	buttons_hbox.add_theme_constant_override("separation", 5)
	
	optimize_button = Button.new()
	optimize_button.name = "OptimizeButton"
	optimize_button.text = "Optimize"
	optimize_button.custom_minimum_size = Vector2(100, 32)
	optimize_button.pressed.connect(_on_optimize_pressed)
	buttons_hbox.add_child(optimize_button)
	
	unequip_all_button = Button.new()
	unequip_all_button.name = "UnequipAllButton"
	unequip_all_button.text = "Unequip All"
	unequip_all_button.custom_minimum_size = Vector2(100, 32)
	unequip_all_button.pressed.connect(_on_unequip_all_pressed)
	buttons_hbox.add_child(unequip_all_button)
	
	bottom_section.add_child(buttons_hbox)
	
	# Attributes panel
	attributes_panel = Panel.new()
	attributes_panel.name = "AttributesPanel"
	attributes_panel.custom_minimum_size = Vector2(0, 140)
	
	var attributes_vbox = VBoxContainer.new()
	attributes_vbox.name = "AttributesVBox"
	attributes_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	attributes_vbox.set_offsets_preset(Control.PRESET_FULL_RECT)
	attributes_vbox.add_theme_constant_override("separation", 3)
	
	var attributes_title = Label.new()
	attributes_title.name = "AttributesTitle"
	attributes_title.text = "Attributes"
	attributes_title.add_theme_font_size_override("font_size", 14)
	attributes_title.add_theme_color_override("font_color", Color.WHITE)
	attributes_vbox.add_child(attributes_title)
	
	# Attributes in two columns
	var attributes_columns = HBoxContainer.new()
	attributes_columns.name = "AttributesColumns"
	attributes_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	attributes_columns.add_theme_constant_override("separation", 30)
	
	# Left column
	var left_attributes = VBoxContainer.new()
	left_attributes.name = "LeftAttributes"
	left_attributes.add_theme_constant_override("separation", 2)
	create_attribute_row(left_attributes, "Max. HP", "❤️")
	create_attribute_row(left_attributes, "Phys. Atk.", "⚔️")
	create_attribute_row(left_attributes, "Phys. Def.", "🛡️")
	create_attribute_row(left_attributes, "Accuracy", "🎯")
	create_attribute_row(left_attributes, "Critical", "⭐")
	attributes_columns.add_child(left_attributes)
	
	# Right column
	var right_attributes = VBoxContainer.new()
	right_attributes.name = "RightAttributes"
	right_attributes.add_theme_constant_override("separation", 2)
	create_attribute_row(right_attributes, "Max. SP", "💙")
	create_attribute_row(right_attributes, "Elem. Atk.", "✨")
	create_attribute_row(right_attributes, "Elem. Def.", "🔰")
	create_attribute_row(right_attributes, "Speed", "👟")
	create_attribute_row(right_attributes, "Evasion", "💨")
	attributes_columns.add_child(right_attributes)
	
	attributes_vbox.add_child(attributes_columns)
	attributes_panel.add_child(attributes_vbox)
	bottom_section.add_child(attributes_panel)
	
	main_container.add_child(bottom_section)
	
	# Create category and equipped item rows
	create_category_and_equipped_rows()

func create_category_and_equipped_rows():
	"""Create rows for categories and equipped items"""
	if not category_list or not equipped_list:
		return
	
	# Clear existing rows
	for row in category_rows:
		if is_instance_valid(row):
			row.queue_free()
	for row in equipped_rows:
		if is_instance_valid(row):
			row.queue_free()
	category_rows.clear()
	equipped_rows.clear()
	
	# Create rows for each category
	for i in range(equipment_categories.size()):
		var category = equipment_categories[i]
		
		# Create category row (left side)
		var category_row = create_category_row(category, i)
		category_list.add_child(category_row)
		category_rows.append(category_row)
		
		# Create equipped item row (right side)
		var equipped_row = create_equipped_row(category.id, i)
		equipped_list.add_child(equipped_row)
		equipped_rows.append(equipped_row)
	
	# Select first category
	if equipment_categories.size() > 0:
		select_category(0)

func create_category_row(category: Dictionary, index: int) -> Control:
	"""Create a row for category list (left side)"""
	var row = Panel.new()
	row.name = "CategoryRow_" + category.id
	row.custom_minimum_size = Vector2(0, 24)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var hbox = HBoxContainer.new()
	hbox.name = "HBox"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.set_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 6)
	
	# Icon
	var icon_rect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.custom_minimum_size = Vector2(20, 20)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Перевіряємо, чи файл існує перед завантаженням
	var icon_texture = null
	if ResourceLoader.exists(category.icon_path):
		icon_texture = load(category.icon_path)
	else:
		# Виводимо попередження тільки в debug режимі, щоб не засмічувати консоль
		if OS.is_debug_build():
			push_warning("EquipmentComponent: Icon file not found: " + category.icon_path)
	if icon_texture:
		icon_rect.texture = icon_texture
	hbox.add_child(icon_rect)
	
	# Category name
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = category.name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)
	
	row.add_child(hbox)
	
	# Make clickable
	row.gui_input.connect(_on_category_row_clicked.bind(index))
	
	return row

func create_equipped_row(slot_id: String, _index: int) -> Control:
	"""Create a row for equipped item (right side)"""
	var row = Panel.new()
	row.name = "EquippedRow_" + slot_id
	row.custom_minimum_size = Vector2(0, 24)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var hbox = HBoxContainer.new()
	hbox.name = "HBox"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.set_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 6)
	
	# Icon (will be updated)
	var icon_rect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.custom_minimum_size = Vector2(20, 20)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon_rect)
	
	# Item name (will be updated)
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = "None"
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)
	
	row.add_child(hbox)
	
	# Make clickable to open inventory
	row.gui_input.connect(_on_equipped_row_clicked.bind(slot_id))
	
	return row

func _on_category_row_clicked(event: InputEvent, index: int):
	"""Handle click on category row"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		select_category(index)

func _on_equipped_row_clicked(event: InputEvent, slot_id: String):
	"""Handle click on equipped item row"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_inventory_for_slot(slot_id)

func select_category(index: int):
	"""Select an equipment category"""
	if index < 0 or index >= equipment_categories.size():
		return
	
	selected_category_index = index
	
	# Update row highlights
	for i in range(category_rows.size()):
		var row = category_rows[i]
		if is_instance_valid(row):
			if i == index:
				# Highlight selected row
				row.modulate = Color(1.0, 1.0, 0.9, 1.0)
				# Add background color
				var style_box = StyleBoxFlat.new()
				style_box.bg_color = Color(0.3, 0.3, 0.3, 0.5)
				row.add_theme_stylebox_override("panel", style_box)
			else:
				# Reset to normal
				row.modulate = Color.WHITE
				row.remove_theme_stylebox_override("panel")

func update_equipped_rows():
	"""Update all equipped item rows"""
	if not game_manager:
		return
	
	for i in range(equipped_rows.size()):
		if i >= equipment_categories.size():
			break
		
		var slot_id = equipment_categories[i].id
		var row = equipped_rows[i]
		if not is_instance_valid(row):
			continue
		
		var hbox = row.get_node_or_null("HBox")
		if not hbox:
			continue
		
		var icon_rect = hbox.get_node_or_null("Icon")
		var name_label = hbox.get_node_or_null("NameLabel")
		
		var equipped_item = game_manager.player_state.equipment.get(slot_id, null)
		
		if equipped_item and item_database:
			# Item is equipped
			var item_id = equipped_item.get("id", "")
			var item_name = equipped_item.get("name", "Unknown")
			
			if name_label:
				name_label.text = item_name
				name_label.add_theme_color_override("font_color", Color.WHITE)
			
			if icon_rect and item_database:
				var icon = item_database.get_item_icon(item_id)
				if icon:
					icon_rect.texture = icon
		else:
			# No item equipped
			if name_label:
				name_label.text = "None"
				name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			
			if icon_rect:
				icon_rect.texture = null

func update_display():
	"""Update all equipment display"""
	if not game_manager:
		return
	
	# Update character name
	if character_name_label:
		var character = game_manager.get_active_character()
		if character:
			character_name_label.text = character.name
		else:
			character_name_label.text = "Player"
	
	# Create rows if not created
	if category_rows.size() == 0:
		create_category_and_equipped_rows()
	
	# Update equipped items
	update_equipped_rows()
	
	# Update attributes
	update_attributes()

func update_attributes():
	"""Update attribute values"""
	if not game_manager:
		print("⚠️ EquipmentComponent: game_manager is null in update_attributes")
		return
	
	if not attributes_panel:
		print("⚠️ EquipmentComponent: attributes_panel is null in update_attributes")
		return
	
	# Get attribute rows
	var left_attributes = attributes_panel.get_node_or_null("AttributesVBox/AttributesColumns/LeftAttributes")
	var right_attributes = attributes_panel.get_node_or_null("AttributesVBox/AttributesColumns/RightAttributes")
	
	if not left_attributes:
		print("⚠️ EquipmentComponent: left_attributes not found")
		return
	
	if not right_attributes:
		print("⚠️ EquipmentComponent: right_attributes not found")
		return
	
	# Calculate values
	var max_hp = game_manager.calculate_max_health()
	var phys_atk = game_manager.calculate_physical_damage()
	var phys_def = game_manager.calculate_physical_defense()
	var magic_atk = game_manager.calculate_magic_damage()
	var magic_def = game_manager.calculate_magic_defense()
	var speed_mult = game_manager.calculate_attack_speed()
	var dodge_chance = game_manager.calculate_dodge_chance()
	
	print("📊 EquipmentComponent: Calculated stats - HP: ", max_hp, ", Phys. Atk: ", phys_atk, ", Phys. Def: ", phys_def)
	
	# Left column attributes
	update_attribute_value(left_attributes, "Max. HP", str(max_hp))
	update_attribute_value(left_attributes, "Phys. Atk.", str(phys_atk))
	update_attribute_value(left_attributes, "Phys. Def.", str(phys_def))
	update_attribute_value(left_attributes, "Accuracy", "88")  # Placeholder
	update_attribute_value(left_attributes, "Critical", "80")  # Placeholder
	
	# Right column attributes
	update_attribute_value(right_attributes, "Max. SP", "40")  # Placeholder
	update_attribute_value(right_attributes, "Elem. Atk.", str(magic_atk))
	update_attribute_value(right_attributes, "Elem. Def.", str(magic_def))
	update_attribute_value(right_attributes, "Speed", str(int(speed_mult * 100)))
	update_attribute_value(right_attributes, "Evasion", str(int(dodge_chance * 100)))

func update_attribute_value(container: VBoxContainer, attribute_name: String, value: String):
	"""Update value for a specific attribute"""
	# Replace both spaces and dots with underscores to match create_attribute_row
	var row_name = "AttributeRow_" + attribute_name.replace(" ", "_").replace(".", "_")
	var row = container.get_node_or_null(row_name)
	if row:
		var value_label = row.get_node_or_null("ValueLabel")
		if value_label:
			value_label.text = value
			print("✅ EquipmentComponent: Updated ", attribute_name, " = ", value)
		else:
			print("⚠️ EquipmentComponent: ValueLabel not found for ", attribute_name, " (row: ", row_name, ")")
	else:
		print("⚠️ EquipmentComponent: Row not found for ", attribute_name, " (looking for: ", row_name, ")")
		# Debug: list all children
		for child in container.get_children():
			print("  - Child: ", child.name)

func create_attribute_row(container: VBoxContainer, label_text: String, icon: String):
	"""Create a row for an attribute"""
	var row = HBoxContainer.new()
	# Replace both spaces and dots with underscores for consistent naming
	row.name = "AttributeRow_" + label_text.replace(" ", "_").replace(".", "_")
	row.add_theme_constant_override("separation", 6)
	
	var icon_label = Label.new()
	icon_label.name = "IconLabel"
	icon_label.text = icon
	icon_label.custom_minimum_size = Vector2(20, 0)
	row.add_child(icon_label)
	
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(80, 0)
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	row.add_child(name_label)
	
	var value_label = Label.new()
	value_label.name = "ValueLabel"
	value_label.text = "0"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(value_label)
	
	container.add_child(row)

func _open_inventory_for_slot(slot_id: String):
	"""Open inventory in equipment selection mode for specified slot"""
	print("🎯 EquipmentComponent: Opening inventory for slot: ", slot_id)
	
	# Используем группы для поиска game_menu (вместо get_node("../../.."))
	var game_menu = get_tree().get_first_node_in_group("game_menu")
	if not game_menu:
		# Fallback: ищем через owner
		game_menu = owner
		if not game_menu:
			print("⚠️ EquipmentComponent: GameMenu not found!")
			return
	
	# Запрашиваем открытие вкладки inventory через сигнал
	request_tab.emit("inventory")
	print("✅ EquipmentComponent: Requested inventory tab via signal")
	
	# Wait a frame for inventory to be visible
	await get_tree().process_frame
	
	# Находим inventory component через группы или поиск
	var inventory_content = game_menu.find_child("InventoryContent", true, false)
	if not inventory_content:
		print("⚠️ EquipmentComponent: InventoryContent not found!")
		return
	
	var inventory_component = inventory_content.find_child("InventoryComponent", false, false)
	if not inventory_component:
		print("⚠️ EquipmentComponent: InventoryComponent not found!")
		return
	
	# Set equipment selection mode (прямой вызов, но это внутренний метод компонента)
	if inventory_component.has_method("set_equipment_selection_mode"):
		inventory_component.set_equipment_selection_mode(true, slot_id, self)
		print("✅ EquipmentComponent: Set equipment selection mode for slot: ", slot_id)
	else:
		print("⚠️ EquipmentComponent: set_equipment_selection_mode method not found!")

func _on_optimize_pressed():
	"""Optimize equipment (auto-equip best items)"""
	print("⚙️ EquipmentComponent: Optimize pressed")
	if not game_manager or not item_database:
		print("⚠️ EquipmentComponent: GameManager or ItemDatabase not found!")
		return
	
	# Get all items from inventory
	var inventory_items = _get_equipment_from_inventory()
	if inventory_items.is_empty():
		print("⚠️ EquipmentComponent: No equipment items in inventory!")
		return
	
	# Find best item for each slot
	var optimized_equipment = {}
	var used_items = []  # Track items already equipped to avoid duplicates
	
	# First, handle non-accessory slots
	for category in equipment_categories:
		var slot_id = category.id
		
		# Skip accessories for now - handle them separately
		if slot_id == "accessory_1" or slot_id == "accessory_2":
			continue
		
		var best_item = _find_best_item_for_slot(slot_id, inventory_items, used_items)
		
		if best_item:
			optimized_equipment[slot_id] = {
				"id": best_item.id,
				"name": item_database.get_item_name(best_item.id, "en"),
				"data": best_item.item_data
			}
			used_items.append(best_item.id)
			print("✅ EquipmentComponent: Best item for ", slot_id, ": ", best_item.id, " (total stats: ", _get_item_total_stats(best_item), ")")
		else:
			optimized_equipment[slot_id] = null
	
	# Handle accessory slots separately to avoid duplicates
	var accessory_slots = ["accessory_1", "accessory_2"]
	for slot_id in accessory_slots:
		var best_item = _find_best_item_for_slot(slot_id, inventory_items, used_items)
		
		if best_item:
			optimized_equipment[slot_id] = {
				"id": best_item.id,
				"name": item_database.get_item_name(best_item.id, "en"),
				"data": best_item.item_data
			}
			used_items.append(best_item.id)
			print("✅ EquipmentComponent: Best item for ", slot_id, ": ", best_item.id, " (total stats: ", _get_item_total_stats(best_item), ")")
		else:
			optimized_equipment[slot_id] = null
	
	# Apply optimized equipment
	game_manager.player_state.equipment = optimized_equipment
	
	# Update active character equipment and bonuses
	if game_manager.active_character:
		game_manager.active_character.equipment = optimized_equipment.duplicate()
		game_manager.active_character.update_equipment_bonuses()
	
	# Update display
	update_equipped_rows()
	update_attributes()
	
	# Update player stats in scene if player exists
	var player = game_manager.get_current_player()
	if player and player.has_method("apply_stats_from_game_manager"):
		player.apply_stats_from_game_manager()
	
	print("✅ EquipmentComponent: Equipment optimized!")

func _get_equipment_from_inventory() -> Array:
	"""Get all equipment items from inventory"""
	var equipment_items = []
	
	if not game_manager or not item_database:
		return equipment_items
	
	# Use InventoryManager if available
	var inventory_manager = game_manager.inventory_manager
	if not inventory_manager:
		return equipment_items
	
	# Get items from inventory manager
	var items_dict = inventory_manager.get_items_dict()
	for item_id in items_dict:
		var count = items_dict[item_id]
		if count > 0:
			var item_data = item_database.get_item(item_id)
			if not item_data.is_empty():
				var item_type = item_data.get("type", "")
				# Only get weapons and armor
				if item_type == "weapon" or item_type == "armor":
					equipment_items.append({
						"id": item_id,
						"item_data": item_data,
						"count": count
					})
	
	return equipment_items

func _get_item_total_stats(item: Dictionary) -> int:
	"""Calculate total stats value for an item (attack + defense + magic)"""
	var item_data = item.get("item_data", {})
	var stats = item_data.get("stats", {})
	
	var attack = stats.get("attack", 0)
	var defense = stats.get("defense", 0)
	var magic = stats.get("magic", 0)
	
	return attack + defense + magic

func _find_best_item_for_slot(slot_id: String, items: Array, used_items: Array = []):
	"""Find the best item for a specific slot based on total stats. Returns Dictionary or null."""
	var best_item = null
	var best_stats = -1
	
	for item in items:
		# Skip if item is already used
		if item.id in used_items:
			continue
		
		var item_data = item.get("item_data", {})
		var item_category = item_data.get("category", "")
		
		# Check if item can be equipped in this slot
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
			var total_stats = _get_item_total_stats(item)
			if total_stats > best_stats:
				best_stats = total_stats
				best_item = item
	
	return best_item

func _on_unequip_all_pressed():
	"""Unequip all items"""
	print("⚙️ EquipmentComponent: Unequip All pressed")
	if not game_manager:
		return
	
	# Clear all equipment slots
	for slot_id in game_manager.player_state.equipment.keys():
		game_manager.player_state.equipment[slot_id] = null
	
	# Update active character equipment and bonuses
	if game_manager.active_character:
		for slot_id in game_manager.active_character.equipment.keys():
			game_manager.active_character.equipment[slot_id] = null
		game_manager.active_character.update_equipment_bonuses()
	
	# Update display and attributes
	update_equipped_rows()
	update_attributes()
	
	# Update player stats in scene if player exists
	var player = game_manager.get_current_player()
	if player and player.has_method("apply_stats_from_game_manager"):
		player.apply_stats_from_game_manager()
	
	print("✅ EquipmentComponent: All items unequipped")
