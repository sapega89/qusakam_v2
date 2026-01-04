extends Control
class_name CursorIndicator

## Переиспользуемый компонент курсора для меню и табов
## Автоматически позиционируется относительно активной кнопки с анимацией
## Поддерживает сдвиг кнопки при активации

## Размер курсора
const CURSOR_SIZE = Vector2(20, 20)

## Смещение курсора от кнопки (в пикселях)
const CURSOR_OFFSET_X = 5.0

## Процент перекрытия курсора с кнопкой (0.0 - 1.0)
## 1.0 означает, что курсор полностью перекрывает кнопку (100%)
const CURSOR_OVERLAP_PERCENT = 1.0

## Смещение кнопки при активации (в пикселях)
const BUTTON_OFFSET_X = 10.0

## Длительность анимации (в секундах)
const ANIMATION_DURATION = 0.2

## Текущая активная кнопка
var current_active_button: Button = null

## Храним исходные позиции кнопок для сброса
var button_original_positions: Dictionary = {}

## Текущий активный Tween для анимации (чтобы не создавать несколько одновременно)
var current_tween: Tween = null

## Исходный родительский узел (сохраняется до перемещения в CursorLayer)
var _initial_parent_node: Node = null

## Массив кнопок для автоматического отслеживания (можно задать в Inspector)
@export var tracked_buttons: Array[Button] = []

## Автоматически отслеживать нажатия на кнопки
@export var auto_track_buttons: bool = true

func _ready() -> void:
	# Сохраняем исходного родителя до любых перемещений
	_initial_parent_node = get_parent()
	
	# ВАЖНО: Убеждаемся, что курсор имеет top_level для независимости от родителя
	_ensure_top_level()
	
	# Настраиваем курсор
	_setup_cursor()
	
	# ВАЖНО: Убираем фон у Control узла (даже если он создан в сцене)
	# Это нужно делать в _ready(), так как узел может быть создан в сцене, а не программно
	_remove_background()
	
	# Автоматически подключаемся к кнопкам, если включено автоотслеживание
	if auto_track_buttons:
		# Запускаем цикл попыток поиска кнопок (максимум 5 попыток)
		_try_setup_auto_tracking(5)
	else:
		# Если автоотслеживание выключено, проверяем есть ли кнопки и показываем курсор
		var buttons = get_button_list()
		if not buttons.is_empty():
			initialize_buttons(buttons)
			if buttons[0]:
				var other_buttons: Array[Button] = []
				for i in range(1, buttons.size()):
					other_buttons.append(buttons[i])
				set_target_button(buttons[0], other_buttons)

## Виртуальный метод для получения списка кнопок
## Теперь содержит базовую логику поиска PanelManager для совместимости
func get_button_list() -> Array[Button]:
	# По умолчанию возвращаем tracked_buttons, если они заданы
	if not tracked_buttons.is_empty():
		return tracked_buttons
		
	# Если tracked_buttons пусты, пробуем найти кнопки через PanelManager (логика VerticalMenu/GameMenu)
	var buttons: Array[Button] = []
	var panel_manager: Node = null
	
	# Используем сохраненного родителя, если курсор был перемещен
	var search_context = _initial_parent_node if _initial_parent_node else get_parent()
	
	# 1. Ищем PanelManager среди соседей (детей родителя)
	if search_context:
		# Сначала ищем по имени прямо в контексте (если контекст не удален)
		if search_context.has_node("PanelManager"):
			panel_manager = search_context.get_node("PanelManager")
		else:
			# Перебираем детей контекста
			for child in search_context.get_children():
				if child == self: continue
				if child.name == "PanelManager" or (child.get_script() and "panel_manager.gd" in child.get_script().resource_path):
					panel_manager = child
					break
	
	# 2. Fallback: Ищем глобально в VerticalMenu (для GameMenu)
	if not panel_manager:
		var root = get_tree().current_scene
		if root:
			# Ищем VerticalMenu рекурсивно
			var vertical_menu = root.find_child("VerticalMenu", true, false)
			if vertical_menu:
				panel_manager = vertical_menu.find_child("PanelManager", true, false)
	
	if not panel_manager and owner:
		panel_manager = owner.get_node_or_null("PanelManager")
		
	if panel_manager:
		# Способ А: Массив buttons
		var pm_buttons = panel_manager.get("buttons")
		if pm_buttons is Array and not pm_buttons.is_empty():
			for btn in pm_buttons:
				if btn is Button:
					buttons.append(btn)
			return buttons
			
		# Способ Б: Контейнеры
		var tab_buttons = panel_manager.find_child("TabButtons", true, false)
		if not tab_buttons:
			tab_buttons = panel_manager.find_child("ButtonsContainer", true, false)
			
		if tab_buttons:
			for child in tab_buttons.get_children():
				if child is Button:
					buttons.append(child)
					
	return buttons

## Пытается настроить автоотслеживание с повторными попытками
func _try_setup_auto_tracking(attempts_left: int) -> void:
	# Пробуем найти кнопки сразу
	var success = _setup_auto_tracking()
	
	if success:
		return
	
	# Если не нашли, ждем и пробуем снова (если есть попытки)
	if attempts_left > 0:
		# Используем таймер вместо await process_frame для более надежной задержки
		await get_tree().create_timer(0.1).timeout
		_try_setup_auto_tracking(attempts_left - 1)
	else:
		# Если после всех попыток кнопок нет - просто ничего не делаем (курсор будет скрыт)
		pass

## Настраивает автоматическое отслеживание кнопок
## Возвращает true, если кнопки найдены и настроены
func _setup_auto_tracking() -> bool:
	# Получаем список кнопок через абстрактный метод
	var buttons_to_track = get_button_list()
	
	if buttons_to_track.is_empty():
		return false
		
	# Подключаемся к кнопкам и показываем курсор
	_connect_to_buttons(buttons_to_track)
	initialize_buttons(buttons_to_track)
	
	# Показываем курсор на первой кнопке
	if buttons_to_track[0]:
		var other_buttons: Array[Button] = []
		for i in range(1, buttons_to_track.size()):
			other_buttons.append(buttons_to_track[i])
		set_target_button(buttons_to_track[0], other_buttons)
		return true
	
	return false

func _move_to_scene_root() -> void:
	if not is_inside_tree():
		return
	
	var parent = get_parent()
	if not parent:
		return
	
	var scene_root = get_tree().current_scene
	if not scene_root:
		scene_root = get_tree().root
	
	# Ищем существующий CanvasLayer для курсора или создаем новый
	var cursor_layer = scene_root.get_node_or_null("CursorLayer")
	if not cursor_layer:
		# Проверяем, может быть CursorLayer уже существует где-то в дереве
		cursor_layer = get_tree().get_first_node_in_group("cursor_layer")
		if not cursor_layer:
			# Создаем новый CanvasLayer только если его нет
			cursor_layer = CanvasLayer.new()
			cursor_layer.name = "CursorLayer"
			cursor_layer.layer = 100  # Высокий слой, чтобы курсор был поверх всего
			cursor_layer.add_to_group("cursor_layer")  # Добавляем в группу для поиска
			# Добавляем в корень сцены только если его там еще нет
			if not cursor_layer.is_inside_tree():
				scene_root.add_child(cursor_layer)
	
	# Перемещаем курсор в CanvasLayer, если он еще не там
	if parent != cursor_layer:
		parent.remove_child(self)
		cursor_layer.add_child(self)
		# ВАЖНО: Устанавливаем размер после перемещения
		_set_cursor_size()
		# ВАЖНО: Повторно убираем фон после перемещения
		_remove_background()

## Убеждается, что курсор имеет top_level для независимости от родителя
func _ensure_top_level() -> void:
	if not top_level:
		top_level = true
		z_index = 1000
		clip_contents = false
	
	# Если курсор находится внутри узла с фоном, перемещаем его в корень сцены
	# ВАЖНО: Используем call_deferred, так как операции с дочерними узлами могут быть заблокированы во время _ready()
	var parent = get_parent()
	if parent and parent.has_method("get_theme_stylebox"):
		var parent_panel = parent.get_theme_stylebox("panel")
		if parent_panel and parent_panel is StyleBoxFlat:
			var bg_color = parent_panel.bg_color
			# Если родитель имеет непрозрачный фон, перемещаем курсор
			if bg_color.a > 0.0:
				# Отложенное перемещение в корень сцены
				call_deferred("_move_to_scene_root")

## Настраивает курсор (создает визуальный элемент если его нет)
func _setup_cursor() -> void:
	# Проверяем, есть ли уже Label в курсоре
	var cursor_label = get_node_or_null("CursorLabel")
	
	if not cursor_label:
		# Создаем Label для отображения курсора
		cursor_label = Label.new()
		cursor_label.name = "CursorLabel"
		cursor_label.text = "▶"  # Стрелка курсора
		cursor_label.add_theme_font_size_override("font_size", 16)
		# Белый цвет для стрелки
		cursor_label.add_theme_color_override("font_color", Color(1, 1, 1, 1.0))
		cursor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cursor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cursor_label.z_index = 1000
		# Убираем фон у Label
		cursor_label.modulate = Color(1, 1, 1, 1)
		
		# Устанавливаем размер Label
		cursor_label.offset_left = 0
		cursor_label.offset_top = 0
		cursor_label.offset_right = CURSOR_SIZE.x
		cursor_label.offset_bottom = CURSOR_SIZE.y
		
		# ВАЖНО: Убираем фон у Label (на случай, если он задан в теме)
		var transparent_style = StyleBoxFlat.new()
		transparent_style.bg_color = Color(0, 0, 0, 0)
		cursor_label.add_theme_stylebox_override("normal", transparent_style)
		
		add_child(cursor_label)
	
	# Настраиваем сам курсор
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1000
	top_level = true  # ВАЖНО: top_level делает курсор независимым от родителя
	# Убеждаемся, что курсор не наследует фон от родителя
	# top_level должен работать, но для надежности также убираем фон

## Убирает фон у Control узла (вызывается отдельно для надежности)
func _remove_background() -> void:
	# ВАЖНО: Убеждаемся, что top_level установлен ПЕРЕД удалением фона
	# Это делает курсор независимым от родителя и его фона
	if not top_level:
		top_level = true
		z_index = 1000
	
	# Убеждаемся, что clip_contents = false
	clip_contents = false
	
	# ВАЖНО: Полностью удаляем тему, если она задана
	# Тема может содержать стили фона, которые мы не хотим
	if theme:
		theme = null
	
	# Удаляем все переопределения стилей фона (на случай, если они были установлены до удаления темы)
	if has_theme_stylebox_override("panel"):
		remove_theme_stylebox_override("panel")
	if has_theme_stylebox_override("normal"):
		remove_theme_stylebox_override("normal")
	if has_theme_stylebox_override("background"):
		remove_theme_stylebox_override("background")
	if has_theme_stylebox_override("hover"):
		remove_theme_stylebox_override("hover")
	if has_theme_stylebox_override("pressed"):
		remove_theme_stylebox_override("pressed")
	if has_theme_stylebox_override("focus"):
		remove_theme_stylebox_override("focus")
	
	# Устанавливаем полностью прозрачный фон через StyleBoxFlat
	# Это гарантирует, что даже если тема будет применена позже, наш прозрачный стиль будет иметь приоритет
	var transparent_style = StyleBoxFlat.new()
	transparent_style.bg_color = Color(0, 0, 0, 0)  # Полностью прозрачный фон
	transparent_style.border_width_left = 0
	transparent_style.border_width_top = 0
	transparent_style.border_width_right = 0
	transparent_style.border_width_bottom = 0
	transparent_style.border_color = Color(0, 0, 0, 0)  # Прозрачная граница
	transparent_style.shadow_color = Color(0, 0, 0, 0)  # Прозрачная тень
	transparent_style.shadow_size = 0  # Размер тени = 0
	add_theme_stylebox_override("panel", transparent_style)
	add_theme_stylebox_override("normal", transparent_style)
	add_theme_stylebox_override("background", transparent_style)
	
	# Удаляем ColorRect если есть (может быть добавлен в сцене)
	for child in get_children():
		if child is ColorRect:
			child.queue_free()
	
	# ВАЖНО: Убеждаемся, что modulate не влияет на прозрачность фона
	# modulate.a должен быть 1.0 для полной непрозрачности текста
	modulate = Color(1, 1, 1, 1)
	
	# Делаем сам Control прозрачным, но дочерние элементы (Label) останутся видимыми
	# Это уберет любой фон, который может рисоваться самим Control
	self_modulate = Color(1, 1, 1, 0)
	
	# Устанавливаем размер через call_deferred, чтобы избежать конфликта с anchors
	call_deferred("_set_cursor_size")
	
	# Устанавливаем начальную позицию вне экрана
	call_deferred("_set_initial_position")

## Устанавливает размер курсора (вызывается через call_deferred или напрямую)
func _set_cursor_size() -> void:
	if not is_inside_tree():
		# Если узел еще не в дереве, откладываем установку размера
		call_deferred("_set_cursor_size")
		return
	
	custom_minimum_size = CURSOR_SIZE
	size = CURSOR_SIZE
	
	# Также обновляем размер Label, если он есть
	var cursor_label = get_node_or_null("CursorLabel")
	if cursor_label:
		cursor_label.offset_left = 0
		cursor_label.offset_top = 0
		cursor_label.offset_right = CURSOR_SIZE.x
		cursor_label.offset_bottom = CURSOR_SIZE.y

## Устанавливает начальную позицию курсора вне экрана
func _set_initial_position() -> void:
	if is_inside_tree():
		if top_level:
			global_position = Vector2(-1000, -1000)
		else:
			position = Vector2(-1000, -1000)

## Устанавливает целевую кнопку для курсора
## @param button: Кнопка, относительно которой позиционируется курсор
## @param reset_other_buttons: Массив кнопок, которые нужно вернуть в исходное положение
func set_target_button(button: Button, reset_other_buttons: Array[Button] = []) -> void:
	if not button:
		hide()
		return
	
	# Если курсор уже на этой кнопке, не делаем ничего
	if current_active_button == button:
		return
	
	# ВАЖНО: Убеждаемся, что курсор находится в дереве сцены перед обновлением позиции
	if not is_inside_tree():
		# Если курсор еще не в дереве, ждем следующего кадра
		call_deferred("set_target_button", button, reset_other_buttons)
		return
	
	# Сначала сбрасываем позиции других кнопок синхронно (без анимации)
	# ВАЖНО: Это гарантирует, что исходные позиции восстановлены до сохранения новой
	for btn in reset_other_buttons:
		if btn != button and button_original_positions.has(btn):
			_reset_button_position(btn, false)  # Сбрасываем без анимации
	
	# Сохраняем исходный offset кнопки, если еще не сохранен
	# ВАЖНО: Сохраняем ТОЛЬКО один раз, при первом вызове
	if not button_original_positions.has(button):
		# Сохраняем текущий offset_left и offset_top как исходные
		button_original_positions[button] = Vector2(button.offset_left, button.offset_top)
	
	current_active_button = button
	
	# Используем call_deferred чтобы убедиться, что все узлы готовы
	call_deferred("_update_cursor_position", button)

## Обновляет позицию курсора относительно кнопки
func _update_cursor_position(button: Button) -> void:
	if not button or not is_inside_tree():
		# Если курсор еще не в дереве, откладываем обновление
		call_deferred("_update_cursor_position", button)
		return
	
	# Убеждаемся, что кнопка в дереве сцены
	if not button.is_inside_tree():
		call_deferred("_update_cursor_position", button)
		return
	
	# ВАЖНО: Убеждаемся, что top_level установлен и курсор в правильном месте
	if not top_level:
		top_level = true
		z_index = 1000
		clip_contents = false
	
	# ВАЖНО: Убеждаемся, что размер курсора установлен правильно
	if size == Vector2.ZERO or size != CURSOR_SIZE:
		_set_cursor_size()
	
	# ВАЖНО: Устанавливаем видимость курсора СРАЗУ, до всех вычислений
	# Это гарантирует, что курсор виден во время анимации
	modulate.a = 1.0
	visible = true
	
	# Проверяем, что размер кнопки вычислен
	if button.size == Vector2.ZERO:
		call_deferred("_update_cursor_position", button)
		return
	
	# Получаем глобальную область кнопки
	var button_global_rect = button.get_global_rect()
	var button_size = button_global_rect.size
	var button_global_pos = button_global_rect.position
	
	# Вычисляем целевую глобальную позицию курсора
	# Курсор перекрывает кнопку на 100% от размера курсора (CURSOR_OVERLAP_PERCENT = 1.0)
	# Позиция X: начало кнопки минус размер курсора плюс 100% размера курсора (полное перекрытие)
	var overlap_amount = CURSOR_SIZE.x * CURSOR_OVERLAP_PERCENT
	var target_cursor_global_position = button_global_pos - Vector2(CURSOR_SIZE.x - overlap_amount, 0)
	# Позиция Y: по центру кнопки по вертикали
	var vertical_overlap = CURSOR_SIZE.y * CURSOR_OVERLAP_PERCENT
	target_cursor_global_position.y += (button_size.y - CURSOR_SIZE.y) / 2 - vertical_overlap / 2
	
	# Определяем, нужна ли анимация
	# ВАЖНО: Для top_level узлов используем global_position
	var current_cursor_global_pos = get_global_position()
	var was_visible = visible
	var needs_animation = was_visible and current_cursor_global_pos.distance_to(target_cursor_global_position) > 1.0
	
	# ВАЖНО: Останавливаем предыдущий Tween, если он еще активен
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	
	# Создаем новый Tween для анимации
	current_tween = create_tween()
	current_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # Разрешаем работу при паузе
	current_tween.set_parallel(true)
	
	# Анимируем позицию курсора
	# ВАЖНО: Для top_level узлов всегда используем global_position
	if needs_animation:
		if top_level:
			current_tween.tween_property(self, "global_position", target_cursor_global_position, ANIMATION_DURATION)
		else:
			# Если не top_level, нужно преобразовать global_position в local position
			var local_pos = get_global_transform().affine_inverse() * target_cursor_global_position
			current_tween.tween_property(self, "position", local_pos, ANIMATION_DURATION)
		
		# ВАЖНО: Убеждаемся, что курсор остается видимым во время анимации
		current_tween.tween_property(self, "modulate:a", 1.0, 0.0)  # Устанавливаем полную непрозрачность сразу
	else:
		# Устанавливаем позицию сразу без анимации
		if top_level:
			global_position = target_cursor_global_position
		else:
			# Если не top_level, нужно преобразовать global_position в local position
			var local_pos = get_global_transform().affine_inverse() * target_cursor_global_position
			position = local_pos
	
	# ВАЖНО: Используем offset_left вместо изменения position, чтобы не конфликтовать с layout
	# Это позволяет сдвигать кнопку вправо без нарушения layout контейнера
	var original_offset = button_original_positions.get(button, Vector2.ZERO)
	if original_offset == Vector2.ZERO:
		# Сохраняем исходный offset_left, если еще не сохранен
		button_original_positions[button] = Vector2(button.offset_left, button.offset_top)
		original_offset = Vector2(button.offset_left, button.offset_top)
	
	var target_offset_left = original_offset.x + BUTTON_OFFSET_X
	if needs_animation:
		current_tween.tween_property(button, "offset_left", target_offset_left, ANIMATION_DURATION)
	else:
		button.offset_left = target_offset_left

## Возвращает кнопку в исходное положение
## @param animated: Если true, использует анимацию, иначе сбрасывает позицию сразу
func _reset_button_position(button: Button, animated: bool = true) -> void:
	if not button or not button_original_positions.has(button):
		return
	
	var original_offset = button_original_positions[button]
	
	if animated:
		# Анимируем возврат offset_left кнопки
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # Разрешаем работу при паузе
		tween.tween_property(button, "offset_left", original_offset.x, ANIMATION_DURATION)
	else:
		# Сбрасываем offset_left сразу (синхронно)
		button.offset_left = original_offset.x

## Скрывает курсор
func hide_cursor() -> void:
	visible = false
	
	# Возвращаем активную кнопку в исходное положение
	if current_active_button and button_original_positions.has(current_active_button):
		_reset_button_position(current_active_button)
	
	current_active_button = null

## Находит кнопки в сцене автоматически
func _find_buttons_in_scene() -> Array[Button]:
	var buttons: Array[Button] = []
	var scene_root = get_tree().current_scene
	if not scene_root:
		return buttons
	
	# Ищем кнопки в корне сцены и его дочерних узлах
	_find_buttons_recursive(scene_root, buttons)
	return buttons

## Рекурсивно ищет кнопки в узле и его дочерних узлах
func _find_buttons_recursive(node: Node, buttons: Array[Button]) -> void:
	if node is Button:
		buttons.append(node as Button)
	
	for child in node.get_children():
		_find_buttons_recursive(child, buttons)

## Подключается к сигналам кнопок для автоматической анимации
func _connect_to_buttons(buttons: Array[Button]) -> void:
	for button in buttons:
		if button and button.is_inside_tree():
			# Подключаемся к сигналу pressed
			if not button.pressed.is_connected(_on_button_pressed):
				button.pressed.connect(_on_button_pressed.bind(button))
			# Если кнопка использует toggle_mode, также отслеживаем toggled
			if button.toggle_mode and not button.toggled.is_connected(_on_button_toggled):
				button.toggled.connect(_on_button_toggled.bind(button))

## Обработчик нажатия на кнопку
func _on_button_pressed(button: Button) -> void:
	if button:
		# Получаем все отслеживаемые кнопки для сброса
		var all_buttons = tracked_buttons.duplicate()
		if all_buttons.is_empty():
			all_buttons = _find_buttons_in_scene()
		
		# Убираем текущую кнопку из списка для сброса
		var buttons_to_reset: Array[Button] = []
		for btn in all_buttons:
			if btn != button:
				buttons_to_reset.append(btn)
		
		# Анимируем курсор к нажатой кнопке
		set_target_button(button, buttons_to_reset)

## Обработчик переключения кнопки (для toggle_mode)
func _on_button_toggled(button_pressed: bool, button: Button) -> void:
	if button_pressed and button:
		_on_button_pressed(button)

## Инициализирует исходные позиции для всех кнопок сразу
## Вызывайте этот метод при старте, чтобы "прикрепить" курсор ко всем кнопкам
## @param buttons: Массив всех кнопок для инициализации
func initialize_buttons(buttons: Array[Button]) -> void:
	for button in buttons:
		if button and button.is_inside_tree():
			# Сохраняем исходный offset кнопки, если еще не сохранен
			if not button_original_positions.has(button):
				button_original_positions[button] = Vector2(button.offset_left, button.offset_top)

## Очищает сохраненные позиции кнопок (полезно при динамическом изменении кнопок)
func clear_button_positions() -> void:
	button_original_positions.clear()
