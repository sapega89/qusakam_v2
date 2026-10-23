extends SceneTree

## performance_plan, slice 4: спрайти задників і землі малюють лише ту частину текстури, де є непрозорі пікселі.
## Разовий інструмент — у грі не запускається. Пише в .tscn region_enabled, region_rect (Image.get_used_rect()
## з полем MARGIN) і зсунутий offset, тож кожен піксель лишається на тому ж місці екрана:
##   godot --headless --path . --script res://Scripts/Tools/region_backdrops.gd            # усі сцени
##   godot --headless --path . --script res://Scripts/Tools/region_backdrops.gd -- dry     # лише звіт
## Після build_terrain.gd -- place (воно переписує вузли землі) інструмент треба запустити ще раз.
## Альфу читаємо з PNG на диску, а не texture.get_image(): той читав би назад з відеокарти.

const SCENE_DIRS: Array[String] = ["res://SampleProject/Maps/", "res://SampleProject/Scenes/Backgrounds/"]
const ART_DIR := "res://SampleProject/Assets/Backgrounds/"
const DECOR_DIR := "res://SampleProject/Assets/Backgrounds/Decor/"
## Поле навколо непрозорих пікселів, у текселях. depth_blur бере сусідів на відстані до 1.6 текселя (з лінійним
## фільтром — ще один), тож розмита облямівка не дотягується далі 3; 4 — із запасом.
const MARGIN := 4
## Менший виграш не вартий зміни сцени.
const MIN_SAVED := 0.05
## project.godot вмикає snap_2d_vertices_to_pixel: краї квадрата спрайта стають на цілий піксель екрана. Якщо обрізаний
## край лежить на дробовому пікселі, текстура зсувається до пів пікселя, і межі текселів падають на інші рядки.
## Тому край обрізки — кратне кроку, що дає цілі пікселі за камери 2.25 (Game.tscn) при кожному розмірі вікна зі
## Settings (DisplayManager.RESOLUTIONS: множники 2/3, 5/6, 1, 4/3 від 1920×1080). Для спрайтів з масштабом 1.5 крок 16.
const CAMERA_ZOOM := 2.25
const WINDOW_FACTORS: Array[float] = [2.0 / 3.0, 5.0 / 6.0, 1.0, 4.0 / 3.0]

var dry: bool = false
var total_before: int = 0
var total_after: int = 0


func _initialize() -> void:
	dry = OS.get_cmdline_user_args().has("dry")
	for dir: String in SCENE_DIRS:
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".tscn"):
				_process_scene(dir + file)
	print("REGION total: %.2f MP -> %.2f MP of backdrop texels (%.0f %%)" % [
			total_before / 1e6, total_after / 1e6, 100.0 * total_after / maxf(total_before, 1.0)])
	quit()


func _process_scene(path: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	if not text.contains('type="Sprite2D"'):
		return
	var root: Node = (load(path) as PackedScene).instantiate()
	var lines: PackedStringArray = text.split("\n")
	var changed: int = 0
	for sprite: Node in root.find_children("*", "Sprite2D", true, false):
		var edit: Dictionary = _region_for(sprite as Sprite2D)
		if edit.is_empty():
			continue
		var header: int = _header_line(lines, String(root.get_path_to(sprite)))
		if header < 0:
			continue  # вузол з інстансованої сцени — його правлять у ній самій
		print("REGION %s %s: %s used %s -> offset %s" % [path.get_file(), root.get_path_to(sprite),
				edit.texture.get_file(), edit.rect, edit.offset])
		_set_property(lines, header, "offset", "Vector2(%s, %s)" % [_num(edit.offset.x), _num(edit.offset.y)])
		_set_property(lines, header, "region_enabled", "true")
		_set_property(lines, header, "region_rect", "Rect2(%d, %d, %d, %d)" % [
				edit.rect.position.x, edit.rect.position.y, edit.rect.size.x, edit.rect.size.y])
		changed += 1
	root.free()
	if changed > 0 and not dry:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("\n".join(lines))
		file.close()


## {texture, rect: Rect2i, offset: Vector2} або {}, якщо спрайт не задник / вже обрізаний / виграш замалий.
func _region_for(sprite: Sprite2D) -> Dictionary:
	var texture: Texture2D = sprite.texture
	if texture == null or sprite.region_enabled or sprite.hframes != 1 or sprite.vframes != 1:
		return {}
	var tex_path: String = texture.resource_path
	if not tex_path.begins_with(ART_DIR) or tex_path.begins_with(DECOR_DIR):
		return {}
	var image := Image.load_from_file(ProjectSettings.globalize_path(tex_path))
	var full := Vector2i(image.get_width(), image.get_height())
	var used: Rect2i = image.get_used_rect()
	if used.size == Vector2i.ZERO:
		return {}
	var step: Vector2i = Vector2i(_step(absf(_world_scale(sprite).x)), _step(absf(_world_scale(sprite).y)))
	if step.x == 0 or step.y == 0:
		return {}
	var rect: Rect2i = _aligned(used.grow(MARGIN), full, step)
	total_before += full.x * full.y
	if 1.0 - float(rect.get_area()) / float(full.x * full.y) < MIN_SAVED:
		total_after += full.x * full.y
		return {}
	total_after += rect.get_area()
	# Де лівий-верхній кут прямокутника опиняється в повній картинці з урахуванням дзеркала.
	var corner := Vector2(rect.position)
	if sprite.flip_h:
		corner.x = full.x - rect.position.x - rect.size.x
	if sprite.flip_v:
		corner.y = full.y - rect.position.y - rect.size.y
	var offset: Vector2 = sprite.offset + corner
	if sprite.centered:
		offset += (Vector2(rect.size) - Vector2(full)) / 2.0
	return {"texture": tex_path, "rect": rect, "offset": offset}


## Сумарний масштаб від кореня сцени (Parallax2D теж Node2D).
func _world_scale(n: Node) -> Vector2:
	var s := Vector2.ONE
	while n != null:
		if n is Node2D:
			s *= (n as Node2D).scale
		n = n.get_parent()
	return s


## Найменша кількість текселів, яка при кожному WINDOW_FACTORS — цілі пікселі екрана; 0, якщо до 64 такої немає.
func _step(scale: float) -> int:
	for n: int in range(1, 65):
		var whole: bool = true
		for f: float in WINDOW_FACTORS:
			var px: float = n * scale * CAMERA_ZOOM * f
			whole = whole and is_equal_approx(px, roundf(px))
		if whole:
			return n
	return 0


## Прямокутник, чиї краї віддалені від країв картинки на кратне [param step] (тоді й зсув краю — цілі пікселі).
func _aligned(want: Rect2i, full: Vector2i, step: Vector2i) -> Rect2i:
	var lo := Vector2i(floori(maxi(want.position.x, 0) / float(step.x)) * step.x,
			floori(maxi(want.position.y, 0) / float(step.y)) * step.y)
	var hi := Vector2i(full.x - floori(maxi(full.x - want.end.x, 0) / float(step.x)) * step.x,
			full.y - floori(maxi(full.y - want.end.y, 0) / float(step.y)) * step.y)
	return Rect2i(lo, hi - lo)


func _header_line(lines: PackedStringArray, node_path: String) -> int:
	var name: String = node_path.get_file()
	var parent: String = "." if not node_path.contains("/") else node_path.get_base_dir()
	var want := '[node name="%s" type="Sprite2D" parent="%s"' % [name, parent]
	for i: int in lines.size():
		if lines[i].begins_with(want):
			return i
	return -1


## Замінює рядок "key = ..." у блоці вузла або додає його в кінець блоку.
func _set_property(lines: PackedStringArray, header: int, key: String, value: String) -> void:
	var i: int = header + 1
	while i < lines.size() and not lines[i].begins_with("[") and not lines[i].is_empty():
		if lines[i].begins_with(key + " = "):
			lines[i] = "%s = %s" % [key, value]
			return
		i += 1
	lines.insert(i, "%s = %s" % [key, value])


func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else str(v)
