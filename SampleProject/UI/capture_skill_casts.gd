extends SceneTree

## Кадри кастів навичок (BACKLOG 21, D271) і ефектів удару (D268) у справжньому вікні, вирізки 480×320 навколо героя.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_skill_casts.gd -- <тека> casts|fx_<мітка>
## casts — схована зброя, замах і вивільнення кожної навички, зірваний каст;
## fx_<мітка> — удар мечем, фінішер, важкий, влучання по ворогу й по героєві (fb21_fx_<мітка>_*.png).

var game: Node
var hero: Node
var sl: Node
var target: Node
var out_dir: String


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0]
	var mode: String = args[1]
	root.size = Vector2i(1920, 1080)
	await process_frame
	set_meta("start_new_game", true)
	sl = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue()
	game.set_quest_flag("desert_road_monologue_complete", true)
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue()
	await create_timer(2.5).timeout
	await _finish_dialogue()
	hero = game.player
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.Max_Health = 9999
			node.current_health = 9999
			node.poise_max = 99
			node.poise = 99
			node.set_physics_process(false)
			node.detection_area.monitoring = false
			node.enemy_logic.current_state = 0
			if target == null:
				target = node
			else:
				node.global_position.x = 99999  # не в кадрі
	var who: String = sl.get_game_manager().get_active_character().character_id
	var em: Node = sl.get_equipment_manager()
	var items: Node = sl.get_item_database()
	em.equip_item(who, "sword", "iron_sword", items.get_item("iron_sword"))
	if mode == "casts":
		await _casts(em, who, items)
	else:
		await _fx(mode)
	quit(0)


func _casts(em: Node, who: String, items: Node) -> void:
	var sm: Node = sl.get_skill_manager()
	var xp: Node = sl.get_xp_manager()
	while xp.get_level() < 6:
		xp.add_xp(1000)
	for id in ["healing_palm", "fire_strike", "electric_strike"]:
		sm.unlock_skill(id)
	em.equip_item(who, "mace", "iron_mace", items.get_item("iron_mace"))

	await _place(-110)
	await create_timer(3.5).timeout
	await _shot("fb21_sheathed_hidden")

	for cast in [["healing_palm", "sword", "palm"], ["fire_strike", "sword", "fire"], ["electric_strike", "mace", "storm"]]:
		var definition: Object = sm.skill_database.get_skill(cast[0])
		while em.get_weapon_in_hand() != cast[1]:
			await _press(&"weapon_next")
		sm.clear_cooldowns()
		sm.restore_sp(999)
		hero.current_health = hero.Max_Health - 50
		await _place(-70)
		await _press(StringName("skill_slot_%d" % (sm.get_slot_of_skill(cast[0]) + 1)))
		await create_timer(definition.cast_windup * 0.7).timeout
		await _shot("fb21_%s_windup" % cast[2])
		await create_timer(definition.cast_windup * 0.3 + 0.12).timeout
		await _shot("fb21_%s_release" % cast[2])
		await create_timer(1.5).timeout

	while em.get_weapon_in_hand() != "sword":
		await _press(&"weapon_next")
	sm.clear_cooldowns()
	sm.restore_sp(999)
	await _place(-50)
	await _press(StringName("skill_slot_%d" % (sm.get_slot_of_skill("fire_strike") + 1)))
	await create_timer(0.15).timeout
	hero.take_damage(5, target)
	await create_timer(0.06).timeout
	await _shot("fb21_interrupt")


func _fx(label: String) -> void:
	var prefix := "fb21_" + label + "_"
	target.enemy_logic.current_state = 1
	await create_timer(0.5).timeout
	target.enemy_logic.current_state = 0
	await _place(-40)
	await _press(&"attack")
	await create_timer(0.1).timeout
	await _shot(prefix + "slash")
	await create_timer(0.24).timeout
	await _press(&"attack")
	await create_timer(0.32).timeout
	await _press(&"attack")
	await create_timer(0.1).timeout
	await _shot(prefix + "finisher")
	await create_timer(1.2).timeout
	await _place(-45)
	await _press(&"heavy_attack")
	await create_timer(0.47).timeout
	await _shot(prefix + "heavy")
	await create_timer(1.4).timeout
	await _place(-40)
	await _press(&"attack")
	await create_timer(0.16).timeout
	await _shot(prefix + "hit_enemy")
	await create_timer(1.0).timeout
	await _place(-45)
	hero.take_damage(10, target)
	await create_timer(0.06).timeout
	await _shot(prefix + "hit_hero")


func _finish_dialogue() -> void:
	var dm: Node = sl.get_dialogue_manager()
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return


func _place(dx: float) -> void:
	hero.global_position = target.global_position + Vector2(dx, -4)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1
	for i in 12: await physics_frame


func _press(action: StringName) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await physics_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var at: Vector2 = root.get_viewport().get_canvas_transform() * hero.global_position
	var img: Image = root.get_texture().get_image()
	var rect := Rect2i(Vector2i(at) - Vector2i(200, 200), Vector2i(480, 320)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(rect).save_png(out_dir.path_join(name + ".png"))
	print("shot ", name, " ", rect)
