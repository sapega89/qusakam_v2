extends MarginContainer
class_name PanelManager

## Универсальный шаблон для управления панелями с кнопками
## Автоматически подключает кнопки к соответствующим панелям
##
## РЕКОМЕНДУЕМАЯ СТРУКТУРА:
## MenuRoot (MarginContainer) <- скрипт PanelManager.gd
##  ├─ ButtonsContainer (HBoxContainer/VBoxContainer)
##  │    ├─ Button1
##  │    ├─ Button2
##  │    └─ ...
##  └─ PanelsContainer (PanelContainer/VBoxContainer)
##       ├─ Panel1
##       ├─ Panel2
##       └─ ...
##
## ПРИМЕЧАНИЕ: Для курсора добавьте CursorIndicator в сцену отдельно
##
## ИСПОЛЬЗОВАНИЕ:
## Вариант 1 (рекомендуемый): Используйте стандартные имена контейнеров
##   - ButtonsContainer для кнопок
##   - PanelsContainer для панелей
##   Скрипт автоматически найдет их и соберет кнопки/панели
##
## Вариант 2: Укажите массивы buttons и panels в Inspector вручную
##
## Вариант 3: Укажите пути к контейнерам через экспортированные переменные

## Путь к контейнеру с кнопками (если не указан, ищется автоматически)
@export var buttons_container_path: NodePath = NodePath()

## Путь к контейнеру с панелями (если не указан, ищется автоматически)
@export var panels_container_path: NodePath = NodePath()

## Массив кнопок (заполняется автоматически или вручную в Inspector)
## ПРИОРИТЕТ 1: Если заполнен вручную, используется вместо автоматического поиска
@export var buttons: Array[Button] = []

## Массив панелей (заполняется автоматически или вручную в Inspector)
## ПРИОРИТЕТ 1: Если заполнен вручную, используется вместо автоматического поиска
@export var panels: Array[PanelContainer] = []

## Прямые ссылки на кнопки через unique_name_in_owner (ПРИОРИТЕТ 0 - самый высокий)
## Если эти переменные заполнены, они используются вместо автоматического поиска
## ВАЖНО: Використовуємо звичайні змінні (не @onready), щоб уникнути помилок
## якщо PanelManager використовується в різних контекстах (наприклад, в inventory_component.tscn)
var inventory_button: Button = null
var equipment_button: Button = null
var world_map_button: Button = null
var misc_button: Button = null
var journal_button: Button = null
var skills_button: Button = null
var status_button: Button = null

## Прямые ссылки на панели через unique_name_in_owner (ПРИОРИТЕТ 0 - самый высокий)
var inventory_panel: PanelContainer = null
var equipment_panel: PanelContainer = null
var world_map_panel: PanelContainer = null
var misc_panel: PanelContainer = null
var journal_panel: PanelContainer = null
var skills_panel: PanelContainer = null
var status_panel: PanelContainer = null

# Для inventory_component.tscn - інші панелі
var all_button: Button = null
var armor_button: Button = null
var weapon_button: Button = null
var all_panel: PanelContainer = null
var armor_panel: PanelContainer = null
var weapon_panel: PanelContainer = null

## Имя группы для поиска кнопок (ПРИОРИТЕТ 2)
## Кнопки в этой группе будут найдены автоматически, даже если они в разных местах сцены
## Пример: добавьте кнопки в группу "tab_buttons" через Inspector > Groups
@export var buttons_group: String = "tab_buttons"

## Использовать поиск по группам (если true, ищет кнопки в группе buttons_group)
@export var use_group_search: bool = false

## Использовать поиск по метаданным (если true, ищет кнопки с metadata["panel_index"] или metadata["panel_name"])
## Кнопки должны иметь metadata с ключом "panel_index" (int) или "panel_name" (String)
@export var use_metadata_search: bool = false

## Текущая активная кнопка
var current_active_button: Button = null

func _ready() -> void:
	# Затримка для забезпечення того, що всі панелі вже додані (якщо вони додаються динамічно)
	# Особливо важливо, якщо панелі додаються через game_menu_content.tscn
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame  # Додаткова затримка для динамічно доданих панелей
	
	# Спочатку намагаємося знайти посилання через unique_name_in_owner (без помилок, якщо не знайдено)
	_try_find_direct_references()
	
	# ПРИОРИТЕТ 0: Собираем кнопки и панели из прямых ссылок через unique_name_in_owner
	_collect_from_direct_references()
	
	# Автоматически собираем кнопки и панели из контейнеров, если массивы пусты
	if buttons.is_empty() or panels.is_empty():
		print("PanelManager: Прямые ссылки не заполнили массивы, используем автоматический поиск...")
		_collect_from_containers()
	
	# Если используется поиск по группам или метаданным, применяем его
	if use_group_search and buttons.is_empty():
		_collect_buttons_from_group()
	if use_metadata_search and buttons.is_empty():
		_collect_buttons_by_metadata()
	
	# ПРАВИЛО ИМЕНОВАНИЯ: Автоматически сопоставляем кнопки и панели по именам
	# Кнопка: "InventoryButton" → Панель: "InventoryPanel"
	# Кнопка: "EquipmentButton" → Панель: "EquipmentPanel"
	# НЕ викликаємо, якщо панелі вже зібрані через прямі посилання в правильному порядку
	if buttons.size() == panels.size() and buttons.size() > 0:
		# Якщо кількість збігається і всі панелі знайдені, просто впорядковуємо їх
		_order_buttons_and_panels()
	else:
		_match_buttons_to_panels_by_naming_rule()
	
	# Перевіряємо на дублікати перед валідацією
	_remove_duplicate_panels()
	
	# Проверяем соответствие количества кнопок и панелей
	if not _validate_arrays():
		# Додаткова спроба зібрати панелі, якщо вони додалися пізніше
		await get_tree().process_frame
		if panels.is_empty() or buttons.size() != panels.size():
			_collect_from_containers()
			_match_buttons_to_panels_by_naming_rule()
			_remove_duplicate_panels()
		
		# Додаткова перевірка: якщо все ще не відповідає, спробуємо знайти панелі ще раз
		if buttons.size() != panels.size():
			print("PanelManager: Після першої спроби - кнопок: %d, панелей: %d" % [buttons.size(), panels.size()])
			# Шукаємо панелі безпосередньо в HBoxContainer ще раз (правильному - дочірньому для PanelManager)
			var hbox = get_node_or_null("./HBoxContainer")
			if not hbox:
				for child in get_children():
					if child is HBoxContainer:
						hbox = child
						break
			if hbox:
				var found_panels: Array[PanelContainer] = []
				var panel_names_found = []
				for child in hbox.get_children():
					# Пропускаємо TabButtons
					if child is VBoxContainer or child.name == "TabButtons":
						continue
					if child is PanelContainer:
						if child.name not in panel_names_found:
							found_panels.append(child)
							panel_names_found.append(child.name)
				if found_panels.size() > panels.size():
					print("PanelManager: Знайдено більше панелей при повторному пошуку: %d (було %d)" % [found_panels.size(), panels.size()])
					panels = found_panels
					_match_buttons_to_panels_by_naming_rule()
					_remove_duplicate_panels()
		
		if not _validate_arrays():
			# Виводимо детальну інформацію про помилку
			print("PanelManager: ДЕТАЛЬНА ДІАГНОСТИКА:")
			print("  Кнопки (%d):" % buttons.size())
			for i in range(buttons.size()):
				var btn = buttons[i]
				if btn:
					print("    [%d] %s (valid: %s)" % [i, btn.name, is_instance_valid(btn)])
				else:
					print("    [%d] null" % i)
			print("  Панелі (%d):" % panels.size())
			for i in range(panels.size()):
				var pnl = panels[i]
				if pnl:
					print("    [%d] %s (valid: %s)" % [i, pnl.name, is_instance_valid(pnl)])
				else:
					print("    [%d] null" % i)
			
			# Шукаємо всі панелі в HBoxContainer для порівняння (правильному - дочірньому для PanelManager)
			var hbox = get_node_or_null("./HBoxContainer")
			if not hbox:
				for child in get_children():
					if child is HBoxContainer:
						hbox = child
						break
			if hbox:
				print("  Всі панелі в HBoxContainer ('%s'):" % hbox.name)
				for child in hbox.get_children():
					if child is PanelContainer:
						print("    - %s (valid: %s)" % [child.name, is_instance_valid(child)])
			
			push_error("PanelManager: Количество кнопок (%d) не соответствует количеству панелей (%d)!" % [buttons.size(), panels.size()])
			return

	# Подключаем кнопки к методу show_panel
	_connect_buttons()
	
	# Показываем первую панель по умолчанию (отложенно, чтобы все узлы были готовы)
	if panels.size() > 0:
		# Используем await get_tree().process_frame чтобы убедиться, что все layout вычислен
		await get_tree().process_frame
		await get_tree().process_frame  # Два кадра для надежности
		
		# Ищем AllPanel явно, чтобы она всегда открывалась первой
		var all_panel: PanelContainer = null
		for panel in panels:
			if panel and panel.name == "AllPanel":
				all_panel = panel
				break
		
		# Если нашли AllPanel, показываем её, иначе показываем первую панель
		if all_panel:
			show_panel(all_panel)
		else:
			show_panel(panels[0])

## Пытается найти прямые ссылки через unique_name_in_owner (без ошибок, если не найдено)
func _try_find_direct_references() -> void:
	# Для vertical_menu.tscn - основні панелі меню
	inventory_button = get_node_or_null("%InventoryButton")
	equipment_button = get_node_or_null("%EquipmentButton")
	world_map_button = get_node_or_null("%WorldMapButton")
	misc_button = get_node_or_null("%MiscButton")
	journal_button = get_node_or_null("%JournalButton")
	skills_button = get_node_or_null("%SkillsButton")
	status_button = get_node_or_null("%StatusButton")
	
	inventory_panel = get_node_or_null("%InventoryPanel")
	equipment_panel = get_node_or_null("%EquipmentPanel")
	world_map_panel = get_node_or_null("%WorldMapPanel")
	misc_panel = get_node_or_null("%MiscPanel")
	journal_panel = get_node_or_null("%JournalPanel")
	skills_panel = get_node_or_null("%SkillsPanel")
	status_panel = get_node_or_null("%StatusPanel")
	
	# Для inventory_component.tscn - панелі інвентаря
	all_button = get_node_or_null("%AllButton")
	armor_button = get_node_or_null("%ArmorButton")
	weapon_button = get_node_or_null("%WeaponButton")
	all_panel = get_node_or_null("%AllPanel")
	armor_panel = get_node_or_null("%ArmorPanel")
	weapon_panel = get_node_or_null("%WeaponPanel")
	
	# MiscButton і MiscPanel можуть бути в обох контекстах, тому перевіряємо обидва
	if not misc_button:
		misc_button = get_node_or_null("%MiscButton")
	if not misc_panel:
		misc_panel = get_node_or_null("%MiscPanel")

## Собирает кнопки и панели из прямых ссылок через unique_name_in_owner
## ПРИОРИТЕТ 0 - самый высокий приоритет
func _collect_from_direct_references() -> void:
	buttons.clear()
	panels.clear()
	
	# Собираем кнопки из прямых ссылок (для vertical_menu.tscn)
	if inventory_button and is_instance_valid(inventory_button):
		buttons.append(inventory_button)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена кнопка через direct reference: InventoryButton")
	if equipment_button and is_instance_valid(equipment_button):
		buttons.append(equipment_button)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена кнопка через direct reference: EquipmentButton")
	if world_map_button and is_instance_valid(world_map_button):
		buttons.append(world_map_button)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена кнопка через direct reference: WorldMapButton")
	if misc_button and is_instance_valid(misc_button) and misc_button not in buttons:
		buttons.append(misc_button)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена кнопка через direct reference: MiscButton")
	if journal_button and is_instance_valid(journal_button):
		buttons.append(journal_button)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена кнопка через direct reference: JournalButton")
	if skills_button and is_instance_valid(skills_button):
		buttons.append(skills_button)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена кнопка через direct reference: SkillsButton")
	if status_button and is_instance_valid(status_button):
		buttons.append(status_button)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена кнопка через direct reference: StatusButton")
	
	# Собираем кнопки для inventory_component.tscn
	if all_button and is_instance_valid(all_button) and all_button not in buttons:
		buttons.append(all_button)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена кнопка через direct reference: AllButton")
	if armor_button and is_instance_valid(armor_button) and armor_button not in buttons:
		buttons.append(armor_button)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена кнопка через direct reference: ArmorButton")
	if weapon_button and is_instance_valid(weapon_button) and weapon_button not in buttons:
		buttons.append(weapon_button)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена кнопка через direct reference: WeaponButton")
	
	# Собираем панели из прямых ссылок (для vertical_menu.tscn)
	if inventory_panel and is_instance_valid(inventory_panel):
		panels.append(inventory_panel)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена панель через direct reference: InventoryPanel")
	if equipment_panel and is_instance_valid(equipment_panel):
		panels.append(equipment_panel)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена панель через direct reference: EquipmentPanel")
	if world_map_panel and is_instance_valid(world_map_panel):
		panels.append(world_map_panel)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена панель через direct reference: WorldMapPanel")
	if misc_panel and is_instance_valid(misc_panel) and misc_panel not in panels:
		panels.append(misc_panel)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена панель через direct reference: MiscPanel")
	if journal_panel and is_instance_valid(journal_panel):
		panels.append(journal_panel)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена панель через direct reference: JournalPanel")
	if skills_panel and is_instance_valid(skills_panel):
		panels.append(skills_panel)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена панель через direct reference: SkillsPanel")
	if status_panel and is_instance_valid(status_panel):
		panels.append(status_panel)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена панель через direct reference: StatusPanel")
	
	# Собираем панели для inventory_component.tscn
	if all_panel and is_instance_valid(all_panel) and all_panel not in panels:
		panels.append(all_panel)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена панель через direct reference: AllPanel")
	if armor_panel and is_instance_valid(armor_panel) and armor_panel not in panels:
		panels.append(armor_panel)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена панель через direct reference: ArmorPanel")
	if weapon_panel and is_instance_valid(weapon_panel) and weapon_panel not in panels:
		panels.append(weapon_panel)
		if OS.is_debug_build():
			print("PanelManager: ✅ Найдена панель через direct reference: WeaponPanel")
	
	if buttons.size() > 0 or panels.size() > 0:
		print("PanelManager: ✅ Собрано %d кнопок и %d панелей из прямых ссылок (unique_name_in_owner)" % [buttons.size(), panels.size()])
	else:
		print("PanelManager: ⚠️ Прямые ссылки не найдены, будет использован автоматический поиск")

## Автоматически собирает кнопки и панели из контейнеров
## УСТОЙЧИВО К НАСЛЕДОВАНИЮ СЦЕН: использует поиск по уникальным именам и группам
func _collect_from_containers() -> void:
	# Находим контейнер с кнопками
	var buttons_container: Node = null
	
	if not buttons_container_path.is_empty():
		# ПРИОРИТЕТ 1: Используем заданный путь (с проверкой валидности)
		buttons_container = _find_node_safe(buttons_container_path, Node)
	else:
		# ПРИОРИТЕТ 2: Поиск по уникальному имени (устойчиво к наследованию)
		buttons_container = _find_node_by_unique_name("TabButtons", Node)
		if not buttons_container:
			buttons_container = _find_node_by_unique_name("ButtonsContainer", Node)
		
		# ПРИОРИТЕТ 3: Поиск по группам
		if not buttons_container:
			buttons_container = _find_node_by_group("buttons_container", Node)
		
		# ПРИОРИТЕТ 4: Поиск по стандартному имени (может сломаться при наследовании)
		if not buttons_container:
			buttons_container = get_node_or_null("TabButtons")
		if not buttons_container:
			buttons_container = get_node_or_null("ButtonsContainer")
		
		# ПРИОРИТЕТ 5: Поиск по типу (последний резерв)
		if not buttons_container:
			buttons_container = _find_container_with_buttons()
	
	# Находим контейнер с панелями (аналогично кнопкам)
	var panels_container: Node = null
	
	if not panels_container_path.is_empty():
		# ПРИОРИТЕТ 1: Используем заданный путь (с проверкой валидности)
		panels_container = _find_node_safe(panels_container_path, Node)
	else:
		# ПРИОРИТЕТ 2: Поиск по уникальному имени
		panels_container = _find_node_by_unique_name("PanelsContainer", Node)
		if not panels_container:
			panels_container = _find_node_by_unique_name("ContentContainer", Node)
		
		# ПРИОРИТЕТ 3: Поиск по группам
		if not panels_container:
			panels_container = _find_node_by_group("panels_container", Node)
		
		# ПРИОРИТЕТ 4: Поиск по стандартному имени
		if not panels_container:
			panels_container = get_node_or_null("PanelsContainer")
		
		# ПРИОРИТЕТ 5: Поиск по типу (последний резерв)
		if not panels_container:
			panels_container = _find_container_with_panels()
	
	# Собираем кнопки из контейнера
	if buttons_container:
		buttons.clear()
		for child in buttons_container.get_children():
			if child is Button:
				buttons.append(child)
		print("PanelManager: Найдено %d кнопок в контейнере '%s'" % [buttons.size(), buttons_container.name])
	else:
		print("PanelManager: Контейнер с кнопками не найден!")
	
	# ВАЖНО: Завжди шукаємо панелі безпосередньо в HBoxContainer, який є прямим дочірнім елементом PanelManager
	# Це гарантує, що ми знайдемо правильні панелі (InventoryPanel, EquipmentPanel, тощо), а не панелі з дочірніх компонентів
	# Використовуємо "./HBoxContainer" щоб знайти саме дочірній HBoxContainer, а не рекурсивно
	var hbox = get_node_or_null("./HBoxContainer")
	if not hbox:
		# Fallback: якщо "./HBoxContainer" не працює, шукаємо в прямих дітях
		for child in get_children():
			if child is HBoxContainer:
				hbox = child
				break
	
	if hbox:
		panels.clear()
		var panel_names_seen = []
		var all_children = hbox.get_children()
		print("PanelManager: HBoxContainer знайдено ('%s'), всього дітей: %d" % [hbox.name, all_children.size()])
		for child in all_children:
			var child_type = child.get_class()
			# ВАЖНО: Пропускаємо TabButtons (VBoxContainer), шукаємо тільки PanelContainer
			if child is VBoxContainer or child.name == "TabButtons":
				if OS.is_debug_build():
					print("PanelManager: Пропускаємо TabButtons: ", child.name)
				continue
			if OS.is_debug_build():
				print("PanelManager: Перевіряємо дитину: ", child.name, " (тип: ", child_type, ", is PanelContainer: ", child is PanelContainer, ")")
			if child is PanelContainer:
				# Перевіряємо, чи не додали ми вже цю панель
				if child.name in panel_names_seen:
					if OS.is_debug_build():
						print("PanelManager: Пропускаємо дублікат панелі: ", child.name)
					continue
				panels.append(child)
				panel_names_seen.append(child.name)
				print("PanelManager: ✅ Найдена панель: ", child.name, " (is_instance_valid: ", is_instance_valid(child), ")")
		print("PanelManager: Найдено %d панелей в HBoxContainer" % [panels.size()])
		if OS.is_debug_build():
			print("PanelManager: Список панелей: ", panel_names_seen)
	elif panels_container:
		# Fallback: якщо HBoxContainer не знайдено, використовуємо panels_container
		panels.clear()
		var panel_names_seen = []
		for child in panels_container.get_children():
			if child is PanelContainer:
				# Перевіряємо, чи не додали ми вже цю панель
				if child.name in panel_names_seen:
					if OS.is_debug_build():
						print("PanelManager: Пропускаємо дублікат панелі: ", child.name)
					continue
				panels.append(child)
				panel_names_seen.append(child.name)
				if OS.is_debug_build():
					print("PanelManager: Найдена панель: ", child.name, " (is_instance_valid: ", is_instance_valid(child), ")")
		print("PanelManager: Найдено %d панелей в контейнере '%s'" % [panels.size(), panels_container.name])
		if OS.is_debug_build():
			print("PanelManager: Список панелей: ", panel_names_seen)
	else:
		print("PanelManager: Контейнер с панелями не найден!")

## Находит контейнер с кнопками (HBoxContainer или VBoxContainer)
func _find_container_with_buttons() -> Node:
	# Сначала ищем контейнер с именем TabButtons (стандартное имя в vertical_menu)
	# Может быть прямым потомком или внутри HBoxContainer
	var tab_buttons = get_node_or_null("TabButtons")
	if tab_buttons:
		return tab_buttons
	
	# Ищем внутри HBoxContainer
	var hbox = get_node_or_null("HBoxContainer")
	if hbox:
		tab_buttons = hbox.get_node_or_null("TabButtons")
		if tab_buttons:
			return tab_buttons
	
	# Ищем рекурсивно в дочерних узлах
	return _find_container_with_buttons_recursive(self)

## Рекурсивно ищет контейнер с кнопками
func _find_container_with_buttons_recursive(node: Node) -> Node:
	for child in node.get_children():
		if child is HBoxContainer or child is VBoxContainer:
			# Проверяем, есть ли в нем кнопки
			for grandchild in child.get_children():
				if grandchild is Button:
					return child
		# Рекурсивно ищем в дочерних узлах
		var result = _find_container_with_buttons_recursive(child)
		if result:
			return result
	return null

## Находит контейнер с панелями (PanelContainer, VBoxContainer или HBoxContainer)
func _find_container_with_panels() -> Node:
	# Ищем HBoxContainer, который содержит панели (стандартная структура для vertical_menu)
	var hbox = get_node_or_null("HBoxContainer")
	if hbox:
		# Проверяем, есть ли в нем панели
		for child in hbox.get_children():
			if child is PanelContainer:
				return hbox
	
	# Ищем в прямых потомках
	for child in get_children():
		if child is HBoxContainer:
			# Проверяем, есть ли в нем панели
			for grandchild in child.get_children():
				if grandchild is PanelContainer:
					return child
		if child is PanelContainer:
			return child
		if child is VBoxContainer:
			# Проверяем, есть ли в нем панели
			for grandchild in child.get_children():
				if grandchild is PanelContainer:
					return child
	# Рекурсивно ищем в дочерних узлах
	return _find_container_with_panels_recursive(self)

## Рекурсивно ищет контейнер с панелями
func _find_container_with_panels_recursive(node: Node) -> Node:
	for child in node.get_children():
		if child is HBoxContainer or child is VBoxContainer:
			# Проверяем, есть ли в нем панели
			for grandchild in child.get_children():
				if grandchild is PanelContainer:
					return child
		# Рекурсивно ищем в дочерних узлах
		var result = _find_container_with_panels_recursive(child)
		if result:
			return result
	return null

## Впорядковує кнопки та панелі в правильному порядку (якщо вони зібрані через прямі посилання)
func _order_buttons_and_panels() -> void:
	if buttons.size() != panels.size():
		return
	
	# Створюємо правильний порядок на основі імен
	var ordered_buttons: Array[Button] = []
	var ordered_panels: Array[PanelContainer] = []
	
	# Порядок: Inventory, Equipment, WorldMap, Misc, Journal, Skills, Status
	var button_order = [
		inventory_button, equipment_button, world_map_button, 
		misc_button, journal_button, skills_button, status_button
	]
	var panel_order = [
		inventory_panel, equipment_panel, world_map_panel,
		misc_panel, journal_panel, skills_panel, status_panel
	]
	
	# Додаємо тільки валідні кнопки та панелі
	for i in range(button_order.size()):
		if button_order[i] and is_instance_valid(button_order[i]) and button_order[i] in buttons:
			ordered_buttons.append(button_order[i])
		if panel_order[i] and is_instance_valid(panel_order[i]) and panel_order[i] in panels:
			ordered_panels.append(panel_order[i])
	
	if ordered_buttons.size() == buttons.size() and ordered_panels.size() == panels.size():
		buttons = ordered_buttons
		panels = ordered_panels
		print("PanelManager: ✅ Кнопки и панели упорядочены: %d пар" % buttons.size())

## Удаляет дублікати панелей за іменами
func _remove_duplicate_panels() -> void:
	var unique_panels: Array[PanelContainer] = []
	var seen_names: Array[String] = []
	
	print("PanelManager: _remove_duplicate_panels() - початкова кількість панелей: ", panels.size())
	for panel in panels:
		if not panel:
			if OS.is_debug_build():
				print("PanelManager: Пропускаємо null панель")
			continue
		var panel_name = panel.name
		if panel_name not in seen_names:
			unique_panels.append(panel)
			seen_names.append(panel_name)
			if OS.is_debug_build():
				print("PanelManager: Додано унікальну панель: ", panel_name)
		elif OS.is_debug_build():
			print("PanelManager: Видалено дублікат панелі: ", panel_name)
	
	if unique_panels.size() != panels.size():
		print("PanelManager: Видалено %d дублікатів панелей (було %d, стало %d)" % [panels.size() - unique_panels.size(), panels.size(), unique_panels.size()])
		if OS.is_debug_build():
			print("PanelManager: Список унікальних панелей: ", seen_names)
		panels = unique_panels
	else:
		if OS.is_debug_build():
			print("PanelManager: Дублікатів не знайдено, всі %d панелей унікальні" % panels.size())

## Проверяет соответствие массивов кнопок и панелей
func _validate_arrays() -> bool:
	# Фільтруємо null елементи
	var valid_buttons: Array[Button] = []
	var valid_panels: Array[PanelContainer] = []
	
	if OS.is_debug_build():
		print("PanelManager: Початок валідації - кнопок: ", buttons.size(), ", панелей: ", panels.size())
	
	for button in buttons:
		if button and is_instance_valid(button):
			valid_buttons.append(button)
		elif OS.is_debug_build():
			print("PanelManager: Кнопка не валідна: ", button, " (is_instance_valid: ", is_instance_valid(button) if button else "null", ")")
	
	for panel in panels:
		if panel and is_instance_valid(panel):
			valid_panels.append(panel)
			if OS.is_debug_build():
				print("PanelManager: Валідна панель: ", panel.name, " (is_instance_valid: ", is_instance_valid(panel), ")")
		elif OS.is_debug_build():
			print("PanelManager: Панель не валідна: ", panel, " (is_instance_valid: ", is_instance_valid(panel) if panel else "null", ")")
	
	# Оновлюємо масиви
	buttons = valid_buttons
	panels = valid_panels
	
	# Перевіряємо відповідність
	if buttons.size() != panels.size():
		push_warning("PanelManager: Після фільтрації кількість кнопок (%d) не відповідає кількості панелей (%d)!" % [buttons.size(), panels.size()])
		if OS.is_debug_build():
			print("PanelManager: Валідні кнопки (%d): " % valid_buttons.size(), valid_buttons.map(func(b): return b.name if b else "null"))
			print("PanelManager: Валідні панелі (%d): " % valid_panels.size(), valid_panels.map(func(p): return p.name if p else "null"))
			# Знаходимо панелі, які не мають відповідних кнопок
			var panel_names = valid_panels.map(func(p): return p.name if p else "null")
			var button_base_names = valid_buttons.map(func(b): 
				if b and b.name.ends_with("Button"):
					return b.name.substr(0, b.name.length() - 6) + "Panel"
				return ""
			)
			var unmatched_panels = []
			for panel_name in panel_names:
				var found = false
				for button_base in button_base_names:
					if panel_name == button_base:
						found = true
						break
				if not found:
					unmatched_panels.append(panel_name)
			if unmatched_panels.size() > 0:
				print("PanelManager: Панелі без відповідних кнопок: ", unmatched_panels)
		return false
	
	return true

## Подключает все кнопки к соответствующим панелям
func _connect_buttons() -> void:
	for i in range(buttons.size()):
		if buttons[i] and i < panels.size():
			# Используем замыкание для сохранения индекса
			var panel_index = i
			buttons[i].pressed.connect(func(): show_panel(panels[panel_index]))


func show_panel(panel_to_show: PanelContainer) -> void:
	"""Показывает указанную панель и скрывает все остальные"""
	if not panel_to_show:
		return
	
	# Находим индекс панели
	var panel_index = panels.find(panel_to_show)
	if panel_index == -1:
		push_warning("PanelManager: Панель не найдена в массиве panels!")
		return
	
	# Находим соответствующую кнопку
	var button_to_activate: Button = null
	if panel_index < buttons.size():
		button_to_activate = buttons[panel_index]
	
	# Собираем все кнопки кроме активной для сброса позиций
	var buttons_to_reset: Array[Button] = []
	for btn in buttons:
		if btn != button_to_activate:
			buttons_to_reset.append(btn)
	
	# Скрываем все панели
	for panel in panels:
		if panel:
			panel.visible = false
	
	# Показываем выбранную панель
	panel_to_show.visible = true
	
	current_active_button = button_to_activate
	
	# Уведомляем InventoryComponent о смене панели (если он есть)
	var inventory_component = get_parent()
	if inventory_component and inventory_component.has_method("_on_panel_changed"):
		inventory_component._on_panel_changed()

## Получает индекс текущей активной панели
func get_current_panel_index() -> int:
	if current_active_button:
		return buttons.find(current_active_button)
	return -1

## Переключает на панель по индексу
func switch_to_panel(index: int) -> void:
	if index >= 0 and index < panels.size():
		show_panel(panels[index])
	else:
		push_warning("PanelManager: Индекс %d вне диапазона! Доступно панелей: %d" % [index, panels.size()])

## Собирает кнопки из группы
func _collect_buttons_from_group() -> void:
	if buttons_group.is_empty():
		return
	
	var group_buttons = get_tree().get_nodes_in_group(buttons_group)
	buttons.clear()
	
	for node in group_buttons:
		if node is Button:
			buttons.append(node)
	
	if buttons.size() > 0:
		# Сортируем по порядку в дереве сцены для стабильности
		buttons.sort_custom(func(a, b): return a.get_index() < b.get_index())
		print("PanelManager: Найдено %d кнопок в группе '%s'" % [buttons.size(), buttons_group])

## Собирает кнопки по метаданным
func _collect_buttons_by_metadata() -> void:
	buttons.clear()
	
	# Ищем все кнопки в сцене
	var all_buttons: Array[Button] = []
	_find_all_buttons_recursive(self, all_buttons)
	
	# Фильтруем кнопки с метаданными
	var buttons_with_metadata: Array[Dictionary] = []
	for button in all_buttons:
		if button.has_meta("panel_index"):
			var panel_index = button.get_meta("panel_index")
			if panel_index is int:
				buttons_with_metadata.append({"button": button, "index": panel_index})
		elif button.has_meta("panel_name"):
			var panel_name = button.get_meta("panel_name")
			if panel_name is String:
				# Пытаемся найти соответствующий индекс панели по имени
				var panel_index = _find_panel_index_by_name(panel_name)
				if panel_index >= 0:
					buttons_with_metadata.append({"button": button, "index": panel_index})
	
	# Сортируем по индексу
	buttons_with_metadata.sort_custom(func(a, b): return a.index < b.index)
	
	# Добавляем кнопки в правильном порядке
	for item in buttons_with_metadata:
		buttons.append(item.button)
	
	if buttons.size() > 0:
		print("PanelManager: Найдено %d кнопок по метаданным" % buttons.size())

## Рекурсивно находит все кнопки в дереве узлов
func _find_all_buttons_recursive(node: Node, result: Array[Button]) -> void:
	if node is Button:
		result.append(node)
	
	for child in node.get_children():
		_find_all_buttons_recursive(child, result)

## Находит индекс панели по имени
func _find_panel_index_by_name(panel_name: String) -> int:
	for i in range(panels.size()):
		var panel = panels[i]
		if panel and (panel.name == panel_name or panel.name.begins_with(panel_name)):
			return i
	
	return -1

## Безопасный поиск узла по пути с проверкой валидности
## УСТОЙЧИВО К НАСЛЕДОВАНИЮ: если путь не работает, пытается найти по уникальному имени
func _find_node_safe(path: NodePath, expected_type: Variant = null) -> Node:
	if path.is_empty():
		return null
	
	var node = get_node_or_null(path)
	if not node:
		# Если путь не работает, пытаемся найти по имени узла
		var path_str = str(path)
		# Извлекаем имя узла из пути (последний элемент)
		var path_parts = path_str.split("/")
		if path_parts.size() > 0:
			var node_name = path_parts[path_parts.size() - 1]
			node = _find_node_by_unique_name(node_name, expected_type)
			if node:
				print("PanelManager: Путь '%s' не найден, но узел '%s' найден по уникальному имени" % [path_str, node_name])
	
	# Проверяем тип, если указан
	if node and expected_type != null:
		if not _is_node_of_type_panel_manager(node, expected_type):
			push_warning("PanelManager: Узел по пути '%s' имеет неправильный тип (ожидается %s)" % [path, str(expected_type)])
			return null
	
	return node

## Проверяет тип узла для PanelManager
func _is_node_of_type_panel_manager(node: Node, node_type: Variant) -> bool:
	if node_type is String:
		return node.is_class(node_type)
	elif node_type == Node:
		return true
	else:
		var type_str = str(node_type)
		if type_str.begins_with("<") and type_str.ends_with(">"):
			type_str = type_str.substr(1, type_str.length() - 2)
		if type_str.begins_with("class "):
			type_str = type_str.substr(6)
		return node.is_class(type_str)

## Находит узел по уникальному имени (unique_name_in_owner)
## УСТОЙЧИВО К НАСЛЕДОВАНИЮ: работает даже если структура изменилась
func _find_node_by_unique_name(unique_name: String, expected_type: Variant = null) -> Node:
	# Ищем в корне сцены (owner)
	var scene_root = get_tree().current_scene
	if not scene_root:
		scene_root = get_tree().root
	
	# Ищем узел с уникальным именем
	var found_node = scene_root.find_child(unique_name, true, false)
	if not found_node:
		# Пытаемся найти рекурсивно по имени
		found_node = _find_node_by_name_recursive_panel_manager(scene_root, unique_name)
	
	# Проверяем тип, если указан
	if found_node and expected_type != null:
		if not _is_node_of_type_panel_manager(found_node, expected_type):
			return null
	
	return found_node

## Рекурсивно ищет узел по имени для PanelManager
func _find_node_by_name_recursive_panel_manager(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	
	for child in node.get_children():
		var result = _find_node_by_name_recursive_panel_manager(child, node_name)
		if result:
			return result
	
	return null

## Находит узел по группе для PanelManager
## УСТОЙЧИВО К НАСЛЕДОВАНИЮ: узлы могут быть в разных местах, но в одной группе
func _find_node_by_group(group_name: String, expected_type: Variant = null) -> Node:
	var nodes_in_group = get_tree().get_nodes_in_group(group_name)
	
	for node in nodes_in_group:
		if expected_type == null or _is_node_of_type_panel_manager(node, expected_type):
			return node
	
	return null

## Автоматически сопоставляет кнопки и панели по правилу именования
## ПРАВИЛО: Кнопка заканчивается на "Button", панель заканчивается на "Panel"
## Пример: "InventoryButton" → "InventoryPanel", "EquipmentButton" → "EquipmentPanel"
func _match_buttons_to_panels_by_naming_rule() -> void:
	if buttons.is_empty():
		return
	
	# Якщо панелі не знайдені, спробуємо знайти їх безпосередньо в HBoxContainer (правильному - дочірньому для PanelManager)
	if panels.is_empty():
		var hbox = get_node_or_null("./HBoxContainer")
		if not hbox:
			for child in get_children():
				if child is HBoxContainer:
					hbox = child
					break
		if hbox:
			print("PanelManager: Панелі не знайдені, шукаємо в HBoxContainer ('%s')..." % hbox.name)
			var panel_names_seen = []
			for child in hbox.get_children():
				# Пропускаємо TabButtons
				if child is VBoxContainer or child.name == "TabButtons":
					continue
				if child is PanelContainer:
					# Перевіряємо, чи не додали ми вже цю панель
					if child.name in panel_names_seen:
						if OS.is_debug_build():
							print("PanelManager: Пропускаємо дублікат панелі: ", child.name)
						continue
					panels.append(child)
					panel_names_seen.append(child.name)
					print("PanelManager: Знайдено панель: ", child.name)
			print("PanelManager: Всього знайдено %d панелей" % [panels.size()])
			if OS.is_debug_build():
				print("PanelManager: Список панелей: ", panel_names_seen)
	
	if panels.is_empty():
		return
	
	# Создаем словарь для сопоставления: имя_базы → {button: Button, panel: PanelContainer}
	var matched_pairs: Dictionary = {}
	var used_buttons: Array[Button] = []
	var used_panels: Array[PanelContainer] = []
	
	# Проходим по всем кнопкам и ищем соответствующие панели
	for button in buttons:
		if not button or button in used_buttons:
			continue
		
		var button_name = button.name
		
		# Проверяем, заканчивается ли имя кнопки на "Button"
		if not button_name.ends_with("Button"):
			continue
		
		# Извлекаем базовое имя (без "Button")
		var base_name = button_name.substr(0, button_name.length() - 6)  # "Button" = 6 символов
		
		# Ищем панель с именем base_name + "Panel"
		var expected_panel_name = base_name + "Panel"
		
		var found_panel = null
		for panel in panels:
			if not panel or panel in used_panels:
				continue
			
			# Проверяем точное совпадение или начинается с базового имени
			if panel.name == expected_panel_name or (panel.name.begins_with(base_name) and panel.name.ends_with("Panel")):
				found_panel = panel
				matched_pairs[base_name] = {"button": button, "panel": panel}
				used_buttons.append(button)
				used_panels.append(panel)
				if OS.is_debug_build():
					print("PanelManager: Сопоставлено: ", button_name, " → ", panel.name)
				break
		
		if not found_panel and OS.is_debug_build():
			print("PanelManager: Не знайдено панель для кнопки: ", button_name, " (очікувана: ", expected_panel_name, ")")
			print("PanelManager: Доступні панелі: ", panels.map(func(p): return p.name if p else "null"))
	
	# Если нашли совпадения, переупорядочиваем массивы
	if matched_pairs.size() > 0:
		var ordered_buttons: Array[Button] = []
		var ordered_panels: Array[PanelContainer] = []
		
		# Сортируем по базовым именам для стабильного порядка
		var sorted_keys = matched_pairs.keys()
		sorted_keys.sort()
		
		# Добавляем совпавшие пары в правильном порядке
		for base_name in sorted_keys:
			var pair = matched_pairs[base_name]
			ordered_buttons.append(pair.button)
			ordered_panels.append(pair.panel)
		
		# Добавляем оставшиеся кнопки и панели, которые не были сопоставлены
		var unmatched_buttons: Array[Button] = []
		for button in buttons:
			if button and button not in used_buttons:
				ordered_buttons.append(button)
				unmatched_buttons.append(button)
		
		var unmatched_panels: Array[PanelContainer] = []
		var used_panel_names = used_panels.map(func(p): return p.name if p else "")
		for panel in panels:
			if panel and panel not in used_panels and panel.name not in used_panel_names:
				ordered_panels.append(panel)
				unmatched_panels.append(panel)
				used_panel_names.append(panel.name)
		
		# Обновляем массивы
		buttons = ordered_buttons
		panels = ordered_panels
		
		# Діагностика: перевіряємо, чи всі панелі збережені
		if OS.is_debug_build():
			print("PanelManager: Після сопоставлення - кнопок: ", buttons.size(), ", панелей: ", panels.size())
			print("PanelManager: Список панелей після сопоставлення: ", panels.map(func(p): return p.name if p else "null"))
		
		print("PanelManager: Сопоставлено %d пар кнопок и панелей по правилу именования" % matched_pairs.size())
		if matched_pairs.size() < min(buttons.size(), panels.size()):
			if OS.is_debug_build():
				print("PanelManager: Не сопоставленные кнопки: ", unmatched_buttons.map(func(b): return b.name if b else "null"))
				print("PanelManager: Не сопоставленные панели: ", unmatched_panels.map(func(p): return p.name if p else "null"))
				print("PanelManager: Всі кнопки: ", buttons.map(func(b): return b.name if b else "null"))
				print("PanelManager: Всі панелі: ", panels.map(func(p): return p.name if p else "null"))
			push_warning("PanelManager: Не все кнопки/панели сопоставлены по правилу именования. Проверьте имена: кнопки должны заканчиваться на 'Button', панели на 'Panel'")
