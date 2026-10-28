extends SceneTree

## Будує кімнати лабораторії з ASCII-схем (D225, D303, [[lab_vertical_plan]], [[lab_story_plan]]; v3 — D863, D865,
## design/refs/room_graph_M4_lab_v3.png): LabCells (камери), три поверхи — Laboratory (нижній), LabMiddleFloor,
## LabTopFloor, — двоє великих сходів між ними (LabStairsEast, LabStairsWest), кишеня вартового (LabGuardPocket) і
## LabBoss (зала джина). Одна схема — одна кімната (ROOMS). Тайли Foreground — зі схеми (сховані, лише колізія), видно
## намальовані поверхні й плани глибини; тригери, сейви, точки ворогів стають на свої місця. Решту сцени (скрипт,
## спавнер, музика, RoomInstance, двері build_world_rooms.py) не чіпає.
## Запуск (усі кімнати або лише названі): godot --headless --path . --script res://Scripts/Tools/build_laboratory.gd [-- Laboratory LabTopFloor]
## Клітинки карти — MapData.txt (build_world_rooms.py, PLACE і LAB_V3): лабораторія під землею, герой підіймається
## (D863): LabCells [12..13,5,2] → Laboratory [14..18,5] (праворуч) → LabStairsEast [19..20,5] (марш угору праворуч,
## двері нагору) → LabMiddleFloor [16..20,4] (ліворуч; на схід — LabGuardPocket [21..22,4]) → LabStairsWest [14..15,4]
## (марш угору ліворуч, двері нагору) → LabTopFloor [14..18,3] (праворуч; двері вгору) → LabBoss [18..19,2] (рівень
## поверхні) → LaboratoryOutside [20..21,2..3].
## Підлога кожного поверху — рядок 12 клітинки (y 384 від її верху), прохід між кімнатами — рядки 6–11.

const TILE := 32
const SOURCE := 1  # Sprites/Tiles.png — зелені рамкові блоки й місток

## Атмосфера (D226): у приміщенні темно, світло — від ламп і колб (лор: сонця немає, вогні — локальні).
const LAMP := "res://SampleProject/Assets/Laboratory/lamp.png"
const DARKNESS := Color(0.36, 0.36, 0.44)
const LAMP_LIGHT := Color(1.0, 0.82, 0.55)

## Глибина (D246): далекий зал, ряд обладнання, передній план зі стелі; згенеровані comfy_backdrop.py (Lab/*).
## Шар — екран 576×324 px ×1.5; по вертикалі прибитий до поверху (scroll 1).
const BG := "res://SampleProject/Assets/Backgrounds/Lab/%s.png"
const MATERIALS := "res://SampleProject/Resources/Materials/depth_blur_%s.tres"
const LAYER_SIZE := Vector2(864, 486)
## [назва, текстура, scroll x, z, низ шару відносно підлоги (px), modulate, розмиття]; %s — варіант поверху (mid).
const FAR := ["Far", "gen_far", 0.4, -10, 60.0, Color(0.6, 0.58, 0.72), "far"]
const MID := ["Mid", "gen_mid%s", 0.75, -9, 40.0, Color(0.7, 0.66, 0.8), "near"]
const FRONT := ["Front", "gen_front", 1.25, 20, -384.0 + LAYER_SIZE.y, Color(0.86, 0.8, 1, 0.94), "front"]
## Зала джина: дальня стіна з печами, світліша — вогонь.
const BOSS_FAR := ["Far", "gen_boss_far", 0.4, -10, 60.0, Color(0.72, 0.62, 0.66), "far"]
## Поверхні, по яких ходить герой: текстура перерізу плити (Lab/gen_slab, 576×64): нагорі ґратчастий
## настил із латунним краєм (до рядка SLAB_PLATES), нижче — клепані плити. Колізія — у прихованому Foreground.
const SLAB_PLATES := 26

## Компаньйони-NPC (D230) у коридорах: кадри як у сценах асистів (companion_<id>.tscn, assist_cat.tscn).
const NPC_SCRIPT := "res://SampleProject/Scripts/Gameplay/Characters/Companions/CompanionNPC.gd"
const COMPANIONS := "res://SampleProject/Assets/Characters/Companions/%s/%s.png"
const NPC_LOOK := {
	"alisia": [64, Vector2(-32, -58), 1.5, "enter"],
	"astrit": [64, Vector2(-32, -58), 1.5, "run"],
	"urizen": [64, Vector2(-32, -58), 1.5, "enter"],
	"cat": [64, Vector2(-32, -58), 1.5, "run"],
}
const CAT_AT := Vector2(-64, 0)
const NPC_SCENES := "res://SampleProject/Scenes/Gameplay/Objects/NPCs/lab_%s.tscn"

## # — стіна/підлога (рамкові блоки 3x3 за сусідами), = — односторонній місток, . — порожньо.
## Кожна кімната:
##   layout — рядки тайлів; floors — [верх, низ інтер'єру] поверхів (рядки); planes — плани глибини;
##   mid_variant / plane_shift — варіант ряду обладнання й зсув шарів по x на поверх (щоб не повторювались);
##   places — наявні вузли сцени → позиція; trigger_height — висота тригера (решта — на всю висоту поверху);
##   storey — [ширина в тайлах, прохід ліворуч, прохід праворуч] замість layout: рівний поверх від стіни до стіни;
##   stairs — великі сходи (_stairs); lamps — центри ламп; npcs — компаньйони [id, ступні, дивиться ліворуч];
##   props — [вузол, текстура Lab/*, [низ-центр, ...], z, масштаб]: вузол перебудовується, спрайти стоять на точках;
##   actors — [вузол, сцена NPC (lab_<id>), ступні, дивиться ліворуч, анімація].
const ROOMS := {
	# Камери (D303): п'ять камер уздовж задньої стіни, операційний стіл посередині; вихід праворуч у коридори.
	# Сюди переносить кінець MayorHall (MayorHall.LAB_ROOM / LAB_MARKER → Arrival у першій камері).
	"res://SampleProject/Maps/LabCells.tscn": {
		"layout": [
			"######################################################",  # 0  стеля
			"######################################################",
			"#....................................................#",
			"#....................................................#",
			"#....................................................#",
			"#....................................................#",
			"#.....................................................",  # прохід у Laboratory
			"#.....................................................",
			"#.....................................................",
			"#.....................................................",
			"#.....................................................",
			"#.....................................................",
			"######################################################",  # 12 підлога
			"######################################################",
			"######################################################",
		],
		"floors": [[2, 11]],
		"planes": [FAR, FRONT],
		"mid_variant": [""],
		"plane_shift": [0.0],
		"places": {"Arrival": Vector2(150, 344)},
		"lamps": [Vector2(275, 150), Vector2(525, 150), Vector2(925, 150), Vector2(1325, 150), Vector2(1600, 150)],
		# Три камери ліворуч, стіл, дві праворуч; перша — героя (Arrival), остання — Маліка
		"props": [
			["Cells", "gen_cell", [Vector2(150, 384), Vector2(400, 384), Vector2(650, 384), Vector2(1200, 384), Vector2(1450, 384)], -3, Vector2(1.5, 1.5)],
			# Ґрати перед камерами — над героєм у камері; після пробудження зникають (9.5, D304)
			["Bars", "gen_bars", [Vector2(150, 384), Vector2(400, 384), Vector2(650, 384), Vector2(1200, 384), Vector2(1450, 384)], 5, Vector2(1.5, 1.5)],
			["Table", "gen_table", [Vector2(925, 384)], -1, Vector2(1.5, 1.5)],
		],
		"actors": [
			["Malik", "malik", Vector2(1450, 384), true, &"idle"],
			["Scientist", "alchemist", Vector2(790, 384), false, &"idle"],
			["Prisoner", "prisoner", Vector2(1070, 384), true, &"idle"],
		],
		# Супутники — кожен у своїй камері (D305): Астрит, Алісия (ближче до столу, D304), Уризен; кадри спокою — фас.
		"npcs": [["astrit", Vector2(400, 384), false], ["alisia", Vector2(650, 384), false], ["urizen", Vector2(1200, 384), false]],
	},
	# Поверхи v3 (D863, D865): кожен — окрема кімната на 5 клітинок, рівна підлога від стіни до стіни (D832), без драбин
	# і отворів (B201). Бої — по одному на поверх (D306), імена — порядок зустрічі (Laboratory.gd). Зони Trigger — на
	# шляху героя, вороги — на підлозі попереду нього.
	# Нижній поверх: з камер (двері ліворуч, CellsDoor) праворуч до великих сходів; медитація біля камер; люк у дренаж.
	"res://SampleProject/Maps/Laboratory.tscn": {
		"storey": [135, false, true],
		"floors": [[2, 11]],
		"planes": [FAR, MID, FRONT],
		"mid_variant": [""],
		"plane_shift": [0.0],
		"places": {
			"SavePoint_Entrance": Vector2(200, 344),
			"Fight_Fly/Trigger": Vector2(900, 208),
			"Fight_Fly/EnemySpawnPoint1": Vector2(1150, 300),
			# BigSlot_* — місця великих видів (D652), поки без арту спавнять звичайних.
			"Fight_Upper/Trigger": Vector2(1800, 208),
			"Fight_Upper/BigSlot_BanditBrute_1": Vector2(1950, 368),
			"Fight_Upper/EnemySpawnPoint2": Vector2(2250, 368),
			"Fight_Upper/BigSlot_BanditBrute_3": Vector2(2450, 368),
		},
		"lamps": [Vector2(140, 214), Vector2(620, 214), Vector2(1150, 214), Vector2(1650, 214), Vector2(2150, 214),
				Vector2(2650, 214), Vector2(3150, 214), Vector2(3650, 214), Vector2(4150, 214)],
	},
	# Великі сходи схід: вхід ліворуч з нижнього поверху, марш угору праворуч, двері нагору (FloorDoor) — на середній.
	"res://SampleProject/Maps/LabStairsEast.tscn": {
		"storey": [54, true, false],
		"floors": [[2, 11]],
		"planes": [FAR, FRONT],
		"mid_variant": [""],
		"plane_shift": [288.0],
		"stairs": {"rise": "right", "from": 300.0, "count": 8, "tread": 140.0, "riser": 22.0},
		"places": {},
		"lamps": [Vector2(200, 214), Vector2(900, 150), Vector2(1550, 110)],
	},
	# Середній поверх: від дверей сходів (праворуч) ліворуч до других сходів; на схід — кишеня вартового (D724).
	"res://SampleProject/Maps/LabMiddleFloor.tscn": {
		"storey": [135, true, true],
		"floors": [[2, 11]],
		"planes": [FAR, MID, FRONT],
		"mid_variant": ["2"],
		"plane_shift": [288.0],
		"places": {
			# Проклятий шакал уперше — сам (D582): щойно герой зійде зі сходів.
			"Fight_Cursed/Trigger": Vector2(3400, 208),
			"Fight_Cursed/BigSlot_JackalCursed_1": Vector2(3150, 368),
			"Fight_Middle/Trigger": Vector2(2200, 208),
			"Fight_Middle/EnemySpawnPoint1": Vector2(1900, 368),
			"Fight_Middle/EnemySpawnPoint2": Vector2(1820, 368),
			"Fight_Middle/EnemySpawnPoint3": Vector2(1740, 368),
			"Fight_Middle/EnemySpawnPoint4": Vector2(1660, 368),
		},
		"lamps": [Vector2(330, 214), Vector2(980, 214), Vector2(1560, 214), Vector2(2140, 214), Vector2(2720, 214),
				Vector2(3300, 214), Vector2(3880, 214)],
	},
	# Кишеня вартового з баштовим щитом (D724): необов'язковий бій і скриня, на схід від середнього поверху.
	"res://SampleProject/Maps/LabGuardPocket.tscn": {
		"storey": [54, true, false],
		"floors": [[2, 11]],
		"planes": [FAR, FRONT],
		"mid_variant": [""],
		"plane_shift": [576.0],
		"places": {
			"Fight_TowerGuard/Trigger": Vector2(500, 208),
			"Fight_TowerGuard/BigSlot_TowerShieldGuard_1": Vector2(1100, 368),
			"Chest_TowerGuard": Vector2(1450, 384),
		},
		"lamps": [Vector2(400, 214), Vector2(1300, 214)],
	},
	# Великі сходи захід: вхід праворуч із середнього поверху, марш угору ліворуч, двері нагору — на верхній поверх.
	"res://SampleProject/Maps/LabStairsWest.tscn": {
		"storey": [54, false, true],
		"floors": [[2, 11]],
		"planes": [FAR, FRONT],
		"mid_variant": [""],
		"plane_shift": [0.0],
		"stairs": {"rise": "left", "from": 300.0, "count": 8, "tread": 140.0, "riser": 22.0},
		"places": {},
		"lamps": [Vector2(1528, 214), Vector2(828, 150), Vector2(178, 110)],
	},
	# Верхній поверх: від дверей сходів (ліворуч; поруч — двері коридору алхіміка) праворуч; медитація перед залою;
	# двері вгору, у залу джина — вона вже на рівні поверхні (D865).
	"res://SampleProject/Maps/LabTopFloor.tscn": {
		"storey": [135, false, false],
		"floors": [[2, 11]],
		"planes": [FAR, MID, FRONT],
		"mid_variant": [""],
		"plane_shift": [576.0],
		"places": {
			"Fight_Lower/Trigger": Vector2(1500, 208),
			"Fight_Lower/BigSlot_ArmouredScorpion_1": Vector2(2000, 368),
			"Fight_Lower/EnemySpawnPoint2": Vector2(2100, 368),
			"Fight_Lower/BigSlot_JackalCursed_3": Vector2(2200, 368),
			"Fight_Lower/BigSlot_JackalCursed_4": Vector2(2300, 368),
			"SavePoint_PreBoss": Vector2(3700, 344),
			"BossDoorEntrance": Vector2(4200.25, 384),
			"BossDoor": Vector2(4192, 309.75),
		},
		"lamps": [Vector2(600, 214), Vector2(1150, 214), Vector2(1650, 214), Vector2(2150, 214), Vector2(2650, 214),
				Vector2(3150, 214), Vector2(3650, 214), Vector2(4150, 214)],
	},
	# Зала джина (D303, D307): один рівний поверх (містки прибрано, D832); брама праворуч (зачинена до смерті джина — 9.7;
	# її колізія Gates/Body — вузол сцени, будівник його не чіпає).
	"res://SampleProject/Maps/LabBoss.tscn": {
		"layout": [
			"######################################################",  # 0  стеля
			"######################################################",
			"#....................................................#",
			"#....................................................#",
			"#....................................................#",
			"#....................................................#",
			"......................................................",  # прохід: Laboratory | LaboratoryOutside
			"......................................................",
			"......................................................",
			# Без містків (D832): ухили — по підлозі
			"......................................................",
			"......................................................",
			"......................................................",
			"######################################################",  # 12 підлога
			"######################################################",
			"######################################################",
		],
		"floors": [[2, 11]],
		"planes": [BOSS_FAR, FRONT],
		"mid_variant": [""],
		"plane_shift": [0.0],
		"places": {"Arrival": Vector2(120, 344)},
		"lamps": [Vector2(300, 214), Vector2(860, 150), Vector2(1300, 214)],
		"props": [["Gates", "gen_gates", [Vector2(1560, 384)], -3, Vector2(1.5, 1.5)]],
	},
}

## Схема кімнати, яку зараз будуємо (_at, _runs, _block читають її).
var layout: Array = []


func _initialize() -> void:
	var only := OS.get_cmdline_user_args()
	for path: String in ROOMS:
		if only.is_empty() or path.get_file().get_basename() in only:
			_build(path, ROOMS[path])
	quit()


func _build(path: String, spec: Dictionary) -> void:
	layout = _storey(spec.storey) if spec.has("storey") else spec.layout
	# Стан редактора: вкладені сцени (джин у LabBoss) зберігаються посиланням, без запечених властивостей.
	var room: Node = load(path).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	_paint(room.get_node(^"TileMap/Foreground"))
	_surfaces(room)
	_stairs(room, spec)
	_decorate(room, spec)
	_add_props(room, spec.get("props", []))
	_add_actors(room, spec.get("actors", []))
	_add_companions(room, spec.get("npcs", []))
	var places: Dictionary = spec.places
	var heights: Dictionary = spec.get("trigger_height", {})
	var floor_height: float = (spec.floors[0][1] - spec.floors[0][0] + 2) * TILE
	for node_path: String in places:
		var node: Node2D = room.get_node(NodePath(node_path))
		node.position = places[node_path]
		if node_path.begins_with("StateChangeTrigger"):
			var shape := RectangleShape2D.new()
			shape.size = Vector2(32, heights.get(node_path, floor_height))
			node.get_node(^"CollisionShape2D").shape = shape
	# UID сцени — за ним MapData.txt знаходить кімнату; ResourceSaver нового PackedScene його не зберігає.
	var uid := ResourceLoader.get_resource_uid(path)
	var packed := PackedScene.new()
	packed.pack(room)
	print("%s save %d uid %d" % [path.get_file(), ResourceSaver.save(packed, path), ResourceSaver.set_uid(path, uid)])
	room.free()


## Схема рівного поверху: стеля (рядки 0–1), порожньо до підлоги (рядок 12, три рядки плит), стіни по краях; на боці з
## проходом стіна відкрита в рядках 6–11 (як проходи між кімнатами в усій лабораторії).
func _storey(spec: Array) -> Array:
	var cols: int = spec[0]
	var rows: Array = []
	for y in 15:
		if y < 2 or y >= 12:
			rows.append("#".repeat(cols))
			continue
		var left := "." if spec[1] and y >= 6 else "#"
		var right := "." if spec[2] and y >= 6 else "#"
		rows.append(left + ".".repeat(cols - 2) + right)
	return rows


## Великі сходи (D863: «великі сходи, як у храмах»): широкий кам'яний марш від підлоги до майданчика, де двері нагору.
## Колізія — пандус крізь середини проступів (D834: схил, а не сходинки під ногами), видно — сходинки з тієї ж плити,
## що й підлога: кожна сходинка — від свого краю до стіни, вища лягає поверх нижчої. spec.stairs: rise — у який бік
## марш іде вгору ("right" / "left"), from — відстань першої сходинки від стіни внизу маршу, count, tread, riser — px.
## Вузол Stairs перебудовується щоразу.
func _stairs(room: Node, spec: Dictionary) -> void:
	var old := room.get_node_or_null(^"Stairs")
	if old:
		room.remove_child(old)
		old.free()
	if not spec.has("stairs"):
		return
	var s: Dictionary = spec.stairs
	var width := float(layout[0].length() * TILE)
	var floor_y := float((spec.floors[0][1] + 1) * TILE)
	var count: int = s.count
	var tread: float = s.tread
	var top: float = floor_y - count * s.riser
	var flip: bool = s.rise == "left"
	var body := StaticBody2D.new()
	body.name = "Stairs"
	room.add_child(body)
	room.move_child(body, room.get_node(^"Surfaces").get_index() + 1)
	var line := [Vector2(s.from - tread * 0.5, floor_y), Vector2(s.from + (count - 0.5) * tread, top),
			Vector2(width, top), Vector2(width, floor_y)]
	var shape := CollisionPolygon2D.new()
	shape.name = "Ramp"
	shape.polygon = PackedVector2Array(line.map(func(p: Vector2) -> Vector2: return _mirror(p, width, flip)))
	body.add_child(shape)
	var slab: Texture2D = load(BG % "gen_slab")
	for i in count:
		var x: float = s.from + i * tread
		var step_top: float = floor_y - (i + 1) * s.riser
		var at := Vector2(0.0 if flip else x, step_top)
		var sprite := _slab_sprite(slab, at)
		sprite.name = "Step%d" % (i + 1)
		sprite.region_rect = Rect2(at.x / 1.5, 0.0, (width - x) / 1.5, (floor_y - step_top) / 1.5)
		body.add_child(sprite)
	for node in body.get_children():
		node.owner = room
	body.owner = room


func _mirror(p: Vector2, width: float, flip: bool) -> Vector2:
	return Vector2(width - p.x, p.y) if flip else p


func _paint(fg: TileMapLayer) -> void:
	fg.clear()
	for y in layout.size():
		for x in layout[y].length():
			var c: String = layout[y][x]
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
	for y in layout.size():
		var row: String = layout[y]
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


## Реквізит кімнати (камери, ґрати, стіл, брама): спрайти вузла-групи перебудовуються, кожен стоїть низом-центром
## на своїй точці. Окремі вузли — щоб скрипт кімнати вмикав їх за станом ($Bars після пробудження, 9.5).
## Решта дітей групи — зі сцени (колізія брами Gates/Body, 9.7) — лишається.
func _add_props(room: Node, props: Array) -> void:
	for prop: Array in props:
		var group: Node2D = room.get_node_or_null(NodePath(prop[0]))
		if group == null:
			group = Node2D.new()
			group.name = prop[0]
			room.add_child(group)
			group.owner = room
		for old in group.get_children():
			if old is Sprite2D:
				group.remove_child(old)
				old.free()
		group.z_index = prop[3]
		var points: Array = prop[2]
		for i in points.size():
			var sprite := _sprite(BG % prop[1], points[i], Vector2(-0.5, -1), 0)
			sprite.name = "%s%d" % [prop[0], i + 1] if points.size() > 1 else "Sprite"
			sprite.scale = prop[4]
			group.add_child(sprite)
			group.move_child(sprite, i)
			sprite.owner = room


## Персонажі сцен лабораторії (lab_<id>.tscn): стоять ступнями на точці; скрипт кімнати керує ними (9.5).
func _add_actors(room: Node, actors: Array) -> void:
	for actor: Array in actors:
		var old := room.get_node_or_null(NodePath(actor[0]))
		if old:
			room.remove_child(old)
			old.free()
		var node: Node2D = load(NPC_SCENES % actor[1]).instantiate()
		node.name = actor[0]
		node.position = actor[2]
		(node.get_node(^"Sprite2D") as Sprite2D).flip_h = actor[3]
		(node.get_node(^"AnimationPlayer") as AnimationPlayer).autoplay = actor[4]
		room.add_child(node)
		node.owner = room


## Компаньйони-NPC (D230): кадри idle (спокій) і run (біг до героя після розмови); в Алісії — кішка.
func _add_companions(room: Node, npcs: Array) -> void:
	for child in room.get_children():
		if child.name.begins_with("CompanionNPC_"):
			room.remove_child(child)
			child.free()
	for npc: Array in npcs:
		var node := Node2D.new()
		node.name = "CompanionNPC_%s" % npc[0]
		node.set_script(load(NPC_SCRIPT))
		node.set("companion_id", npc[0])
		node.position = npc[1]
		room.add_child(node)
		node.owner = room
		var sprite := _npc_sprite(npc[0], npc[2])
		sprite.name = "Sprite"
		node.add_child(sprite)
		sprite.owner = room
		if npc[0] == "alisia":
			var cat := _npc_sprite("cat", npc[2])
			cat.name = "Cat"
			cat.position = CAT_AT * (-1.0 if npc[2] else 1.0)
			node.add_child(cat)
			cat.owner = room


func _npc_sprite(who: String, face_left: bool) -> AnimatedSprite2D:
	var look: Array = NPC_LOOK[who]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim in [["idle", "idle", 4.0, true], ["run", look[3], 16.0, true]]:
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


## Темрява, лампи зі світлом і плани глибини кожного поверху — у вузлі Atmosphere (перебудовується щоразу).
func _decorate(room: Node, spec: Dictionary) -> void:
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
	var lamps: Array = spec.lamps
	for i in lamps.size():
		var lamp := _sprite(LAMP, lamps[i], Vector2(0, -0.5), -1)
		lamp.name = "Lamp%d" % (i + 1)
		root.add_child(lamp)
		lamp.add_child(_light(glow, LAMP_LIGHT, 1.25, 1.6, Vector2(4, 0)))
	var floors: Array = spec.floors
	for storey in floors.size():
		var floor_y: float = (floors[storey][1] + 1) * TILE
		for plane: Array in spec.planes:
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
			var texture: String = plane[1] % spec.mid_variant[storey] if plane[1].contains("%") else plane[1]
			sprite.texture = load(BG % texture)
			sprite.material = load(MATERIALS % plane[6])
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.centered = false
			sprite.scale = Vector2(1.5, 1.5)
			sprite.position = Vector2(spec.plane_shift[storey], floor_y + plane[4] - LAYER_SIZE.y)
			layer.add_child(sprite)
	for node in root.find_children("*", "", true, false):
		node.owner = room
	root.owner = room


## Спрайт ×1.5 з [param texture_path]; [param anchor] — частка розміру, що лягає в [param at] (0,0 — лівий верх).
func _sprite(texture_path: String, at: Vector2, anchor: Vector2, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path)
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
	if y < 0 or y >= layout.size() or x < 0 or x >= layout[y].length():
		return "#"
	return layout[y][x]


## Рамковий блок 3x3 атласа (7..9, 6..8) за тим, чи порожньо зверху / знизу / ліворуч / праворуч.
func _block(x: int, y: int) -> Vector2i:
	var col := 0 if _at(x - 1, y) != "#" else 2 if _at(x + 1, y) != "#" else 1
	var row := 0 if _at(x, y - 1) != "#" else 2 if _at(x, y + 1) != "#" else 1
	return Vector2i(7 + col, 6 + row)
