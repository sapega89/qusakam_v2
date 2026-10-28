extends SceneTree
const Kit = preload("res://SampleProject/UI/input_kit.gd")

## Правила навичок з рішень Sapega 2026-10-23 у справжній грі: сила від атаки героя (B137), SP за влучання й парирування
## без перезарядок поза ультимативними (D504), фляга Healing Palm (D504), ультимативні навички професій (D491),
## синергії, умовні пасивки й підказка (D496), ліміти дерев і пороги професій (D497), безкоштовне скидання (D490).
##   godot --headless --path . --script res://SampleProject/UI/verify_skill_rules.gd

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

func _level_to(xp: Node, level: int) -> void:
	while xp.get_level() < level:
		xp.add_xp(xp.xp_for_next_level - xp.current_xp)

## Справжній ворог (default_enemy), далеко від героя й без фізики — сам не б'є; HP вистачить на весь тест.
## Місце медитації (D447) для скидання (D592): SkillManager питає лише групу save_points і поле meditating.
class MeditationSpot extends Node:
	var meditating := false


func _make_enemy(game: Node, hp: int) -> Node:
	var enemy: Node2D = load("res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn").instantiate()
	enemy.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_melee.tres")
	game.map.add_child(enemy)
	enemy.global_position = game.player.global_position + Vector2(3000, 0)
	enemy.set_physics_process(false)
	enemy.Max_Health = hp
	enemy.current_health = hp
	return enemy

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
	Kit.pre_d815_hero(self)  # D815: this test buys skills and counts JP from a hero who has none
	var sm: Node = sl.get_skill_manager()
	var xp: Node = sl.get_xp_manager()
	var gm: Node = sl.get_game_manager()
	var inv: Node = sl.get_inventory_manager()
	var db: Node = root.get_node("SkillDatabase")
	var bus: Node = root.get_node("EventBus")
	var R = load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd").Result
	var Tooltip = load("res://SampleProject/Scripts/Systems/SkillTooltip.gd")
	var player: Node2D = game.player
	var enemy: Node = _make_enemy(game, 100000)

	print("[1] Tree data: 10 actives and 9 passives a tab, cooldowns only on ultimates, caps and gates (D491, D496, D497, D504, D535)")
	var counts := {}
	var data_ok := true
	for d in db.get_all_skills():
		var c: Dictionary = counts.get_or_add(d.oath, {"active": 0, "passive": 0, "conditional": 0, "ultimate": 0})
		c["active" if d.is_active() else "passive"] += 1
		if d.passive_condition != "":
			c.conditional += 1
		if d.ultimate:
			c.ultimate += 1
			if d.required_level != 20 or d.cooldown < 45.0 or d.base_jp != 10 or d.oath == "":
				data_ok = false
				print("    ultimate not a level-20 oath skill with a long cooldown and the 10-JP gate: ", d.id)
		elif d.cooldown > 0.0:
			data_ok = false
			print("    cooldown on a non-ultimate: ", d.id)
		if d.oath != "" and not d.ultimate and d.base_jp != (3 if d.required_level <= 5 else 6):
			data_ok = false
			print("    profession gate is not 3 / 6: ", d.id, " ", d.base_jp)
		if d.is_active() and not d.planned and not d.synergies.size() in [1, 2]:
			data_ok = false
			print("    active without 1–2 synergies: ", d.id)
		for synergy: Dictionary in d.synergies:
			var source = db.get_skill(String(synergy.skill))
			if source == null or source.is_active() or source.oath != d.oath:
				data_ok = false
				print("    synergy source is not a passive of the same tree: ", d.id, " ← ", synergy.skill)
	ck(data_ok, "ultimates, cooldowns, gates and synergy sources are consistent")
	var trees_ok := true
	for tree in counts:
		var c: Dictionary = counts[tree]
		if c.active != 10 or c.passive != 9 or c.conditional < 2 or c.conditional > 3:
			trees_ok = false
		if c.ultimate != (0 if tree == "" else 1):
			trees_ok = false
	ck(trees_ok and counts.size() == 4, "every tree: 10 actives, 9 passives (D535), 2–3 conditional passives, one ultimate per oath %s" % counts)
	for oath in ["paladin", "dark_knight", "warden"]:
		var level_20: Array = db.get_all_skills().filter(func(d) -> bool: return d.oath == oath and d.required_level == 20)
		ck(level_20.size() == 1 and level_20[0].ultimate, "%s: level 20 holds only the ultimate (D491)" % oath)
	ck(db.get_skill("judgement_of_the_sky").ultimate and db.get_skill("eclipse_cleave").ultimate and db.get_skill("second_wind").ultimate,
			"ultimates: Judgement of the Sky, Eclipse Cleave, Second Wind")
	ck(db.tree_cap("") == 14 and db.tree_cap("paladin") == 12 and db.tree_cap("dark_knight") == 12 and db.tree_cap("warden") == 12,
			"caps re-tuned for 19 skills a tab: base 14 JP, profession 12 JP")
	for tree in ["", "paladin", "dark_knight", "warden"]:
		var full := 0
		var maxed := 0
		for d in db.get_all_skills():
			if d.oath == tree:
				full += d.jp_cost
				maxed += d.jp_cost + (d.max_rank - 1) * d.rank_jp
		ck(db.tree_cap(tree) < full and full > xp.MAX_LEVEL - 1, "tab '%s': learning all 19 costs %d JP (all at top rank %d), over its cap %d and over the %d JP of level %d"
				% [tree, full, maxed, db.tree_cap(tree), xp.MAX_LEVEL - 1, xp.MAX_LEVEL])

	print("[2] Skill power scales with Phys. Atk. and Elem. Atk. (B137)")
	_level_to(xp, 20)
	sm.add_job_points(40)
	ck(sm.unlock_skill("fire_strike") == R.OK, "Fire Strike learned")
	var items: Node = root.get_node("ItemDatabase")
	sl.get_equipment_manager().equip_item(gm.get_active_character().character_id, "sword", "iron_sword", items.get_item("iron_sword"))
	ck(gm.player_state.weapon_in_hand == "sword", "a sword in hand (Fire Strike needs it)")
	var phys: int = gm.calculate_physical_damage()
	var elem: int = gm.calculate_magic_damage()
	var fire = db.get_skill("fire_strike")
	var expected := roundi((fire.damage + fire.damage_phys * phys + fire.damage_elem * elem) * (1.0 + sm.synergy_bonus("fire_strike")))
	ck(sm.skill_damage("fire_strike") == expected, "Fire Strike = 20 + 1.3 × %d + 0.3 × %d = %d (%d)" % [phys, elem, expected, sm.skill_damage("fire_strike")])
	ck(sm.skill_damage("fire_strike") > phys, "a skill hits harder than a light swing (%d > %d)" % [sm.skill_damage("fire_strike"), phys])
	# D828: навичка — вагомий удар: кожна збудована бойова активна вже на 1-му ранзі й на 20-му рівні (де Phys. Atk. найбільший
	# щодо бази навички) б'є сильніше за всю легку серію. Заплановані (planned) — ще з попередніми числами D808.
	var combo: float = 0.0
	for share: float in load("res://SampleProject/Scripts/Player/Components/PlayerCombat.gd").COMBO_DAMAGE:
		combo += share * phys
	# D877: навичка по гарді (Shield Bash, Stone Palm — «мало шкоди HP») вагома стійкістю: збиває більше за всю легку серію
	var combat_script: GDScript = load("res://SampleProject/Scripts/Player/Components/PlayerCombat.gd")
	var combo_poise: float = combat_script.COMBO_DAMAGE.size() * combat_script.POISE_LIGHT
	var weak: Array[String] = []
	for definition in db.get_all_skills():
		if not definition.is_active() or definition.planned or definition.damage <= 0:
			continue
		if definition.control_poise_x > 0.0:
			if definition.control_poise_x * combat_script.POISE_HEAVY <= combo_poise:
				weak.append("%s guard %.1f" % [definition.id, definition.control_poise_x * combat_script.POISE_HEAVY])
		elif sm.skill_damage(definition.id, 1) <= combo:
			weak.append("%s %d" % [definition.id, sm.skill_damage(definition.id, 1)])
	ck(weak.is_empty(), "every built attack skill outhits a whole light combo, a guard skill in poise (combo %.0f HP, %.0f poise; not above it: %s)" % [combo, combo_poise, weak])
	var strength_before: int = sm.skill_damage("fire_strike")
	sl.get_attribute_manager().spend({"strength": 5})
	ck(sm.skill_damage("fire_strike") > strength_before, "more Phys. Atk. → more skill damage (%d → %d)" % [strength_before, sm.skill_damage("fire_strike")])
	var hp0: int = enemy.current_health
	sm.restore_sp(100)
	var feel: Array = []
	var on_hit := func(source: Node, _target: Node, _amount: int) -> void: feel.append(load("res://SampleProject/Scripts/Systems/VFXHooks.gd").hit_strength(source))
	bus.damage_dealt.connect(on_hit)
	ck(sm.use_skill("fire_strike", enemy) == R.OK and hp0 - enemy.current_health == sm.skill_damage("fire_strike"),
			"the hit deals the scaled damage (%d)" % (hp0 - enemy.current_health))
	bus.damage_dealt.disconnect(on_hit)
	ck(feel == [3], "a skill hit lands with the heaviest feel, like a riposte: hitstop, shake, sound (D828, strengths %s)" % [feel])
	ck(not sm.is_skill_on_cooldown("fire_strike"), "no cooldown on an ordinary skill (D504)")

	print("[3] SP from hits and parries, not over time (D504)")
	gm.player_state.current_sp = 0
	sm._process(5.0)
	ck(sm.get_current_sp() == 0, "five seconds give no SP")
	bus.damage_dealt.emit(player, enemy, 10)
	ck(sm.get_current_sp() == 2, "a landed hit gives 2 SP (%d)" % sm.get_current_sp())
	bus.player_parried.emit(enemy)
	ck(sm.get_current_sp() == 8, "a parry gives 6 SP (%d)" % sm.get_current_sp())
	bus.damage_dealt.emit(enemy, player, 10)
	ck(sm.get_current_sp() == 8, "being hit gives nothing")
	sm.restore_sp(10)
	var sp_before: int = sm.get_current_sp()
	sm.use_skill("fire_strike", enemy)
	ck(sm.get_current_sp() == sp_before - fire.sp_cost, "a skill's own hit gives no SP (%d → %d)" % [sp_before, sm.get_current_sp()])

	print("[4] Healing Palm is a flask: 3 sips, refilled on save (D504)")
	ck(sm.unlock_skill("healing_palm") == R.OK, "Healing Palm learned")
	var palm = db.get_skill("healing_palm")
	ck(palm.charges == 3 and palm.sp_cost == 0 and palm.cooldown == 0.0, "3 charges, no SP, no cooldown")
	ck(sm.get_charges("healing_palm") == 3, "the flask starts full")
	gm.player_state.current_sp = 0
	var sips := 0
	for i in 3:
		player.current_health = player.Max_Health - 60  # take_damage дав би невразливість після удару
		var hp: int = player.current_health
		if sm.use_skill("healing_palm", player) == R.OK and player.current_health > hp:
			sips += 1
	ck(sips == 3 and sm.get_charges("healing_palm") == 0, "three sips heal, with no SP (%d sips, %d left)" % [sips, sm.get_charges("healing_palm")])
	ck(sm.use_skill("healing_palm", player) == R.NO_CHARGES, "an empty flask refuses")
	var pdm = root.get_node("SaveSystem").player_data_module
	var snap: Dictionary = pdm.save()
	ck(snap.skill_charges.get("healing_palm", -1) == 0, "the charges are saved")
	bus.game_saving.emit(1)
	ck(sm.get_charges("healing_palm") == 3, "saving at a save point refills the flask")
	pdm.load_data(snap)
	ck(sm.get_charges("healing_palm") == 0, "the charges are loaded back")
	sm.refill_charges()
	var palm_heal: int = sm.skill_heal("healing_palm")
	ck(palm_heal == roundi((palm.heal + palm.heal_elem * elem) * (1.0 + sm.synergy_bonus("healing_palm"))), "the heal scales with Elem. Atk. (%d)" % palm_heal)

	print("[5] Caps and profession gates (D497)")
	ck(sm.swear_oath("paladin") == R.OK, "swore the Paladin oath at level 20")
	gm.player_state.unlocked_skills.assign(["healing_palm"])
	gm.player_state.skill_ranks = {}
	ck(sm.tree_spent("") == 0, "nothing spent in the base tree")
	ck(sm.can_unlock("radiant_smite") == R.BASE_TREE_GATE and sm.base_jp_missing("radiant_smite") == 3, "a level-5 profession skill needs 3 base JP")
	for id in ["fire_strike", "electric_strike", "toughness"]:
		sm.unlock_skill(id)
	ck(sm.tree_spent("") == 3 and sm.can_unlock("radiant_smite") == R.OK, "3 base JP open it")
	ck(sm.can_unlock("aura_of_resolve") == R.BASE_TREE_GATE and sm.base_jp_missing("aura_of_resolve") == 3, "a middle tier needs 6 (3 more)")
	for id in ["shield_block", "devotion", "weapon_training"]:
		sm.unlock_skill(id)
	ck(sm.can_unlock("aura_of_resolve") == R.OK, "6 base JP open the middle tiers")
	for id in ["radiant_smite", "skyfall_blessing", "aura_of_resolve"]:
		ck(sm.unlock_skill(id) == R.OK, "learned %s" % id)
	ck(sm.can_unlock("judgement_of_the_sky") == R.BASE_TREE_GATE and sm.base_jp_missing("judgement_of_the_sky") == 4, "the ultimate needs 10 base JP (4 more)")
	sm.unlock_skill("fortitude")
	sm.upgrade_skill("fire_strike")
	sm.upgrade_skill("fire_strike")
	ck(sm.tree_spent("") == 10 and sm.can_unlock("judgement_of_the_sky") == R.OK, "10 base JP open the ultimate")
	for i in 2:
		sm.upgrade_skill("fire_strike")
	ck(sm.can_upgrade("fire_strike") == R.MAX_RANK, "an active stops at rank 5 (D674)")
	ck(sm.upgrade_skill("fortitude") == R.OK, "Fortitude rank 2 costs its 2 JP (D674)")
	ck(sm.tree_spent("") == 14 and sm.can_upgrade("fortitude") == R.TREE_CAP, "the base tree stops at 14 JP")
	ck(sm.unlock_skill("riposte_instinct") == R.TREE_CAP, "a new skill past the cap → TREE_CAP")
	ck(sm.unlock_skill("judgement_of_the_sky") == R.OK, "Judgement of the Sky learned")
	ck(sm.tree_spent("paladin") == 6, "paladin tree: 6 JP spent (%d)" % sm.tree_spent("paladin"))
	for id in ["skys_grace", "mending_hands", "merciful_light", "zealous_answer", "consecrated_ground", "aura_of_valour"]:
		sm.unlock_skill(id)
	ck(sm.tree_spent("paladin") == 12 and sm.can_unlock("unbroken_vow") == R.TREE_CAP, "the profession tree stops at 12 JP")
	var budgets: Dictionary = sm.tree_budgets()
	ck(budgets[""].spent == 14 and budgets[""].cap == 14 and budgets.paladin.spent == 12 and budgets.paladin.cap == 12, "spent / cap per tree for the screen %s" % budgets)
	var plan = load("res://SampleProject/Scripts/Systems/SkillPlan.gd").new(sm, sl.get_attribute_manager())
	ck(plan.can_pick("mending_hands") == R.TREE_CAP, "the skill screen's plan obeys the cap")

	print("[6] The ultimate (D491)")
	sm.restore_sp(100)
	var ult = db.get_skill("judgement_of_the_sky")
	var light: int = gm.calculate_physical_damage()
	ck(sm.skill_damage("judgement_of_the_sky") >= 3 * light, "the level-20 ultimate hits far harder than a light swing (%d vs %d)" % [sm.skill_damage("judgement_of_the_sky"), light])
	var camera: Camera2D = player.get_viewport().get_camera_2d()
	var shook := [false]
	ck(sm.use_skill("judgement_of_the_sky", enemy) == R.OK, "the ultimate is used")
	for i in 6:
		await process_frame
		if camera.offset != Vector2.ZERO:
			shook[0] = true
	ck(shook[0], "the screen shakes")
	ck(sm.is_skill_on_cooldown("judgement_of_the_sky") and sm.get_remaining_cooldown("judgement_of_the_sky") > ult.cooldown - 1.0
			and ult.cooldown >= 45.0, "a long cooldown (%s s)" % ult.cooldown)
	ck(sm.use_skill("judgement_of_the_sky", enemy) == R.ON_COOLDOWN, "a second cast waits")
	ck(ult.to_dict().ultimate, "the HUD can read the ultimate flag")

	print("[7] Synergies (D496)")
	sm._process(10.0)  # вікна умовних пасивок (парирування з [3], ультимативна з [6]) закриті — множник лише від синергії
	var skyfall = db.get_skill("skyfall_blessing")
	ck(skyfall.synergies[0].skill == "mending_hands" and is_equal_approx(skyfall.synergies[0].per_rank, 0.08), "Skyfall Blessing takes Mending Hands +8 %% per rank")
	var with_one: float = sm.synergy_bonus("skyfall_blessing")
	gm.player_state.skill_ranks["mending_hands"] = 3
	ck(is_equal_approx(sm.synergy_bonus("skyfall_blessing") - with_one, 0.16), "two more ranks → +16 %% (%.2f → %.2f)" % [with_one, sm.synergy_bonus("skyfall_blessing")])
	var base_power: float = skyfall.damage + skyfall.damage_phys * gm.calculate_physical_damage() + skyfall.damage_elem * gm.calculate_magic_damage()
	ck(sm.skill_damage("skyfall_blessing") == roundi(base_power * (1.0 + sm.synergy_bonus("skyfall_blessing"))), "the synergy multiplies the damage (%d)" % sm.skill_damage("skyfall_blessing"))

	print("[8] Conditional passives (D496, D207 hook passive_value)")
	ck(is_equal_approx(sm.passive_value("heal_power"), 0.25 * 1.5), "Merciful Light is off at full HP (only Mending Hands, rank 3: +25 %% a rank, D674)")
	player.current_health = roundi(player.Max_Health * 0.2)
	ck(is_equal_approx(sm.passive_value("heal_power"), 0.25 * 1.5 + 0.4), "below 30 %% HP it adds +40 %% healing (%.2f)" % sm.passive_value("heal_power"))
	player.current_health = player.Max_Health
	sm._process(10.0)  # парирування з [3] давно минуло
	ck(is_equal_approx(sm.passive_value("skill_damage"), 0.0), "Zealous Answer is off before a parry")
	bus.player_parried.emit(enemy)
	ck(is_equal_approx(sm.passive_value("skill_damage"), 0.3), "for 4 s after a parry: skills +30 %%")
	var boosted: int = sm.skill_damage("radiant_smite")
	sm._process(4.5)
	ck(is_equal_approx(sm.passive_value("skill_damage"), 0.0) and sm.skill_damage("radiant_smite") < boosted, "the window closes (%d → %d)" % [boosted, sm.skill_damage("radiant_smite")])

	print("[9] Tooltip: current rank, next rank, synergies (D496)")
	var tip: Dictionary = Tooltip.data(sm, "skyfall_blessing")
	ck(tip.rank == 1 and tip.current.damage == sm.skill_damage("skyfall_blessing") and tip.next.damage > tip.current.damage, "rank 1 values and stronger rank-2 values")
	ck(tip.synergies.size() == 2 and tip.synergies[0].rank == 3 and is_equal_approx(tip.synergies[0].bonus, 0.24), "synergy lines with their sources' ranks")
	var text := "\n".join(tip.lines)
	ck(text.contains("Rank 1:") and text.contains("Next rank:") and text.contains("Receives bonuses from:") and text.contains("Mending Hands: +8% per rank (now +24%)"),
			"tooltip lines:\n      " + text.replace("\n", "\n      "))
	var flask_tip: Dictionary = Tooltip.data(sm, "healing_palm")
	ck("\n".join(flask_tip.lines).contains("Flask: 3 / 3 sips"), "the flask's tooltip shows its sips")
	ck("\n".join(Tooltip.data(sm, "judgement_of_the_sky").lines).contains("Ultimate · cooldown 60 s"), "the ultimate's tooltip says so")
	ck(Tooltip.effect_text(sm, db.get_skill("merciful_light"), 1) == "heals +40% (below 30% HP)", "a conditional passive names its condition (%s)" % Tooltip.effect_text(sm, db.get_skill("merciful_light"), 1))

	print("[10] Respec costs coins and needs a meditation spot (D592, D447); the oath stays (D570)")
	var spent: int = sm.spent_points()
	var jp_before: int = sm.get_job_points()
	ck(spent == 26 + 2, "points spent: 14 base + 12 paladin + 2 extra Mending Hands ranks (%d)" % spent)
	ck(sm.respec_price() == 10 * spent, "the price scales with spent JP: 10 × %d = %d coins" % [spent, sm.respec_price()])
	inv.add_coins(sm.respec_price())
	var coins: int = inv.get_coins()
	ck(sm.respec() == R.NOT_MEDITATING and sm.spent_points() == spent, "not at a meditation spot → refused")
	var spot := MeditationSpot.new()
	spot.add_to_group(&"save_points")
	game.add_child(spot)
	spot.meditating = true
	var price: int = sm.respec_price()
	ck(sm.respec() == R.OK, "meditating: respec done")
	ck(sm.get_job_points() == jp_before + spent and inv.get_coins() == coins - price, "every JP back, %d coins taken (%d JP, %d coins)" % [price, sm.get_job_points(), inv.get_coins()])
	ck(sm.get_unlocked_skills().is_empty() and sm.get_oath() == "paladin" and sl.get_attribute_manager().spent_total() == 0, "skills and attributes forgotten, the oath stays")
	ck(sm.respec() == R.NOTHING_TO_RESET, "nothing left to reset")
	ck(not sm.has_method("reset_free"), "the free reset is gone (D592 reverses D490's free respec)")
	spot.queue_free()

	print("[11] v2 draft actives: all built; a planned row is not learnable, not castable (D535)")
	var planned: Array = db.get_all_skills().filter(func(d) -> bool: return d.planned)
	# v2 зріз 3 (D812) — 6 навичок руху, зріз 4 — 4 кидки й зони, зріз 5 — 7 стійок і баффів, зріз 6a — 5 навичок контролю,
	# зріз 6б — 6 навичок контролю й добивання: запланованих не лишилось (integrate-33)
	ck(planned.is_empty(), "no planned actives left: all 28 v2 drafts are built (%s)" % [planned.map(func(d) -> String: return d.id)])
	var ranged: Array = db.get_all_skills().filter(func(d) -> bool: return d.throws() or d.leaves_zone())
	ck(ranged.map(func(d) -> String: return d.id) == ["holy_javelin", "lightspear", "hallowed_circle", "hellfire_stomp"]
			and ranged.all(func(d) -> bool: return not d.planned and d.vfx != "" and d.release_pose != "" and d.synergies.size() in [1, 2]),
			"the 4 ranged and zone skills are built: learnable, with a cast, an effect and synergies (%s)" % [ranged.map(func(d) -> String: return d.id)])
	var shaped := true
	for d in ranged:
		if (d.projectile_speed > 0.0) != d.throws() or (d.zone_radius > 0.0) != d.leaves_zone() or (d.leaves_zone() and d.zone_dps + d.zone_heal <= 0):
			shaped = false
	ck(shaped, "each throw has a speed, each zone a radius and a dps or heal")
	var control_b_built := true
	for id in ["chain_of_night", "sand_veil", "dread_howl", "radiant_flare", "night_reaper", "soul_harvest"]:
		var cb = db.get_skill(id)
		if cb.planned or cb.vfx.get_file() != "AreaSkill.tscn" or not cb.synergies.size() in [1, 2] \
				or not (cb.controls() or cb.area_hits != "" or cb.execute_below > 0.0):
			control_b_built = false
			print("    not built: ", id)
	ck(control_b_built, "the 6 control and finisher skills of slice 6b are built: learnable, a cast, an effect, synergies and their keys")
	var moves: Array = db.get_all_skills().filter(func(d) -> bool: return d.moves())
	ck(moves.map(func(d) -> String: return d.id) == ["dash_strike", "shield_charge", "heavens_anvil", "blood_rush", "wind_step", "dune_quake"]
			and moves.all(func(d) -> bool: return not d.planned and d.vfx != "" and d.synergies.size() in [1, 2]),
			"the 6 movement skills are built: learnable, with a cast, an effect and synergies (%s)" % [moves.map(func(d) -> String: return d.id)])
	var buffs: Array = db.get_all_skills().filter(func(d) -> bool: return d.is_buff())
	ck(buffs.map(func(d) -> String: return d.id) == ["battle_cry", "counter_stance", "aegis", "rally", "blood_price", "mirror_stance", "centered_breath"]
			and buffs.all(func(d) -> bool: return not d.planned and d.vfx != "" and d.release_pose != "" and d.synergies.size() in [1, 2]),
			"the 7 stances and buffs are built: learnable, with a cast, an effect and synergies (%s)" % [buffs.map(func(d) -> String: return d.id)])
	ck(buffs.filter(func(d) -> bool: return d.is_stance()).all(func(d) -> bool: return d.cast_release == d.buff_time and d.buff_time > 0.0),
			"a stance lasts its cast's release (Counter %.1f s, Mirror %.1f s)" % [db.get_skill("counter_stance").buff_time, db.get_skill("mirror_stance").buff_time])
	var controls_built := true
	for id in ["rising_slash", "ground_slam", "sweeping_arc", "shield_bash", "stone_palm"]:
		var c = db.get_skill(id)
		controls_built = controls_built and not c.planned and c.vfx.ends_with("ControlSkill.tscn") and c.release_pose != ""
		controls_built = controls_built and c.synergies.size() in [1, 2] and (c.control_launch > 0.0 or c.control_knockdown > 0.0 or c.control_poise_x > 0.0)
	ck(controls_built, "the 5 control skills are built (D877): learnable, with a cast, an effect, synergies and a control block")
	var raw: Array = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/skills.json")).skills
	ck(raw.filter(func(e: Dictionary) -> bool: return e.has("draft") or e.has("planned")).is_empty(),
			"no row keeps `draft` or `planned`: every draft became real keys")
	var unnumbered: Array = raw.filter(func(e: Dictionary) -> bool:
			return e.get("planned", false) and (not e.has("sp_cost") or e.get("draft", {}).is_empty() or not ResourceLoader.exists(e.icon)))
	ck(unnumbered.is_empty(), "every planned active has provisional SP, `draft` numbers and its icon %s" % [unnumbered.map(func(e): return e.id)])
	# Запланованих рядків у даних більше немає, а ворота D535 лишаються для наступних чернеток: перевіряємо їх на
	# Soul Harvest, на час перевірки позначеному planned (як рядок із "planned": true)
	var stand_in: SkillDefinition = db.get_skill("soul_harvest")
	stand_in.planned = true
	ck(sm.can_unlock("soul_harvest") == R.PLANNED and sm.unlock_skill("soul_harvest") == R.PLANNED and sm.get_unlocked_skills().is_empty(),
			"level 20, %d JP, sworn: a planned skill → PLANNED, nothing learned" % sm.get_job_points())
	gm.player_state.unlocked_skills.append("soul_harvest")  # навіть якщо потрапила в стан (старий сейв) — не б'є
	sm.restore_sp(100)
	ck(sm.can_use_skill("soul_harvest") == R.PLANNED and sm.cast_skill("soul_harvest") == R.PLANNED and sm.use_skill("soul_harvest", enemy) == R.PLANNED,
			"a planned skill in the state still cannot be cast or used")
	ck(sm.can_upgrade("soul_harvest") == R.PLANNED, "nor ranked up")
	gm.player_state.unlocked_skills.erase("soul_harvest")
	var plan_v2 = load("res://SampleProject/Scripts/Systems/SkillPlan.gd").new(sm, sl.get_attribute_manager())
	ck(plan_v2.can_pick("soul_harvest") == R.PLANNED, "the skill screen's plan refuses it too")
	stand_in.planned = false

	print("[12] The 5 new v2 passives work (D535)")
	ck(sm.unlock_skill("weapon_training") == R.OK, "Weapon Training learned (Keen Edge and Heavy Hand need it)")
	var crit: float = gm.calculate_critical_chance()
	ck(sm.unlock_skill("keen_edge") == R.OK and is_equal_approx(gm.calculate_critical_chance() - crit, 0.05),
			"Keen Edge: +5 %% crit (%.3f → %.3f)" % [crit, gm.calculate_critical_chance()])
	var combat = player.combat
	combat._strike_heavy()
	var heavy_poise: int = combat._poise
	ck(sm.unlock_skill("heavy_hand") == R.OK, "Heavy Hand learned")
	combat._strike_heavy()
	ck(combat._poise == roundi(heavy_poise * 1.3), "Heavy Hand: the heavy attack's poise ×1.3 (%d → %d)" % [heavy_poise, combat._poise])
	combat._set_hitbox_active(false, 1)
	for id in ["healing_palm", "fire_strike", "electric_strike", "toughness", "shield_block", "mending_hands"]:
		sm.unlock_skill(id)
	ck(sm.unlock_skill("shield_of_faith") == R.OK, "Shield of Faith learned (6 base JP, Mending Hands)")
	ck(gm.player_state.equipment.get("shield") == null, "no shield item: the shield is a block spell (Sapega 2026-10-27)")
	player.current_health = player.Max_Health - 50
	player._heal_on_block(40)
	ck(player.current_health == player.Max_Health - 40, "a held block of a 40 hit heals 10 (25 %%) without a shield item: %d" % (player.Max_Health - player.current_health))
	gm.player_state.unlocked_skills.append("embers_within")  # клятва Dark Knight — стат перевіряємо прямо через стан
	enemy.burn_left = 0.0  # Fire Strike і ультимативна з попередніх розділів могли підпалити
	enemy.current_health = enemy.Max_Health
	enemy.take_damage(100, player)
	var cold: int = enemy.Max_Health - enemy.current_health
	enemy.apply_burn(1, 5.0)
	enemy.current_health = enemy.Max_Health
	enemy.take_damage(100, player)
	ck(enemy.Max_Health - enemy.current_health == roundi(cold * 1.2), "Embers Within: a burning enemy takes +20 %% from the hero (%d → %d)" % [cold, enemy.Max_Health - enemy.current_health])
	enemy.current_health = enemy.Max_Health
	enemy.take_damage(10)
	ck(enemy.Max_Health - enemy.current_health == 10, "the burn's own tick is not boosted")
	enemy.burn_left = 0.0
	gm.player_state.unlocked_skills.erase("embers_within")
	gm.player_state.unlocked_skills.append("light_feet")  # клятва Warden
	ck(player.mover.start_roll() and is_equal_approx(player.mover.roll_length, player.mover.roll_duration * 1.2) and player.is_invulnerable,
			"Light Feet: the roll lasts 20 %% longer at the same speed (%.2f s), invulnerable" % player.mover.roll_length)
	gm.player_state.unlocked_skills.erase("light_feet")
	ck(Tooltip.effect_text(sm, db.get_skill("light_feet"), 1) == "roll +20%" and Tooltip.effect_text(sm, db.get_skill("embers_within"), 1) == "+20% damage to burning enemies",
			"the tooltip names the new stats")

	enemy.queue_free()
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
