extends SceneTree

## Живий світ (BACKLOG 7 + 19):
##   1. Кожна відкрита кімната має передній план `Front` (Parallax2D) над героєм (z більший за z гравця),
##      scroll_scale.x > 1, depth blur, текстура задана; його непрозорий верх не вище лінії підлоги героя.
##   2. Декор (банери, пальми, лампи, кристали, пил) — AnimatedSprite2D з циклом `idle` у кожній кімнаті зі списку;
##      сусіди в кімнаті не крутяться в одній фазі; кожна сцена декору справді анімується в дереві.
##   3. Хмари пливуть самі (без вводу) у небі обох задників і в високому небі Каньйону.
##   godot --headless --path . --script res://SampleProject/UI/verify_living_world.gd

const FRONT_BLUR := "res://SampleProject/Resources/Materials/depth_blur_front.tres"
const PLAYER_SCENE := "res://SampleProject/Player.tscn"
const DECOR_DIR := "res://SampleProject/Scenes/Backgrounds/Decor/%s.tscn"
const BACKDROPS := [
	"res://SampleProject/Scenes/Backgrounds/desert_backdrop_open.tscn",
	"res://SampleProject/Scenes/Backgrounds/desert_backdrop_canyon.tscn",
]
## Кімната → лінія підлоги, на якій стоїть герой (верх тайлів Foreground; у City — підлога біля кузні).
const FRONT_ROOMS := {
	"Village": 384.0,
	"Canyon": 384.0,
	"DesertRoad": 384.0,
	"CityGates": 384.0,
	"City": 396.0,
	"LaboratoryOutside": 384.0,
}
## Кімната → види декору, які в ній мають бути (банери на брамі — у сцені gate_passage, вона стоїть в обох містах).
const DECOR_ROOMS := {
	"Village": ["palm", "banner"],
	"Canyon": ["dust"],
	"DesertRoad": ["palm", "dust"],
	"CityGates": ["banner"],
	"City": ["banner"],
	"LaboratoryOutside": ["palm"],
	"Laboratory": ["lamp", "crystal"],
	"LabCells": ["lamp", "crystal"],
	"LabBoss": ["lamp", "crystal"],
}
const DECOR_KINDS := ["banner", "palm", "lamp", "crystal", "dust"]

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _initialize() -> void:
	await process_frame
	var player: Node2D = load(PLAYER_SCENE).instantiate()
	var player_z := _max_z(player, 0)
	player.free()
	_check_fronts(player_z)
	_check_room_decor()
	await _check_decor_animates()
	await _check_clouds_drift()
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()


## Найбільший сумарний z серед вузлів гравця (z_as_relative додається до батьківського).
func _max_z(node: Node, parent_z: int) -> int:
	var z := parent_z
	if node is CanvasItem:
		var ci := node as CanvasItem
		z = ci.z_index + (parent_z if ci.z_as_relative else 0)
	var best := z
	for child: Node in node.get_children():
		best = maxi(best, _max_z(child, z))
	return best


func _check_fronts(player_z: int) -> void:
	for room: String in FRONT_ROOMS:
		var map: Node = load("res://SampleProject/Maps/%s.tscn" % room).instantiate()
		var front := map.get_node_or_null(^"Front") as Parallax2D
		ck(front != null, "%s: Front Parallax2D exists" % room)
		if front:
			ck(front.z_index > player_z, "%s: Front z %d is above the player (max z %d)" % [room, front.z_index, player_z])
			ck(front.scroll_scale.x > 1.0, "%s: Front scroll %.2f > 1" % [room, front.scroll_scale.x])
			ck(front.repeat_size.x > 0.0 and front.repeat_times >= 2, "%s: Front repeats along the room" % room)
			var sprite := front.get_node_or_null(^"Sprite") as Sprite2D
			ck(sprite != null and sprite.texture != null, "%s: Front sprite has a texture" % room)
			if sprite and sprite.texture:
				ck(sprite.material != null and sprite.material.resource_path == FRONT_BLUR, "%s: Front uses depth_blur_front" % room)
				var top_row := sprite.texture.get_image().get_used_rect().position.y
				var top := front.position.y + sprite.position.y + top_row * sprite.scale.y
				ck(top >= FRONT_ROOMS[room], "%s: Front starts at y %.0f, not above the platform line %.0f" % [room, top, FRONT_ROOMS[room]])
		map.free()


## Усі AnimatedSprite2D декору в піддереві (і в інстансах сцен, напр. gate_passage).
func _decor_in(node: Node, out: Array[AnimatedSprite2D]) -> void:
	for child: Node in node.get_children():
		if child is AnimatedSprite2D and (child as AnimatedSprite2D).scene_file_path.begins_with(DECOR_DIR.get_base_dir()):
			out.append(child)
		_decor_in(child, out)


func _check_room_decor() -> void:
	for room: String in DECOR_ROOMS:
		var map: Node = load("res://SampleProject/Maps/%s.tscn" % room).instantiate()
		var decor: Array[AnimatedSprite2D] = []
		_decor_in(map, decor)
		var kinds := {}
		var phases := {}
		for sprite: AnimatedSprite2D in decor:
			kinds[sprite.scene_file_path.get_file().get_basename()] = true
			phases["%d/%.2f" % [sprite.frame, sprite.speed_scale]] = true
		for kind: String in DECOR_ROOMS[room]:
			ck(kinds.has(kind), "%s: has %s decor" % [room, kind])
		ck(decor.size() < 2 or phases.size() > 1, "%s: %d decor sprites do not share one phase/speed" % [room, decor.size()])
		map.free()


func _check_decor_animates() -> void:
	var sprites: Array[AnimatedSprite2D] = []
	for kind: String in DECOR_KINDS:
		var sprite: AnimatedSprite2D = load(DECOR_DIR % kind).instantiate()
		ck(sprite.autoplay == "idle" and sprite.sprite_frames.get_frame_count(&"idle") > 1, "%s: idle loop with several frames" % kind)
		ck(sprite.sprite_frames.get_animation_loop(&"idle"), "%s: idle loops" % kind)
		root.add_child(sprite)
		sprites.append(sprite)
	var seen: Array[Dictionary] = []
	for sprite: AnimatedSprite2D in sprites:
		seen.append({sprite.frame: true})
	for i in 30:
		await create_timer(0.05).timeout
		for k in sprites.size():
			seen[k][sprites[k].frame] = true
	for k in sprites.size():
		ck(sprites[k].is_playing() and seen[k].size() > 1, "%s: frames change on their own (%d seen)" % [DECOR_KINDS[k], seen[k].size()])
		sprites[k].queue_free()


## Хмари: Parallax2D з autoscroll і повтором; у дереві їхній кадр зсувається з часом без руху камери.
func _check_clouds_drift() -> void:
	var camera := Camera2D.new()
	root.add_child(camera)
	camera.make_current()
	var layers: Array[Parallax2D] = []
	for path: String in BACKDROPS:
		var backdrop: Node = load(path).instantiate()
		root.add_child(backdrop)
		var clouds := backdrop.get_node_or_null(^"DriftingClouds")
		ck(clouds != null, "%s: DriftingClouds in the sky" % path.get_file())
		if clouds:
			for layer: Node in clouds.get_children():
				layers.append(layer as Parallax2D)
		layers.append(backdrop.get_node(^"Plan4") as Parallax2D)
	var canyon: Node = load("res://SampleProject/Maps/Canyon.tscn").instantiate()
	var high := canyon.get_node(^"HighClouds") as Parallax2D
	ck(high.autoscroll.x != 0.0 and high.repeat_size.x > 0.0, "Canyon: HighClouds drift and wrap")
	canyon.free()
	for layer: Parallax2D in layers:
		ck(layer.autoscroll.x != 0.0 and layer.repeat_size.x > 0.0, "%s: drifts (autoscroll) and wraps (repeat)" % layer.get_path())
		ck(layer.scroll_scale.x > 0.0 and layer.scroll_scale.x < 1.0, "%s: parallax %.2f behind the hero" % [layer.get_path(), layer.scroll_scale.x])
	await process_frame
	var before: Array[float] = []
	for layer: Parallax2D in layers:
		before.append(_screen_x(layer))
	await create_timer(1.5).timeout
	for k in layers.size():
		var moved := absf(_screen_x(layers[k]) - before[k])
		ck(moved > 1.0, "%s: moved %.1f px in 1.5 s with no input" % [layers[k].get_path(), moved])


func _screen_x(layer: Parallax2D) -> float:
	return (layer.get_child(0) as Node2D).get_global_transform_with_canvas().origin.x
