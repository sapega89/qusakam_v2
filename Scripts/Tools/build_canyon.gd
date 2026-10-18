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

	for old_name in ["PrideRock", "CanyonWalls"]:
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
	walls_sprite.texture = load(ART % "canyon_walls")
	walls_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	walls_sprite.centered = false
	walls_sprite.scale = Vector2(1.5, 1.5)
	walls_sprite.position = Vector2(0, -3)
	walls.add_child(walls_sprite)
	room.add_child(walls)
	room.move_child(walls, room.get_node(^"Backdrop").get_index() + 1)
	walls.owner = room
	walls_sprite.owner = room

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
