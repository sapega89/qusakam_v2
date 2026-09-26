extends SceneTree

## Самоперевірка фундаменту Skills (Phase 5.4 A).
##   godot --headless --path . --script res://SampleProject/UI/verify_skills.gd
##
## Використовує ТЕСТОВІ фікстури, а не продакшн-контент: skills.json порожній
## навмисно, бо навички ще не спроєктовані.

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

const FIXTURES := [
	{"id": "test_strike", "name": "Test Strike", "skill_type": "active",
	 "jp_cost": 100, "required_level": 1, "sp_cost": 10, "cooldown": 2.0},
	{"id": "test_advanced", "name": "Test Advanced", "skill_type": "active",
	 "jp_cost": 50, "required_level": 5, "prerequisites": ["test_strike"], "sp_cost": 5},
	{"id": "test_passive", "name": "Test Passive", "skill_type": "passive",
	 "jp_cost": 25, "sp_cost": 99, "cooldown": 9.0},
	{"id": "", "name": "Broken - no id"},
	{"id": "test_negative", "name": "Negative values", "jp_cost": -50,
	 "required_level": -3, "sp_cost": -7, "cooldown": -1.0},
	{"id": "test_strike", "name": "Duplicate id"},
]

func _initialize() -> void:
	await process_frame; await process_frame
	var sl: Node = root.get_node_or_null("ServiceLocator")
	var gm: Node = sl.get_game_manager()
	var db: Node = root.get_node_or_null("SkillDatabase")
	var sm: Node = sl.get_skill_manager()
	var R = load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd").Result

	print("[1] wiring")
	ck(db != null, "SkillDatabase autoload present")
	ck(sm != null, "SkillManager reachable via ServiceLocator")
	if db == null or sm == null: _done(); return
	ck(db.skills.is_empty(), "production skills.json is empty (no invented content)")

	print("[2] database loads and rejects safely")
	db.load_from_array(FIXTURES)
	sm.skill_database = db
	ck(db.has_skill("test_strike"), "valid definition loaded")
	ck(db.skills.size() == 4, "4 valid of 6 entries (%d)" % db.skills.size())
	ck(db.rejected.size() == 2, "2 rejected: missing id + duplicate")
	var neg: SkillDefinition = db.get_skill("test_negative")
	ck(neg.jp_cost == 0 and neg.sp_cost == 0, "negative costs clamped to 0")
	ck(neg.required_level == 1, "negative level clamped to 1")
	ck(neg.cooldown == 0.0, "negative cooldown clamped to 0")
	var passive: SkillDefinition = db.get_skill("test_passive")
	ck(not passive.is_active(), "passive parsed as passive")
	ck(passive.sp_cost == 0 and passive.cooldown == 0.0, "passive forced to 0 sp / 0 cooldown")

	print("[3] job points")
	gm.player_state["job_points"] = 0
	gm.player_state["unlocked_skills"] = []
	ck(sm.get_job_points() == 0, "starts at 0")
	ck(not sm.spend_job_points(10), "cannot spend more than held")
	ck(sm.get_job_points() == 0, "JP never goes negative")
	sm.add_job_points(120)
	ck(sm.get_job_points() == 120, "add_job_points works")
	ck(not sm.spend_job_points(-5), "negative spend refused")

	print("[4] unlock validation")
	ck(sm.can_unlock("nope") == R.UNKNOWN_SKILL, "unknown skill rejected")
	ck(sm.can_unlock("test_advanced") == R.LEVEL_TOO_LOW, "level requirement enforced")
	ck(sm.unlock_skill("test_strike") == R.OK, "unlock succeeds when affordable")
	ck(sm.get_job_points() == 20, "exactly jp_cost deducted (120-100=%d)" % sm.get_job_points())
	ck(sm.is_unlocked("test_strike"), "recorded in unlocked_skills")
	ck(sm.unlock_skill("test_strike") == R.ALREADY_UNLOCKED, "duplicate unlock refused")
	ck(sm.get_job_points() == 20, "refused duplicate did not charge JP")
	ck(sm.can_unlock("test_passive") == R.NOT_ENOUGH_JP, "insufficient JP blocks unlock")
	ck(sm.get_job_points() == 20, "failed unlock did not charge JP")

	print("[5] prerequisites")
	gm.player_state["unlocked_skills"] = []
	sm.add_job_points(1000)
	sl.get_xp_manager().add_xp(100000)
	await process_frame
	ck(sm.can_unlock("test_advanced") == R.MISSING_PREREQUISITE, "prerequisite enforced")
	sm.unlock_skill("test_strike")
	ck(sm.can_unlock("test_advanced") == R.OK, "unlocks once prerequisite is met")

	print("[6] SP")
	sm.set_max_sp(50)
	ck(sm.get_max_sp() == 50, "max_sp set")
	ck(sm.get_current_sp() == 0, "current clamped to max on change")
	sm.restore_sp(80)
	ck(sm.get_current_sp() == 50, "restore clamps at max")
	ck(sm.spend_sp(20), "spend works")
	ck(sm.get_current_sp() == 30, "spend deducts exactly")
	ck(not sm.spend_sp(999), "cannot overspend")
	ck(sm.get_current_sp() == 30, "SP never goes negative")
	ck(not sm.spend_sp(-1), "negative spend refused")

	print("[7] use_skill gating")
	ck(sm.use_skill("test_strike") == R.OK, "active skill usable")
	ck(sm.get_current_sp() == 20, "sp_cost deducted on use (30-10=%d)" % sm.get_current_sp())
	sm.unlock_skill("test_passive")
	ck(sm.use_skill("test_passive") == R.NOT_ACTIVE, "passive cannot be used")
	sm.clear_cooldowns()
	gm.player_state["current_sp"] = 0
	ck(sm.use_skill("test_strike") == R.NOT_ENOUGH_SP, "insufficient SP blocks use")
	sm.clear_cooldowns()
	ck(sm.is_skill_on_cooldown("test_strike") == false, "cooldown cleared between checks")

	print("[8] signals")
	# У скрипті-MainLoop автозавантаження не резолвиться як глобальний ідентифікатор.
	var bus: Node = root.get_node("EventBus")
	var seen := {"unlocked": false, "used": false, "jp": false, "sp": false}
	bus.skill_unlocked.connect(func(_id): seen["unlocked"] = true)
	bus.skill_used.connect(func(_id): seen["used"] = true)
	bus.job_points_changed.connect(func(_c, _p): seen["jp"] = true)
	bus.sp_changed.connect(func(_c, _m): seen["sp"] = true)
	gm.player_state["unlocked_skills"] = []
	sm.add_job_points(500)
	sm.restore_sp(10)
	sm.clear_cooldowns()
	sm.unlock_skill("test_strike")
	sm.use_skill("test_strike")
	await process_frame
	for key in seen:
		ck(seen[key], "EventBus %s emitted" % key)

	print("[9] save / load round-trip")
	var save_system: Node = root.get_node_or_null("SaveSystem")
	var pdm = save_system.player_data_module
	gm.player_state["job_points"] = 777
	gm.player_state["max_sp"] = 60
	gm.player_state["current_sp"] = 42
	var snapshot: Dictionary = pdm.save()
	ck(snapshot.get("job_points") == 777, "job_points saved")
	ck(snapshot.get("max_sp") == 60 and snapshot.get("current_sp") == 42, "SP saved")
	ck(snapshot.get("unlocked_skills", []).has("test_strike"), "unlocked_skills saved")
	gm.player_state["job_points"] = 0
	gm.player_state["current_sp"] = 0
	gm.player_state["max_sp"] = 0
	gm.player_state["unlocked_skills"] = []
	pdm.load_data(snapshot)
	ck(gm.player_state.job_points == 777, "job_points restored")
	ck(gm.player_state.current_sp == 42 and gm.player_state.max_sp == 60, "SP restored")
	ck(gm.player_state.unlocked_skills.has("test_strike"), "unlocked_skills restored")

	print("[10] legacy save compatibility")
	var legacy := snapshot.duplicate(true)
	legacy.erase("job_points"); legacy.erase("current_sp"); legacy.erase("max_sp")
	pdm.load_data(legacy)
	ck(gm.player_state.has("job_points"), "missing keys do not break load")
	ck(gm.player_state.current_sp <= gm.player_state.max_sp, "SP stays within bounds after legacy load")

	print("[11] traversal abilities untouched")
	ck(not ("abilities" in gm.player_state), "Player.abilities is NOT in player_state")
	ck(not snapshot.has("abilities"), "skills save payload does not contain traversal abilities")
	_done()

func _done() -> void:
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
