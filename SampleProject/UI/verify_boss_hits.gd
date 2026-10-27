extends SceneTree

## Боси б'ють (B-boss, Sapega 26.10: «боси не б'ють»): кожен бій боса починається через свою кімнату — справжній
## вхід (move_right), кат-сцена до стану FIGHT, — далі герой стоїть на місці й нічого не тисне. Бос іде через залу; за
## HIT_WITHIN с відтоді, як він став до бою (стан ATTACK), він має влучити (damage_token від боса чи його хвилі), а за
## WEAPON_WITHIN с від початку бою — і зброєю: серія (combo) чи ривок (charge) його хітбоксом. До виправлення боси ставали за 83–90 px від героя, далі за дальність серії, і били лише хвилею.
##   godot --headless --path . --script res://SampleProject/UI/verify_boss_hits.gd

const LAB_HALL := "res://SampleProject/Maps/LabBoss.tscn"
const MAYOR_HALL := "res://SampleProject/Maps/MayorHall.tscn"
const TEST_DIR := "user://verify_boss_hits/"
const TEST_SLOT := 1
## За скільки секунд після початку бою бос має влучити в героя, що стоїть.
const HIT_WITHIN := 4.0
const WEAPON_WITHIN := 15.0

var fails: Array[String] = []
var game: Node
var dm: Node

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _press(action: StringName, pressed: bool = true) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)

## Справжній вхід: герой іде праворуч, доки кімната не вийде з очікування; розмови — до кінця, аж до бою.
func _enter_fight(hall: Node) -> void:
	var wait_state: String = hall.get_current_state_name()
	_press(&"move_right")
	var deadline := Time.get_ticks_msec() + 60000
	while hall.get_current_state_name() != "FIGHT" and Time.get_ticks_msec() < deadline:
		if hall.get_current_state_name() != wait_state:
			_press(&"move_right", false)
		if dm.is_dialogue_active():
			dm.current_dialogue_box.finish()  # D254
			dm.current_dialogue_player.accept()
		await process_frame
	_press(&"move_right", false)

## Герой стоїть; бос має влучити за HIT_WITHIN с. Сліди станів боса — у журнал, щоб було видно, де він застряг.
func _boss_hits(room: String, boss_path: NodePath, label: String) -> void:
	print("[%s] The fight starts through the room; the hero stands still" % label)
	await game.teleport_to_room(room, ^"Arrival")
	for i in 30: await physics_frame
	var hall: Node = game.map
	var boss: Node2D = hall.get_node(boss_path)
	var hero: Node2D = game.player
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health
	await _enter_fight(hall)
	ck(hall.get_current_state_name() == "FIGHT", "%s: the room reaches FIGHT" % label)
	hero.current_health = hero.Max_Health
	var logic: Node = boss.enemy_logic
	var t0 := Time.get_ticks_msec()
	# Кожен удар по героєві: [секунда, хід боса, чи це сам бос (хітбокс), а не його хвиля]
	var hits: Array[Array] = []
	var on_hit := func(_amount: int) -> void:
		var source: Variant = hero.get_meta("last_damage_source", null)
		hits.append([(Time.get_ticks_msec() - t0) / 1000.0, String(logic.last_move.get("kind", "")), source == boss])
	hero.damage_token.connect(on_hit)
	var moves: Array[String] = []
	var engaged := -1.0
	while Time.get_ticks_msec() - t0 < int(WEAPON_WITHIN * 1000) and not hits.any(func(h: Array) -> bool: return h[2]):
		if engaged < 0.0 and logic.current_state == logic.AIState.ATTACK:
			engaged = (Time.get_ticks_msec() - t0) / 1000.0
		if logic.is_attacking and (moves.is_empty() or moves[-1] != logic.last_move.kind):
			moves.append(logic.last_move.kind)
		if not logic.is_attacking and not moves.is_empty() and moves[-1] != "":
			moves.append("")
		await physics_frame
	hero.damage_token.disconnect(on_hit)
	print("    engaged at %.1f s; moves: %s; hits [s, move, weapon]: %s" % [engaged, moves.filter(func(m: String) -> bool: return m != ""), hits])
	ck(engaged >= 0.0 and not hits.is_empty() and hits[0][0] - engaged <= HIT_WITHIN,
			"%s: once in reach, the boss lands a hit on a hero standing still within %.0f s" % [label, HIT_WITHIN])
	ck(hits.any(func(h: Array) -> bool: return h[2] and h[1] in ["combo", "charge"]),
			"%s: the boss swings its weapon and lands it (combo or charge) within %.0f s" % [label, WEAPON_WITHIN])
	hero.current_health = hero.Max_Health

func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()  # D393: без ухилення героя — удар або влучає, або ні
	await process_frame
	var save_system: Node = root.get_node("SaveSystem")
	save_system.settings_module.settings.tutorial_windows = false  # D289
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(TEST_SLOT)
	await process_frame
	dm = root.get_node("ServiceLocator").get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	set_meta("start_new_game", true)
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 60: await physics_frame
	for i in 400:
		if not dm.is_dialogue_active():
			break
		dm.current_dialogue_box.finish()
		dm.current_dialogue_player.accept()
		await process_frame

	await _boss_hits(LAB_HALL, ^"Mercenary", "LabBoss")
	await _boss_hits(MAYOR_HALL, ^"ScorpicoreWarrior", "MayorHall")

	game.queue_free()
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()
