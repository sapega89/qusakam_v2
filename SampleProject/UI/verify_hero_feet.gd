extends SceneTree

## Ноги героя на підлозі (hero-feet, Sapega 2026-10-27: «підняти спрайт, щоб ноги стояли точно на підлозі»): у кожному
## кадрі кожної анімації тіла (усі бібліотеки AnimationPlayer Player.tscn) нижній непрозорий рядок ніг лягає на низ
## колізії героя з точністю до 1 px світу. Ноги — нижній непрозорий рядок без зброї (ключові кольори weapon_palettes.json
## і контур поруч із ними). Древко алебарди, голова булави чи контур кінчика меча не ключового кольору й бувають нижче
## за ноги: у кадрі зі зброєю (Sprites/Player/Weapons), де пальці (SKIN + рядок контуру) на 1–5 рядків вище, ноги — пальці. Без зброї в кадрі
## пальців може й не бути видно (чоботи, каст) — тоді лише нижній рядок.
## Спрайт центрований: низ рядка row у px вузла = position.y + (offset.y + row + 1 − h/2) · scale.y.
## Кадри в повітрі (AIRBORNE) друкуються, але не перевіряються. Кадри, де ноги намальовано нижче чи вище за рядок 56
## (біг художника, згенеровані кадри зі зброєю), садить на підлогу власний ключ Sprite2D:offset.
##   godot --headless --path . --script res://SampleProject/UI/verify_hero_feet.gd

const TOLERANCE := 1.0
const PALETTES := "res://SampleProject/Resources/Data/weapon_palettes.json"
## Кольори шкіри героя (пальці ніг) у кадрах Sprites/Player (палітра художника).
const SKIN: Array[String] = ["f4ce8a", "e7b57b", "eec87d", "af8759"]
## Наскільки вище за нижній рядок пальці ще вважаються ногами (далі — рука чи хвіст над чоботами).
const TOES_ABOVE := 5
## Пози, де ноги не стоять на підлозі: стрибок, вершина, падіння, драбина (D225), сидіння в медитації (D764).
const AIRBORNE: Array[String] = ["Jump", "Apex", "Fall", "Climb", "Meditate"]

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

static var _keys: Array[Color] = []

## Піксель ([param x], [param y]) — зброя: ключовий колір палітри зброї (WeaponView його перефарбовує).
static func _is_weapon(image: Image, x: int, y: int) -> bool:
	if _keys.is_empty():
		for html: String in JSON.parse_string(FileAccess.get_file_as_string(PALETTES)).key:
			_keys.append(Color(html))
	if not Rect2i(Vector2i.ZERO, image.get_size()).has_point(Vector2i(x, y)):
		return false
	var color := image.get_pixel(x, y)
	color.a = 1.0
	return _keys.any(func(key: Color) -> bool: return key.is_equal_approx(color))

## Низ ніг [param image] (рядок під ними, як Rect2i.end.y), див. шапку; [param armed] — кадр зі зброєю в руці.
static func feet_end(image: Image, armed: bool) -> int:
	var lowest := 0
	var toes := 0
	for y in range(image.get_height() - 1, -1, -1):
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a == 0.0:
				continue
			if _is_weapon(image, x, y):
				continue
			if toes == 0 and SKIN.has(color.to_html(false)):
				toes = y + 2
			if lowest == 0 and not range(-1, 2).any(func(dx: int) -> bool:
					return range(-1, 2).any(func(dy: int) -> bool: return _is_weapon(image, x + dx, y + dy))):
				lowest = y + 1
	if armed and toes < lowest and toes >= lowest - TOES_ABOVE:
		return toes
	return lowest

## Низ ніг кадру [param texture] у px вузла героя (зсув кадру [param offset]).
static func feet_y(sprite: Sprite2D, texture: Texture2D, offset: Vector2) -> float:
	var image: Image = texture.get_image()
	var armed := texture.resource_path.contains("/Weapons/")
	return sprite.position.y + (offset.y + feet_end(image, armed) - image.get_height() / 2.0) * sprite.scale.y

func _initialize() -> void:
	var player: CharacterBody2D = load("res://SampleProject/Player.tscn").instantiate()
	var sprite: Sprite2D = player.get_node(^"Sprite2D")
	var body: CollisionShape2D = player.get_node(^"CollisionShape2D")
	var floor_y: float = body.position.y + (body.shape as RectangleShape2D).size.y / 2.0
	print("collision bottom y = %.1f, sprite position = %s, scale = %s" % [floor_y, sprite.position, sprite.scale])
	ck(sprite.position == player.get_node(^"WeaponMount").position, "WeaponMount stands where Sprite2D does")
	var animation_player: AnimationPlayer = player.get_node(^"AnimationPlayer")
	var checked := 0
	for name in animation_player.get_animation_list():
		var animation: Animation = animation_player.get_animation(name)
		var textures := animation.find_track(^"Sprite2D:texture", Animation.TYPE_VALUE)
		var offsets := animation.find_track(^"Sprite2D:offset", Animation.TYPE_VALUE)
		if textures == -1:
			continue
		var base := String(name).get_slice("/", String(name).get_slice_count("/") - 1)
		for key in animation.track_get_key_count(textures):
			var texture: Texture2D = animation.track_get_key_value(textures, key)
			var at := animation.track_get_key_time(textures, key)
			var offset: Vector2 = Vector2.ZERO if offsets == -1 else animation.value_track_interpolate(offsets, at)
			var gap := feet_y(sprite, texture, offset) - floor_y
			var frame := texture.resource_path.trim_prefix("res://SampleProject/Sprites/Player/")
			var label := "%s key %d (%s): feet %+.1f px from the collision bottom" % [name, key, frame, gap]
			if AIRBORNE.has(base):
				print("  --  " + label + " (in the air, not checked)")
			else:
				ck(absf(gap) <= TOLERANCE, label)
				checked += 1
	ck(checked > 150, "standing frames checked: %d" % checked)
	player.free()
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit(0 if fails.is_empty() else 1)
