extends SceneTree

## Вертикальний зріз бойових навичок (Phase 5.5).
##   godot --headless --path . --script res://SampleProject/UI/verify_skills_combat.gd
##
## ⚠️ ТІЛЬКИ ТЕСТОВІ ФІКСТУРИ. Продакшн skills.json лишається порожнім —
## бойові значення нижче детерміновані й потрібні виключно для перевірок.

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

# --- TEST-ONLY FIXTURES ---------------------------------------------------
const FIXTURES := [
	{"id": "t_strike", "name": "TEST Strike", "skill_type": "active",
	 "jp_cost": 0, "sp_cost": 10, "cooldown": 0.25, "damage": 7},
	{"id": "t_free", "name": "TEST Free Hit", "skill_type": "active",
	 "jp_cost": 0, "sp_cost": 0, "cooldown": 0.0, "damage": 3},
	{"id": "t_passive", "name": "TEST Passive", "skill_type": "passive",
	 "jp_cost": 0, "damage": 99},
	{"id": "t_locked", "name": "TEST Locked", "skill_type": "active",
	 "jp_cost": 9999, "sp_cost": 0, "damage": 5},
]

## Класи вантажимо в рантаймі: скрипт-MainLoop компілюється до реєстрації
## автозавантажень, тож пряме посилання на CombatBody2D тягне EventBus і падає.
func _make_target(name: String) -> Node:
	var BodyScript = load("res://SampleProject/Scripts/Combat/CombatBody2D.gd")
	var HealthScript = load("res://SampleProject/Scripts/Combat/Components/HealthComponent.gd")
	var body: Node = BodyScript.new()
	body.name = name
	body.Max_Health = 100
	var health: Node = HealthScript.new()
	health.owner_body = body
	body.add_child(health)
	root.add_child(body)
	return body

func _initialize() -> void:
	await process_frame; await process_frame
	var sl: Node = root.get_node_or_null("ServiceLocator")
	var gm: Node = sl.get_game_manager()
	var db: Node = root.get_node_or_null("SkillDatabase")
	var sm: Node = sl.get_skill_manager()
	var R = load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd").Result

	db.load_from_array(FIXTURES)
	sm.skill_database = db
	gm.player_state["unlocked_skills"] = ["t_strike", "t_free", "t_passive"]
	sm.set_max_sp(100)
	sm.restore_sp(100)
	sm.clear_cooldowns()

	var target := _make_target("Dummy")
	var bystander := _make_target("Bystander")
	# Явний кастер: у headless-прогоні гравця в сцені немає, тож джерело
	# ушкодження передаємо самі — так перевіряємо і прокидання source.
	var caster := Node2D.new()
	caster.name = "TestCaster"
	root.add_child(caster)
	await process_frame
	ck(target.get_current_health() == 100, "target starts at full health")

	print("[1] rejection paths cost nothing")
	var sp0: int = sm.get_current_sp()
	ck(sm.use_skill("t_nope", target) == R.UNKNOWN_SKILL, "unknown skill rejected")
	ck(sm.use_skill("t_locked", target) == R.NOT_UNLOCKED, "locked skill cannot execute")
	ck(sm.use_skill("t_passive", target) == R.NOT_ACTIVE, "passive cannot be activated")
	ck(sm.use_skill("t_strike", null) == R.NO_TARGET, "damaging skill without target rejected")
	ck(sm.get_current_sp() == sp0, "no SP spent on any rejection")
	ck(target.get_current_health() == 100, "no damage dealt on any rejection")
	ck(not sm.is_skill_on_cooldown("t_strike"), "no cooldown started on rejection")

	print("[2] insufficient SP")
	gm.player_state["current_sp"] = 3
	ck(sm.use_skill("t_strike", target) == R.NOT_ENOUGH_SP, "insufficient SP prevents execution")
	ck(sm.get_current_sp() == 3, "failed attempt spent no SP")
	ck(target.get_current_health() == 100, "failed attempt dealt no damage")
	ck(not sm.is_skill_on_cooldown("t_strike"), "failed attempt started no cooldown")

	print("[3] successful use")
	sm.restore_sp(100)
	var before_sp: int = sm.get_current_sp()
	ck(sm.use_skill("t_strike", target, caster) == R.OK, "successful use returns OK")
	await process_frame
	ck(target.get_current_health() == 93, "target damaged by exactly 7 (%d)" % target.get_current_health())
	ck(sm.get_current_sp() == before_sp - 10, "exact sp_cost spent")
	ck(bystander.get_current_health() == 100, "unrelated target NOT damaged")
	ck(sm.is_skill_on_cooldown("t_strike"), "cooldown started after success")

	print("[4] damage went through the existing combat path")
	ck(target.get_meta("last_damage_source", null) == caster, "CombatBody2D recorded the caster as damage source")
	ck(target.get_current_health() < target.Max_Health, "health mutated via take_damage pipeline")

	print("[5] cooldown blocks reuse")
	var sp_before: int = sm.get_current_sp()
	var hp_before: int = target.get_current_health()
	ck(sm.use_skill("t_strike", target) == R.ON_COOLDOWN, "cannot reuse during cooldown")
	ck(sm.get_current_sp() == sp_before, "blocked attempt spent no SP")
	ck(target.get_current_health() == hp_before, "blocked attempt dealt no damage")
	ck(sm.get_remaining_cooldown("t_strike") > 0.0, "remaining cooldown reported")

	print("[6] cooldown expires")
	# Тікаємо перезарядку детерміновано, не чекаючи реального часу.
	ck(sm.get_remaining_cooldown("t_strike") > 0.0, "cooldown is counting down")
	sm._process(0.1)
	ck(sm.is_skill_on_cooldown("t_strike"), "still on cooldown after partial tick")
	sm._process(0.2)
	ck(not sm.is_skill_on_cooldown("t_strike"), "cooldown eventually expires")
	ck(sm.get_remaining_cooldown("t_strike") == 0.0, "remaining cooldown is zero")
	ck(sm.use_skill("t_strike", target) == R.OK, "skill usable again after cooldown")
	await process_frame
	ck(target.get_current_health() == 86, "second hit landed (%d)" % target.get_current_health())

	print("[7] zero-cost skill, no cooldown")
	var hp: int = target.get_current_health()
	ck(sm.use_skill("t_free", target) == R.OK, "free skill works")
	await process_frame
	ck(target.get_current_health() == hp - 3, "free skill damage applied")
	ck(not sm.is_skill_on_cooldown("t_free"), "zero cooldown does not register")

	print("[8] events")
	var bus: Node = root.get_node("EventBus")
	var seen := {"used": 0, "failed": 0}
	bus.skill_used.connect(func(_id): seen["used"] += 1)
	bus.skill_failed.connect(func(_id, _r): seen["failed"] += 1)
	sm.use_skill("t_free", target)
	sm.use_skill("t_nope", target)
	await process_frame
	ck(seen["used"] == 1, "skill_used fired once on success")
	ck(seen["failed"] == 1, "skill_failed fired once on failure")

	print("[9] unaffected systems")
	ck(not ("abilities" in gm.player_state), "traversal Player.abilities untouched")
	var player: Node = gm.get_current_player()
	ck(player == null or player.has_method("perform_attack"), "normal attack entry point intact")
	ck(gm.calculate_physical_damage() > 0, "Equipment stat pipeline still works (%d)" % gm.calculate_physical_damage())
	var pdm = root.get_node("SaveSystem").player_data_module
	var snap: Dictionary = pdm.save()
	ck(snap.has("unlocked_skills") and snap.has("current_sp"), "save payload still valid")
	ck(not snap.has("cooldowns"), "cooldowns deliberately NOT persisted")

	target.queue_free(); bystander.queue_free(); caster.queue_free()
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
