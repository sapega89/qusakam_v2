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
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
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

	print("[2] SP pool 30, +1 per second (D146)")
	ck(sm.get_max_sp() == 30 and sm.get_current_sp() == 30, "starts with 30 / 30")
	sm.spend_sp(10)
	await create_timer(2.2).timeout
	ck(sm.get_current_sp() == 22, "regains 1 SP per second (%d)" % sm.get_current_sp())
	sm.restore_sp(30)

	print("[2b] Healing Palm comes from the old man; strikes at level 6 for skill points (D148, D149)")
	ck(not sm.is_unlocked("healing_palm") and sm.get_equipped_skill(0) == "", "no skills at New Game — the old man teaches Healing Palm")
	sm.unlock_skill("healing_palm")  # те, що робить сцена з дідом (verify_village_fight)
	sm.equip_skill("healing_palm", 0)
	ck(sm.get_rank("healing_palm") == 1, "rank 1 once learned")
	ck(sm.can_unlock("fire_strike") == R.LEVEL_TOO_LOW, "Fire Strike locked below level 6")
	var xp: Node = sl.get_xp_manager()
	var jp_before: int = sm.get_job_points()
	while xp.get_level() < 6:
		xp.add_xp(1000)
	ck(sm.get_job_points() - jp_before == 2 * (xp.get_level() - 1), "2 skill points per level (%d for %d levels)" % [sm.get_job_points() - jp_before, xp.get_level() - 1])
	ck(sm.unlock_skill("fire_strike") == R.OK and sm.unlock_skill("electric_strike") == R.OK, "both strikes learned at level 6")
	ck(sm.get_job_points() - jp_before == 2 * (xp.get_level() - 1) - 2, "1 point each")

	print("[3] Healing Palm: an ally next to you, else yourself (D142)")
	player.take_damage(40)
	var hp: int = player.current_health
	ck(sm.use_skill("healing_palm") == R.OK, "usable with no ally around")
	ck(player.current_health == hp + 40, "healed yourself by 40 — a Potion minus 10 (%d → %d)" % [hp, player.current_health])
	sm.clear_cooldowns()
	var ally := Ally.new()
	ally.add_to_group(&"allies")
	game.map.add_child(ally)
	ally.global_position = player.global_position + Vector2(30, 0)
	hp = player.current_health
	ck(sm.use_skill("healing_palm") == R.OK, "usable next to an ally")
	ck(ally.healed == 40 and player.current_health == hp, "the ally is healed, not you")
	ally.queue_free()
	sm.clear_cooldowns()

	print("[4] Strikes need the right weapon (D141)")
	for slot in equipment.keys():
		equipment[slot] = null
	ck(sm.can_use_skill("fire_strike") == R.WRONG_WEAPON, "Fire Strike refused bare-handed")
	equipment["dagger"] = "iron_dagger"
	ck(sm.can_use_skill("fire_strike") == R.OK, "Fire Strike with a dagger")
	ck(sm.can_use_skill("electric_strike") == R.WRONG_WEAPON, "Electric Strike refused with a dagger")
	equipment["mace"] = "iron_mace"
	ck(sm.can_use_skill("electric_strike") == R.OK, "Electric Strike with a mace")

	print("[5] Strikes hit everything in front, nothing behind (D142)")
	game.set_quest_flag("desert_road_monologue_complete", true)
	game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
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
	for i in 3: await physics_frame
	var hp_front: int = front.current_health
	var hp_behind: int = behind.current_health
	ck(sm.use_skill("fire_strike") == R.OK, "Fire Strike lands")
	ck(front.current_health == hp_front - 20, "front enemy -20 (%d → %d)" % [hp_front, front.current_health])
	ck(behind.current_health == hp_behind, "enemy behind untouched")
	sm.clear_cooldowns()
	# Усіх ворогів — геть: тіла проходять крізь гравця (D197), і ворог зі спавну на x 1000 лишився б попереду.
	for e in enemies:
		e.global_position = player.global_position + Vector2(-400, 0)
	front.global_position = player.global_position + Vector2(400, 0)
	ck(sm.use_skill("fire_strike") == R.NO_TARGET, "nothing in front → NO_TARGET, no SP spent")

	print("[6] Upgrades to rank 20, +10% each (D150)")
	sm.add_job_points(5)
	ck(sm.upgrade_skill("fire_strike") == R.OK and sm.get_rank("fire_strike") == 2, "Fire Strike → rank 2")
	ck(sm.scaled("fire_strike", 20) == 22, "rank 2 deals 22")
	ck(sm.upgrade_skill("healing_palm") == R.OK and sm.scaled("healing_palm", 40) == 44, "Healing Palm upgrades too: 40 → 44")
	sm.clear_cooldowns()
	front.global_position = player.global_position + Vector2(30, 0)
	hp_front = front.current_health
	sm.use_skill("fire_strike")
	ck(front.current_health == hp_front - 22, "the upgraded strike lands for 22")
	sl.get_game_manager().player_state.skill_ranks["fire_strike"] = 20
	ck(sm.can_upgrade("fire_strike") == R.MAX_RANK, "rank 20 is the cap")
	ck(sm.scaled("fire_strike", 20) == 58, "rank 20 = ×2.9")

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
