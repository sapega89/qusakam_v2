extends SceneTree

## Самоперевірка бойового лоадауту і панелі навичок (Phase 5.7).
##   godot --headless --path . --script res://SampleProject/UI/verify_hotbar.gd
##
## ⚠️ ФІКСТУРИ ТІЛЬКИ ДЛЯ ТЕСТІВ. Продакшн skills.json лишається порожнім.

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

const FIXTURES := [
	{"id": "h_a", "name": "Test Skill A", "skill_type": "active",
	 "jp_cost": 0, "sp_cost": 10, "cooldown": 0.3, "damage": 5},
	{"id": "h_b", "name": "Test Skill B", "skill_type": "active",
	 "jp_cost": 0, "sp_cost": 0, "cooldown": 0.0, "damage": 2},
	{"id": "h_c", "name": "Test Skill C", "skill_type": "active",
	 "jp_cost": 0, "sp_cost": 4, "cooldown": 0.0, "damage": 1},
	{"id": "h_passive", "name": "Test Passive", "skill_type": "passive", "jp_cost": 0},
	{"id": "h_locked", "name": "Test Locked", "skill_type": "active", "jp_cost": 9999},
]

func _make_target() -> Node:
	var BodyScript = load("res://SampleProject/Scripts/Combat/CombatBody2D.gd")
	var HealthScript = load("res://SampleProject/Scripts/Combat/Components/HealthComponent.gd")
	var body: Node = BodyScript.new()
	body.Max_Health = 100
	var health: Node = HealthScript.new()
	health.owner_body = body
	body.add_child(health)
	root.add_child(body)
	return body

func _initialize() -> void:
	await process_frame
	await process_frame
	var sl: Node = root.get_node_or_null("ServiceLocator")
	var gm: Node = sl.get_game_manager()
	var db: Node = root.get_node_or_null("SkillDatabase")
	var sm: Node = sl.get_skill_manager()
	var R = load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd").Result

	db.load_from_array(FIXTURES)
	sm.skill_database = db
	gm.player_state["unlocked_skills"] = ["h_a", "h_b", "h_c", "h_passive"]
	gm.player_state["equipped_skills"] = ["", "", "", ""]
	sm.set_max_sp(100)
	sm.restore_sp(100)
	sm.clear_cooldowns()

	print("[1] slot count comes from Figma, not invented")
	ck(sm.SLOT_COUNT == 4, "4 active skill slots (Figma 434:6628)")
	ck(sm.get_equipped_skills().size() == 4, "loadout normalised to 4 entries")
	ck(sm.is_valid_slot(0) and sm.is_valid_slot(3), "slots 0..3 valid")
	ck(not sm.is_valid_slot(-1) and not sm.is_valid_slot(4), "out-of-range slots invalid")

	print("[2] equip validation")
	ck(sm.equip_skill("h_a", 0) == R.OK, "unlocked active skill equips")
	ck(sm.get_equipped_skill(0) == "h_a", "slot reports the skill")
	ck(sm.equip_skill("h_passive", 1) == R.NOT_ACTIVE_SKILL, "passive cannot occupy an active slot")
	ck(sm.equip_skill("h_locked", 1) == R.NOT_UNLOCKED, "locked skill cannot equip")
	ck(sm.equip_skill("nope", 1) == R.UNKNOWN_SKILL, "unknown skill cannot equip")
	ck(sm.equip_skill("h_b", 9) == R.INVALID_SLOT, "invalid slot refused")
	ck(sm.get_equipped_skill(1) == "", "no failed equip leaked into slot 1")

	print("[3] duplicates move rather than duplicate")
	sm.equip_skill("h_b", 1)
	ck(sm.equip_skill("h_a", 2) == R.OK, "re-equipping an equipped skill succeeds")
	var loadout: Array = sm.get_equipped_skills()
	var occurrences := 0
	for entry in loadout:
		if entry == "h_a": occurrences += 1
	ck(occurrences == 1, "skill occupies exactly one slot (%s)" % str(loadout))
	ck(sm.get_equipped_skill(2) == "h_a", "moved into the new slot")
	ck(sm.get_equipped_skill(0) == "", "old slot released")

	print("[4] swap and unequip")
	sm.equip_skill("h_c", 0)
	ck(sm.swap_equipped_skills(0, 2) == R.OK, "swap succeeds")
	ck(sm.get_equipped_skill(0) == "h_a" and sm.get_equipped_skill(2) == "h_c", "slots exchanged")
	ck(sm.unequip_skill(2) == R.OK, "unequip succeeds")
	ck(sm.get_equipped_skill(2) == "", "slot cleared")
	ck(sm.unequip_skill(2) == R.SLOT_EMPTY, "unequipping an empty slot reports SLOT_EMPTY")
	ck(sm.swap_equipped_skills(0, 7) == R.INVALID_SLOT, "swap validates slots")

	print("[5] loadout is separate from progression")
	ck(gm.player_state.has("equipped_skills"), "equipped_skills exists in player_state")
	ck(gm.player_state.has("unlocked_skills"), "unlocked_skills still separate")
	ck(sm.is_unlocked("h_c"), "unequipping does not un-learn the skill")

	print("[6] use via slot")
	var target := _make_target()
	await process_frame
	sm.equip_skill("h_a", 0)
	# Слот 1 звільняємо явно, інакше проба "порожнього слота" застосувала б h_b.
	sm.unequip_skill(1)
	var sp_before: int = sm.get_current_sp()
	var hp_before: int = target.get_current_health()
	ck(sm.use_slot(1, target) == R.SLOT_EMPTY, "empty slot returns SLOT_EMPTY")
	ck(sm.get_current_sp() == sp_before, "empty slot spends no SP")
	ck(target.get_current_health() == hp_before, "empty slot deals no damage")
	ck(sm.use_slot(9, target) == R.INVALID_SLOT, "invalid slot refused")

	ck(sm.use_slot(0, target) == R.OK, "equipped slot invokes the skill")
	await process_frame
	ck(sm.get_current_sp() == sp_before - 10, "exact SP consumed (%d)" % sm.get_current_sp())
	ck(target.get_current_health() == hp_before - 5, "damage applied via existing pipeline")

	print("[7] cooldown gating")
	ck(sm.is_skill_on_cooldown("h_a"), "cooldown started")
	var sp_mid: int = sm.get_current_sp()
	var hp_mid: int = target.get_current_health()
	ck(sm.use_slot(0, target) == R.ON_COOLDOWN, "slot blocked during cooldown")
	ck(sm.get_current_sp() == sp_mid, "blocked use spends no SP")
	ck(target.get_current_health() == hp_mid, "blocked use deals no damage")
	sm._process(0.5)
	ck(not sm.is_skill_on_cooldown("h_a"), "cooldown expires")
	ck(sm.use_slot(0, target) == R.OK, "usable again after cooldown")
	await process_frame

	print("[8] insufficient SP")
	gm.player_state["current_sp"] = 0
	sm.clear_cooldowns()
	var hp_now: int = target.get_current_health()
	ck(sm.use_slot(0, target) == R.NOT_ENOUGH_SP, "insufficient SP blocks slot use")
	ck(target.get_current_health() == hp_now, "no damage on insufficient SP")
	ck(not sm.is_skill_on_cooldown("h_a"), "no cooldown started on failure")
	sm.restore_sp(100)

	print("[9] save / load round-trip")
	var pdm = root.get_node("SaveSystem").player_data_module
	sm.equip_skill("h_a", 0)
	sm.equip_skill("h_b", 3)
	var snap: Dictionary = pdm.save()
	ck(snap.has("equipped_skills"), "equipped_skills is saved")
	ck(snap["equipped_skills"][3] == "h_b", "slot contents saved")
	gm.player_state["equipped_skills"] = ["", "", "", ""]
	pdm.load_data(snap)
	ck(sm.get_equipped_skill(0) == "h_a", "loadout restored")
	ck(sm.get_equipped_skill(3) == "h_b", "all slots restored")

	print("[10] legacy saves without equipped_skills")
	var legacy: Dictionary = snap.duplicate(true)
	legacy.erase("equipped_skills")
	pdm.load_data(legacy)
	ck(gm.player_state.has("equipped_skills"), "old save loads without crashing")
	ck(sm.get_equipped_skills().size() == 4, "loadout still normalised after legacy load")

	print("[11] hotbar UI reflects manager state")
	var InputMapCheck := InputMap.has_action("skill_slot_1") and InputMap.has_action("skill_slot_4")
	ck(InputMapCheck, "skill_slot_1..4 input actions registered")
	var HotbarScene = load("res://SampleProject/UI/Components/skill_hotbar.tscn")
	var hotbar: Control = HotbarScene.instantiate()
	root.add_child(hotbar)
	for i in 3: await process_frame
	ck(hotbar._slots.size() == 4, "hotbar renders 4 slots")
	hotbar.refresh()
	await process_frame
	var badge: Label = hotbar._slots[0].get_node("Slot/Cooldown")
	ck(not badge.visible, "no cooldown overlay when ready")
	sm.use_slot(0, target)
	hotbar.refresh()
	await process_frame
	ck(badge.visible, "cooldown overlay appears from manager state")
	ck(badge.text.ends_with("s"), "overlay shows remaining seconds (%s)" % badge.text)

	print("[12] hotbar does no rules work")
	var src: String = FileAccess.open(
		"res://SampleProject/UI/Components/skill_hotbar.gd", FileAccess.READ).get_as_text()
	ck(src.find("player_state") == -1, "hotbar never touches player_state")
	ck(src.find("sp_cost") == -1, "hotbar does not read SP cost")
	ck(src.find("damage") == -1, "hotbar does not compute damage")
	ck(src.find("Input.is_key_pressed") == -1, "no hardcoded key polling")

	print("[13] unaffected systems")
	ck(not ("abilities" in gm.player_state), "traversal Player.abilities unaffected")
	ck(gm.calculate_physical_damage() > 0, "Equipment stat pipeline intact")
	var player: Node = gm.get_current_player()
	ck(player == null or player.has_method("perform_attack"), "normal attack entry point intact")

	hotbar.queue_free()
	target.queue_free()
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
