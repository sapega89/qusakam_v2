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


func _initialize() -> void:
	var room: Node = load(ROOM).instantiate()
	_paint(room.get_node(^"TileMap/Foreground"), room.get_node(^"TileMap/Bakcground"))
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
			if c != "#" and x > 0 and x < 53:
				# фон-кладка: здебільшого рівна, зрідка з візерунком
				bg.set_cell(Vector2i(x, y), SOURCE, Vector2i(8, 1) if rng.randf() < 0.85 else Vector2i([7, 9, 12][rng.randi() % 3], 1))


func _at(x: int, y: int) -> String:
	if y < 0 or y >= LAYOUT.size() or x < 0 or x >= LAYOUT[y].length():
		return "#"
	return LAYOUT[y][x]


## Рамковий блок 3x3 атласа (7..9, 6..8) за тим, чи порожньо зверху / знизу / ліворуч / праворуч.
func _block(x: int, y: int) -> Vector2i:
	var col := 0 if _at(x - 1, y) != "#" else 2 if _at(x + 1, y) != "#" else 1
	var row := 0 if _at(x, y - 1) != "#" else 2 if _at(x, y + 1) != "#" else 1
	return Vector2i(7 + col, 6 + row)
