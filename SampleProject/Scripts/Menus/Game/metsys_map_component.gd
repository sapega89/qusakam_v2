extends Control

## Вкладка World Map — карта у два рівні (D458, D487, D565; design/world_map_spec.md, Figma 539:6472 / 539:6615).
## Рівень 1 — ілюстрована мапа світу (тло меню) зі шпилькою на кожну локацію locations.json (тут / відвідано /
## закрито) і карткою вибраної: досліджено %, скрині. Вліво / вправо — між шпильками, A / Enter — рівень 2 вибраної,
## якщо герой там бував.
## Рівень 2 — кімнати локації з клітинок MetSys (LocationMap): досліджені залиті, з баченим входом — пунктиром, решта
## не малюються; назви кімнат, значки об'єктів, підписи драбин і спусків, легенда. B / Esc — назад на рівень 1.
## Вкладка відкривається на рівні 1 (вона зветься World Map; кадри не кажуть інакше — рішення рутини, звіт world-map).
## Обидва рівні — полотно (map-pan, як в Octopath Traveler): ліва кнопка миші тягне карту 1:1 і відпускає з ковзанням,
## коліщатко масштабує навколо курсора; правий стік / WASD (на рівні 2 ще й стрілки) рухають, тригери / Q-E
## масштабують. Під курсором шпилька вибирається, кімната підсвічується з карткою; клац без тягнення відкриває.
## Розкладка й стилі — у сцені й темі (UITokens), тут поведінка й малювання клітинок.

const LocationDB := preload("res://SampleProject/Scripts/Systems/LocationDB.gd")
const LocationMap := preload("res://SampleProject/Scripts/Systems/LocationMap.gd")
const MapIcon := preload("res://SampleProject/UI/Components/map_icon.gd")
const MapCamera := preload("res://SampleProject/Scripts/Menus/Game/map_camera.gd")
const PIN_SCENE := preload("res://SampleProject/Scenes/Menus/Game/world_map_pin.tscn")

enum Level { WORLD, LOCATION }

const PIN_HERE := &"here"
const PIN_VISITED := &"visited"
const PIN_LOCKED := &"locked"
const PIN_PLATE := {&"here": &"MapPinHere", &"visited": &"MapPin", &"locked": &"MapPinLocked"}
const PIN_DOT := {&"here": &"MapPinDotHere", &"visited": &"MapPinDotVisited", &"locked": &"MapPinDotLocked"}
const PIN_TEXT := {&"here": "you are here", &"visited": "visited", &"locked": "locked"}
const PAN_HINT := "Drag or stick — move the map. Wheel or Q / E — zoom."
const PASSAGE_TEXT := {&"ladder": "↕ ladder", &"drop": "↓ drop"}
## Значки, які видно й у клітинці з баченим входом: вхід і брама видно з порога.
const SEEN_KINDS: Array[StringName] = [&"locked", &"exit"]

var level: Level = Level.WORLD
## Індекс вибраної шпильки в [member location_ids].
var selected := 0
var is_map_active := false
## Id локацій зліва направо на мапі — так ходять вліво / вправо.
var location_ids: Array[String] = []
## Id локації → LocationMap; збирається щоразу, як вкладку відкрито (стан гри міг змінитися).
var maps: Dictionary = {}
## Локація рівня 2.
var shown_id := ""

## Камери рівнів: світ (тло меню й шпильки, координати кадру) і локація (Grid у координатах Rooms).
var world_camera: MapCamera = MapCamera.new()
var room_camera: MapCamera = MapCamera.new()
## Кімната під курсором (або під центром вікна після стіка / клавіш) на рівні 2; "" — жодної.
var hovered_room := ""

## Ліва верхня клітинка рамки рівня 2 (найменші x, y намальованих клітинок).
var _grid_min := Vector2i.ZERO
## Ліва кнопка затиснута: звідки почали і скільки пройшли (клац чи тягнення).
var _dragging := false
var _drag_travel := 0.0
var _drag_velocity := Vector2.ZERO
var _drag_last_motion := 0
## Тло меню (ілюстрована мапа BaseMenu) — рівень 1 рухає саме його.
var _background: Control
var _world_title := ""
var _world_subtitle := ""

@onready var _frame: Control = %Frame
@onready var _level1: Control = %Level1
@onready var _level2: Control = %Level2
@onready var _pins: Control = %Pins
@onready var _rooms: Control = %Rooms
@onready var _grid: Control = %Grid
@onready var _title: Label = %MapTitle
@onready var _subtitle: Label = %MapSubtitle


func _ready() -> void:
	_world_title = _title.text
	_world_subtitle = _subtitle.text
	_grid.draw.connect(_draw_cells)
	for bg: Node in get_tree().get_nodes_in_group(&"menu_map_background"):
		if bg.get_parent().is_ancestor_of(self):
			_background = bg
	ServiceLocator.get_ui_manager().ui_refresh_requested.connect(_refresh_texts)
	# Видимість задає сцена меню (D116); тут лише підлаштовуємо обробку під неї. Відкладено: нижня панель і колонка
	# партії стоять у дереві після карти й ще не готові.
	if is_visible_in_tree():
		set_map_active.call_deferred(true)
	else:
		process_mode = Node.PROCESS_MODE_DISABLED


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready():
		set_map_active(is_visible_in_tree())
	elif what == NOTIFICATION_RESIZED and is_node_ready():
		_place_frame()


func set_map_active(active: bool) -> void:
	is_map_active = active
	process_mode = Node.PROCESS_MODE_ALWAYS if active else Node.PROCESS_MODE_DISABLED
	_dragging = false
	if active:
		_place_frame()
		_build_world()
		show_world()
	else:
		# Тло меню спільне з іншими вкладками — віддаємо його в кадрі Figma.
		_background.scale = Vector2.ONE
		_background.position = Vector2.ZERO
	_publish_hints()


## Кадр 1920×1080 у координатах полотна: шпильки, картка й легенда стоять у координатах кадру Figma.
func _place_frame() -> void:
	_frame.global_position = Vector2.ZERO


# ── Рівень 1 — світ ─────────────────────────────────────────────────────────

func _build_world() -> void:
	for pin in _pins.get_children():
		_pins.remove_child(pin)
		pin.queue_free()
	maps.clear()
	location_ids.clear()
	for loc: Dictionary in LocationDB.all():
		location_ids.append(loc.id)
		maps[loc.id] = LocationMap.new(loc.id)
	location_ids.sort_custom(func(a: String, b: String) -> bool: return LocationDB.map_pos(a).x < LocationDB.map_pos(b).x)
	selected = 0
	for i in location_ids.size():
		var pin: PanelContainer = PIN_SCENE.instantiate()
		pin.name = location_ids[i]
		_pins.add_child(pin)
		if pin_state(location_ids[i]) == PIN_HERE:
			selected = i
	# Вікно — область вмісту (між бічною панеллю й нижньою смугою); полотно — кадр 1920×1080 тла.
	# Найменший масштаб — тло ще вкриває вікно; відкривається в масштабі кадру Figma (1) на «ви тут».
	var view: Rect2 = _pins.get_rect()
	var cover: float = maxf(view.size.x / _frame.size.x, view.size.y / _frame.size.y)
	world_camera.zoom = 1.0
	world_camera.setup(view, _frame.size, cover, UITokens.MAP_ZOOM_MAX)
	_update_world()  # назви на плашках задають їхній розмір, а з ним і центр шпильки
	world_camera.center_on(pin_center(selected))
	_apply_world_camera()


## here — герой у цій локації; visited — бував; locked — ще не досягнута.
func pin_state(id: String) -> StringName:
	var data: LocationMap = maps[id]
	if data.is_here():
		return PIN_HERE
	return PIN_VISITED if data.visited() else PIN_LOCKED


func show_world() -> void:
	level = Level.WORLD
	shown_id = ""
	_level1.visible = true
	_level2.visible = false
	_title.text = _world_title
	_subtitle.text = _world_subtitle
	_publish_hints()


func select(index: int) -> void:
	selected = clampi(index, 0, location_ids.size() - 1)
	_update_world()


## Центр шпильки в координатах кадру (масштаб 1): плашка стоїть лівим верхнім кутом у map_pos.
func pin_center(index: int) -> Vector2:
	var pin: Control = _pins.get_child(index)
	return LocationDB.map_pos(location_ids[index]) + pin.get_combined_minimum_size() / 2.0


## Тло й шпильки за камерою світу. Шпильки не масштабуються (читаються за будь-якого масштабу), лише їдуть.
func _apply_world_camera() -> void:
	_background.scale = Vector2.ONE * world_camera.zoom
	_background.position = world_camera.offset
	for i in location_ids.size():
		var pin: Control = _pins.get_child(i)
		var center: Vector2 = world_camera.to_view(pin_center(i))
		pin.position = center - pin.get_combined_minimum_size() / 2.0 - _pins.position


## Індекс шпильки під точкою екрана або -1.
func pin_at(screen: Vector2) -> int:
	for i in location_ids.size():
		if (_pins.get_child(i) as Control).get_global_rect().has_point(screen):
			return i
	return -1


func _update_world() -> void:
	for i in location_ids.size():
		var id: String = location_ids[i]
		var state := pin_state(id)
		var pin: PanelContainer = _pins.get_child(i)
		pin.theme_type_variation = &"MapPinSelected" if i == selected and state == PIN_VISITED else PIN_PLATE[state]
		(pin.get_node(^"Row/Dot") as Panel).theme_type_variation = PIN_DOT[state]
		var title: Label = pin.get_node(^"Row/Text/Name")
		title.text = LocationDB.title(id)
		title.theme_type_variation = &"MapPinNameLocked" if state == PIN_LOCKED else &"MapPinName"
		(pin.get_node(^"Row/Text/State") as Label).text = tr(PIN_TEXT[state])
	var chosen: String = location_ids[selected]
	var data: LocationMap = maps[chosen]
	%CardName.text = LocationDB.title(chosen)
	%CardStats.text = tr("Explored %d%% · Chests %d/%d · Secrets %d/%d") % [data.explored_percent(), data.chests_opened,
		data.chests_total, data.secrets_found, data.secrets_total]
	%CardHint.visible = pin_state(chosen) != PIN_LOCKED


## Рівень 2 відкривається лише для локації, де герой бував.
func open_location(id: String) -> void:
	if pin_state(id) == PIN_LOCKED:
		return
	level = Level.LOCATION
	shown_id = id
	_level1.visible = false
	_level2.visible = true
	_title.text = LocationDB.title(id).to_upper()
	_subtitle.text = tr("Location map · B — back to the world map")
	_build_location()
	_dragging = false
	_publish_hints()


# ── Рівень 2 — локація ──────────────────────────────────────────────────────

func _build_location() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var data: LocationMap = maps[shown_id]
	var lo := Vector2i(Vector2i.MAX.x, Vector2i.MAX.y)
	var hi := Vector2i(Vector2i.MIN.x, Vector2i.MIN.y)
	for c: Vector3i in data.cells:
		if data.state(c) != LocationMap.Cell.HIDDEN:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	_grid_min = lo
	_grid.size = Vector2(hi - lo + Vector2i.ONE) * UITokens.MAP_CELL
	# Найменший масштаб — уся локація в рамці (мала — у натуральний розмір посередині); відкривається в
	# натуральному розмірі клітинки 150×84 на герої — велика локація далі тягнеться.
	var fit: float = minf(1.0, minf(_rooms.size.x / _grid.size.x, _rooms.size.y / _grid.size.y))
	room_camera.zoom = 1.0
	room_camera.setup(Rect2(Vector2.ZERO, _rooms.size), _grid.size, fit, UITokens.MAP_ZOOM_MAX)
	_add_room_names(data)
	_add_passages(data)
	_add_icons(data)
	var hero := Vector3i.MAX
	var hero_at := Vector2(0.5, 0.5)
	for marker: Dictionary in data.markers:
		if marker.kind == LocationMap.KIND_HERO:
			hero = marker.cell
			hero_at = marker.at
	if hero != Vector3i.MAX:
		var r := cell_rect(hero)
		room_camera.center_on(r.position + hero_at * r.size)
	_apply_room_camera()
	_set_hovered_room(data.cells.get(hero, ""))


func _apply_room_camera() -> void:
	_grid.scale = Vector2.ONE * room_camera.zoom
	_grid.position = room_camera.offset


## Намальована кімната під точкою екрана або "".
func room_at(screen: Vector2) -> String:
	var data: LocationMap = maps[shown_id]
	var p := room_camera.to_content(screen - _rooms.global_position)
	if not Rect2(Vector2.ZERO, _rooms.size).has_point(screen - _rooms.global_position):
		return ""
	for c: Vector3i in data.cells:
		if data.state(c) != LocationMap.Cell.HIDDEN and cell_rect(c).has_point(p):
			return data.cells[c]
	return ""


## Підсвітка кімнати й її картка: назва (або «?») і скрині кімнати.
func _set_hovered_room(room: String) -> void:
	if room == hovered_room and %RoomCard.visible == (room != ""):
		return
	hovered_room = room
	%RoomCard.visible = room != ""
	_grid.queue_redraw()
	if room == "":
		return
	var data: LocationMap = maps[shown_id]
	if data.room_explored(room):
		var opened := 0
		var total := 0
		for marker: Dictionary in data.markers:
			if data.cells[marker.cell] == room and marker.kind in [LocationMap.KIND_CHEST, LocationMap.KIND_CHEST_OPEN]:
				total += 1
				opened += int(marker.kind == LocationMap.KIND_CHEST_OPEN)
		%RoomName.text = LocationMap.room_title(room)
		%RoomStats.text = tr("Chests %d/%d") % [opened, total]
	else:
		%RoomName.text = "?"
		%RoomStats.text = tr("saw the entrance, not entered yet")
	%RoomCard.reset_size()


## Прямокутник клітинки в координатах Grid.
func cell_rect(c: Vector3i) -> Rect2:
	return Rect2(Vector2(c.x - _grid_min.x, c.y - _grid_min.y) * UITokens.MAP_CELL, UITokens.MAP_CELL)


func _draw_cells() -> void:
	if shown_id == "":
		return
	var data: LocationMap = maps[shown_id]
	for c: Vector3i in data.cells:
		var state: LocationMap.Cell = data.state(c)
		var r := cell_rect(c)
		if state == LocationMap.Cell.EXPLORED:
			_grid.draw_rect(r, UITokens.MAP_ROOM_FILL)
			_grid.draw_rect(r, UITokens.MAP_INK, false, UITokens.MAP_ROOM_BORDER)
		elif state == LocationMap.Cell.SEEN:
			MapIcon.dashed_rect(_grid, r, Color(UITokens.MAP_INK, UITokens.MAP_SEEN_ALPHA), UITokens.MAP_SEEN_BORDER,
					UITokens.MAP_SEEN_DASH, UITokens.MAP_SEEN_GAP)
	if hovered_room == "":
		return
	for c: Vector3i in data.cells:
		if data.cells[c] == hovered_room and data.state(c) != LocationMap.Cell.HIDDEN:
			_grid.draw_rect(cell_rect(c), UITokens.MAP_GOLD, false, UITokens.MAP_ROOM_HOVER_BORDER)


## Назва — у першій клітинці кімнати, лише для досліджених; «?» — для кімнати, від якої бачено тільки вхід.
func _add_room_names(data: LocationMap) -> void:
	var rooms: Array[String] = []
	for c: Vector3i in data.cells:
		if not data.cells[c] in rooms:
			rooms.append(data.cells[c])
	for room in rooms:
		var explored := data.room_explored(room)
		var cell: Vector3i = data.first_cell(room, LocationMap.Cell.EXPLORED if explored else LocationMap.Cell.SEEN)
		if cell == Vector3i.MAX:
			continue  # кімнату ще не видно
		var label := Label.new()
		label.theme_type_variation = &"MapRoomName"
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.text = LocationMap.room_title(room) if explored else "?"
		label.position = cell_rect(cell).position + UITokens.MAP_ROOM_NAME_PAD
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(label)


## Підпис переходу — внизу верхньої клітинки, по центру; лише між клітинками, яких хоч одну досліджено.
func _add_passages(data: LocationMap) -> void:
	for passage: Dictionary in data.passages:
		var upper: Vector3i = passage.upper
		var lower: Vector3i = upper + LocationMap.DIRS[LocationMap.DOWN]
		var states: Array = [data.state(upper), data.state(lower)]
		if LocationMap.Cell.HIDDEN in states or not LocationMap.Cell.EXPLORED in states:
			continue
		var label := Label.new()
		label.theme_type_variation = &"MapPassage"
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.text = tr(PASSAGE_TEXT[passage.kind])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(label)
		var r := cell_rect(upper)
		label.size = Vector2(r.size.x, label.get_combined_minimum_size().y)
		label.position = Vector2(r.position.x, r.end.y - label.size.y)


func _add_icons(data: LocationMap) -> void:
	for marker: Dictionary in data.markers:
		var state: LocationMap.Cell = data.state(marker.cell)
		if state == LocationMap.Cell.HIDDEN or (state == LocationMap.Cell.SEEN and not marker.kind in SEEN_KINDS):
			continue
		var icon: MapIcon = MapIcon.new()
		icon.kind = &"chest" if marker.kind == LocationMap.KIND_CHEST_OPEN else marker.kind
		icon.dimmed = marker.kind == LocationMap.KIND_CHEST_OPEN
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size = Vector2.ONE * UITokens.MAP_ICON
		var r := cell_rect(marker.cell)
		icon.position = r.position + (marker.at as Vector2) * r.size - icon.size / 2.0
		icon.set_meta(&"marker", marker.kind)
		_grid.add_child(icon)


# ── Ввід, підказки, мова ────────────────────────────────────────────────────

## Лише коли фокус на карті (BACKLOG 24): на карту заходять D-pad → / A з вкладки. На рівні 1 «вліво» з першої
## шпильки і B не забираємо — FocusRouter повертає фокус на вкладки, як у кожній вкладці.
func _gui_input(event: InputEvent) -> void:
	if not is_map_active:
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		_mouse_input(event)
		return
	if level == Level.LOCATION:
		if event.is_action_pressed(&"ui_cancel"):
			show_world()
			accept_event()
		elif _is_direction(event):
			accept_event()  # фокус лишається на карті; стрілки рухають карту в _process
		return
	if event.is_action_pressed(&"ui_right"):
		select(selected + 1)
		world_camera.reveal(pin_center(selected), UITokens.MAP_REVEAL_MARGIN)
		accept_event()
	elif event.is_action_pressed(&"ui_left") and selected > 0:
		select(selected - 1)
		world_camera.reveal(pin_center(selected), UITokens.MAP_REVEAL_MARGIN)
		accept_event()
	elif event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_down"):
		accept_event()
	elif event.is_action_pressed(&"ui_accept"):
		open_location(location_ids[selected])
		accept_event()


## Миша: ліва кнопка тягне (клац без тягнення відкриває шпильку), коліщатко масштабує, рух вибирає.
func _mouse_input(event: InputEvent) -> void:
	var at: Vector2 = (event as InputEventMouse).global_position
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var factor: float = UITokens.MAP_ZOOM_STEP if button.button_index == MOUSE_BUTTON_WHEEL_UP \
				else 1.0 / UITokens.MAP_ZOOM_STEP
		_camera().zoom_at(_to_camera(at), factor)
		_apply_camera()
		accept_event()
	elif button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_dragging = true
			_drag_travel = 0.0
			_drag_velocity = Vector2.ZERO
			_camera().velocity = Vector2.ZERO
			_camera().goal = null
			grab_focus()
		elif _dragging:
			_dragging = false
			if _drag_travel <= UITokens.MAP_DRAG_SLOP:
				_click(at)
			elif Time.get_ticks_msec() - _drag_last_motion <= UITokens.MAP_GLIDE_STALE * 1000.0:
				_camera().velocity = _drag_velocity.limit_length(UITokens.MAP_GLIDE_MAX)
		accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging:
			_drag_travel += motion.relative.length()
			_drag_velocity = motion.velocity
			_drag_last_motion = Time.get_ticks_msec()
			_camera().pan(motion.relative)
			_apply_camera()
			accept_event()
		_hover(at)


## Під курсором: на рівні 1 вибирається шпилька (картка за нею), на рівні 2 підсвічується кімната.
func _hover(at: Vector2) -> void:
	if level == Level.WORLD:
		var i := pin_at(at)
		if i >= 0 and i != selected:
			select(i)
	else:
		_set_hovered_room(room_at(at))


func _click(at: Vector2) -> void:
	if level == Level.WORLD and pin_at(at) >= 0:
		select(pin_at(at))
		open_location(location_ids[selected])


func _camera() -> MapCamera:
	return world_camera if level == Level.WORLD else room_camera


## Точка екрана в координатах вікна камери: рівень 1 — кадр (Frame стоїть у нулі), рівень 2 — Rooms.
func _to_camera(at: Vector2) -> Vector2:
	return at if level == Level.WORLD else at - _rooms.global_position


func _apply_camera() -> void:
	if level == Level.WORLD:
		_apply_world_camera()
	else:
		_apply_room_camera()


## Стік, клавіші й тригери тримаються — карта їде й масштабується щокадру; ковзання після миші — теж тут.
func _process(delta: float) -> void:
	if not is_map_active:
		return
	var cam := _camera()
	var moved := false
	if has_focus():
		var dir := _pan_input()
		if dir != Vector2.ZERO:
			cam.velocity = Vector2.ZERO
			cam.pan(-dir * UITokens.MAP_PAN_SPEED * delta)
			moved = true
		var zoom_dir := _zoom_input()
		if zoom_dir != 0.0:
			cam.zoom_at(cam.view.get_center(), pow(UITokens.MAP_ZOOM_RATE, zoom_dir * delta))
			moved = true
	if not _dragging and cam.step(delta):
		moved = true
	if not moved:
		return
	_apply_camera()
	# Без миші вибір — під центром вікна (на рівні 2 — кімната там, куди дивишся).
	if level == Level.LOCATION and not _dragging:
		_set_hovered_room(room_at(_rooms.global_position + cam.view.get_center()))


## Напрям погляду: правий стік і WASD; на рівні 2 ще стрілки, D-pad і лівий стік (на рівні 1 вони вибирають шпильку).
func _pan_input() -> Vector2:
	var dir := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if dir.length() < UITokens.MAP_STICK_DEADZONE:
		dir = Vector2.ZERO
	dir += Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if level == Level.LOCATION:
		dir += Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down", UITokens.MAP_STICK_DEADZONE)
	return dir.limit_length(1.0)


## +1 — ближче (правий тригер, E), −1 — далі (лівий тригер, Q).
func _zoom_input() -> float:
	var z: float = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	if absf(z) < UITokens.MAP_STICK_DEADZONE:
		z = 0.0
	z += Input.get_action_strength(&"menu_next_tab") - Input.get_action_strength(&"menu_prev_tab")
	return clampf(z, -1.0, 1.0)


func _is_direction(event: InputEvent) -> bool:
	return event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right") \
			or event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_down")


## Підказки показують тільки те, що справді працює на цьому рівні.
func _publish_hints() -> void:
	var bar: Node = get_tree().get_first_node_in_group(&"ui_bottom_bar")
	if not is_map_active:
		bar.set_context_hint("")
	elif level == Level.WORLD:
		bar.set_context_hint("%s %s" % [tr("Left / Right — choose a location. A — open its map."), tr(PAN_HINT)])
	else:
		bar.set_context_hint("%s %s" % [tr(PAN_HINT), tr("B — back to the world map.")])


func _refresh_texts() -> void:
	if not is_map_active:
		return
	_update_world()
	if level == Level.LOCATION:
		open_location(shown_id)
	_publish_hints()
