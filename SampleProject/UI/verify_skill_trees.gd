extends SceneTree

## Дерева навичок і шлях класу (BACKLOG 22, D279–D285) у справжній грі: дані, одне очко за рівень,
## клятва (рівень 5, раз і назавжди), блокування чужих дерев, нові пасивки, збереження клятви, скидання за монети.
##   godot --headless --path . --script res://SampleProject/UI/verify_skill_trees.gd

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

## Ціль для удару героя: стійкість і відкидання без ворога.
class Dummy extends Node2D:
	func take_poise(_amount: int, _from_x: float) -> void:
		pass
	func nudge(_push: float) -> void:
		pass
	func knockback(_force: float) -> void:
		pass

func _level_to(xp: Node, level: int) -> void:
	while xp.get_level() < level:
		xp.add_xp(xp.xp_for_next_level - xp.current_xp)

func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()  # D393: без крита й ухилення — шкода точна
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain(sl.get_dialogue_manager())
	var sm: Node = sl.get_skill_manager()
	var xp: Node = sl.get_xp_manager()
	var gm: Node = sl.get_game_manager()
	var inv: Node = sl.get_inventory_manager()
	var db: Node = root.get_node("SkillDatabase")
	var R = load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd").Result
	var player: Node2D = game.player

	print("[1] Tree data (D279)")
	ck(db.class_name_trunk == "Holy Warrior", "trunk class is Holy Warrior")
	ck(db.oaths.keys() == ["paladin", "dark_knight", "warden"], "three oaths: %s" % [db.oaths.keys()])
	var per_tree := {"": 0, "paladin": 0, "dark_knight": 0, "warden": 0}
	var data_ok := true
	for d in db.get_all_skills():
		if not per_tree.has(d.oath):
			data_ok = false
			print("    unknown oath on ", d.id)
			continue
		per_tree[d.oath] += 1
		if d.oath != "" and d.required_level < int(db.get_oath(d.oath).level):
			data_ok = false
			print("    oath skill below the oath level: ", d.id)
		for pre in d.prerequisites:
			if not db.has_skill(pre):
				data_ok = false
				print("    missing prerequisite ", pre, " of ", d.id)
		if d.is_active():
			if d.cast_pose == "" or not ResourceLoader.exists(d.vfx):
				data_ok = false
				print("    active without a cast or effect: ", d.id)
			elif not load(d.vfx).instantiate() is Node2D:
				data_ok = false
	ck(data_ok, "every skill: known tree, level gate ≥ oath level, prerequisites exist, actives have a cast and an effect")
	ck(per_tree[""] == 8 and per_tree.paladin == 8 and per_tree.dark_knight == 8 and per_tree.warden == 8, "8 skills per tree %s" % per_tree)
	ck(db.get_skill("healing_palm").oath == "" and db.get_skill("fire_strike").oath == "", "existing skills stay in the trunk")

	print("[2] One point per level (D260)")
	_level_to(xp, 3)
	var jp0: int = sm.get_job_points()
	_level_to(xp, 4)
	ck(sm.get_job_points() - jp0 == 1, "a level gives one point (%d)" % (sm.get_job_points() - jp0))

	print("[3] The oath (D280)")
	ck(sm.get_oath() == "", "no oath at the start")
	ck(sm.class_title() == "Holy Warrior", "class title before the oath: %s" % sm.class_title())
	sm.add_job_points(20)
	ck(sm.can_unlock("radiant_smite") == R.NO_OATH, "an oath skill before the oath → NO_OATH")
	ck(sm.swear_oath("paladin") == R.LEVEL_TOO_LOW, "level 4 cannot swear")
	ck(sm.swear_oath("nobody") == R.UNKNOWN_OATH, "unknown oath rejected")
	_level_to(xp, 5)
	ck(sm.swear_oath("paladin") == R.OK, "level 5 swears the Paladin oath")
	ck(sm.get_oath() == "paladin" and sm.class_title() == "Paladin", "oath kept, title Paladin")
	ck(sm.swear_oath("warden") == R.OATH_SWORN, "the oath is permanent")
	ck(sm.can_unlock("searing_hex") == R.OTHER_OATH, "another oath's skill → OTHER_OATH")
	ck(sm.can_unlock("radiant_smite") == R.OK, "own oath's level-5 skill can be learned")
	ck(sm.can_unlock("aura_of_resolve") == R.LEVEL_TOO_LOW, "a level-8 skill waits for level 8")

	print("[4] New passive stats (D284)")
	var sp_seen := [0]
	root.get_node("EventBus").sp_changed.connect(func(_c: int, m: int) -> void: sp_seen[0] = m)
	var sp_max: int = sm.get_max_sp()
	ck(sm.unlock_skill("devotion") == R.OK and sm.get_max_sp() == sp_max + 5 and sp_seen[0] == sp_max + 5, "Devotion: +5 max SP, HUD told (%d)" % sm.get_max_sp())
	var atk: int = gm.calculate_physical_damage()
	ck(sm.unlock_skill("weapon_training") == R.OK and gm.calculate_physical_damage() == atk + 3, "Weapon Training: +3 attack")
	var hp_max: int = player.Max_Health
	ck(sm.unlock_skill("toughness") == R.OK and player.Max_Health == hp_max + 10, "Toughness: +10 max HP on the hero")
	var hurt: int = player.mitigated_damage(100)
	_level_to(xp, 8)
	ck(sm.unlock_skill("aura_of_resolve") == R.OK and player.mitigated_damage(100) < hurt, "Aura of Resolve: less damage taken (%d → %d)" % [hurt, player.mitigated_damage(100)])
	ck(sm.unlock_skill("mending_hands") == R.OK and sm.unlock_skill("healing_palm") == R.OK, "Mending Hands + Healing Palm learned")
	player.take_damage(90)
	var hp: int = player.current_health
	ck(sm.use_skill("healing_palm", player) == R.OK and player.current_health - hp == 50, "Healing Palm heals 40 × 1.25 = 50 (%d)" % (player.current_health - hp))
	# Blood Pact — чужа клятва; стат перевіряємо прямо через стан (дерево тут ні до чого).
	gm.player_state.unlocked_skills.append("blood_pact")
	player.take_damage(40)
	hp = player.current_health
	var dummy := Dummy.new()
	game.add_child(dummy)
	player.combat._on_damage_applied(dummy, 50)
	ck(player.current_health - hp == 5, "Blood Pact: a 50 hit heals 5 (%d)" % (player.current_health - hp))
	gm.player_state.unlocked_skills.erase("blood_pact")

	print("[5] The oath is saved (D280)")
	var pdm = root.get_node("SaveSystem").player_data_module
	var snap: Dictionary = pdm.save()
	gm.player_state.oath = ""
	pdm.load_data(snap)
	ck(sm.get_oath() == "paladin", "oath survives save/load")

	print("[6] Respec for coins (D282)")
	ck(sm.respec_price() == 10 * xp.get_level(), "price 10 coins × level (%d)" % sm.respec_price())
	inv.spend_coins(inv.get_coins())
	ck(sm.respec() == R.NOT_ENOUGH_COINS, "no coins → refused")
	inv.add_coins(sm.respec_price() + 7)
	sm.upgrade_skill("devotion")
	var spent: int = sm.spent_points()
	var jp_before: int = sm.get_job_points()
	var hp_before: int = player.Max_Health
	var reset_seen := [-1]
	root.get_node("EventBus").skills_reset.connect(func(n: int) -> void: reset_seen[0] = n)
	ck(spent == 1 + 1 + 1 + 1 + 1 + 0 + 1, "points spent counted with ranks (%d)" % spent)
	ck(sm.respec() == R.OK, "respec done")
	ck(sm.get_unlocked_skills().is_empty() and sm.get_equipped_skills() == ["", "", "", ""], "every skill forgotten, hotbar empty")
	ck(sm.get_job_points() == jp_before + spent and reset_seen[0] == spent, "all points back (%d)" % sm.get_job_points())
	ck(inv.get_coins() == 7, "the price was taken (%d left)" % inv.get_coins())
	ck(sm.get_oath() == "paladin", "the oath stays")
	ck(player.Max_Health == hp_before - 10, "Toughness gone from max HP")
	ck(sm.respec() == R.NOTHING_TO_RESET, "nothing learned → nothing to reset")

	print("[7] Level cap %d (D285, D488)" % xp.MAX_LEVEL)
	var jp_cap: int = sm.get_job_points()
	var from_level: int = xp.get_level()
	xp.add_xp(100000000)
	ck(xp.get_level() == xp.MAX_LEVEL, "a flood of XP stops at level %d (%d)" % [xp.MAX_LEVEL, xp.get_level()])
	ck(sm.get_job_points() - jp_cap == xp.MAX_LEVEL - from_level, "one point per level up to %d (%d)" % [xp.MAX_LEVEL, sm.get_job_points() - jp_cap])
	xp.add_xp(5000)
	ck(xp.get_level() == xp.MAX_LEVEL and xp.current_xp == 0, "XP no longer counts at %d" % xp.MAX_LEVEL)

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
