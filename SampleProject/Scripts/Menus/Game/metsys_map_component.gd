extends Control

## MetSysMapComponent - Компонент карти на основі Metroidvania System
## Використовує MetSys для відображення карти світу

# Ссылки на узлы карты
var map_view: MapView = null
var player_location: Node2D = null
var top_draw: Control = null
var percent_label: Label = null

# Размер окна карты в ячейках
var SIZE: Vector2i

# Смещение для прокрутки карты
var offset: Vector2i

# Флаг активности карты
var is_map_active: bool = false

func _ready():
	"""Инициализация компонента карты MetSys"""
	# Видимість задає сцена меню (D116); тут лише підлаштовуємо обробку під неї.
	process_mode = Node.PROCESS_MODE_ALWAYS if is_visible_in_tree() else Node.PROCESS_MODE_DISABLED

	# Получаем ссылки на узлы
	top_draw = $TopDraw
	percent_label = %PercentLabel

	# Ждем, пока размер будет установлен
	await get_tree().process_frame

	# Инициализируем размер карты в ячейках
	if size.x > 0 and size.y > 0:
		SIZE = size / MetSys.CELL_SIZE
	else:
		# Значение по умолчанию, если размер еще не установлен
		SIZE = Vector2i(20, 15)

	# Ждем еще один кадр, чтобы MetSys был полностью инициализирован
	await get_tree().process_frame

	@warning_ignore("integer_division")
	map_view = MetSys.make_map_view(self, -SIZE / 2, SIZE, 0)
	# B132: не досліджені клітинки не малюємо — empty_space_texture теми клав густу сітку на пергамент.
	map_view.skip_empty = true
	map_view.update_all()
	player_location = MetSys.add_player_location(self)

	# Подключаем сигнал обновления карты
	if MetSys.map_updated.is_connected(_on_map_updated):
		MetSys.map_updated.disconnect(_on_map_updated)
	MetSys.map_updated.connect(_on_map_updated)

	# Обновляем процент исследования
	update_percent()

	top_draw.queue_redraw()

func _notification(what: int) -> void:
	"""Обработка уведомлений"""
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready():
		set_map_active(is_visible_in_tree())
	elif what == NOTIFICATION_RESIZED:
		# Обновляем размер при изменении размера компонента
		if size.x > 0 and size.y > 0:
			SIZE = size / MetSys.CELL_SIZE
			if map_view:
				map_view.size = SIZE
				update_offset()

## Підказки показують тільки те, що справді реалізовано: панорамування і назад.
func _publish_hints(active: bool) -> void:
	var bar := get_tree().get_first_node_in_group(&"ui_bottom_bar")
	bar.set_context_hint("Arrow keys — pan the map." if active else "")


func set_map_active(active: bool):
	"""Устанавливает активность карты"""
	is_map_active = active
	_publish_hints(active)

	if active:
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_process_input(true)
		# Обновляем смещение при открытии карты
		update_offset()
		# Обновляем все ячейки карты
		if map_view:
			map_view.update_all()
		# Обновляем процент исследования
		update_percent()
	else:
		process_mode = Node.PROCESS_MODE_DISABLED
		set_process_input(false)

func update_percent():
	"""Обновляет процент исследования карты"""
	percent_label.text = "%03d%%" % int(MetSys.get_explored_ratio() * 100)

func update_offset():
	"""Обновляет смещение карты, центрируя на позиции игрока"""
	if not map_view:
		return

	# Получаем текущие координаты игрока
	var coords: Vector2i = MetSys.get_current_flat_coords()
	@warning_ignore("integer_division")
	offset = coords - SIZE / 2

	# Обновляем позицию игрока на карте
	if player_location:
		player_location.offset = -Vector2(offset) * MetSys.CELL_SIZE

	# Обновляем позицию MapView
	map_view.move_to(Vector3i(offset.x, offset.y, MetSys.current_layer))

	# Обновляем отрисовку
	top_draw.queue_redraw()

## Панорамування карти. Використовуємо дії InputMap (ui_left/right/up/down),
## а не сирі keycode — інакше перепризначення клавіш у налаштуваннях не працює.
## Лише коли фокус на карті (BACKLOG 24): раніше _input забирав стрілки / D-pad, щойно карту видно, і з вкладки
## World Map не можна було перейти на іншу. На карту заходять D-pad → / A з вкладки, виходять B (FocusRouter).
func _gui_input(event: InputEvent) -> void:
	if not is_map_active or not visible:
		return

	var move_offset := Vector2i.ZERO
	if event.is_action_pressed(&"ui_left"):
		move_offset = Vector2i.LEFT
	elif event.is_action_pressed(&"ui_right"):
		move_offset = Vector2i.RIGHT
	elif event.is_action_pressed(&"ui_up"):
		move_offset = Vector2i.UP
	elif event.is_action_pressed(&"ui_down"):
		move_offset = Vector2i.DOWN
	else:
		return

	if map_view == null:
		return
	map_view.move(move_offset)
	offset += move_offset
	if player_location:
		player_location.offset = -Vector2(map_view.begin) * MetSys.CELL_SIZE
	top_draw.queue_redraw()
	accept_event()


func _draw() -> void:
	"""Отрисовка дополнительных элементов на карте"""
	if not is_map_active:
		return

	# Здесь можно добавить дополнительную отрисовку, если нужно
	# Например, линии, стрелки и т.д.

func _on_map_updated() -> void:
	"""Обработка обновления карты"""
	if is_map_active and map_view:
		map_view.queue_redraw()
		update_percent()
