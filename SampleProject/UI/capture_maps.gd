extends SceneTree

## Огляд кімнат: кожна кімната MetSys цілком, з рамкою її клітинок (червона), тригерами
## (жовті), точками ворогів (червоні), маркерами й точками збереження (сині) → design/shots/maps/.
## Список кімнат і їхні розміри беруться з MapData.txt і налаштувань MetSys, а не вписані руками.
## Скрипт кімнати знімається: показуємо, що намальовано, а не запускаємо сюжет.
## Потрібне ВІКНО. godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_maps.gd

const VIEW := Vector2(1920, 1080)
const MARGIN := 80.0


func _initialize() -> void:
	await process_frame
	await process_frame
	var cell: Vector2 = root.get_node("MetSys").settings.in_game_cell_size
	var rooms := _rooms_from_map_data()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://design/shots/maps"))
	for path in rooms:
		var cells: Array = rooms[path]
		var min_c := Vector2i(cells[0].x, cells[0].y)
		var max_c := min_c
		for c in cells:
			min_c = Vector2i(mini(min_c.x, c.x), mini(min_c.y, c.y))
			max_c = Vector2i(maxi(max_c.x, c.x), maxi(max_c.y, c.y))
		var size := Vector2(max_c - min_c + Vector2i.ONE) * cell
		await _shot(path, size, cells, min_c, cell)
	quit()


## {scene_path: [Vector3i клітинок]} з MapData.txt.
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
		rooms[path].append(Vector3i(int(xyz[0]), int(xyz[1]), int(xyz[2])))
	return rooms


func _shot(path: String, size: Vector2, cells: Array, min_c: Vector2i, cell: Vector2) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var room: Node = load(path).instantiate()
	room.set_script(null)
	holder.add_child(room)

	var zoom := minf((VIEW.x - MARGIN * 2) / size.x, (VIEW.y - MARGIN * 2) / size.y)
	var px := 1.0 / zoom  # 1 екранний піксель у світових одиницях
	# Рамка кожної клітинки MetSys.
	for c in cells:
		var o := Vector2(c.x - min_c.x, c.y - min_c.y) * cell
		_rect(holder, Rect2(o, cell), Color(1, 0.2, 0.2, 0.5), 2 * px)
	_rect(holder, Rect2(Vector2.ZERO, size), Color(1, 0.2, 0.2), 4 * px)
	# Позначки.
	for n in room.find_children("*", "Node2D", true, false):
		var color := Color.TRANSPARENT
		if n is Area2D:
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
	title.text = "%s — %d cells, %d×%d px" % [path.get_file().get_basename(), cells.size(), size.x, size.y]
	title.position = Vector2(16, 16)
	title.add_theme_font_size_override("font_size", 28)
	var hud := CanvasLayer.new()
	hud.add_child(title)
	holder.add_child(hud)

	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	var out := ProjectSettings.globalize_path("res://design/shots/maps/%s.png" % path.get_file().get_basename())
	root.get_texture().get_image().save_png(out)
	print("shot %s" % out)
	holder.queue_free()
	await process_frame


func _rect(parent: Node, r: Rect2, color: Color, width: float) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	line.width = width
	line.default_color = color
	parent.add_child(line)
