extends SceneTree

## Клятва в місті (BACKLOG 22, D280–D282): три хранителі стоять у City, меню справжнім вводом (геймпад і клавіша E),
## рівень 5, підтвердження «I swear… / Not yet», клятва назавжди, скидання навичок за монети.
##   godot --headless --path . --script res://SampleProject/UI/verify_oath.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _drain(dm: Node) -> void:
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

func _pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
	await process_frame

func _key_e() -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		ev.keycode = KEY_E
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
	await process_frame

func _labels(keeper: Node) -> Array:
	return keeper.npc_menu.get_children().map(func(b): return b.text)

## Гравець підходить до хранителя зліва.
func _approach(player: Node2D, keeper: Node2D) -> void:
	player.global_position = keeper.global_position + Vector2(-24, -10)
	for i in 10: await physics_frame

## Y — відкрити / вибрати, D-pad вниз — наступний пункт.
func _choose(keeper: Node, index: int) -> void:
	for i in index:
		await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_Y)

func _initialize() -> void:
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await _drain(dm)
	game.teleport_to_room("res://SampleProject/Maps/City.tscn", ^"SavePoint")
	for i in 20: await physics_frame
	await _drain(dm)
	var sm: Node = sl.get_skill_manager()
	var xp: Node = sl.get_xp_manager()
	var player: Node2D = game.player

	print("[1] Three oath keepers stand in the City (D281)")
	var priest: Node2D = game.map.get_node("OathPriest")
	var witch: Node2D = game.map.get_node("OathWitch")
	var dervish: Node2D = game.map.get_node("OathDervish")
	ck([priest.oath_id, witch.oath_id, dervish.oath_id] == ["paladin", "dark_knight", "warden"], "priest → Paladin, witch → Dark Knight, dervish → Warden")
	for keeper in [priest, witch, dervish]:
		var sprite: Sprite2D = keeper.get_node("Sprite2D")
		ck(sprite.hframes == 2 and sprite.vframes == 2 and sprite.texture.get_size() == Vector2(128, 192), "%s: generated sheet, profile + front (D243)" % keeper.name)
		ck(keeper.get_node("AnimationPlayer").current_animation == "idle" and sprite.frame >= 2, "%s stands in the front view" % keeper.name)
	ck(priest.global_position.x > game.map.get_node("Blacksmith").global_position.x, "east of the Blacksmith")

	print("[2] Below level 5 the oath waits (pad)")
	ck(xp.get_level() < 5, "hero below level 5 (%d)" % xp.get_level())
	await _approach(player, priest)
	await _pad(JOY_BUTTON_Y)
	ck(priest.npc_menu.visible and _labels(priest) == ["Talk", "Swear the oath"], "menu: %s" % [_labels(priest)])
	ck(priest.get_node("AnimationPlayer").current_animation == "talk" and priest.get_node("Sprite2D").frame < 2, "turns to profile while the menu is open")
	await _choose(priest, 1)
	ck(priest.npc_menu.visible and _labels(priest) == ["Come back at level 5"], "the oath asks for level 5: %s" % [_labels(priest)])
	await _pad(JOY_BUTTON_Y)
	ck(not priest.npc_menu.visible and sm.get_oath() == "", "closed, no oath")
	ck(priest.get_node("AnimationPlayer").current_animation == "idle", "back to the front view")

	print("[3] At level 5: the choice, Not yet, then the oath (key E + pad)")
	while xp.get_level() < 5:
		xp.add_xp(xp.xp_for_next_level - xp.current_xp)
	await _key_e()
	await _choose(priest, 1)
	ck(_labels(priest) == ["I swear: Paladin (permanent)", "Not yet"], "the confirm: %s" % [_labels(priest)])
	await _choose(priest, 1)
	ck(not priest.npc_menu.visible and sm.get_oath() == "", "Not yet changes nothing")
	await _pad(JOY_BUTTON_Y)
	await _choose(priest, 1)
	await _choose(priest, 0)
	ck(sm.get_oath() == "paladin" and sm.class_title() == "Paladin", "sworn: Paladin")
	ck(dm.is_dialogue_active(), "the priest answers the oath")
	await _drain(dm)
	ck(priest.talk_dialogue.ends_with("City_Oath_Priest_Sworn.dqd"), "the priest's Talk now speaks of the sworn oath")

	print("[4] The oath is permanent; respec for coins at another keeper (D282)")
	sm.add_job_points(3)
	sm.unlock_skill("toughness")
	sm.unlock_skill("radiant_smite")
	await _approach(player, witch)
	await _pad(JOY_BUTTON_Y)
	var price: int = sm.respec_price()
	ck(_labels(witch) == ["Talk", "Unlearn skills (%d coins)" % price], "no oath entry after an oath, respec offered: %s" % [_labels(witch)])
	var inv: Node = sl.get_inventory_manager()
	inv.spend_coins(inv.get_coins())
	await _choose(witch, 1)
	ck(_labels(witch) == ["Not enough coins (%d needed)" % price], "no coins: %s" % [_labels(witch)])
	await _pad(JOY_BUTTON_Y)
	inv.add_coins(price)
	var jp: int = sm.get_job_points()
	await _pad(JOY_BUTTON_Y)
	await _choose(witch, 1)
	ck(_labels(witch) == ["Forget every skill for %d coins" % price, "Not yet"], "the confirm: %s" % [_labels(witch)])
	await _choose(witch, 0)
	ck(sm.get_unlocked_skills().is_empty() and sm.get_job_points() == jp + 2 and inv.get_coins() == 0, "skills forgotten, 2 points back, coins paid")
	ck(sm.get_oath() == "paladin", "the oath stays")

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
