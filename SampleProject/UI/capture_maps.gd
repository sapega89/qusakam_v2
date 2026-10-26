extends SceneTree

## Огляд кімнат: кожна кімната MetSys цілком, з рамкою її клітинок (червона), тригерами
## (жовті), точками ворогів (червоні), маркерами й точками збереження (сині) → design/shots/maps/.
## Проходи (зелені): межа клітинки-проходу з MapData і кожні RoomDoor. Кожен прохід ще знімається зблизька,
## так, як його бачить гравець (одна клітинка на екран), і ці кадри складаються в design/shots/maps/exits_N.png —
## для перевірки, що прохід пояснений фоном (Sapega 2026-10-26: двері, вхід, колодязь, а не посеред стіни).
## Список кімнат і їхні розміри беруться з MapData.txt і налаштувань MetSys, а не вписані руками.
## Скрипт кімнати знімається: показуємо, що намальовано, а не запускаємо сюжет.
## Потрібне ВІКНО. godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_maps.gd

const VIEW := Vector2(1920, 1080)
const MARGIN := 80.0
const EXIT := Color(0.2, 1, 0.35)
const SIDES := ["right", "down", "left", "up"]  # порядок меж у MapData
const THUMB := Vector2i(640, 360)
const SHEET_COLS := 3
const SHEET_ROWS := 3

var _thumbs: Array[Image] = []


func _initialize() -> void:
	await process_frame
	await process_frame
	var cell: Vector2 = root.get_node("MetSys").settings.in_game_cell_size
	var rooms := _rooms_from_map_data()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://design/shots/maps"))
	for path in rooms:
		var cells: Array = rooms[path]
		var min_c := Vector2i(cells[0].cell.x, cells[0].cell.y)
		var max_c := min_c
		for c in cells:
			min_c = Vector2i(mini(min_c.x, c.cell.x), mini(min_c.y, c.cell.y))
			max_c = Vector2i(maxi(max_c.x, c.cell.x), maxi(max_c.y, c.cell.y))
		var size := Vector2(max_c - min_c + Vector2i.ONE) * cell
		await _shot(path, size, cells, min_c, cell)
	_save_sheets()
	quit()


## {scene_path: [{cell: Vector3i, borders: [праворуч, униз, ліворуч, угору]}]} з MapData.txt.
func _rooms_from_map_data() -> Dictionary:
	var lines := FileAccess.get_file_as_string("res://SampleProject/Maps/MapData.txt").split("\n")
	var rooms := {}
	for i in lines.size() - 1:
		if not lines[i].begins_with("["):
			continue
		var xyz := lines[i].trim_prefix("[").trim_suffix("]").split(",")
		var uid := lines[i + 1].get_slice(":", lines[i + 1].get_slice_count(":") - 1)
		if uid.is_empty():
			continue
		var path := ResourceUID.get_id_path(ResourceUID.text_to_id("uid://" + uid))
		if not rooms.has(path):
			rooms[path] = []
		var borders: Array[int] = []
		for b in lines[i + 1].get_slice("|", 0).split(","):
			borders.append(int(b))
		rooms[path].append({cell = Vector3i(int(xyz[0]), int(xyz[1]), int(xyz[2])), borders = borders})
	return rooms


func _shot(path: String, size: Vector2, cells: Array, min_c: Vector2i, cell: Vector2) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var room: Node = load(path).instantiate()
	room.set_script(null)
	holder.add_child(room)
	var room_name := path.get_file().get_basename()

	var zoom := minf((VIEW.x - MARGIN * 2) / size.x, (VIEW.y - MARGIN * 2) / size.y)
	var px := 1.0 / zoom  # 1 екранний піксель у світових одиницях
	# Рамка кожної клітинки MetSys, зелена межа на кожному проході.
	var exits: Array[Dictionary] = []  # {label, view: Rect2, mark: Rect2}
	for c in cells:
		var o := Vector2(c.cell.x - min_c.x, c.cell.y - min_c.y) * cell
		_rect(holder, Rect2(o, cell), Color(1, 0.2, 0.2, 0.5), 2 * px)
		for side in 4:
			if c.borders[side] < 1:
				continue
			var a: Vector2 = [Vector2(o.x + cell.x, o.y), Vector2(o.x, o.y + cell.y), o, o][side]
			var b: Vector2 = [o + cell, o + cell, Vector2(o.x, o.y + cell.y), Vector2(o.x + cell.x, o.y)][side]
			_line(holder, a, b, EXIT, 8 * px)
			exits.append({label = "%s · %s · %s" % [room_name, Vector2i(c.cell.x, c.cell.y), SIDES[side]],
				view = Rect2(o, cell), mark = Rect2(a, b - a)})
	_rect(holder, Rect2(Vector2.ZERO, size), Color(1, 0.2, 0.2), 4 * px)
	# Позначки.
	for n in room.find_children("*", "Node2D", true, false):
		var color := Color.TRANSPARENT
		if "target_room" in n:  # RoomDoor (preload його скрипта тягне автозавантаження, яких ще немає)
			color = EXIT
			var door := Rect2(n.global_position - Vector2(32, 48), Vector2(64, 96))
			_rect(holder, door, EXIT, 4 * px)
			exits.append({label = "%s · door %s → %s" % [room_name, n.name, n.target_room.get_file().get_basename()],
				view = Rect2(door.get_center() - cell / 2, cell), mark = door})
		elif n is Area2D:
			color = Color(1, 0.85, 0.1)
		elif n.get_script() == preload("res://SampleProject/Scripts/Gameplay/EnemySpawnPoint.gd"):
			color = Color(1, 0.25, 0.25)
		elif n is Marker2D:
			color = Color(0.3, 0.6, 1)
		if color.a == 0.0:
			continue
		var dot := Polygon2D.new()
		var poly := PackedVector2Array()
		for k in 12:
			poly.append(Vector2.from_angle(TAU * k / 12) * 10 * px)
		dot.polygon = poly
		dot.color = color
		dot.position = n.global_position
		holder.add_child(dot)
		var label := Label.new()
		label.text = n.name
		label.scale = Vector2.ONE * px
		label.position = n.global_position + Vector2(12, -12) * px
		label.add_theme_color_override("font_color", color)
		label.add_theme_constant_override("outline_size", 6)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		holder.add_child(label)

	var cam := Camera2D.new()
	cam.position = size / 2
	cam.zoom = Vector2.ONE * zoom
	holder.add_child(cam)
	cam.make_current()
	var title := Label.new()
	title.text = "%s — %d cells, %d×%d px" % [room_name, cells.size(), size.x, size.y]
	title.position = Vector2(16, 16)
	title.add_theme_font_size_override("font_size", 28)
	var hud := CanvasLayer.new()
	hud.add_child(title)
	holder.add_child(hud)

	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	var out := ProjectSettings.globalize_path("res://design/shots/maps/%s.png" % room_name)
	root.get_texture().get_image().save_png(out)
	print("shot %s" % out)

	# Кожен прохід зблизька: камера на клітинку, як у грі (одна клітинка на екран). Позначки тоншають, щоб
	# лишатися тієї ж екранної товщини й не закривати фон біля проходу.
	var close_zoom := minf(VIEW.x / cell.x, VIEW.y / cell.y)
	for n in holder.get_children():
		if n is Line2D:
			n.width *= zoom / close_zoom
		elif n is Polygon2D or n is Label:
			n.scale *= zoom / close_zoom
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	for e in exits:
		cam.position = e.view.get_center()
		cam.zoom = Vector2.ONE * close_zoom
		title.text = e.label
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
		_thumbs.append(img)
	holder.queue_free()
	await process_frame


func _save_sheets() -> void:
	var per := SHEET_COLS * SHEET_ROWS
	for s in ceili(_thumbs.size() / float(per)):
		var sheet := Image.create(THUMB.x * SHEET_COLS, THUMB.y * SHEET_ROWS, false, _thumbs[0].get_format())
		for k in mini(per, _thumbs.size() - s * per):
			var t := _thumbs[s * per + k]
			sheet.blit_rect(t, Rect2i(Vector2i.ZERO, THUMB), Vector2i(k % SHEET_COLS, k / SHEET_COLS) * THUMB)
		var out := ProjectSettings.globalize_path("res://design/shots/maps/exits_%d.png" % (s + 1))
		sheet.save_png(out)
		print("sheet %s" % out)


func _rect(parent: Node, r: Rect2, color: Color, width: float) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	line.width = width
	line.default_color = color
	parent.add_child(line)


func _line(parent: Node, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([a, b])
	line.width = width
	line.default_color = color
	parent.add_child(line)
