extends SceneTree

## Клятва (D280; D725–D728, oath_affinity_plan): троє жерців шляхів стоять у City звичайними NPC — лише розмова,
## меню клятви немає (D726); жрець контрактів — у чорному й золоті замість відьми. Клятву дає перепис біля брами
## (verify_oath_census) за будь-якого рівня; дерево відкривається з 5-го. Клятва назавжди; сейв із клятвою її тримає,
## сейв без нахилів — нулі.
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

## Меню відкрите саме (D454); Y — вибрати, D-pad вниз — наступний пункт.
func _choose(keeper: Node, index: int) -> void:
	for i in index:
		await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_Y)

func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
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
	await game.teleport_to_room("res://SampleProject/Maps/City.tscn", ^"SavePoint")
	for i in 20: await physics_frame
	await _drain(dm)
	var sm: Node = sl.get_skill_manager()
	var xp: Node = sl.get_xp_manager()
	var player: Node2D = game.player

	print("[1] Three path priests stand in the City (D726)")
	var priest: Node2D = game.map.get_node("OathPriest")
	var witch: Node2D = game.map.get_node("OathWitch")
	var dervish: Node2D = game.map.get_node("OathDervish")
	ck([priest.oath_id, witch.oath_id, dervish.oath_id] == ["paladin", "dark_knight", "warden"], "priestess of Samal → Paladin, priest of contracts → Dark Knight, dervish → Warden")
	for keeper in [priest, witch, dervish]:
		var sprite: Sprite2D = keeper.get_node("Sprite2D")
		ck(sprite.vframes == 3 and sprite.texture.get_size() == Vector2(64 * sprite.hframes, 288), "%s: generated sheet, profile + front + activity (D243, D295)" % keeper.name)
		var idle: Animation = keeper.get_node("AnimationPlayer").get_animation(&"idle")
		ck(range(idle.track_get_key_count(0)).all(func(k: int) -> bool: return int(idle.track_get_key_value(0, k)) / sprite.hframes == 1), "%s rests in the front view" % keeper.name)
	ck((witch.get_node("Sprite2D") as Sprite2D).texture.resource_path.ends_with("contract_priest/sheet.png"), "the witch's place: the priest of contracts in black and gold")
	ck(root.get_node("DialogueQuest").CharacterDB.get_character_from_id("OATH_WITCH").character_name == "Priest of contracts", "and his name")
	ck(priest.global_position.x > game.map.get_node("Blacksmith").global_position.x, "east of the Blacksmith")

	print("[2] No oath menu: they only talk about their path (pad)")
	await _approach(player, priest)
	ck(priest.npc_menu.visible and _labels(priest) == ["Talk"], "walking up opens her menu (D454) with Talk only: %s" % [_labels(priest)])
	ck(priest.quest_marker() == &"", "no crest over her")
	ck(priest.get_node("AnimationPlayer").current_animation == "talk" and priest.get_node("Sprite2D").frame < 2, "turns to profile while the menu is open")
	await _choose(priest, 0)
	ck(dm.is_dialogue_active() and sm.get_oath() == "", "Talk: she speaks of Samal; no oath comes of it")
	await _drain(dm)
	for keeper in [witch, dervish]:
		await _approach(player, keeper)
		ck(_labels(keeper) == ["Talk"], "%s: Talk only (%s)" % [keeper.name, _labels(keeper)])
	ck(FileAccess.get_file_as_string("res://SampleProject/Scripts/Gameplay/NPCs/OathKeeper.gd").find("swear_oath") == -1, "OathKeeper.gd swears nothing")
	player.global_position = priest.global_position + Vector2(-400, -10)
	for i in 10: await physics_frame
	ck(not priest.npc_menu.visible and priest.get_node("AnimationPlayer").current_animation == "work", "the hero walks off: menu closed, back to her prayer (D295)")

	print("[3] The oath at any level (the census); the tree opens at level 5")
	ck(xp.get_level() < 5, "hero below level 5 (%d)" % xp.get_level())
	ck(sm.swear_oath("paladin") == 0 and sm.get_oath() == "paladin" and sm.class_title() == "Paladin", "sworn below level 5: Paladin")
	ck(sm.can_unlock("radiant_smite") == load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd").Result.LEVEL_TOO_LOW, "its skills wait for level 5")
	while xp.get_level() < 5:
		xp.add_xp(xp.xp_for_next_level - xp.current_xp)
	sm.add_job_points(5)
	for id in ["toughness", "shield_block", "devotion"]:  # D497: навичка клятви — від 3 JP у стовбурі
		sm.unlock_skill(id)
	ck(sm.can_unlock("radiant_smite") == 0, "at level 5 the Paladin tree opens")
	ck(priest.talk_dialogue.ends_with("City_Oath_Priest_Sworn.dqd") and witch.talk_dialogue.ends_with("City_Oath_Witch_Talk.dqd"), "the priestess now speaks to one of her path; the others as before")

	print("[4] The oath is permanent; respec is at a meditation spot (D592)")
	ck(sm.swear_oath("warden") == load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd").Result.OATH_SWORN and sm.get_oath() == "paladin", "a second oath is refused")
	sm.unlock_skill("radiant_smite")
	sl.get_inventory_manager().add_coins(sm.respec_price())
	ck(sm.respec() == load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd").Result.NOT_MEDITATING and sm.get_unlocked_skills().size() == 4, "a respec away from a meditation spot is refused")

	print("[5] Saves: an old save with an oath keeps it; leanings are saved, an old save has none")
	var pdm = root.get_node("SaveSystem").player_data_module
	sm.leanings.add("samal", 4.0)
	var snap: Dictionary = pdm.save()
	ck(snap.oath == "paladin" and is_equal_approx(float(snap.leanings.samal), 4.0), "saved: the oath and the leanings")
	var old: Dictionary = snap.duplicate(true)
	old.erase("leanings")
	sl.get_game_manager().player_state.oath = ""
	pdm.load_data(old)
	ck(sm.get_oath() == "paladin", "a save from before the census keeps its oath")
	ck(sm.leanings.values().values().all(func(v: float) -> bool: return v == 0.0), "and starts with no leanings")
	pdm.load_data(snap)
	ck(is_equal_approx(sm.leanings.values().samal, 4.0), "the leanings come back with the save")

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
