extends SceneTree

## Навички Кусакама (D141–D147) у справжній грі: SP-запас і відновлення, нова зброя й слот mace,
## вимога зброї, ціль за D142 (усе перед героєм / союзник поруч або сам герой).
##   godot --headless --path . --script res://SampleProject/UI/verify_kusakam_skills.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return

## Союзник для «Длані»: будь-хто в групі allies з heal_damage().
class Ally extends Node2D:
	var healed := 0
	func heal_damage(amount: int) -> void:
		healed += amount

func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()  # D393: без крита й ухилення — шкода точна
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289: hints as banners, the game never pauses under a window
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
	var sl: Node = root.get_node("ServiceLocator")
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await _drain(dm)
	var sm: Node = sl.get_skill_manager()
	var R = load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd").Result
	var db: Node = sl.get_item_database()
	var rules = load("res://SampleProject/Scripts/Systems/InventorySlotRules.gd")
	var player: Node2D = game.player
	var equipment: Dictionary = sl.get_game_manager().player_state.equipment

	print("[1] New weapons and the mace slot (D143, D147)")
	ck(rules.default_slot(db.get_item("iron_halberd")) == "polearm", "halberd → polearm")
	ck(rules.default_slot(db.get_item("iron_mace")) == "mace", "mace → mace")
	ck(rules.default_slot(db.get_item("iron_dagger")) == "dagger", "dagger → dagger")
	ck(equipment.has("mace"), "player_state.equipment has a mace slot")

	print("[2] SP pool 30; it does not refill over time, hits and parries give it (D146, D504)")
	ck(sm.get_max_sp() == 30 and sm.get_current_sp() == 30, "starts with 30 / 30")
	sm.spend_sp(10)
	await create_timer(2.2).timeout
	ck(sm.get_current_sp() == 20, "no SP over time (%d)" % sm.get_current_sp())
	sm.restore_sp(30)

	print("[2b] Healing Palm is learned at the first level-up (D252, D261); strikes at level 6 for skill points (D149)")
	ck(not sm.is_unlocked("healing_palm") and sm.get_equipped_skill(0) == "", "no skills at New Game")
	ck(sm.can_unlock("healing_palm") == R.LEVEL_TOO_LOW, "Healing Palm locked at level 1")
	var xp: Node = sl.get_xp_manager()
	xp.add_xp(100)
	ck(xp.get_level() == 2 and sm.can_unlock("healing_palm") == R.OK, "level 2: Healing Palm can be learned (level %d)" % xp.get_level())
	await create_timer(4.0).timeout
	var hint: Node = get_first_node_in_group(&"tutorial_hint_display")
	ck(hint.is_showing and hint.current_hint == "healing_palm" and hint.hint_label.text.contains("Healing Palm"),
			"the level-up hint asks to learn Healing Palm (%s)" % hint.current_hint)
	await create_timer(5.0).timeout
	ck(hint.is_showing and hint.current_hint == "healing_palm", "…and stays until it is learned")
	# Як гравець: Esc → Skills, клік по вузлу Healing Palm, Enter (позначити), Accept (D330).
	game.set_quest_flag("village_oldman_healed", true)  # вкладку Skills відкриває сюжет
	root.size = Vector2i(1920, 1080)  # headless-вікно 64×64 — клік мимо меню
	var ui: Node = sl.get_ui_manager()
	ui.open_game_menu()
	for i in 16: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Skills")
	for i in 8: await process_frame
	var skills_tab: Node = menu.find_child("SkillsComponent", true, false)
	var row: Control = skills_tab._rows["healing_palm"]
	var at: Vector2 = row.get_global_rect().get_center()
	var vp: Viewport = row.get_viewport()  # рядок перебудовується, щойно навичку вивчено
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	vp.push_input(motion)
	await process_frame
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.position = at
		click.global_position = at
		vp.push_input(click)
		await process_frame
	ck(skills_tab._selected_id == "healing_palm", "clicking the row selects Healing Palm (%s)" % skills_tab._selected_id)
	for down in [true, false]:
		var enter := InputEventAction.new()
		enter.action = &"ui_accept"
		enter.pressed = down
		vp.push_input(enter)
		await process_frame
	ck(not sm.is_unlocked("healing_palm") and skills_tab.plan.skill_picks("healing_palm") == 1, "Enter only picks it (D330)")
	for down in [true, false]:
		var accept := InputEventAction.new()
		accept.action = &"skills_accept"
		accept.pressed = down
		vp.push_input(accept)
		await process_frame
	ck(sm.is_unlocked("healing_palm") and sm.get_rank("healing_palm") == 1, "Accept learns it, rank 1")
	ck(sm.get_equipped_skill(0) == "healing_palm", "a learned active skill goes on the first free hotbar slot (%s)" % sm.get_equipped_skill(0))
	ck(not hint.is_showing, "the hint goes away once Healing Palm is learned")
	ui.close_game_menu()
	for i in 8: await process_frame
	ck(sm.can_unlock("fire_strike") == R.LEVEL_TOO_LOW, "Fire Strike locked below level 6")
	var jp_before: int = sm.get_job_points()
	var level_before: int = xp.get_level()
	while xp.get_level() < 6:
		xp.add_xp(1000)
	var gained: int = xp.get_level() - level_before
	ck(sm.get_job_points() - jp_before == gained, "1 skill point per level, D279 (%d for %d levels)" % [sm.get_job_points() - jp_before, gained])
	ck(sm.unlock_skill("fire_strike") == R.OK and sm.unlock_skill("electric_strike") == R.OK, "both strikes learned at level 6")
	ck(sm.get_job_points() - jp_before == gained - 2, "1 point each")

	print("[3] Healing Palm: an ally next to you, else yourself (D142)")
	player.take_damage(90)
	var hp: int = player.current_health
	var palm_heal: int = sm.skill_heal("healing_palm")  # B137: 25 + Elem. Atk.
	ck(sm.use_skill("healing_palm") == R.OK, "usable with no ally around")
	ck(player.current_health == hp + palm_heal, "healed yourself by %d (%d → %d)" % [palm_heal, hp, player.current_health])
	sm.clear_cooldowns()
	var ally := Ally.new()
	ally.add_to_group(&"allies")
	game.map.add_child(ally)
	ally.global_position = player.global_position + Vector2(30, 0)
	hp = player.current_health
	ck(sm.use_skill("healing_palm") == R.OK, "usable next to an ally")
	ck(ally.healed == palm_heal and player.current_health == hp, "the ally is healed, not you")
	ally.queue_free()
	sm.clear_cooldowns()

	print("[4] Strikes need the right weapon (D141)")
	for slot in equipment.keys():
		equipment[slot] = null
	var state: Dictionary = sl.get_game_manager().player_state
	state.weapon_in_hand = ""
	ck(sm.can_use_skill("fire_strike") == R.WRONG_WEAPON, "Fire Strike refused bare-handed")
	# D202: навички дивляться на зброю в руці. Вдягаємо справжнім шляхом (EquipmentManager → CharacterManager).
	var em: Node = sl.get_equipment_manager()
	var hero: String = sl.get_game_manager().get_active_character().character_id
	em.equip_item(hero, "dagger", "iron_dagger", db.get_item("iron_dagger"))
	ck(state.weapon_in_hand == "dagger", "equipping a weapon with empty hands draws it (%s)" % state.weapon_in_hand)
	ck(sm.can_use_skill("fire_strike") == R.OK, "Fire Strike with a dagger in hand")
	ck(sm.can_use_skill("electric_strike") == R.WRONG_WEAPON, "Electric Strike refused with a dagger")
	em.equip_item(hero, "mace", "iron_mace", db.get_item("iron_mace"))
	ck(state.weapon_in_hand == "mace" and sm.can_use_skill("electric_strike") == R.OK, "equipping the mace draws it: Electric Strike works (D475)")
	ck(sm.can_use_skill("fire_strike") == R.WRONG_WEAPON, "…and Fire Strike does not")
	em.equip_item(hero, "dagger", "iron_dagger", db.get_item("iron_dagger"))
	ck(state.weapon_in_hand == "dagger", "equipping the dagger again draws it back (%s)" % state.weapon_in_hand)

	print("[5] Strikes hit everything in front, nothing behind (D142)")
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _drain(dm)
	await create_timer(2.5).timeout
	var enemies: Array = []
	for n in game.map.find_children("*", "CharacterBody2D", true, false):
		if n.is_in_group(&"enemies"):
			n.set_physics_process(false)
			enemies.append(n)
	ck(enemies.size() >= 2, "enemies on the road (%d)" % enemies.size())
	player = game.player
	player.mover.last_direction = 1
	var front: Node2D = enemies[0]
	var behind: Node2D = enemies[1]
	player.global_position = Vector2(1000, 344)
	front.global_position = player.global_position + Vector2(30, 0)
	behind.global_position = player.global_position + Vector2(-40, 0)
	for e in enemies:  # B137: навички б'ють від атаки героя — щоб ніхто не загинув за тест
		e.Max_Health = 10000
		e.current_health = 10000
	for i in 3: await physics_frame
	var hp_front: int = front.current_health
	var hp_behind: int = behind.current_health
	ck(sm.use_skill("fire_strike") == R.OK, "Fire Strike lands")
	var fire_damage: int = sm.skill_damage("fire_strike")
	ck(fire_damage > sl.get_game_manager().calculate_physical_damage(), "B137: Fire Strike hits harder than a light swing (%d)" % fire_damage)
	ck(front.current_health == hp_front - fire_damage, "front enemy -%d (%d → %d)" % [fire_damage, hp_front, front.current_health])
	ck(behind.current_health == hp_behind, "enemy behind untouched")
	sm.clear_cooldowns()
	# Усіх ворогів — геть: тіла проходять крізь гравця (D197), і ворог зі спавну на x 1000 лишився б попереду.
	for e in enemies:
		e.global_position = player.global_position + Vector2(-400, 0)
	front.global_position = player.global_position + Vector2(400, 0)
	ck(sm.use_skill("fire_strike") == R.NO_TARGET, "nothing in front → NO_TARGET, no SP spent")

	print("[6] Ranks up to 5 for an active, +15% each from the data (D674)")
	sm.add_job_points(5)
	ck(sm.upgrade_skill("fire_strike") == R.OK and sm.get_rank("fire_strike") == 2, "Fire Strike → rank 2")
	ck(sm.scaled("fire_strike", 20) == 23, "rank 2 deals 23")
	ck(sm.upgrade_skill("healing_palm") == R.OK and sm.scaled("healing_palm", 40) == 46, "Healing Palm upgrades too: 40 → 46")
	sm.clear_cooldowns()
	front.global_position = player.global_position + Vector2(30, 0)
	hp_front = front.current_health
	sm.use_skill("fire_strike")
	ck(front.current_health == hp_front - sm.skill_damage("fire_strike") and sm.skill_damage("fire_strike") > fire_damage,
			"the upgraded strike lands harder (%d → %d)" % [fire_damage, hp_front - front.current_health])
	sl.get_game_manager().player_state.skill_ranks["fire_strike"] = 5
	ck(sm.can_upgrade("fire_strike") == R.MAX_RANK, "rank 5 is the cap")
	ck(sm.scaled("fire_strike", 20) == 32, "rank 5 = ×1.6")

	print("[7] Fire Strike sets the target burning: 4/s for 3 s (D207)")
	state.skill_ranks.erase("fire_strike")
	sm.clear_cooldowns()
	sm.restore_sp(100)
	for e in enemies:
		e.global_position = player.global_position + Vector2(-400, 0)
	front.global_position = player.global_position + Vector2(30, 0)
	front.set_physics_process(true)  # тики підпалу йдуть у його фізиці
	front.stun(10.0)  # стоїть на місці, поки горить
	var hp_burn: int = front.current_health
	ck(sm.use_skill("fire_strike") == R.OK, "Fire Strike lands again")
	await create_timer(3.4).timeout
	ck(front.current_health == hp_burn - fire_damage - 12, "%d from the strike + 3 burn ticks of 4 (%d → %d)" % [fire_damage, hp_burn, front.current_health])
	ck(front.burn_left <= 0.0, "the burn is over after 3 s")

	print("[8] Electric Strike jumps to a neighbour and stuns, cancelling a wind-up (D207)")
	em.equip_item(hero, "mace", "iron_mace", db.get_item("iron_mace"))
	ck(state.weapon_in_hand == "mace", "mace in hand (%s)" % state.weapon_in_hand)
	sm.clear_cooldowns()
	sm.restore_sp(100)
	var second: Node2D = enemies[1]
	var far: Node2D = enemies[2]
	front.enemy_logic.stun_left = 0.0
	front.global_position = player.global_position + Vector2(30, 0)
	second.global_position = front.global_position + Vector2(90, 0)  # поза зоною удару, у 120 px ланцюга
	far.global_position = front.global_position + Vector2(300, 0)
	var player_hits: Array = []
	player.damage_token.connect(func(d: int) -> void: player_hits.append(d))
	front.enemy_logic.last_direction = -1
	front.enemy_logic.perform_attack()  # замах на героя
	await create_timer(0.1).timeout
	var hp_f: int = front.current_health
	var hp_s: int = second.current_health
	var hp_far: int = far.current_health
	ck(sm.use_skill("electric_strike") == R.OK, "Electric Strike lands")
	var shock: int = sm.skill_damage("electric_strike")
	ck(front.current_health == hp_f - shock, "first target -%d (%d → %d)" % [shock, hp_f, front.current_health])
	ck(second.current_health == hp_s - roundi(shock * 0.5), "the neighbour takes 50 %% = %d (%d → %d)" % [roundi(shock * 0.5), hp_s, second.current_health])
	ck(far.current_health == hp_far, "an enemy 300 px away is untouched")
	ck(front.enemy_logic.stun_left > 0.0 and second.enemy_logic.stun_left <= 0.0, "the struck enemy is stunned, the chained one is not")
	await create_timer(0.7).timeout
	ck(player_hits.is_empty(), "the stun cancelled the wind-up: no hit on the hero (%s)" % [player_hits])

	print("[9] Passives: Max HP is the menu's, Toughness, Shield Block (D205–D207)")
	var gm: Node = sl.get_game_manager()
	ck(player.Max_Health == gm.calculate_max_health(), "player Max HP = the menu formula (%d / %d)" % [player.Max_Health, gm.calculate_max_health()])
	var max_before: int = player.Max_Health
	sm.add_job_points(2)
	ck(sm.unlock_skill("toughness") == R.OK and player.Max_Health == max_before + 10, "Toughness: Max HP %d → %d" % [max_before, player.Max_Health])
	ck(sm.equip_skill("toughness", 0) == R.NOT_ACTIVE_SKILL, "a passive cannot go on the hotbar")
	var bare_hit: int = player.mitigated_damage(40)
	em.equip_item(hero, "shield", "iron_shield", db.get_item("iron_shield"))
	var defense: int = gm.calculate_physical_defense()
	ck(player.mitigated_damage(40) == roundi(40 * 100.0 / (100 + defense)) and player.mitigated_damage(40) < bare_hit,
			"the shield's defense %d lowers a 40 hit to %d (was %d)" % [defense, player.mitigated_damage(40), bare_hit])
	ck(player.Max_Health == gm.calculate_max_health(), "armour defense raises Max HP too (%d)" % player.Max_Health)
	ck(sm.unlock_skill("shield_block") == R.OK, "Shield Block learned")
	ck(player.mitigated_damage(40) == roundi(40 * 100.0 / (100 + defense) * 0.8), "Shield Block takes 20 %% more off (%d)" % player.mitigated_damage(40))

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
