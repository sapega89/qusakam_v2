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
## Поверхи: [верх інтер'єру (рядок), низ інтер'єру (рядок)] — плани глибини стають на підлогу поверху.
const FLOORS := [[2, 11], [15, 26], [30, 41]]
## Лампи на стінах (центр).
const LAMPS := [Vector2(140, 214), Vector2(620, 214), Vector2(1150, 214), Vector2(1650, 214),
		Vector2(330, 694), Vector2(980, 694), Vector2(1560, 694),
		Vector2(330, 1174), Vector2(760, 1174), Vector2(1180, 1174), Vector2(1620, 1174)]

## Глибина (D246): на кожному поверсі — далекий зал, ряд обладнання, передній план зі стелі; згенеровані
## comfy_backdrop.py (Lab/*). Шар — екран 576×324 px ×1.5; по вертикалі прибитий до поверху (scroll 1).
const BG := "res://SampleProject/Assets/Backgrounds/Lab/%s.png"
const MATERIALS := "res://SampleProject/Resources/Materials/depth_blur_%s.tres"
const LAYER_SIZE := Vector2(864, 486)
## [назва, текстура, scroll x, z, низ шару відносно підлоги (px), modulate, розмиття]; текстура поверху — %d.
const PLANES := [
	["Far", "gen_far", 0.4, -10, 60.0, Color(0.6, 0.58, 0.72), "far"],
	["Mid", "gen_mid%s", 0.75, -9, 40.0, Color(0.7, 0.66, 0.8), "near"],
	["Front", "gen_front", 1.25, 20, -384.0 + LAYER_SIZE.y, Color(0.86, 0.8, 1, 0.94), "front"],
]
## Варіант ряду обладнання й зсув шарів по x — щоб поверхи не повторювали один одного.
const MID_VARIANT := ["", "2", ""]
const PLANE_SHIFT := [0.0, 288.0, 576.0]
## Поверхні, по яких ходить герой: текстура перерізу плити (Lab/gen_slab, 576×64): нагорі ґратчастий
## настил із латунним краєм (до рядка SLAB_PLATES), нижче — клепані плити. Колізія — у прихованому Foreground.
const SLAB_PLATES := 26

## Компаньйони чекають біля своїх тригерів (D230): [id, ступні, дивиться ліворуч].
## Верхній поверх — герой іде праворуч від входу; середній — ліворуч від драбини.
const NPC_SCRIPT := "res://SampleProject/Scripts/Gameplay/Characters/Companions/CompanionNPC.gd"
const COMPANIONS := "res://SampleProject/Assets/Characters/Companions/%s/%s.png"
## Кадри спокою — фас, їх не дзеркалимо (у Алісії різні очі, D245); дзеркалиться лише біг (CompanionNPC.join).
const NPCS := [["alisia", Vector2(520, 384), false], ["astrit", Vector2(1140, 864), false], ["urizen", Vector2(620, 864), false]]
## Розмір кадру й зсув/масштаб — як у сценах асистів (companion_<id>.tscn, assist_cat.tscn).
const NPC_LOOK := {
	"alisia": [64, Vector2(-32, -58), 1.5],
	"astrit": [64, Vector2(-32, -58), 1.5],
	"urizen": [64, Vector2(-32, -58), 1.5],
	"cat": [64, Vector2(-32, -58), 1.5],
}
const CAT_AT := Vector2(-64, 0)


func _initialize() -> void:
	var room: Node = load(ROOM).instantiate()
	_paint(room.get_node(^"TileMap/Foreground"))
	_surfaces(room)
	_decorate(room)
	_add_companions(room)
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


func _paint(fg: TileMapLayer) -> void:
	fg.clear()
	for y in LAYOUT.size():
		for x in LAYOUT[y].length():
			var c: String = LAYOUT[y][x]
			if c == "#":
				fg.set_cell(Vector2i(x, y), SOURCE, _block(x, y))
			elif c == "=":
				var left := _at(x - 1, y) == "="
				var right := _at(x + 1, y) == "="
				fg.set_cell(Vector2i(x, y), SOURCE, Vector2i(1 if left and right else 2 if left else 0, 0))
	# Тайли — лише колізія; видно намальовані поверхні (_surfaces) і плани глибини (D246)
	fg.visible = false
	for old in [^"Bakcground", ^"BackColumns"]:  # кладка й колони фону минулої версії (D225)
		var layer := fg.get_parent().get_node_or_null(old)
		if layer:
			layer.get_parent().remove_child(layer)
			layer.free()


## Поверхні з текстури плити: кожен прямокутник суцільних тайлів — спрайт із повтором текстури, x прив'язаний
## до світу (сусідні шматки стикуються); відкритий згори — з настилом, вузька стіна — та сама плита, повернута.
## Містки «=» — лише настил. Вузол Surfaces перебудовується щоразу.
func _surfaces(room: Node) -> void:
	var old := room.get_node_or_null(^"Surfaces")
	if old:
		room.remove_child(old)
		old.free()
	var root := Node2D.new()
	root.name = "Surfaces"
	room.add_child(root)
	room.move_child(root, room.get_node(^"TileMap").get_index() + 1)
	var slab: Texture2D = load(BG % "gen_slab")
	for r in _runs("#"):
		var px := Vector2(r.position * TILE)
		var size := Vector2(r.size * TILE) / 1.5
		var sprite := _slab_sprite(slab, px)
		if r.size.x == 1 and r.size.y > 1:
			sprite.rotation = PI / 2
			sprite.position.x += TILE
			sprite.region_rect = Rect2(px.y / 1.5, slab.get_height() - size.x, size.y, size.x)
		else:
			var open_top := _at(int(r.position.x + r.size.x * 0.5), r.position.y - 1) != "#"
			sprite.region_rect = Rect2(px.x / 1.5, 0.0 if open_top else maxf(slab.get_height() - size.y, SLAB_PLATES), size.x, size.y)
		root.add_child(sprite)
	for r in _runs("="):
		var sprite := _slab_sprite(slab, Vector2(r.position * TILE))
		sprite.region_rect = Rect2(r.position.x * TILE / 1.5, 0, r.size.x * TILE / 1.5, TILE / 1.5)
		root.add_child(sprite)
	for node in root.get_children():
		node.owner = room
	root.owner = room


func _slab_sprite(texture: Texture2D, at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	sprite.centered = false
	sprite.scale = Vector2(1.5, 1.5)
	sprite.position = at
	return sprite


## Прямокутники з символу [param c]: відрізки рядків, однакові відрізки сусідніх рядків зливаються.
func _runs(c: String) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	var open := {}  # Vector2i(x0, x1) відрізка попереднього рядка → індекс у rects
	for y in LAYOUT.size():
		var row: String = LAYOUT[y]
		var next := {}
		var x := 0
		while x < row.length():
			if row[x] != c:
				x += 1
				continue
			var x0 := x
			while x < row.length() and row[x] == c:
				x += 1
			var key := Vector2i(x0, x)
			if open.has(key):
				rects[open[key]].size.y += 1
				next[key] = open[key]
			else:
				next[key] = rects.size()
				rects.append(Rect2i(x0, y, x - x0, 1))
		open = next
	return rects


## Темрява, лампи й колби зі світлом, ланцюги, передній план — у вузлі Atmosphere (перебудовується щоразу).
## Компаньйони-NPC (D230): кадри idle (спокій) і run (біг до героя після розмови); в Алісії — кішка.
func _add_companions(room: Node) -> void:
	for child in room.get_children():
		if child.name.begins_with("CompanionNPC_"):
			room.remove_child(child)
			child.free()
	for npc in NPCS:
		var node := Node2D.new()
		node.name = "CompanionNPC_%s" % npc[0]
		node.set_script(load(NPC_SCRIPT))
		node.set("companion_id", npc[0])
		node.position = npc[1]
		room.add_child(node)
		node.owner = room
		var sprite := _npc_sprite(npc[0], "enter", npc[2])
		sprite.name = "Sprite"
		node.add_child(sprite)
		sprite.owner = room
		if npc[0] == "alisia":
			var cat := _npc_sprite("cat", "run", npc[2])
			cat.name = "Cat"
			cat.position = CAT_AT * (-1.0 if npc[2] else 1.0)
			node.add_child(cat)
			cat.owner = room


func _npc_sprite(who: String, run_sheet: String, face_left: bool) -> AnimatedSprite2D:
	var look: Array = NPC_LOOK[who]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim in [["idle", "idle", 4.0, true], ["run", run_sheet, 16.0, true]]:
		var texture: Texture2D = load(COMPANIONS % [who, anim[1]])
		frames.add_animation(anim[0])
		frames.set_animation_speed(anim[0], anim[2])
		frames.set_animation_loop(anim[0], anim[3])
		for i in texture.get_width() / look[0]:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(i * look[0], 0, look[0], look[0])
			frames.add_frame(anim[0], atlas)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.animation = &"idle"
	sprite.centered = false
	sprite.offset = look[1]
	sprite.scale = Vector2.ONE * look[2]
	sprite.flip_h = face_left
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite


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
	for storey in FLOORS.size():
		var floor_y: float = (FLOORS[storey][1] + 1) * TILE
		for plane in PLANES:
			var layer := Parallax2D.new()
			layer.name = "%s%d" % [plane[0], storey + 1]
			layer.scroll_scale = Vector2(plane[2], 1)
			layer.repeat_size = Vector2(LAYER_SIZE.x, 0)
			layer.repeat_times = 4
			layer.z_index = plane[3]
			layer.modulate = plane[5]
			root.add_child(layer)
			var sprite := Sprite2D.new()
			sprite.name = "Sprite"
			sprite.texture = load(BG % (plane[1] % MID_VARIANT[storey] if plane[1].contains("%") else plane[1]))
			sprite.material = load(MATERIALS % plane[6])
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.centered = false
			sprite.scale = Vector2(1.5, 1.5)
			sprite.position = Vector2(PLANE_SHIFT[storey], floor_y + plane[4] - LAYER_SIZE.y)
			layer.add_child(sprite)
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
