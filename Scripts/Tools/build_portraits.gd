extends SceneTree

## Портрети мовців у вікні діалогу (BACKLOG 36): голова з кадру «анфас» спрайта, який гра вже малює
## (NPC, боси, герой). Пише <тека спрайта>/portrait.tres (AtlasTexture) і ставить його в `portrait` персонажа
## DialogueQuest (dialogue_quest/characters/*.tres) — аддон передає його у вікно (dialogue_player.gd → set_portrait_image).
## Портрети компаньйонів (Астрит, Алісия, Уризен) уже є (D243–D245, CompanionManager.PORTRAIT_PATH) — лише прив'язуються.
## Голова: перший непрозорий рядок кадру, квадрат SIZE px від нього, по центру непрозорих стовпців цієї смуги.
## Запуск: godot --headless --path . --script res://Scripts/Tools/build_portraits.gd

const CHARACTERS := "res://dialogue_quest/characters/%s.tres"
const NPCS := "res://SampleProject/Assets/Characters/NPCs/%s/"
const BOSSES := "res://SampleProject/Assets/Characters/Bosses/%s/"
const COMPANION_PORTRAIT := "res://SampleProject/Assets/Characters/Companions/%s/portrait.tres"
const HERO_DIR := "res://SampleProject/Sprites/Player/"
const ALPHA := 0.5

## [тека, файл кадру, клітинка (x, y, w, h), сторона квадрата, персонажі з цим портретом, зсув униз (px, необов'язково —
## дервіш у високій шапці: перший рядок — її верх, а не голова)].
const SOURCES := [
	[HERO_DIR, "Idle/2.png", Rect2i(0, 0, 64, 64), 32, ["KUSAKAM"]],
	[NPCS % "old_man", "sheet.png", Rect2i(0, 0, 64, 96), 32, ["GRANDFATHER"]],
	[NPCS % "blacksmith", "sheet.png", Rect2i(0, 192, 64, 96), 32, ["BLACKSMITH"]],
	[NPCS % "merchant", "sheet.png", Rect2i(0, 192, 64, 96), 32, ["MERCHANT"]],
	[NPCS % "gate_guard", "sheet.png", Rect2i(0, 0, 64, 96), 32, ["GATE_GUARD"]],
	[NPCS % "priest", "sheet.png", Rect2i(0, 96, 64, 96), 32, ["OATH_PRIEST"]],
	[NPCS % "witch", "sheet.png", Rect2i(0, 96, 64, 96), 32, ["OATH_WITCH"]],
	[NPCS % "dervish", "sheet.png", Rect2i(0, 96, 64, 96), 32, ["OATH_DERVISH"], 14],
	[NPCS % "malik", "sheet.png", Rect2i(0, 192, 64, 96), 32, ["MALIK"]],
	[NPCS % "prisoner", "sheet.png", Rect2i(0, 384, 64, 96), 32, ["PRISONER"]],
	[NPCS % "alchemist", "sheet.png", Rect2i(0, 288, 64, 96), 32, ["SCIENTIST"]],
	[BOSSES % "brass_collector", "sheet.png", Rect2i(0, 0, 96, 112), 48, ["BRASS_COLLECTOR"]],
	[BOSSES % "fire_djinn", "sheet.png", Rect2i(0, 0, 96, 112), 48, ["FIRE_DJINN"]],
]
## Персонаж → тека компаньйона з готовим portrait.tres.
const COMPANIONS := {"ASTRIT": "astrit", "ALISIA": "alisia", "URIZEN": "urizen"}


func _initialize() -> void:
	for source: Array in SOURCES:
		var dir: String = source[0]
		var texture: Texture2D = load(dir + source[1])
		var portrait := AtlasTexture.new()
		portrait.atlas = texture
		portrait.region = _head(texture.get_image(), source[2], source[3], source[5] if source.size() > 5 else 0)
		var path: String = dir + "portrait.tres"
		_save(portrait, path)
		for id: String in source[4]:
			_assign(id, path)
	for id: String in COMPANIONS:
		_assign(id, COMPANION_PORTRAIT % COMPANIONS[id])
	quit()


## Квадрат side×side від першого непрозорого рядка клітинки, по центру непрозорих стовпців смуги голови.
func _head(image: Image, cell: Rect2i, side: int, drop: int) -> Rect2:
	var top: int = -1
	for y: int in range(cell.position.y, cell.end.y):
		for x: int in range(cell.position.x, cell.end.x):
			if image.get_pixel(x, y).a > ALPHA:
				top = y
				break
		if top >= 0:
			break
	assert(top >= 0, "build_portraits: empty cell %s" % cell)
	top += drop
	var left: int = cell.end.x
	var right: int = cell.position.x
	for y: int in range(top, mini(top + side, cell.end.y)):
		for x: int in range(cell.position.x, cell.end.x):
			if image.get_pixel(x, y).a > ALPHA:
				left = mini(left, x)
				right = maxi(right, x)
	var x0: int = clampi((left + right + 1 - side) / 2, cell.position.x, cell.end.x - side)
	var y0: int = clampi(top - 2, cell.position.y, cell.end.y - side)
	return Rect2(x0, y0, side, side)


## Текстом, а не ResourceSaver: той переписує заголовок персонажа без uid (на нього посилаються .dqd-плеєр і сцени).
## Повторний запуск замінює рядки портрета, а не додає нові.
func _assign(id: String, portrait_path: String) -> void:
	var path: String = CHARACTERS % id
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	var out: PackedStringArray = []
	for line: String in lines:
		if line.begins_with("[ext_resource") and line.contains('id="portrait"') or line.begins_with("portrait = "):
			continue
		out.append(line)
		if line.begins_with("[ext_resource") and line.contains("character.gd"):
			out.append('[ext_resource type="Texture2D" path="%s" id="portrait"]' % portrait_path)
		elif line.begins_with("script = "):
			out.append('portrait = ExtResource("portrait")')
	assert(out.size() == lines.size() + 2 or lines.has('portrait = ExtResource("portrait")'), "build_portraits: unexpected layout of %s" % path)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(out))
	file.close()
	print("build_portraits: %s" % path)


func _save(resource: Resource, path: String) -> void:
	var err: Error = ResourceSaver.save(resource, path)
	assert(err == OK, "build_portraits: cannot save %s (%s)" % [path, error_string(err)])
	print("build_portraits: %s" % path)
