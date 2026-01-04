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
	# Изначально скрываем карту
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	
	# Получаем ссылки на узлы
	top_draw = get_node_or_null("TopDraw")
	percent_label = get_node_or_null("PercentLabel")
	
	# Ждем, пока размер будет установлен
	await get_tree().process_frame
	
	# Инициализируем размер карты в ячейках
	if size.x > 0 and size.y > 0:
		SIZE = size / MetSys.CELL_SIZE
	else:
		# Значение по умолчанию, если размер еще не установлен
		SIZE = Vector2i(20, 15)
	
	# Создаем MapView для отображения карты
	if not MetSys:
		push_error("MetSysMapComponent: MetSys not found! Make sure MetroidvaniaSystem is enabled.")
		return
	
	# Ждем еще один кадр, чтобы MetSys был полностью инициализирован
	await get_tree().process_frame
	
	if not MetSys:
		push_error("MetSysMapComponent: MetSys still not available after waiting!")
		return
	
	map_view = MetSys.make_map_view(self, -SIZE / 2, SIZE, 0)
	player_location = MetSys.add_player_location(self)
	
	# Подключаем сигнал обновления карты
	if MetSys.map_updated.is_connected(_on_map_updated):
		MetSys.map_updated.disconnect(_on_map_updated)
	MetSys.map_updated.connect(_on_map_updated)
	
	# Обновляем процент исследования
	update_percent()
	
	# Подключаем сигнал отрисовки для top_draw
	if top_draw:
		# Используем queue_redraw для обновления отрисовки
		top_draw.queue_redraw()

func _notification(what: int) -> void:
	"""Обработка уведомлений"""
	if what == NOTIFICATION_RESIZED:
		# Обновляем размер при изменении размера компонента
		if size.x > 0 and size.y > 0:
			SIZE = size / MetSys.CELL_SIZE
			if map_view:
				map_view.size = SIZE
				update_offset()

func set_map_active(active: bool):
	"""Устанавливает активность карты"""
	is_map_active = active
	visible = active
	
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
	if percent_label and MetSys:
		var percent = int(MetSys.get_explored_ratio() * 100)
		percent_label.text = "%03d%%" % percent

func update_offset():
	"""Обновляет смещение карты, центрируя на позиции игрока"""
	if not MetSys or not map_view:
		return
	
	# Получаем текущие координаты игрока
	var coords: Vector2i = MetSys.get_current_flat_coords()
	offset = coords - SIZE / 2
	
	# Обновляем позицию игрока на карте
	if player_location:
		player_location.offset = -Vector2(offset) * MetSys.CELL_SIZE
	
	# Обновляем позицию MapView
	map_view.move_to(Vector3i(offset.x, offset.y, MetSys.current_layer))
	
	# Обновляем отрисовку
	if top_draw:
		top_draw.queue_redraw()

func _input(event: InputEvent) -> void:
	"""Обработка ввода для прокрутки карты"""
	if not is_map_active or not visible:
		return
	
	if event is InputEventKey and event.pressed:
		var move_offset: Vector2i = Vector2i.ZERO
		
		if event.keycode == KEY_LEFT:
			move_offset = Vector2i.LEFT
		elif event.keycode == KEY_RIGHT:
			move_offset = Vector2i.RIGHT
		elif event.keycode == KEY_UP:
			move_offset = Vector2i.UP
		elif event.keycode == KEY_DOWN:
			move_offset = Vector2i.DOWN
		else:
			return
		
		# Перемещаем видимую область карты
		if map_view:
			map_view.move(move_offset)
			offset += move_offset
			
			# Обновляем позицию игрока на карте
			if player_location:
				player_location.offset = -Vector2(map_view.begin) * MetSys.CELL_SIZE
			
			# Обновляем отрисовку
			if top_draw:
				top_draw.queue_redraw()

func _draw() -> void:
	"""Отрисовка дополнительных элементов на карте"""
	if not MetSys or not is_map_active:
		return
	
	# Здесь можно добавить дополнительную отрисовку, если нужно
	# Например, линии, стрелки и т.д.

func _on_map_updated() -> void:
	"""Обработка обновления карты"""
	if is_map_active and map_view:
		map_view.queue_redraw()
		update_percent()
