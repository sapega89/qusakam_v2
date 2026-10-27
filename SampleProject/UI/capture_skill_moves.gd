extends SceneTree

## Навички руху (v2 зріз 3, D812) у справжньому вікні: замах, рух і удар кожної по ворогу на DesertRoad,
## один аркуш 3 × 6 вирізок 480×320 (рядок — навичка).
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_skill_moves.gd -- <тека>

const SKILLS := ["dash_strike", "shield_charge", "blood_rush", "wind_step", "heavens_anvil", "dune_quake"]
const CELL := Vector2i(480, 320)

var game: Node
var hero: Node
var sl: Node
var target: Node
var sheet: Image


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
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
			node.set_physics_process(false)
			node.detection_area.monitoring = false
			node.enemy_logic.current_state = 0
			if target == null:
				target = node
			else:
				node.global_position.x = 99999  # не в кадрі
	var sm: Node = sl.get_skill_manager()
	sm.set_max_sp(999)
	for id in SKILLS:
		sl.get_game_manager().player_state.unlocked_skills.append(id)
	sheet = Image.create(CELL.x * 3, CELL.y * SKILLS.size(), false, Image.FORMAT_RGBA8)
	for row in SKILLS.size():
		var id: String = SKILLS[row]
		var definition: Object = sm.skill_database.get_skill(id)
		sm.restore_sp(999)
		await _place(-230)
		sm.cast_skill(id)
		await create_timer(definition.cast_windup * 0.7).timeout
		await _cell(0, row)
		var State = load("res://SampleProject/Scripts/Player/Components/PlayerCombat.gd").State
		for i in 120:
			if hero.combat.state != State.CAST_WINDUP:
				break
			await physics_frame
		for i in (4 if definition.move_kind == "dash" else 14):
			await physics_frame
		await _cell(1, row)
		for i in 120:
			if hero.combat.state != State.CAST_MOVE:
				break
			await physics_frame
		for i in 3:
			await physics_frame
		await _cell(2, row)
		await create_timer(1.2).timeout
	sheet.save_png(out_dir.path_join("skill_moves_sheet.png"))
	print("sheet ", out_dir.path_join("skill_moves_sheet.png"))
	quit(0)


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


## Вирізка навколо героя й цілі в клітинку [param column], [param row] аркуша.
func _cell(column: int, row: int) -> void:
	await RenderingServer.frame_post_draw
	var at: Vector2 = root.get_viewport().get_canvas_transform() * ((hero.global_position + target.global_position) / 2.0)
	var img: Image = root.get_texture().get_image().duplicate()
	img.convert(Image.FORMAT_RGBA8)
	var rect := Rect2i(Vector2i(at) - Vector2i(240, 200), CELL).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	sheet.blit_rect(img, rect, Vector2i(column * CELL.x, row * CELL.y))
