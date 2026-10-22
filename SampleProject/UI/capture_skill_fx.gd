extends SceneTree

## Вивільнення дев'яти активних навичок клятв (D279) у справжньому вікні DesertRoad, поряд в один рядок:
## radiant_smite, skyfall_blessing, judgement_of_the_sky, searing_hex, withering_grasp, eclipse_cleave,
## balanced_strike, dervish_whirl, second_wind → design/shots/skill_fx_all.png.
##   godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_skill_fx.gd

const OATH_ACTIVES := ["radiant_smite", "skyfall_blessing", "judgement_of_the_sky", "searing_hex", "withering_grasp",
		"eclipse_cleave", "balanced_strike", "dervish_whirl", "second_wind"]
## Вирізка навколо героя: ліворуч, вгору, розмір (екранні px).
const CROP_FROM := Vector2i(-120, -230)
const CROP_SIZE := Vector2i(320, 300)

var game: Node
var hero: Node
var target: Node


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	game.set_quest_flag("desert_road_monologue_complete", true)
	game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await create_timer(2.5).timeout
	hero = game.player
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.Max_Health = 9999
			node.current_health = 9999
			node.poise_max = 99
			node.poise = 99
			node.set_physics_process(false)
			node.detection_area.monitoring = false
			if target == null:
				target = node
			else:
				node.global_position.x = 99999  # не в кадрі
	var sm: Node = sl.get_skill_manager()
	var xp: Node = sl.get_xp_manager()
	while xp.get_level() < 20:
		xp.add_xp(1000)
	var state: Dictionary = sl.get_game_manager().player_state
	var sheet := Image.create(CROP_SIZE.x * OATH_ACTIVES.size(), CROP_SIZE.y, false, Image.FORMAT_RGBA8)
	for i in OATH_ACTIVES.size():
		var id: String = OATH_ACTIVES[i]
		var definition: Object = sm.skill_database.get_skill(id)
		state["oath"] = definition.oath
		state["unlocked_skills"] = state.get("unlocked_skills", []) + [id]
		sm.clear_cooldowns()
		sm.restore_sp(999)
		hero.current_health = hero.Max_Health - 70
		hero.global_position = target.global_position + Vector2(-40, -4)
		hero.velocity = Vector2.ZERO
		hero.mover.last_direction = 1
		for f in 12: await physics_frame
		print("cast ", id, " → ", sm.cast_skill(id))
		await create_timer(definition.cast_windup + 0.13).timeout  # release_2 — повний кадр
		await RenderingServer.frame_post_draw
		var at := Vector2i(root.get_viewport().get_canvas_transform() * hero.global_position)
		sheet.blit_rect(root.get_texture().get_image(), Rect2i(at + CROP_FROM, CROP_SIZE), Vector2i(CROP_SIZE.x * i, 0))
		await create_timer(1.5).timeout
	sheet.save_png(ProjectSettings.globalize_path("res://design/shots/skill_fx_all.png"))
	print("saved design/shots/skill_fx_all.png")
	quit(0)


func _finish_dialogue(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return
