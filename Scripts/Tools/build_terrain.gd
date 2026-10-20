extends SceneTree

## Намальована земля кімнат (D248, D249): тайли лишаються колізією (невидимі), вигляд — одна картинка на кімнату
## з Scripts/Tools/paint_terrain.py. Два кроки, між ними — Python:
##   godot --headless --path . --script res://Scripts/Tools/build_terrain.gd -- mask   # маски твердого → %TEMP%/terrain_masks
##   python -I Scripts/Tools/paint_terrain.py                                        # маски → Assets/Backgrounds/Terrain
##   godot --headless --path . --script res://Scripts/Tools/build_terrain.gd -- place  # вузли картинок у кімнатах
## Після mask / place можна назвати кімнати (Canyon Village …) — тоді лише їх.
## Маска — у пікселях гри (1 px = 1.5 px світу, як у героя): R — тверде, G — односторонній місток.

const MAPS := "res://SampleProject/Maps/%s.tscn"
const ART := "res://SampleProject/Assets/Backgrounds/Terrain/%s.png"
const PX := 1.5
## Кімната → вузол картинки → що в ній тверде: шари тайлів і тіла з CollisionPolygon2D (шляхи від кореня кімнати).
## Ущелина каньйону — окремий вузол: до обвалу містка CanyonBridge.gd її ховає.
const ROOMS := {
	"Canyon": {
		"Terrain": {"layers": ["TileMap/Foreground"], "bodies": ["PrideRock"]},
		"Gorge": {"layers": ["TileMap/RockCollision"], "bodies": []},
	},
	"Village": {"Terrain": {"layers": ["TileMap/Foreground"], "bodies": []}},
	"DesertRoad": {"Terrain": {"layers": ["TileMap/Foreground"], "bodies": []}},
	"CityGates": {"Terrain": {"layers": ["TileMap/Foreground"], "bodies": []}},
	"City": {"Terrain": {"layers": ["TileMap/Foreground"], "bodies": []}},
	"LaboratoryOutside": {"Terrain": {"layers": ["TileMap/Foreground"], "bodies": []}},
	"MayorHall": {"Terrain": {"layers": ["TileMap/Foreground"], "bodies": []}},
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0]
	assert(mode in ["mask", "place"], "build_terrain.gd -- mask | place [кімната ...]")
	var only := args.slice(1)
	var out_dir: String = OS.get_environment("TEMP").path_join("terrain_masks")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for room_name: String in ROOMS:
		if not only.is_empty() and not only.has(room_name):
			continue
		if mode == "place":
			_place(room_name)
			continue
		var room: Node = (load(MAPS % room_name) as PackedScene).instantiate()
		for node_name: String in ROOMS[room_name]:
			var path: String = out_dir.path_join("%s_%s.png" % [room_name, node_name])
			_mask(room, ROOMS[room_name][node_name]).save_png(path)
			print("mask ", path)
		room.free()
	quit()


## Маска твердого від (0, 0) кімнати до нижнього правого краю всього твердого.
func _mask(room: Node, spec: Dictionary) -> Image:
	var cells: Array[Array] = []  # [Rect2 у px світу, односторонній]
	var end := Vector2.ZERO
	for layer_path: String in spec.layers:
		var layer: TileMapLayer = room.get_node(NodePath(layer_path))
		var tile := Vector2(layer.tile_set.tile_size)
		for c: Vector2i in layer.get_used_cells():
			var r := Rect2(_offset(room, layer) + Vector2(c) * tile, tile)
			var data: TileData = layer.get_cell_tile_data(c)
			var one_way: bool = data.get_collision_polygons_count(0) > 0 and data.is_collision_polygon_one_way(0, 0)
			cells.append([r, one_way])
			end = end.max(r.end)
	var polygons: Array[PackedVector2Array] = []
	for body_path: String in spec.bodies:
		var body: Node2D = room.get_node(NodePath(body_path))
		for shape: CollisionPolygon2D in body.find_children("*", "CollisionPolygon2D", false, false):
			var poly := PackedVector2Array()
			for p: Vector2 in shape.polygon:
				poly.append(_offset(room, shape) + p)
			polygons.append(poly)
			for p: Vector2 in poly:
				end = end.max(p)
	var size := Vector2i(ceili(end.x / PX), ceili(end.y / PX))
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	for cell: Array in cells:
		var r: Rect2 = cell[0]
		var a := Vector2i((r.position / PX).round()).max(Vector2i.ZERO)
		var b := Vector2i((r.end / PX).round())
		if b.x <= a.x or b.y <= a.y:
			continue
		img.fill_rect(Rect2i(a, b - a), Color(1, 1 if cell[1] else 0, 0))
	for poly: PackedVector2Array in polygons:
		var box := Rect2(poly[0], Vector2.ZERO)
		for p: Vector2 in poly:
			box = box.expand(p)
		for y: int in range(int(box.position.y / PX), ceili(box.end.y / PX)):
			for x: int in range(int(box.position.x / PX), ceili(box.end.x / PX)):
				if Geometry2D.is_point_in_polygon((Vector2(x, y) + Vector2(0.5, 0.5)) * PX, poly):
					img.set_pixel(x, y, Color(1, 0, 0))
	return img


## Зсув вузла від кореня кімнати (масштабів у кімнатах немає: TileMap у City стоїть вище на 160 px).
func _offset(room: Node, node: Node2D) -> Vector2:
	var at := Vector2.ZERO
	var n: Node = node
	while n != room:
		at += (n as Node2D).position
		n = n.get_parent()
	return at


## Правка тексту .tscn, а не PackedScene.pack(): pack переписує всю сцену (вшиває скрипти й властивості інстансів
## як перевизначення). Додає вузол-картинку одразу після піддерева TileMap і ховає шари тайлів; уже доданий — не чіпає.
func _place(room_name: String) -> void:
	var scene_path: String = MAPS % room_name
	var text := FileAccess.get_file_as_string(scene_path)
	for node_name: String in ROOMS[room_name]:
		var art: String = ART % ("%s_%s" % [room_name, node_name])
		assert(ResourceLoader.exists(art), "немає %s — спершу paint_terrain.py" % art)
		if text.contains('[node name="%s" type="Sprite2D" parent="."' % node_name):
			continue
		var id := "terrain_%s" % node_name.to_snake_case()
		var res_end := text.find("

", text.rfind("[ext_resource "))
		text = text.insert(res_end, '
[ext_resource type="Texture2D" path="%s" id="%s"]' % [art, id])
		for layer_path: String in ROOMS[room_name][node_name].layers:
			var parts := layer_path.rsplit("/", true, 1)
			var head := text.find('[node name="%s" type="TileMapLayer" parent="%s"' % [parts[1], parts[0]])
			assert(head >= 0, "немає шару %s у %s" % [layer_path, room_name])
			var eol := text.find("
", head)
			if not text.substr(eol, 17) == "
visible = false
":
				text = text.insert(eol, "
visible = false")
		# перший вузол верхнього рівня після TileMap (його діти мають parent="TileMap…")
		var tilemap := text.find('[node name="TileMap" ')
		var next := text.find('parent="."', text.find("
", tilemap))
		assert(next >= 0, "у %s після TileMap немає вузлів верхнього рівня" % room_name)
		next = text.rfind("[node ", next)
		var block := '[node name="%s" type="Sprite2D" parent="."]
texture_filter = 1
scale = Vector2(%s, %s)
texture = ExtResource("%s")
centered = false

' % [node_name, PX, PX, id]
		text = text.insert(next, block)
	var f := FileAccess.open(scene_path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("placed ", room_name)
