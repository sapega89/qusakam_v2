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
	var sprite := Sprite2D.new()  # як у справжніх тіл: спалах ушкодження (VFXHooks) світить спрайт
	sprite.name = "Sprite2D"
	body.add_child(sprite)
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
	ck(sm.SLOT_COUNT == 8, "8 active skill slots (Hotbar v2 497:6587, D549)")
	ck(InputMap.has_action("skill_slot_8") and not InputMap.has_action("skill_slot_9"), "one input action per slot")
	ck(sm.get_equipped_skills().size() == 8, "loadout normalised to 8 entries")
	ck(sm.is_valid_slot(0) and sm.is_valid_slot(7), "slots 0..7 valid")
	ck(not sm.is_valid_slot(-1) and not sm.is_valid_slot(8), "out-of-range slots invalid")

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
	ck(sm.swap_equipped_skills(0, 8) == R.INVALID_SLOT, "swap validates slots")

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
	ck(sm.get_equipped_skills().size() == 8, "loadout still normalised after legacy load")
	print("[10b] a 4-slot save from before D549 loads into 8 slots, the first four kept")
	var four: Dictionary = snap.duplicate(true)
	four["equipped_skills"] = ["h_a", "", "", "h_b"]
	pdm.load_data(four)
	ck(sm.get_equipped_skills().size() == 8 and sm.get_equipped_skill(0) == "h_a" and sm.get_equipped_skill(3) == "h_b"
			and sm.get_equipped_skill(7) == "", "old 4-slot loadout padded to 8 (%s)" % [sm.get_equipped_skills()])
	ck(sm.equip_skill("h_a", 7) == R.OK and sm.get_equipped_skill(7) == "h_a", "slot 8 takes a skill")
	ck(sm.equip_skill("h_a", 8) == R.INVALID_SLOT, "slot 9 does not exist")
	sm.equip_skill("h_a", 0)

	print("[11] hotbar UI reflects manager state")
	var InputMapCheck := range(1, 9).all(func(n: int) -> bool: return InputMap.has_action("skill_slot_%d" % n))
	ck(InputMapCheck, "skill_slot_1..8 input actions registered")
	for n in range(1, 9):
		var keys: Array = InputMap.action_get_events("skill_slot_%d" % n).filter(func(e: InputEvent) -> bool: return e is InputEventKey)
		ck(keys.size() == 1 and keys[0].physical_keycode == KEY_0 + n, "slot %d on key %d" % [n, n])
	var HotbarScene = load("res://SampleProject/UI/Components/skill_hotbar.tscn")
	var hotbar: Control = HotbarScene.instantiate()
	root.add_child(hotbar)
	for i in 3: await process_frame
	ck(hotbar._slots.size() == 8, "hotbar renders 8 slots")
	ck(hotbar.size == Vector2(780, 124), "hotbar is Figma 780 × 124 (%s)" % hotbar.size)
	var xs: Array = hotbar._slots.map(func(b: Control) -> int: return int(b.position.x))
	ck(xs == [78, 154, 230, 306, 410, 486, 562, 638], "two groups of four around the centre diamond (%s)" % [xs])
	var diamond: Control = hotbar.get_node(^"CentreDiamond")
	ck(diamond.position == Vector2(382, 62), "centre diamond at (382, 62)")
	ck(hotbar.get_node(^"CurlRight").flip_h and not hotbar.get_node(^"CurlLeft").flip_h, "right curl mirrored")
	ck(hotbar.get_node(^"Slots/Bind8/Badge/Key").text == "8", "slot 8 badge reads 8 on the keyboard")
	ck(not hotbar.get_node(^"Slots/Bind8/Icon").visible and not hotbar.get_node(^"Slots/Bind8/Ready").visible,
			"an empty slot is the bare hexagon")
	hotbar.refresh()
	await process_frame
	var bind0: Control = hotbar._slots[0]
	var badge: Control = bind0.get_node("Cooldown")
	ck(not badge.visible, "no cooldown overlay when ready")
	ck(bind0.get_node(^"Ready").visible and bind0.get_node(^"Glow").visible, "a ready slot shows the gold ring and the glow")
	var cost: int = root.get_node(^"SkillDatabase").get_skill(sm.get_equipped_skill(0)).sp_cost
	ck(bind0.get_node(^"Gem").visible == (cost > 0) and bind0.get_node(^"Gem/Cost").text == str(cost),
			"the SP gem shows the skill's cost (%d)" % cost)
	sm.use_slot(0, target)
	hotbar.refresh()
	await process_frame
	ck(badge.visible, "cooldown overlay appears from manager state")
	var seconds: Label = badge.get_node(^"Seconds")
	ck(seconds.text == ("%.1f" % sm.get_remaining_cooldown(sm.get_equipped_skill(0))) or seconds.text.is_valid_int(),
			"overlay shows the seconds left, Figma style (%s)" % seconds.text)
	ck(not bind0.get_node(^"Ready").visible, "no ready ring while cooling down")
	print("[11b] the gamepad: LT shifts the four slot buttons to slots 5–8 (D549)")
	var SkillSlotInput: GDScript = load("res://SampleProject/Scripts/UI/skill_slot_input.gd")
	var InputGlyphs: GDScript = load("res://SampleProject/Scripts/UI/input_glyphs.gd")
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	ck(SkillSlotInput.slot_for(rt) == 0, "RT alone is slot 1")
	Input.action_press(&"assist")
	SkillSlotInput.shift_used = false
	ck(SkillSlotInput.slot_for(rt) == 4 and SkillSlotInput.shift_used, "LT + RT is slot 5, and the LT hold is used up")
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_BACK
	back.pressed = true
	ck(SkillSlotInput.slot_for(back) == 7, "LT + Back is slot 8")
	Input.action_release(&"assist")
	ck(SkillSlotInput.slot_for(back) == 3, "Back alone is slot 4")
	var key6 := InputEventKey.new()
	key6.physical_keycode = KEY_6
	key6.pressed = true
	ck(SkillSlotInput.slot_for(key6) == 5, "key 6 is slot 6")
	InputGlyphs.using_gamepad = true
	ck(SkillSlotInput.badge(0) == "RT" and SkillSlotInput.badge(4) == "LT+RT" and SkillSlotInput.badge(7) == "LT+Back",
			"pad badges: RT … LT+Back (%s, %s)" % [SkillSlotInput.badge(0), SkillSlotInput.badge(4)])
	InputGlyphs.using_gamepad = false

	print("[12] hotbar does no rules work")
	var src: String = FileAccess.open(
		"res://SampleProject/UI/Components/skill_hotbar.gd", FileAccess.READ).get_as_text()
	ck(src.find("player_state") == -1, "hotbar never touches player_state")
	ck(src.count("sp_cost") == 1 and src.find("get_current_sp") == -1, "hotbar shows the SP cost on the gem, never compares SP")
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
