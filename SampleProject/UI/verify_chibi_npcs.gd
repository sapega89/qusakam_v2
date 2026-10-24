extends SceneTree

## Чібі-кадри (D677, D598): Малік і алхімік у lab_*.tscn, охоронець-компаньйон, їхні портрети, Алісія на столі (B127).
## Кожен — на новому аркуші 64×64; ступні (нижній непрозорий рядок кадру) — на підлозі (y 0 вузла); на зріст трохи
## вищі за Кусакама; удар охоронця (strike_frame) — на випаді списа.
##   godot --headless --path . --script res://SampleProject/UI/verify_chibi_npcs.gd

const NPCS := "res://SampleProject/Scenes/Gameplay/Objects/NPCs/"
const CHARS := "res://SampleProject/Assets/Characters/"
## [сцена, аркуш, hframes, vframes]
const SHEETS := [
	["lab_malik.tscn", "NPCs/malik/sheet_chibi.png", 4, 3],
	["lab_alchemist.tscn", "NPCs/alchemist/sheet_chibi.png", 4, 4],
]
## [портрет, аркуш]
const PORTRAITS := [
	["NPCs/malik/portrait.tres", "NPCs/malik/sheet_chibi.png"],
	["NPCs/alchemist/portrait.tres", "NPCs/alchemist/sheet_chibi.png"],
	["Companions/guard/portrait.tres", "Companions/guard/chibi/idle.png"],
]
## «Трохи вищий» за героя (D598): зріст на екрані — у цих межах від зросту Кусакама.
const TALLER_MIN := 1.05
const TALLER_MAX := 1.4

var fails: Array[String] = []


func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _initialize() -> void:
	var hero: Node2D = (load("res://SampleProject/Player.tscn") as PackedScene).instantiate()
	var hero_sprite: Sprite2D = hero.get_node(^"Sprite2D")
	var hero_h: float = hero_sprite.texture.get_image().get_used_rect().size.y * hero_sprite.scale.y
	hero.free()

	print("[1] Malik and the alchemist: chibi sheets, feet on the floor, a little taller than Kusakam")
	for spec: Array in SHEETS:
		var npc: Node2D = (load(NPCS + spec[0]) as PackedScene).instantiate()
		var sprite: Sprite2D = npc.get_node(^"Sprite2D")
		ck(sprite.texture.resource_path == CHARS + spec[1] and sprite.hframes == spec[2] and sprite.vframes == spec[3],
				"%s: %s, %d×%d cells of 64×64" % [spec[0], spec[1], spec[2], spec[3]])
		var image := sprite.texture.get_image()
		var anim: AnimationPlayer = npc.get_node(^"AnimationPlayer")
		var feet: Array[float] = []
		for name in anim.get_animation_list():
			var animation := anim.get_animation(name)
			for key in animation.track_get_key_count(0):
				var frame: int = animation.track_get_key_value(0, key)
				var rect := _used(image, Rect2i(frame % sprite.hframes * 64, frame / sprite.hframes * 64, 64, 64))
				feet.append((sprite.offset.y + rect.end.y - 32.0) * sprite.scale.y)
		ck(feet.all(func(y: float) -> bool: return absf(y) <= 1.5), "%s: every frame's feet on the floor (%s)" % [spec[0], feet])
		var idle := _used(image, Rect2i(0, 0, 64, 64))
		var ratio := idle.size.y * sprite.scale.y / hero_h
		ck(ratio >= TALLER_MIN and ratio <= TALLER_MAX, "%s: %.2f× Kusakam's height (D598)" % [spec[0], ratio])
		npc.free()

	print("[2] The guard companion: chibi enter 12 + strike 12, the hit on the spear thrust")
	var guard: Node2D = (load("res://SampleProject/Scenes/Characters/Companions/companion_guard.tscn") as PackedScene).instantiate()
	var body: AnimatedSprite2D = guard.get_node(^"Sprite")
	var frames := body.sprite_frames
	var atlases_ok := true
	for name in [&"enter", &"strike"]:
		for i in frames.get_frame_count(name):
			var atlas := frames.get_frame_texture(name, i) as AtlasTexture
			atlases_ok = atlases_ok and atlas.atlas.resource_path == CHARS + "Companions/guard/chibi/%s.png" % name and atlas.region.size == Vector2(64, 64)
	ck(atlases_ok and frames.get_frame_count(&"enter") == 12 and frames.get_frame_count(&"strike") == 12,
			"enter %d + strike %d frames, all from Companions/guard/chibi/" % [frames.get_frame_count(&"enter"), frames.get_frame_count(&"strike")])
	var stand := _frame_rect(frames, &"enter", 0)
	var hit := _frame_rect(frames, &"strike", int(guard.get(&"strike_frame")))
	ck(hit.size.x >= stand.size.x * 1.5, "strike_frame %d is the thrust (%d px wide against %d standing)" % [guard.get(&"strike_frame"), hit.size.x, stand.size.x])
	var guard_feet := (body.offset.y + stand.end.y) * body.scale.y
	ck(absf(guard_feet) <= 1.5 and body.scale == Vector2(1.5, 1.5), "feet on the floor (%.1f), scale 1.5 like the other companions" % guard_feet)
	guard.free()

	print("[3] Portraits from the new heads")
	for spec: Array in PORTRAITS:
		var portrait: AtlasTexture = load(CHARS + spec[0])
		var used := _used(portrait.atlas.get_image(), Rect2i(portrait.region))
		ck(portrait.atlas.resource_path == CHARS + spec[1] and portrait.region.size == Vector2(32, 32) and used.size.x > 20,
				"%s: 32×32 of %s, not empty" % [spec[0], spec[1]])
	for id in ["MALIK", "SCIENTIST"]:
		var character: Resource = load("res://dialogue_quest/characters/%s.tres" % id)
		ck((character.get(&"portrait") as AtlasTexture).atlas.resource_path.ends_with("sheet_chibi.png"), "%s speaks with the chibi portrait" % id)

	print("[4] B127: Alisia's lying frames in LabCells")
	var cells: Node2D = (load("res://SampleProject/Maps/LabCells.tscn") as PackedScene).instantiate()
	var alisia_frames: SpriteFrames = (cells.get_node(^"CompanionNPC_alisia/Sprite") as AnimatedSprite2D).sprite_frames
	var lie := alisia_frames.get_frame_texture(&"lie", 0) as AtlasTexture
	var sit := alisia_frames.get_frame_texture(&"sit_up", 0) as AtlasTexture
	ck(lie.atlas.resource_path == CHARS + "Companions/alisia/lie.png" and lie.region.position.x == 0.0 and sit.region.position.x == 64.0,
			"lie = frame 0 (on her back), sit_up = frame 1 (dazed) of Companions/alisia/lie.png")
	cells.free()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()


func _frame_rect(frames: SpriteFrames, name: StringName, index: int) -> Rect2i:
	var atlas := frames.get_frame_texture(name, index) as AtlasTexture
	return _used(atlas.atlas.get_image(), Rect2i(atlas.region))


## Непрозорі пікселі кадру [param cell] — у координатах кадру.
func _used(image: Image, cell: Rect2i) -> Rect2i:
	return image.get_region(cell).get_used_rect()
