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
		var room: Node = (load(MAPS % room_name) as PackedScene).instantiate()
		for node_name: String in ROOMS[room_name]:
			var spec: Dictionary = ROOMS[room_name][node_name]
			if mode == "mask":
				var path: String = out_dir.path_join("%s_%s.png" % [room_name, node_name])
				_mask(room, spec).save_png(path)
				print("mask ", path)
			else:
				_place(room, room_name, node_name, spec)
		if mode == "place":
			var scene_path: String = MAPS % room_name
			var uid: int = ResourceLoader.get_resource_uid(scene_path)
			var packed := PackedScene.new()
			packed.pack(room)
			print("save %s %d %d" % [room_name, ResourceSaver.save(packed, scene_path), ResourceSaver.set_uid(scene_path, uid)])
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


func _place(room: Node, room_name: String, node_name: String, spec: Dictionary) -> void:
	var sprite := room.get_node_or_null(NodePath(node_name)) as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = node_name
		room.add_child(sprite)
		room.move_child(sprite, room.get_node(^"TileMap").get_index() + 1)
		sprite.owner = room
	var art: String = ART % ("%s_%s" % [room_name, node_name])
	assert(ResourceLoader.exists(art), "немає %s — спершу paint_terrain.py" % art)
	sprite.texture = load(art)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.scale = Vector2(PX, PX)
	sprite.position = Vector2.ZERO
	sprite.offset = Vector2.ZERO
	for layer_path: String in spec.layers:
		(room.get_node(NodePath(layer_path)) as TileMapLayer).visible = false
