extends SceneTree

## Скеля Прайду в каньйоні (D227): невидима колізія навісу й уступів (шар RockCollision), картинка скелі
## (Scripts/Tools/draw_canyon.py), далекі стіни каньйону паралаксом; сюжетні тригери — на всю висоту
## кімнати, щоб їх не перестрибнути зі скелі. Плато, ущелину, брами й переходи не чіпає.
## Запуск: godot --headless --path . --script res://Scripts/Tools/build_canyon.gd

const ROOM := "res://SampleProject/Maps/Canyon.tscn"
const ART := "res://SampleProject/Assets/Backgrounds/Canyon/%s.png"
const TILE := 32
const SOURCE := 1
const SOLID := Vector2i(8, 7)
const ONE_WAY := Vector2i(1, 0)
## Ті самі числа, що SHELF / LEDGES у draw_canyon.py: (рядок, перший стовпець, останній стовпець).
const SHELF := [[3, 40, 49], [4, 35, 51], [5, 37, 51]]
const LEDGES := [[10, 59, 61], [8, 56, 58], [6, 53, 55]]
## Лівий верх картинки скелі (стовпець 33, рядок 2).
const ROCK_AT := Vector2(33 * 32, 2 * 32)
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
## Далекі стіни: основа сховалась за лінією плато, трохи холодніші (повітряна перспектива).
const WALLS_Y := 45.0
const WALLS_TINT := Color(1.04, 1.02, 1.12)
## Тіло плато темнішає з глибиною (множення), щоб верхня лінія плато відділялась від маси.
const PLATEAU_SHADE_RECT := Rect2(800, 416, 1792, 544)
const PLATEAU_SHADE_BOTTOM := Color(0.55, 0.5, 0.5)
## Дорога плато й тіло під нею — картинка з рядка 12 (y 384), D231.
const PLATEAU_BODY_AT := Vector2(800, 384)
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
	for row in SHELF:
		for x in range(row[1], row[2] + 1):
			rocks.set_cell(Vector2i(x, row[0]), SOURCE, SOLID)
	for row in LEDGES:
		for x in range(row[1], row[2] + 1):
			rocks.set_cell(Vector2i(x, row[0]), SOURCE, ONE_WAY)

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

	# Фон пустелі для каньйону — desert_backdrop_4 без Plan2 (оазис з водою й велика скеля): вода внизу
	# читалась як безодня, скеля конкурувала зі Скелею Прайду. Окрема сцена, бо зміни у вкладеній не пакуються.
	var old_backdrop: Node2D = room.get_node(^"Backdrop")
	var backdrop: Node2D = load(BACKDROP).instantiate()
	backdrop.position = old_backdrop.position
	room.add_child(backdrop)
	room.move_child(backdrop, old_backdrop.get_index())
	room.remove_child(old_backdrop)
	old_backdrop.free()
	backdrop.name = "Backdrop"
	backdrop.owner = room

	for old_name in ["PrideRock", "CanyonWalls", "Gorge", "CanyonDepths", "DepthUnderlay", "PlateauShade", "PlateauBody", "Bridge"]:
		var old := room.get_node_or_null(NodePath(old_name))
		if old:
			room.remove_child(old)
			old.free()
	var rock := Sprite2D.new()
	rock.name = "PrideRock"
	rock.texture = load(ART % "pride_rock")
	rock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rock.centered = false
	rock.scale = Vector2(1.5, 1.5)
	rock.position = ROCK_AT
	room.add_child(rock)
	room.move_child(rock, tilemap.get_index())  # під тайлами й героєм
	rock.owner = room

	var walls := Parallax2D.new()
	walls.name = "CanyonWalls"
	walls.z_index = -9
	walls.scroll_scale = Vector2(0.45, 1)
	walls.repeat_size = Vector2(864, 0)
	walls.repeat_times = 4
	var walls_sprite := Sprite2D.new()
	walls_sprite.name = "Sprite"
	walls_sprite.texture = load(ART % "gen_walls")  # D235: згенеровані (comfy_backdrop.py)
	walls_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	walls_sprite.centered = false
	walls_sprite.scale = Vector2(1.5, 1.5)
	walls_sprite.position = Vector2(0, WALLS_Y)
	walls.modulate = WALLS_TINT
	walls_sprite.material = load(BLUR % "mid")  # D233: дальній план розмитий
	walls.add_child(walls_sprite)
	room.add_child(walls)
	room.move_child(walls, room.get_node(^"Backdrop").get_index() + 1)
	walls.owner = room
	walls_sprite.owner = room

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
	room.move_child(depths, walls.get_index() + 1)
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

	var gorge_sprite := _sprite("gorge", Vector2(0, GORGE_ROW0 * TILE))
	gorge_sprite.name = "Gorge"
	room.add_child(gorge_sprite)
	room.move_child(gorge_sprite, tilemap.get_index() + 1)  # над тайлами: накриває й праву стіну (тіло плато)
	gorge_sprite.owner = room

	var body := _sprite("plateau_body", PLATEAU_BODY_AT)
	body.name = "PlateauBody"
	room.add_child(body)
	room.move_child(body, gorge_sprite.get_index())  # над тайлами плато, під ущелиною
	body.owner = room

	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, PLATEAU_SHADE_BOTTOM)
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = gradient
	shade_texture.fill_from = Vector2(0, 0)
	shade_texture.fill_to = Vector2(0, 1)
	shade_texture.width = int(PLATEAU_SHADE_RECT.size.x)
	shade_texture.height = int(PLATEAU_SHADE_RECT.size.y)
	var shade := Sprite2D.new()
	shade.name = "PlateauShade"
	shade.texture = shade_texture
	shade.centered = false
	shade.position = PLATEAU_SHADE_RECT.position
	shade.z_index = 1
	var multiply := CanvasItemMaterial.new()
	multiply.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	shade.material = multiply
	room.add_child(shade)
	shade.owner = room

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
	room.move_child(bridge, room.get_node(^"Gorge").get_index() + 1)
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
