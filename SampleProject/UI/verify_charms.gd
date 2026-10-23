extends SceneTree

## Обереги (D592, design/charms_plan.md) у справжній грі:
##   [1] дані: 6 оберегів, у кожного правило (effects), назва й опис у en.po / uk.po
##   [2] слоти: 2 відкриті на старті, третій відкриває unlock_slot (Латунний Збирач, MayorHall); вдягнути можна лише знайдений
##   [3] кожне правило працює: парирування лікує; без блоку й довший перекат; дешевші навички й слабше лікування;
##       сильніший удар по збитому ворогу; ще один ковток, слабший; SP за вбивство
##   [4] скриня з оберегом дає його; скриня на горищі діда тримає Grandfather's Ring
##   [5] збереження й завантаження (PlayerDataModule, без файлів); сейв до D592 — порожні слоти
##   [6] екран Equipment: секція CHARMS з трьох рядків-шаблонів, закритий слот, вдягнутий оберіг
## Справжніх сейвів не чіпає.
##   godot --headless --path . --script res://SampleProject/UI/verify_charms.gd

var Charms: GDScript
const ENEMY_SCENE := "res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn"
const CHEST_SCENE := "res://SampleProject/Objects/Chest.tscn"
const ELDER_HOUSE := "res://SampleProject/Maps/ElderHouse.tscn"

var fails: Array[String] = []


func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


## Підказки навчання (модалки) ставлять гру на паузу й забирають ввід — закриваємо їх.
func _clear_modals(sl: Node) -> void:
	var layer: Node = sl.get_ui_manager().get_modal_layer()
	for i in 20:
		if layer.active_modal == null:
			return
		layer._close_with_result("confirm", layer.active_modal)
		for f in 4: await process_frame


## Справжня подія дії block — Player._unhandled_input ставить combat.block_held.
func _block(pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = &"block"
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _initialize() -> void:
	await process_frame; await process_frame
	Charms = load("res://SampleProject/Scripts/Systems/Charms.gd")
	set_meta("start_new_game", true)
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	for intro_round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
	var sl: Node = root.get_node("ServiceLocator")
	var gm: Node = sl.get_game_manager()
	var sm = sl.get_skill_manager()
	var player: Node = gm.get_current_player()
	var bus: Node = root.get_node("EventBus")
	var sdb: Node = root.get_node("SkillDatabase")

	await _clear_modals(sl)

	print("[1] data")
	ck(Charms.all_ids().size() == 6, "6 charms in charms.json (%d)" % Charms.all_ids().size())
	var en: Translation = load("res://SampleProject/Resources/Translations/en.po")
	var uk: Translation = load("res://SampleProject/Resources/Translations/uk.po")
	for charm_id in Charms.all_ids():
		var charm: Dictionary = Charms.get_charm(charm_id)
		ck(not (charm.effects as Dictionary).is_empty() and String(charm.kind) in ["ring", "amulet"], "%s: a ring or amulet with a rule" % charm_id)
		for key: String in [String(charm.name), String(charm.description)]:
			ck(key.ends_with("[DRAFT]") and en.get_message(key) != "" and uk.get_message(key).ends_with("[ЧЕРНЕТКА]"),
				"%s: '%s' in en.po and uk.po (draft)" % [charm_id, key])
	ck(Charms.icon("grandfathers_ring") != null, "the icon loads")

	print("[2] slots and unlocks")
	ck(Charms.total_slots() == 3 and Charms.open_slots() == 2, "3 slots, 2 open at the start")
	ck(Charms.owned().is_empty() and Charms.equipped() == ["", "", ""], "a new hero owns no charm")
	ck(not Charms.equip(0, "breaker_ring"), "a charm not found cannot be worn")
	ck(not Charms.grant("no_such_charm"), "an unknown charm is not granted")
	for charm_id in Charms.all_ids():
		Charms.grant(charm_id)
	ck(not Charms.grant("breaker_ring"), "a charm is found once")
	ck(Charms.owned().size() == 6, "all six found")
	ck(not Charms.equip(2, "breaker_ring"), "the third slot is closed")
	Charms.unlock_slot()
	ck(Charms.open_slots() == 3, "unlock_slot opens the third")
	Charms.unlock_slot()
	ck(Charms.open_slots() == 3, "never more than 3")
	ck(Charms.equip(2, "breaker_ring"), "the third slot takes a charm")
	ck(Charms.equip(0, "breaker_ring") and Charms.equipped() == ["breaker_ring", "", ""], "the same charm moves, never in two slots")
	Charms.unequip(0)
	ck(Charms.equipped() == ["", "", ""] and Charms.effect(&"staggered_damage") == 0.0, "unequipped: no effect")
	var hall: String = FileAccess.get_file_as_string("res://SampleProject/Scripts/Gameplay/Scenes/MayorHall.gd")
	ck(hall.find("\"mayor_boss_defeated\", true)\n\tCharms.unlock_slot()") >= 0, "the Brass Collector's fall opens the third slot (MayorHall)")

	print("[3a] Grandfather's Ring: a parry heals")
	player.current_health = 40
	bus.player_parried.emit(player)
	var heal: int = roundi(player.Max_Health * 0.05)
	ck(player.current_health == 40, "no charm: a parry heals nothing")
	Charms.equip(0, "grandfathers_ring")
	bus.player_parried.emit(player)
	ck(player.current_health == 40 + heal, "worn: a parry heals 5%% max HP (+%d → %d)" % [heal, player.current_health])
	Charms.unequip(0)
	player.current_health = player.Max_Health

	await _clear_modals(sl)
	print("[3b] Sand Runner's Ring: no block, a longer roll")
	var combat = player.combat
	var roll_before: float = player.mover.roll_factor()
	_block(true)
	for i in 30:
		if combat.is_blocking(): break
		await physics_frame
	ck(combat.is_blocking(), "no charm: holding block blocks (state %s)" % combat.state)
	_block(false)
	for i in 5: await physics_frame
	Charms.equip(0, "sand_runner_ring")
	_block(true)
	for i in 30: await physics_frame
	ck(not combat.is_blocking(), "worn: holding block does nothing (state %s)" % combat.state)
	_block(false)
	ck(is_equal_approx(player.mover.roll_factor(), roll_before + 0.3), "worn: roll ×%.2f (was ×%.2f)" % [player.mover.roll_factor(), roll_before])
	Charms.unequip(0)

	print("[3c] Hermit's Amulet: cheaper skills, weaker healing")
	var strike = sdb.get_skill("fire_strike")
	var palm_heal: int = sm.skill_heal("healing_palm")
	Charms.equip(0, "hermit_amulet")
	ck(sm.sp_cost(strike) == roundi(strike.sp_cost * 0.7), "Fire Strike %d → %d SP" % [strike.sp_cost, sm.sp_cost(strike)])
	ck(sm.skill_heal("healing_palm") == roundi(palm_heal * 0.7) or absi(sm.skill_heal("healing_palm") - roundi(palm_heal * 0.7)) <= 1,
		"the flask heals 30%% less (%d → %d)" % [palm_heal, sm.skill_heal("healing_palm")])
	sm.restore_sp(1000)
	var sp_full: int = sm.get_current_sp()
	sm._pay(strike)
	ck(sp_full - sm.get_current_sp() == sm.sp_cost(strike), "a cast pays the lower cost (%d)" % (sp_full - sm.get_current_sp()))
	Charms.unequip(0)
	ck(sm.sp_cost(strike) == strike.sp_cost, "unequipped: full cost again")

	print("[3d] Breaker's Ring: more damage to a staggered enemy")
	var enemy: Node = load(ENEMY_SCENE).instantiate()
	enemy.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_melee.tres")
	enemy.position = player.global_position + Vector2(4000, -2000)
	root.add_child(enemy)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 2: await process_frame
	var hp: int = enemy.current_health
	var applier = combat.damage_applier
	applier.is_active = true
	combat._load_hit(20)
	enemy.enemy_logic.stun_left = 1.0
	applier._on_hitbox_body_entered(enemy)
	ck(hp - enemy.current_health == 20, "no charm: a staggered enemy takes 20 (%d)" % (hp - enemy.current_health))
	Charms.equip(0, "breaker_ring")
	applier.hit_targets.clear()
	hp = enemy.current_health
	combat._load_hit(20)
	applier._on_hitbox_body_entered(enemy)
	ck(hp - enemy.current_health == 27, "worn: a staggered enemy takes 27 (+35%%) (%d)" % (hp - enemy.current_health))
	applier.hit_targets.clear()
	hp = enemy.current_health
	enemy.enemy_logic.stun_left = 0.0
	combat._load_hit(20)
	applier._on_hitbox_body_entered(enemy)
	ck(hp - enemy.current_health == 20, "worn: an enemy on his feet takes 20 (%d)" % (hp - enemy.current_health))
	applier.disable_damage()
	Charms.unequip(0)
	enemy.queue_free()

	print("[3e] Deep Gourd Amulet: one more sip, each weaker")
	var palm = sdb.get_skill("healing_palm")
	sm.refill_charges()
	ck(sm.max_charges(palm) == 3 and sm.get_charges("healing_palm") == 3, "no charm: 3 sips")
	Charms.equip(0, "deep_gourd_amulet")
	ck(sm.max_charges(palm) == 4, "worn: a 4-sip flask")
	ck(sm.get_charges("healing_palm") == 3, "the new sip waits for a save")
	sm.refill_charges()
	ck(sm.get_charges("healing_palm") == 4, "a save fills 4")
	ck(absi(sm.skill_heal("healing_palm") - roundi(palm_heal * 0.7)) <= 1, "each sip heals 30%% less (%d)" % sm.skill_heal("healing_palm"))
	Charms.unequip(0)
	ck(sm.get_charges("healing_palm") == 3, "unequipped: the extra sip is gone")

	print("[3f] Jackal Tooth Amulet: kills restore SP")
	sm.spend_sp(sm.get_current_sp())
	bus.enemy_died.emit("bandit", Vector2.ZERO)
	ck(sm.get_current_sp() == 0, "no charm: a kill gives no SP")
	Charms.equip(0, "jackal_tooth_amulet")
	bus.enemy_died.emit("bandit", Vector2.ZERO)
	ck(sm.get_current_sp() == 4, "worn: a kill gives 4 SP (%d)" % sm.get_current_sp())
	Charms.unequip(0)

	print("[4] chests")
	var state: SceneState = (load(ELDER_HOUSE) as PackedScene).get_state()
	var attic_charm := ""
	for i in state.get_node_count():
		if state.get_node_name(i) == "Chest_Attic":
			for p in state.get_node_property_count(i):
				if state.get_node_property_name(i, p) == "charm":
					attic_charm = state.get_node_property_value(i, p)
	ck(attic_charm == "grandfathers_ring", "the grandfather's attic chest holds Grandfather's Ring")
	gm.player_state.charms = Charms.initial_state()
	var chest: Node = load(CHEST_SCENE).instantiate()
	chest.persistent = false
	chest.charm = "grandfathers_ring"
	chest.position = player.global_position + Vector2(4000, 0)
	game.add_child(chest)
	await process_frame
	ck(chest.get_node("Interactable").enabled, "a charm-only chest is open to interact")
	await _clear_modals(sl)
	chest._on_interacted()
	ck("grandfathers_ring" in Charms.owned(), "opening it grants the charm")
	for i in 120: await process_frame
	var layer: Node = sl.get_ui_manager().get_modal_layer()
	var modal_text := ""
	if layer.active_modal != null:
		for label in layer.active_modal.find_children("*", "Label", true, false):
			modal_text += (label as Label).text + " | "
	ck(modal_text.find("Grandfather's Ring") >= 0, "the modal names the charm (%s)" % modal_text.left(120))
	if layer.active_modal != null:
		layer._close_with_result("confirm", layer.active_modal)
	for i in 6: await process_frame

	print("[5] save and load (PlayerDataModule, no files)")
	Charms.grant("breaker_ring")
	Charms.unlock_slot()
	Charms.equip(2, "breaker_ring")
	var pdm = root.get_node("SaveSystem").player_data_module
	var snap: Dictionary = pdm.save()
	ck(snap.has("charms"), "the save carries charms")
	gm.player_state.charms = Charms.initial_state()
	pdm.load_data(snap)
	ck(Charms.owned() == ["grandfathers_ring", "breaker_ring"] and Charms.open_slots() == 3 and Charms.equipped() == ["", "", "breaker_ring"],
		"loaded back: owned, 3 slots, Breaker's Ring in slot III")
	ck(Charms.effect(&"staggered_damage") == 0.35, "the loaded charm works")
	var old: Dictionary = snap.duplicate(true)
	old.erase("charms")
	pdm.load_data(old)
	ck(Charms.owned().is_empty() and Charms.open_slots() == 2, "a save from before D592: no charms, 2 slots")
	pdm.load_data(snap)

	print("[6] Equipment: the CHARMS section")
	sl.get_ui_manager().open_game_menu()
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Equipment")
	for i in 8: await process_frame
	var eq: Node = menu.find_child("EquipmentComponent", true, false)
	ck(eq._charm_list.get_child_count() == 3, "3 charm rows")
	ck(eq._charm_rows.all(func(r: Button) -> bool: return r.theme_type_variation == eq._slot_row.theme_type_variation),
		"charm rows are copies of the slot row template (same theme variation)")
	var names: Array = eq._charm_rows.map(func(r: Button) -> String: return r.get_node("Row/ItemName").text)
	ck(names == [eq.PLACEHOLDER, eq.PLACEHOLDER, "Breaker's Ring [DRAFT]"], "rows show the worn charm (%s)" % str(names))
	gm.player_state.charms.slots = 2
	bus.charms_changed.emit()
	await process_frame
	ck(eq._charm_rows[2].get_node("Row/ItemName").text == eq.LOCKED, "a closed slot reads (locked)")
	eq._charm_rows[2].grab_focus()
	for i in 2: await process_frame
	var bar: Node = get_first_node_in_group("ui_bottom_bar")
	ck(bar._hint_label.text.find("locked") >= 0, "the hint says the slot is locked (%s)" % bar._hint_label.text)
	eq._on_charm_pressed(0)
	for i in 4: await process_frame
	var picker: Node = layer.active_modal
	ck(picker != null and picker._ids == Charms.owned(), "a slot opens the equip picker with the found charms")
	picker.chosen.emit("grandfathers_ring")
	for i in 4: await process_frame
	ck(Charms.equipped()[0] == "grandfathers_ring", "picking equips it into slot I")
	ck(eq._charm_rows[0].get_node("Row/ItemName").text == "Grandfather's Ring [DRAFT]", "the row updates")
	sl.get_ui_manager().close_game_menu()
	for i in 6: await process_frame

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
