extends SceneTree

## Смерть героя (H1, D138): кадри Death 1–4 у грі (DesertRoad, меч у руці до смерті), стрічка 1×4, кожна клітинка —
## 420×360 px екрана навколо тіла; ліворуч кадр перед смертю. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_hero_death.gd -- <out.png>

const CROP := Vector2i(420, 360)
## Центр кадру — на стільки екранних px вище низу тіла.
const LIFT := 60

var game: Node
var dm: Node

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	dm = sl.get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain()
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 30: await physics_frame
	await _drain()
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.process_mode = Node.PROCESS_MODE_DISABLED
	var who: String = sl.get_game_manager().get_active_character().character_id
	sl.get_equipment_manager().equip_item(who, "sword", "iron_sword", sl.get_item_database().get_item("iron_sword"))
	game.player.get_node(^"WeaponMount").sheathed = false
	for i in 60: await physics_frame
	await create_timer(0.5).timeout
	var sheet := Image.create(CROP.x * 5, CROP.y, false, Image.FORMAT_RGBA8)
	await _shot(sheet, 0, "before")
	# Програмний рендер xvfb повільний: кадр пози (0.15 с) проскакує між знімками. Тож поза стоїть (час ×0.01),
	# а кожен кадр ставить seek на його ключ — тіло, тінь і зброя ті самі, що в грі.
	Engine.time_scale = 0.01
	game.player.take_damage(99999)
	var anim: AnimationPlayer = game.player.get_node(^"AnimationPlayer")
	anim.pause()
	for frame in range(1, 5):
		anim.seek((frame - 1) * 0.15, true)
		await _shot(sheet, frame, "Death %d" % frame)
	Engine.time_scale = 1.0
	sheet.save_png(out)
	print("saved ", out)
	quit()

## Кадр навколо тіла (камера йде за героєм, тож центр — від низу колізії в цьому кадрі, у px екрана).
func _shot(sheet: Image, cell: int, label: String) -> void:
	await RenderingServer.frame_post_draw
	var shadow: Node2D = game.player.get_node(^"Shadow")
	var centre: Vector2 = root.get_final_transform() * shadow.get_global_transform_with_canvas().origin - Vector2(0, LIFT)
	var image := root.get_texture().get_image()
	var corner := (Vector2i(centre) - CROP / 2).clamp(Vector2i.ZERO, image.get_size() - CROP)
	var crop := image.get_region(Rect2i(corner, CROP))
	crop.convert(Image.FORMAT_RGBA8)
	sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(cell * CROP.x, 0))
	var sprite: Sprite2D = game.player.get_node(^"Sprite2D")
	print("%s: %s, on floor %s, shadow visible %s, weapon pivot %s" % [label, sprite.texture.resource_path.trim_prefix("res://SampleProject/Sprites/Player/"), game.player.is_on_floor(), shadow.visible, game.player.get_node(^"WeaponMount/Pivot").visible])

func _drain() -> void:
	for i in 400:
		if not dm.is_dialogue_active():
			for f in 10: await process_frame
			if not dm.is_dialogue_active():
				return
		else:
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		await process_frame
