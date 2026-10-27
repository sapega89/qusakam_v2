extends Control

## Вкладка World Map — карта у два рівні (D458, D487, D565; design/world_map_spec.md, Figma 539:6472 / 539:6615).
## Рівень 1 — ілюстрована мапа світу (тло меню) зі шпилькою на кожну локацію locations.json (тут / відвідано /
## закрито) і карткою вибраної: досліджено %, скрині. Вліво / вправо — між шпильками, A / Enter — рівень 2 вибраної,
## якщо герой там бував.
## Рівень 2 — кімнати локації з клітинок MetSys (LocationMap): досліджені залиті, з баченим входом — пунктиром, решта
## не малюються; назви кімнат, значки об'єктів, підписи драбин і спусків, легенда. B / Esc — назад на рівень 1.
## Вкладка відкривається на рівні 1 (вона зветься World Map; кадри не кажуть інакше — рішення рутини, звіт world-map).
## Розкладка й стилі — у сцені й темі (UITokens), тут поведінка й малювання клітинок.

const LocationDB := preload("res://SampleProject/Scripts/Systems/LocationDB.gd")
const LocationMap := preload("res://SampleProject/Scripts/Systems/LocationMap.gd")
const MapIcon := preload("res://SampleProject/UI/Components/map_icon.gd")
const PIN_SCENE := preload("res://SampleProject/Scenes/Menus/Game/world_map_pin.tscn")

enum Level { WORLD, LOCATION }

const PIN_HERE := &"here"
const PIN_VISITED := &"visited"
const PIN_LOCKED := &"locked"
const PIN_PLATE := {&"here": &"MapPinHere", &"visited": &"MapPin", &"locked": &"MapPinLocked"}
const PIN_DOT := {&"here": &"MapPinDotHere", &"visited": &"MapPinDotVisited", &"locked": &"MapPinDotLocked"}
const PIN_TEXT := {&"here": "you are here", &"visited": "visited", &"locked": "locked"}
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

## Ліва верхня клітинка рамки рівня 2 (найменші x, y намальованих клітинок).
var _grid_min := Vector2i.ZERO
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
	if active:
		_place_frame()
		_build_world()
		show_world()
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
		pin.position = LocationDB.map_pos(location_ids[i])
		if pin_state(location_ids[i]) == PIN_HERE:
			selected = i
	_update_world()


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
	# Велика локація стискається в рамку, мала стоїть у натуральний розмір посередині.
	var fit: float = minf(1.0, minf(_rooms.size.x / _grid.size.x, _rooms.size.y / _grid.size.y))
	_grid.scale = Vector2.ONE * fit
	_grid.position = (_rooms.size - _grid.size * fit) / 2.0
	_add_room_names(data)
	_add_passages(data)
	_add_icons(data)
	_grid.queue_redraw()


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
	if level == Level.LOCATION:
		if event.is_action_pressed(&"ui_cancel"):
			show_world()
			accept_event()
		elif _is_direction(event):
			accept_event()  # фокус лишається на карті
		return
	if event.is_action_pressed(&"ui_right"):
		select(selected + 1)
		accept_event()
	elif event.is_action_pressed(&"ui_left") and selected > 0:
		select(selected - 1)
		accept_event()
	elif event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_down"):
		accept_event()
	elif event.is_action_pressed(&"ui_accept"):
		open_location(location_ids[selected])
		accept_event()


func _is_direction(event: InputEvent) -> bool:
	return event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right") \
			or event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_down")


## Підказки показують тільки те, що справді працює на цьому рівні.
func _publish_hints() -> void:
	var bar: Node = get_tree().get_first_node_in_group(&"ui_bottom_bar")
	if not is_map_active:
		bar.set_context_hint("")
	elif level == Level.WORLD:
		bar.set_context_hint("Left / Right — choose a location. A — open its map.")
	else:
		bar.set_context_hint("B — back to the world map.")


func _refresh_texts() -> void:
	if not is_map_active:
		return
	_update_world()
	if level == Level.LOCATION:
		open_location(shown_id)
	_publish_hints()
