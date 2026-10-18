extends SceneTree

## Будує Laboratory.tscn з ASCII-схеми (D225, [[lab_vertical_plan]]): три поверхи, драбини між ними.
## Тайли Foreground — з LAYOUT, фон-кладка (без колізії) — на все порожнє всередині; тригери, сейви, точки
## ворогів і драбини стають на свої поверхи. Решту сцени (скрипт, спавнер, музика, RoomInstance) не чіпає.
## Запуск: godot --headless --path . --script res://Scripts/Tools/build_laboratory.gd
## Клітинки карти — MapData.txt ([14..15, 3..5, 2]); вихід праворуч на нижньому поверсі — у LaboratoryOutside.

const ROOM := "res://SampleProject/Maps/Laboratory.tscn"
const LADDER_SCENE := "res://SampleProject/Scenes/Gameplay/Objects/Ladder.tscn"
const TILE := 32
const SOURCE := 1  # Sprites/Tiles.png — зелені рамкові блоки й місток

## # — стіна/підлога (рамкові блоки 3x3 за сусідами), = — односторонній місток, . — порожньо.
## Поверхи: A рядки 0–14 (підлога 12), B 15–29 (підлога 27), C 30–44 (підлога 42).
const LAYOUT := [
	"######################################################",  # 0  стеля
	"######################################################",
	"#....................................................#",  # A
	"#....................................................#",
	"#....................................................#",
	"#....................................................#",
	"#....................................................#",
	"#....................................................#",
	"#.......................======.......................#",
	"#....................................................#",
	"#...............######...............................#",
	"#...............######..............####.............#",
	"##############################################==######",  # 12 підлога A, місток над драбиною
	"##############################################..######",
	"##############################################..######",
	"#....................................................#",  # B
	"#....................................................#",
	"#....................................................#",
	"#....................................................#",
	"#....................................................#",
	"#....................................................#",
	"#....................................................#",
	"#...........................======...................#",
	"#....................................................#",
	"#....................................................#",
	"#.........####............................#####......#",
	"#.........####............................#####......#",
	"######==##############################################",  # 27 підлога B
	"######..##############################################",
	"######..##############################################",
	"#....................................................#",  # C
	"#....................................................#",
	"#....................................................#",
	"#....................................................#",
	"#....................................................#",
	"#....................................................#",
	"#.....................................................",  # вихід у LaboratoryOutside
	"#.....................................................",
	"#...........................=====..........=====......",
	"#.....................................................",
	"#.....................................................",
	"#.....................................................",
	"######################################################",  # 42 підлога C
	"######################################################",
	"######################################################",
]

## Вузли сцени → позиція (px). Тригери стоять на всю висоту поверху.
const PLACES := {
	"SavePoint_Entrance": Vector2(200, 344),
	"StateChangeTrigger_Companion01": Vector2(430, 224),
	"StateChangeTrigger_Companion02": Vector2(1220, 672),
	"StateChangeTrigger_Companion03": Vector2(700, 672),
	"SavePoint_PreBoss": Vector2(400, 1304),
	"StateChangeTrigger_LimitTest": Vector2(560, 1152),
	"EnemySpawner/EnemySpawnPoint1": Vector2(1250, 1328),
	"EnemySpawner/EnemySpawnPoint2": Vector2(1350, 1328),
	"EnemySpawner/EnemySpawnPoint3": Vector2(1450, 1328),
	"EnemySpawner/EnemySpawnPoint4": Vector2(1550, 1328),
}
const TRIGGER_HEIGHT := {"StateChangeTrigger_Companion01": 320.0}
const FLOOR_HEIGHT := 384.0
## Драбини: верх (місток над нею) і довжина донизу до підлоги наступного поверху.
const LADDERS := [[Vector2(1504, 384), 480.0], [Vector2(224, 864), 480.0]]

## Атмосфера (D226): у приміщенні темно, світло — від ламп і колб (лор: сонця немає, вогні — локальні).
const PROPS := "res://SampleProject/Assets/Laboratory/%s.png"
const DARKNESS := Color(0.36, 0.36, 0.44)
const LAMP_LIGHT := Color(1.0, 0.82, 0.55)
const VAT_LIGHT := Color(0.45, 1.0, 0.6)
## Поверхи: [верх інтер'єру (рядок), низ інтер'єру (рядок)] — для колон фону.
const FLOORS := [[2, 11], [15, 26], [30, 41]]
## Колони фону: [стовпець осі, поверх].
const BG_COLUMNS := [[9, 0], [34, 0], [18, 1], [40, 1], [15, 2], [38, 2]]
## Лампи на стінах (центр), колби на підлозі (низ), ланцюги [верх, довжина px].
const LAMPS := [Vector2(140, 214), Vector2(620, 214), Vector2(1150, 214), Vector2(1650, 214),
		Vector2(330, 694), Vector2(980, 694), Vector2(1560, 694),
		Vector2(330, 1174), Vector2(760, 1174), Vector2(1180, 1174), Vector2(1620, 1174)]
const VATS := [Vector2(960, 384), Vector2(1000, 384), Vector2(1630, 864), Vector2(680, 1344)]
const CHAINS := [[Vector2(300, 64), 120.0], [Vector2(1300, 64), 90.0], [Vector2(600, 480), 140.0],
		[Vector2(1200, 480), 100.0], [Vector2(900, 960), 150.0], [Vector2(1400, 960), 120.0]]
## Передній план (перед героєм): труби [від x, до x, y], колони-силуети [x, верх, низ].
const FG_PIPES := [[0, 700, 92], [800, 1728, 508], [0, 900, 988]]
const FG_COLUMNS := [[760, 64, 384], [1350, 480, 864], [920, 960, 1344]]
## Силуети переднього плану не суцільно чорні — крізь них трохи видно (як туман глибини).
const FRONT_TINT := Color(1.6, 1.5, 1.7, 0.82)


func _initialize() -> void:
	var room: Node = load(ROOM).instantiate()
	_paint(room.get_node(^"TileMap/Foreground"), room.get_node(^"TileMap/Bakcground"))
	_decorate(room)
	for path in PLACES:
		var node: Node2D = room.get_node(NodePath(path))
		node.position = PLACES[path]
		if path.begins_with("StateChangeTrigger"):
			var shape := RectangleShape2D.new()
			shape.size = Vector2(32, TRIGGER_HEIGHT.get(path, FLOOR_HEIGHT))
			node.get_node(^"CollisionShape2D").shape = shape
	for child in room.get_children():
		if child.name.begins_with("Ladder"):
			room.remove_child(child)
			child.free()
	for i in LADDERS.size():
		var ladder: Node2D = load(LADDER_SCENE).instantiate()
		ladder.name = "Ladder%d" % (i + 1)
		ladder.position = LADDERS[i][0]
		ladder.height = LADDERS[i][1]
		room.add_child(ladder)
		ladder.owner = room
	# UID сцени — за ним MapData.txt знаходить кімнату; ResourceSaver нового PackedScene його не зберігає.
	var uid := ResourceLoader.get_resource_uid(ROOM)
	var packed := PackedScene.new()
	packed.pack(room)
	print("save ", ResourceSaver.save(packed, ROOM), " uid ", ResourceSaver.set_uid(ROOM, uid))
	room.free()
	quit()


func _paint(fg: TileMapLayer, bg: TileMapLayer) -> void:
	fg.clear()
	bg.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for y in LAYOUT.size():
		for x in LAYOUT[y].length():
			var c: String = LAYOUT[y][x]
			if c == "#":
				fg.set_cell(Vector2i(x, y), SOURCE, _block(x, y))
			elif c == "=":
				var left := _at(x - 1, y) == "="
				var right := _at(x + 1, y) == "="
				fg.set_cell(Vector2i(x, y), SOURCE, Vector2i(1 if left and right else 2 if left else 0, 0))
			if c != "#" and x > 0:  # і в проході-виході в останньому стовпці
				# фон-кладка: здебільшого рівна, зрідка з візерунком
				bg.set_cell(Vector2i(x, y), SOURCE, Vector2i(8, 1) if rng.randf() < 0.85 else Vector2i([7, 9, 12][rng.randi() % 3], 1))
	# Фон декоративний: колони атласа мають колізію, а в фоні вона не потрібна
	bg.collision_enabled = false
	# Колони — окремим шаром поверх кладки: їхні тайли частково прозорі
	var columns := _columns_layer(bg)
	columns.clear()
	for column in BG_COLUMNS:
		var x: int = column[0]
		var top: int = FLOORS[column[1]][0]
		var bottom: int = FLOORS[column[1]][1]
		for dx in range(-2, 3):
			columns.set_cell(Vector2i(x + dx, top), SOURCE, Vector2i(3 + dx, 4))  # капітель
		for dx in range(-1, 2):
			columns.set_cell(Vector2i(x + dx, top + 1), SOURCE, Vector2i(3 + dx, 5))
			columns.set_cell(Vector2i(x + dx, top + 2), SOURCE, Vector2i(3 + dx, 6))
			columns.set_cell(Vector2i(x + dx, bottom - 1), SOURCE, Vector2i(3 + dx, 9))  # база
			columns.set_cell(Vector2i(x + dx, bottom), SOURCE, Vector2i(3 + dx, 10))
		for y in range(top + 3, bottom - 1):
			columns.set_cell(Vector2i(x, y), SOURCE, Vector2i(3, 7 + (y % 2)))  # стовбур


## Шар колон фону (поруч із Bakcground, той самий тайлсет, без колізії); створює, якщо ще немає.
func _columns_layer(bg: TileMapLayer) -> TileMapLayer:
	var layer := bg.get_parent().get_node_or_null(^"BackColumns") as TileMapLayer
	if layer == null:
		layer = TileMapLayer.new()
		layer.name = "BackColumns"
		layer.tile_set = bg.tile_set
		layer.z_index = -1
		layer.collision_enabled = false
		bg.get_parent().add_child(layer)
		bg.get_parent().move_child(layer, bg.get_index() + 1)
		layer.owner = bg.owner
	return layer


## Темрява, лампи й колби зі світлом, ланцюги, передній план — у вузлі Atmosphere (перебудовується щоразу).
func _decorate(room: Node) -> void:
	var old := room.get_node_or_null(^"Atmosphere")
	if old:
		room.remove_child(old)
		old.free()
	var root := Node2D.new()
	root.name = "Atmosphere"
	room.add_child(root)
	var dark := CanvasModulate.new()
	dark.name = "Darkness"
	dark.color = DARKNESS
	root.add_child(dark)
	var glow := _light_texture()
	for i in LAMPS.size():
		var lamp := _sprite("lamp", LAMPS[i], Vector2(0, -0.5), -1)
		lamp.name = "Lamp%d" % (i + 1)
		root.add_child(lamp)
		lamp.add_child(_light(glow, LAMP_LIGHT, 1.25, 1.6, Vector2(4, 0)))
	for i in VATS.size():
		var vat := _sprite("vat", VATS[i], Vector2(0, -1), -1)
		vat.name = "Vat%d" % (i + 1)
		root.add_child(vat)
		vat.add_child(_light(glow, VAT_LIGHT, 0.7, 0.6, Vector2(0, -20)))
	for i in CHAINS.size():
		var chain := _sprite("chain", CHAINS[i][0], Vector2(0, 0), -1)
		chain.name = "Chain%d" % (i + 1)
		chain.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		chain.region_enabled = true
		chain.region_rect = Rect2(0, 0, 6, CHAINS[i][1] / 1.5)
		root.add_child(chain)
	var front := Node2D.new()
	front.name = "Front"
	front.z_index = 20  # перед героєм і ворогами
	front.modulate = FRONT_TINT
	root.add_child(front)
	for i in FG_PIPES.size():
		var pipe := _sprite("fg_pipe", Vector2(FG_PIPES[i][0], FG_PIPES[i][2]), Vector2(0, -0.5), 0)
		pipe.name = "Pipe%d" % (i + 1)
		pipe.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		pipe.region_enabled = true
		pipe.region_rect = Rect2(0, 0, (FG_PIPES[i][1] - FG_PIPES[i][0]) / 1.5, 14)
		front.add_child(pipe)
	for i in FG_COLUMNS.size():
		var column := _sprite("fg_column", Vector2(FG_COLUMNS[i][0], FG_COLUMNS[i][1]), Vector2(-0.5, 0), 0)
		column.name = "Column%d" % (i + 1)
		column.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		column.region_enabled = true
		column.region_rect = Rect2(0, 0, 28, (FG_COLUMNS[i][2] - FG_COLUMNS[i][1]) / 1.5)
		front.add_child(column)
	for node in root.find_children("*", "", true, false):
		node.owner = room
	root.owner = room


## Спрайт реквізиту ×1.5; [param anchor] — частка розміру, що лягає в [param at] (0,0 — лівий верх).
func _sprite(prop: String, at: Vector2, anchor: Vector2, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(PROPS % prop)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.scale = Vector2(1.5, 1.5)
	sprite.position = at
	sprite.offset = Vector2(sprite.texture.get_width(), sprite.texture.get_height()) * anchor
	sprite.z_index = z
	return sprite


func _light(texture: Texture2D, color: Color, energy: float, size: float, offset: Vector2) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = texture
	light.color = color
	light.energy = energy
	light.texture_scale = size
	light.position = offset
	return light


## Кругла м'яка пляма світла (білий центр → прозорий край), 256x256.
func _light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 256
	texture.height = 256
	return texture


func _at(x: int, y: int) -> String:
	if y < 0 or y >= LAYOUT.size() or x < 0 or x >= LAYOUT[y].length():
		return "#"
	return LAYOUT[y][x]


## Рамковий блок 3x3 атласа (7..9, 6..8) за тим, чи порожньо зверху / знизу / ліворуч / праворуч.
func _block(x: int, y: int) -> Vector2i:
	var col := 0 if _at(x - 1, y) != "#" else 2 if _at(x + 1, y) != "#" else 1
	var row := 0 if _at(x, y - 1) != "#" else 2 if _at(x, y + 1) != "#" else 1
	return Vector2i(7 + col, 6 + row)
