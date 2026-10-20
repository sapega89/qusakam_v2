extends SceneTree

## Скеля Прайду в каньйоні (D248): сама земля, якою йде герой, — тераси зі сходу, вершина, ніс над західними
## сходами (колізія — полігон PRIDE_ROCK, вигляд малює Scripts/Tools/paint_terrain.py разом із плато);
## далекі стіни каньйону паралаксом; сюжетні тригери — на всю висоту кімнати, щоб їх не перестрибнути
## зі скелі. Картинки землі й ущелини (Terrain, Gorge) ставить build_terrain.gd, брами й переходи — не тут.
## Запуск: godot --headless --path . --script res://Scripts/Tools/build_canyon.gd

const ROOM := "res://SampleProject/Maps/Canyon.tscn"
const ART := "res://SampleProject/Assets/Backgrounds/Canyon/%s.png"
const TILE := 32
const SOURCE := 1
const SOLID := Vector2i(8, 7)
## Обрис скелі (px кімнати, за годинниковою): західна сходинка y 300 (стрибок 84 від дороги y 384), під носом —
## ніша, ніс на вершині y 216, тераси на схід y 272 і 328 (стрибок герою — 103 px). Низ полігона — у плато.
const PRIDE_ROCK := [
	Vector2(1000, 400), Vector2(1000, 300), Vector2(1196, 300), Vector2(1204, 262), Vector2(1140, 254),
	Vector2(1080, 244), Vector2(1072, 228), Vector2(1080, 216), Vector2(1250, 214), Vector2(1420, 216),
	Vector2(1600, 216), Vector2(1606, 272), Vector2(1760, 272), Vector2(1766, 328), Vector2(1920, 328),
	Vector2(1928, 384), Vector2(1928, 400),
]
## Тригер Canyon_Exploration — біля підніжжя скелі, над західною сходинкою: середина тригера (y 240) — у повітрі.
const RIDGE_TRIGGER := "StateChangeTrigger2"
const RIDGE_TRIGGER_X := 1040.0
const TRIGGERS := ["StateChangeTrigger1", "StateChangeTrigger2", "StateChangeTrigger3"]
const ROOM_HEIGHT := 480.0

## Ущелина (D228): схема — Scripts/Tools/canyon_gorge.txt (стовпці 0–24, рядки 12–29); тайли Foreground там
## прибрано, тверде — у RockCollision, вигляд — картинка gorge.png з x 0, y 384.
const BLUR := "res://SampleProject/Resources/Materials/depth_blur_%s.tres"
const BACKDROP := "res://SampleProject/Scenes/Backgrounds/desert_backdrop_canyon.tscn"
const GORGE_LAYOUT := "res://Scripts/Tools/canyon_gorge.txt"
const GORGE_ROW0 := 12
## Тригер спуску — на дні ущелини (дно — рядок 27, y 864).
const EXIT_AT := Vector2(400, 830)
const EXIT_SIZE := Vector2(740, 64)
## Глибина під плато: нижні стіни каньйону й темна підкладка (сірого clear color не видно ніколи).
const DEPTH_TOP := 380.0
const DEPTH_UNDERLAY := Color(0.24, 0.15, 0.12)
## Місток (D231): стовпці настилу, стовпи на обох краях, поруччя, де починається обвал.
const BRIDGE_SCRIPT := "res://SampleProject/Scripts/Gameplay/CanyonBridge.gd"
const BRIDGE_COLS := Vector2i(1, 24)
const BRIDGE_POSTS := [26.0, 796.0]
const BRIDGE_RAIL_Y := 352.0
const BRIDGE_TRIGGER := Rect2(830, 200, 60, 200)


func _initialize() -> void:
	var room: Node = load(ROOM).instantiate()
	var tilemap: Node2D = room.get_node(^"TileMap")
	var fg: TileMapLayer = tilemap.get_node(^"Foreground")
	var rocks := tilemap.get_node_or_null(^"RockCollision") as TileMapLayer
	if rocks == null:
		rocks = TileMapLayer.new()
		rocks.name = "RockCollision"
		rocks.tile_set = fg.tile_set
		rocks.visible = false  # видно картинку скелі, тайли — лише тверді межі
		tilemap.add_child(rocks)
		rocks.owner = room
	rocks.clear()

	# Ущелина: тайли Foreground у її межах — у невидиму колізію за схемою
	var gorge := _read_gorge()
	for r in gorge.size():
		for c in gorge[r].length():
			var cell := Vector2i(c, GORGE_ROW0 + r)
			fg.erase_cell(cell)
			if gorge[r][c] == "#":
				rocks.set_cell(cell, SOURCE, SOLID)

	# Gate2 — невидимий настил містка через усю ущелину (D231): колізію відчиняє GateController за
	# village_left_complete (Canyon.gd), вигляд — вузол Bridge; бруківкового стовпа більше немає.
	var gate2: TileMapLayer = tilemap.get_node(^"Gate2")
	gate2.position = Vector2.ZERO
	gate2.modulate = Color.WHITE
	gate2.self_modulate = Color(1, 1, 1, 0)  # невидимий настил; modulate скидає GateController
	gate2.clear()
	for x in range(BRIDGE_COLS.x, BRIDGE_COLS.y + 1):
		gate2.set_cell(Vector2i(x, GORGE_ROW0), SOURCE, SOLID)

	# Фон каньйону — окрема сцена (зміни у вкладеній не пакуються): небо з паку, згенеровані хмари, далекі
	# мези й стіни каньйону (D235); той самий фон стоїть і в селі (D236).
	var old_backdrop: Node2D = room.get_node(^"Backdrop")
	var backdrop: Node2D = load(BACKDROP).instantiate()
	backdrop.position = old_backdrop.position
	room.add_child(backdrop)
	room.move_child(backdrop, old_backdrop.get_index())
	room.remove_child(old_backdrop)
	old_backdrop.free()
	backdrop.name = "Backdrop"
	backdrop.owner = room

	for old_name in ["PrideRock", "CanyonWalls", "CanyonDepths", "DepthUnderlay", "PlateauShade", "PlateauBody", "Bridge"]:
		var old := room.get_node_or_null(NodePath(old_name))
		if old:
			room.remove_child(old)
			old.free()
	var rock := StaticBody2D.new()
	rock.name = "PrideRock"
	var rock_shape := CollisionPolygon2D.new()
	rock_shape.name = "CollisionPolygon2D"
	rock_shape.polygon = PackedVector2Array(PRIDE_ROCK)
	rock.add_child(rock_shape)
	room.add_child(rock)
	room.move_child(rock, tilemap.get_index() + 1)
	rock.owner = room
	rock_shape.owner = room

	var depths := Parallax2D.new()
	depths.name = "CanyonDepths"
	depths.z_index = -9
	depths.scroll_scale = Vector2(0.45, 1)
	depths.repeat_size = Vector2(864, 0)
	depths.repeat_times = 4
	var depths_sprite := _sprite("canyon_depths", Vector2(0, DEPTH_TOP))
	depths_sprite.material = load(BLUR % "near")
	depths.add_child(depths_sprite)
	room.add_child(depths)
	room.move_child(depths, room.get_node(^"Backdrop").get_index() + 1)
	depths.owner = room
	depths_sprite.owner = room

	var underlay := ColorRect.new()
	underlay.name = "DepthUnderlay"
	underlay.z_index = -11
	underlay.color = DEPTH_UNDERLAY
	underlay.position = Vector2(0, DEPTH_TOP)
	underlay.size = Vector2(2592, 960 - DEPTH_TOP + 64)
	underlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(underlay)
	room.move_child(underlay, 0)
	underlay.owner = room

	_add_bridge(room)

	var exit_trigger: Node2D = room.get_node(^"CanyonExitTrigger")
	exit_trigger.position = EXIT_AT
	var exit_shape := RectangleShape2D.new()
	exit_shape.size = EXIT_SIZE
	exit_trigger.get_node(^"CollisionShape2D").shape = exit_shape

	# Тригери на всю висоту кімнати (вузол лишається, де був; зміщення форми — до центру кімнати по y)
	for trigger_name in TRIGGERS:
		var trigger: Node2D = room.get_node(NodePath(trigger_name))
		var shape_node: CollisionShape2D = trigger.get_node(^"CollisionShape2D")
		var shape := RectangleShape2D.new()
		shape.size = Vector2(48, ROOM_HEIGHT)
		shape_node.shape = shape
		shape_node.position.y = ROOM_HEIGHT / 2.0 - trigger.position.y
		if trigger_name == RIDGE_TRIGGER:
			shape_node.position.x = RIDGE_TRIGGER_X - trigger.position.x

	var uid := ResourceLoader.get_resource_uid(ROOM)
	var packed := PackedScene.new()
	packed.pack(room)
	print("save ", ResourceSaver.save(packed, ROOM), " uid ", ResourceSaver.set_uid(ROOM, uid))
	room.free()
	quit()


func _sprite(art: String, at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = load(ART % art)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.scale = Vector2(1.5, 1.5)
	sprite.position = at
	return sprite


func _read_gorge() -> PackedStringArray:
	var rows := PackedStringArray()
	for line in FileAccess.get_file_as_string(GORGE_LAYOUT).split("
"):
		if line.is_empty() or line.begins_with("# "):
			continue
		rows.append(line)
	return rows


## Місток із дошок, двох стовпів і мотузки-поруччя; дошки й мотузка — у Pieces (падають при обвалі).
func _add_bridge(room: Node) -> void:
	var bridge := Node2D.new()
	bridge.name = "Bridge"
	bridge.set_script(load(BRIDGE_SCRIPT))
	room.add_child(bridge)
	room.move_child(bridge, room.get_node(^"Gorge").get_index() + 1)  # Gorge ставить build_terrain.gd
	bridge.owner = room
	var pieces := Node2D.new()
	pieces.name = "Pieces"
	bridge.add_child(pieces)
	pieces.owner = room
	for x in range(BRIDGE_COLS.x, BRIDGE_COLS.y + 1):
		var plank := _sprite("bridge_plank", Vector2(x * TILE + TILE / 2.0, GORGE_ROW0 * TILE))
		plank.name = "Plank%d" % x
		plank.centered = true
		plank.offset = Vector2(0, plank.texture.get_height() / 2.0)  # верх дошки — на рівні дороги
		pieces.add_child(plank)
		plank.owner = room
	var rail := _sprite("bridge_rope", Vector2(BRIDGE_POSTS[0], BRIDGE_RAIL_Y))
	rail.name = "Rail"
	rail.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	rail.region_enabled = true
	rail.region_rect = Rect2(0, 0, (BRIDGE_POSTS[1] - BRIDGE_POSTS[0]) / 1.5, 3)
	pieces.add_child(rail)
	rail.owner = room
	for i in BRIDGE_POSTS.size():
		var post := _sprite("bridge_post", Vector2(BRIDGE_POSTS[i] - 6, BRIDGE_RAIL_Y - 12))
		post.name = "Post%d" % (i + 1)
		bridge.add_child(post)
		post.owner = room
	var trigger := Area2D.new()
	trigger.name = "CollapseTrigger"
	trigger.position = BRIDGE_TRIGGER.get_center()
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = BRIDGE_TRIGGER.size
	shape_node.shape = shape
	trigger.add_child(shape_node)
	bridge.add_child(trigger)
	trigger.owner = room
	shape_node.owner = room
