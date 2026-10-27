extends SceneTree

## Власні ефекти дев'яти активних навичок клятв (D279, D271): у кожної активної навички skills.json → vfx зі
## своїми кадрами (жодні дві не ділять кадрів); у навичок клятв charge і release мають стільки кадрів, скільки
## каже README у Assets/FX/Skills/<id>/; каст кожної в справжній фізиці DesertRoad грає charge (1–2, далі 3–4
## по колу), потім release, і ефект дзеркалиться за поглядом героя.
##   godot --headless --path . --script res://SampleProject/UI/verify_skill_fx.gd

const SkillCastFX := preload("res://SampleProject/Scripts/FX/SkillCastFX.gd")
const OathSkillFX := preload("res://SampleProject/Scripts/FX/OathSkillFX.gd")
const OATH_ACTIVES := ["radiant_smite", "skyfall_blessing", "judgement_of_the_sky", "searing_hex", "withering_grasp",
		"eclipse_cleave", "balanced_strike", "dervish_whirl", "second_wind"]

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

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

var game: Node
var hero: Node
var sm: Node
var target: Node

func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	await process_frame
	await process_frame
	var actives: Array = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/skills.json")).skills.filter(
			func(s: Dictionary) -> bool: return s.has("vfx"))

	print("[1] Every active skill has an effect with its own frames")
	var owner_of: Dictionary = {}
	for skill in actives:
		if skill.has("move"):
			# D812: навички руху (v2 зріз 3) позичають наявні ефекти, поки арт-лінія не намалює їхні кадри
			ck(skill.vfx.get_file() == "MoveSkill.tscn", "%s: borrowed effect until its art (MoveSkill.tscn)" % skill.id)
			continue
		var frames: Array = _frame_paths(skill.id, skill.vfx)
		ck(not frames.is_empty(), "%s: %s, %d frames" % [skill.id, skill.vfx.get_file(), frames.size()])
		var shared: Array = frames.filter(func(path: String) -> bool: return owner_of.has(path))
		ck(shared.is_empty(), "%s: no frame shared with another skill %s" % [skill.id, shared.map(func(p: String) -> String: return "%s (%s)" % [p.get_file(), owner_of[p]])])
		for path in frames:
			owner_of[path] = skill.id
	ck(actives.map(func(s: Dictionary) -> String: return s.id).filter(func(id: String) -> bool: return id in OATH_ACTIVES).size() == OATH_ACTIVES.size(),
			"all 9 oath actives are active skills in skills.json")

	print("[2] charge / release frame counts match each README")
	for id in OATH_ACTIVES:
		var readme := FileAccess.get_file_as_string("res://SampleProject/Assets/FX/Skills/%s/README.md" % id)
		var fx: Node2D = _instance(id)
		for animation in [&"charge", &"release"]:
			var match := RegEx.create_from_string("%s_1–(\\d)" % animation).search(readme)
			var count: int = fx.get_node("Sprite").sprite_frames.get_frame_count(animation)
			ck(match != null and count == int(match.get_string(1)), "%s: %s has %d frames (README %s)" % [id, animation, count, match.get_string(1) if match else "?"])
		fx.free()

	print("[3] Casting each oath active plays charge, then release")
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await create_timer(2.5).timeout
	hero = game.player
	sm = sl.get_skill_manager()
	sm.awaken_skills()  # D815: DesertRoad comes after the Canyon meditation
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.set_physics_process(false)
			node.detection_area.monitoring = false
			node.poise_max = 99
			node.poise = 99
			node.Max_Health = 9999
			node.current_health = 9999
			if target == null:
				target = node
			else:
				node.global_position.x += 2000
	var xp: Node = sl.get_xp_manager()
	while xp.get_level() < 20:
		xp.add_xp(1000)
	# Клятва одна на гру (D279) — тест перемикає її в стані гравця й дає навички напряму, без очок.
	var state: Dictionary = sl.get_game_manager().player_state
	for id in OATH_ACTIVES:
		state["oath"] = sm.skill_database.get_skill(id).oath
		state["unlocked_skills"] = state.get("unlocked_skills", []) + [id]
		for facing in [1, -1]:
			await _cast(id, facing)

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()

func _instance(id: String) -> Node2D:
	var definition: Object = root.get_node("SkillDatabase").get_skill(id)
	var fx: Node2D = load(definition.vfx).instantiate()
	fx.skill = definition
	root.add_child(fx)
	return fx

## Шляхи текстур ефекту: кадри SpriteFrames спільної сцени клятв або текстури Sprite2D базових сцен.
func _frame_paths(id: String, vfx: String) -> Array:
	var fx: Node2D = _instance(id)
	var paths: Array = []
	if fx.get_script() == OathSkillFX:
		var frames: SpriteFrames = fx.get_node("Sprite").sprite_frames
		for animation in frames.get_animation_names():
			for i in frames.get_frame_count(animation):
				paths.append(frames.get_frame_texture(animation, i).resource_path)
	else:
		for sprite in fx.find_children("*", "Sprite2D", true, false):
			paths.append(sprite.texture.resource_path)
	fx.free()
	return paths

func _fx() -> Node:
	for child in hero.get_children():
		if child is SkillCastFX:
			return child
	return null

func _cast(id: String, facing: int) -> void:
	var definition: Object = sm.skill_database.get_skill(id)
	await create_timer(1.2).timeout
	sm.clear_cooldowns()
	sm.restore_sp(999)
	target.current_health = 9999
	hero.current_health = hero.Max_Health - 70
	hero.global_position = target.global_position + Vector2(-40 * facing, 0)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = facing
	await physics_frame
	await physics_frame
	var verdict: int = sm.cast_skill(id)
	var fx: Node = _fx()
	ck(verdict == 0 and fx != null and fx.get_script() == OathSkillFX and fx.phase() == &"charge" and fx.scale.x == facing,
			"%s (facing %d): the cast starts, charge plays, mirrored (verdict %d)" % [id, facing, verdict])
	if fx == null:
		return
	var sprite: AnimatedSprite2D = fx.get_node("Sprite")
	var seen: Array[int] = []
	while hero.combat.state == hero.combat.State.CAST_WINDUP:
		if seen.is_empty() or seen[-1] != sprite.frame:
			seen.append(sprite.frame)
		await process_frame
	var looped := seen.slice(0, 4) == [0, 1, 2, 3] and seen.slice(4).all(func(f: int) -> bool: return f >= 2)
	# 3–4 по колу видно, лише якщо замах довший за 5 кадрів charge (0.35 с — це рівно 1–4)
	var loop_visible: bool = definition.cast_windup > 5.0 / OathSkillFX.CHARGE_FPS
	ck(looped and (seen.size() > 4 or not loop_visible), "%s: charge 1–2 then 3–4 looping through the %.2f s wind-up %s" % [id, definition.cast_windup, seen])
	ck(is_instance_valid(fx) and fx.phase() == &"release" and sprite.frame == 0, "%s: release plays at the release" % id)
	await create_timer(definition.cast_release + 0.6).timeout
	ck(not is_instance_valid(fx), "%s: the effect is gone after the release" % id)
