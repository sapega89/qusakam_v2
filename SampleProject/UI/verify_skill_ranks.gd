extends SceneTree
const Kit = preload("res://SampleProject/UI/input_kit.gd")

## Ранги навичок (D674): дані кожної навички (rank.max / jp / bonus, slot), активні до 5, пасивки до 3, ціна рангу в JP
## з даних, сила росте з рангом (ушкодження, лікування, підпал, пасивка), ліміт дерева рахує ранги, план (SkillPlan),
## збереження, старий сейв з рангом понад межу, платне скидання повертає ранги.
##   godot --headless --path . --script res://SampleProject/UI/verify_skill_ranks.gd

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

## Місце медитації (D447) для скидання (D592): SkillManager питає лише групу save_points і поле meditating.
class MeditationSpot extends Node:
	var meditating := true

func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()  # D393: без крита й ухилення — числа точні
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
	Kit.pre_d815_hero(self)  # D815: this test buys skills and counts JP from a hero who has none
	var sm: Node = sl.get_skill_manager()
	var xp: Node = sl.get_xp_manager()
	var gm: Node = sl.get_game_manager()
	var db: Node = root.get_node("SkillDatabase")
	var R = load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd").Result

	print("[1] Every skill carries its rank data and its cell (skills.json)")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/skills.json"))
	var no_block: Array = raw.skills.filter(func(e: Dictionary) -> bool: return not e.has("rank") or not e.has("slot"))
	ck(no_block.is_empty(), "all %d skills have rank and slot %s" % [raw.skills.size(), no_block.map(func(e): return e.id)])
	var wrong_cap: Array = db.get_all_skills().filter(func(d: SkillDefinition) -> bool:
			return d.max_rank != (5 if d.is_active() else 3) or d.rank_jp < 1 or d.rank_bonus <= 0.0)
	ck(wrong_cap.is_empty(), "actives rank to 5, passives to 3, every rank costs ≥ 1 JP and adds power %s" % [wrong_cap.map(func(d): return d.id)])
	var cells := {}
	var clashes: Array = []
	var not_under: Array = []
	for d: SkillDefinition in db.get_all_skills():
		var key := "%s:%d:%d" % [d.oath, d.slot.x, d.slot.y]
		if cells.has(key) or d.slot.x < 0 or d.slot.x >= UITokens.SKILL_GRID_COLUMNS or d.slot.y < 0 or d.slot.y >= UITokens.SKILL_GRID_ROWS:
			clashes.append(d.id)
		cells[key] = d.id
		for p: String in d.prerequisites:
			var parent: SkillDefinition = db.get_skill(p)
			if parent.oath == d.oath and parent.slot.y != d.slot.y - 1:
				not_under.append(d.id)
	ck(clashes.is_empty(), "one skill per cell, inside the 4 × 5 grid %s" % [clashes])
	ck(not_under.is_empty(), "each skill sits in the row right under its prerequisite in the same tree %s" % [not_under])

	print("[2] Rank-ups cost the skill's rank JP and stop at its top rank")
	while xp.get_level() < 14:
		xp.add_xp(xp.xp_for_next_level - xp.current_xp)
	sm._forget_all()
	sm._set_job_points(40)
	ck(sm.unlock_skill("fire_strike") == R.OK and sm.get_rank("fire_strike") == 1, "Fire Strike learned at rank 1")
	var jp: int = sm.get_job_points()
	for i in 4:
		ck(sm.upgrade_skill("fire_strike") == R.OK, "Fire Strike → rank %d" % (i + 2))
	ck(sm.get_rank("fire_strike") == 5 and sm.can_upgrade("fire_strike") == R.MAX_RANK, "an active stops at rank 5")
	ck(sm.get_job_points() == jp - 4 * db.get_skill("fire_strike").rank_jp, "each rank cost %d JP" % db.get_skill("fire_strike").rank_jp)
	ck(sm.unlock_skill("toughness") == R.OK and sm.upgrade_skill("toughness") == R.OK and sm.upgrade_skill("toughness") == R.OK
			and sm.can_upgrade("toughness") == R.MAX_RANK, "a passive stops at rank 3")
	ck(sm.unlock_skill("keen_edge") == R.MISSING_PREREQUISITE and sm.unlock_skill("weapon_training") == R.OK, "prerequisites still hold")
	ck(sm.unlock_skill("keen_edge") == R.OK, "Keen Edge after Weapon Training")
	jp = sm.get_job_points()
	ck(db.get_skill("keen_edge").rank_jp == 2 and sm.upgrade_skill("keen_edge") == R.OK and sm.get_job_points() == jp - 2, "a 2-JP skill's rank costs 2 JP (data)")
	ck(sm.tree_spent("") == 1 + 4 + 1 + 2 + 1 + 2 + 2, "the base tree's spend counts the ranks at their price (%d)" % sm.tree_spent(""))
	ck(sm.spent_points() == sm.tree_spent(""), "spent_points the same")

	print("[3] Each rank raises the effect by the skill's bonus")
	var fire: SkillDefinition = db.get_skill("fire_strike")
	var at1: int = sm.skill_damage("fire_strike", 1)
	ck(sm.skill_damage("fire_strike", 5) == roundi(at1 * (1.0 + 4 * fire.rank_bonus)) or abs(sm.skill_damage("fire_strike", 5) - at1 * (1.0 + 4 * fire.rank_bonus)) <= 1.0,
			"damage at rank 5 = rank 1 × (1 + 4 × %.2f): %d → %d" % [fire.rank_bonus, at1, sm.skill_damage("fire_strike", 5)])
	ck(sm.scaled("fire_strike", fire.burn_dps) > fire.burn_dps, "the burn grows with the rank (%d → %d)" % [fire.burn_dps, sm.scaled("fire_strike", fire.burn_dps)])
	var tough: SkillDefinition = db.get_skill("toughness")
	ck(is_equal_approx(sm.passive_value("max_health"), tough.passive_value * (1.0 + 2 * tough.rank_bonus)),
			"Toughness rank 3 = +%d max HP" % roundi(sm.passive_value("max_health")))
	ck(sm.unlock_skill("healing_palm") == R.OK and sm.upgrade_skill("healing_palm") == R.OK
			and sm.skill_heal("healing_palm", 2) > sm.skill_heal("healing_palm", 1), "healing grows with the rank")
	var tip: Dictionary = load("res://SampleProject/Scripts/Systems/SkillTooltip.gd").data(sm, "toughness")
	ck(tip.max_rank == 3 and tip.next.is_empty(), "the tooltip knows the top rank")

	print("[4] Ranks survive a save; an old save over the cap is fitted and refunded")
	var pdm = root.get_node("SaveSystem").player_data_module
	var snap: Dictionary = pdm.save()
	gm.player_state["skill_ranks"] = {}
	pdm.load_data(snap)
	ck(sm.get_rank("fire_strike") == 5 and sm.get_rank("toughness") == 3 and sm.get_rank("keen_edge") == 2, "ranks back after load")
	jp = sm.get_job_points()
	var old: Dictionary = snap.duplicate(true)
	old.skill_ranks["fire_strike"] = 12  # сейв часів D150: ранги до 20 по 1 JP
	pdm.load_data(old)
	ck(sm.get_rank("fire_strike") == 5 and sm.get_job_points() == jp + 7, "rank 12 → 5, 7 JP refunded (%d → %d)" % [jp, sm.get_job_points()])

	print("[5] The paid respec refunds the ranks (D628)")
	var spot := MeditationSpot.new()
	spot.add_to_group(&"save_points")
	root.add_child(spot)
	var spent: int = sm.spent_points()
	jp = sm.get_job_points()
	sl.get_inventory_manager().add_coins(sm.respec_price())
	ck(sm.respec() == R.OK and sm.get_job_points() == jp + spent and sm.get_rank("fire_strike") == 0, "respec gives back %d JP, ranks included" % spent)
	spot.queue_free()

	print("[6] The plan prices ranks from the data (D330)")
	ck(sm.unlock_skill("weapon_training") == R.OK and sm.unlock_skill("keen_edge") == R.OK, "Keen Edge learned again")
	var plan = load("res://SampleProject/Scripts/Systems/SkillPlan.gd").new(sm, sl.get_attribute_manager())
	ck(plan.pick("keen_edge") == R.OK and plan.jp_cost() == 2, "a planned Keen Edge rank costs 2 JP")
	ck(plan.pick("keen_edge") == R.OK and plan.jp_cost() == 4 and plan.pick("keen_edge") == R.MAX_RANK, "and the plan stops at rank 3")
	plan.clear()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
