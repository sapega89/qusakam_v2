extends SceneTree

## Стартові навички (D815, Sapega 2026-10-27: «блок і хіл мають бути вже вивчені спочатку, може під час медитації вони
## доступні, і якось повідомити гравця, що в нас є скіли»):
##   1. New Game: Shield Block і Healing Palm вивчені (ранг 1), JP не витрачено, Длань — на першому слоті хотбара;
##      до першої медитації не діють: Длань — NOT_AWAKENED, слот тьмяний, Shield Block — 0.
##   2. Сейв до медитації й завантаження: усе так само (вивчені, сплять).
##   3. Медитація на вершині каньйону (справжній MeditationTrigger): навички діють, слот яскравий, Shield Block 0.2;
##      вікно туторіалу «Your Skills» — на паузі, з кнопками з InputMap (блок, перший слот, меню гри); вікно над
##      підказкою «Hold Tab to skip» кат-сцени (B196, D879).
##   4. Раз за проходження: ще одна спроба нічого не показує.
##   5. Сейв після медитації й завантаження: діють.
##   6. Скидання (D592) стартові навички не забирає й JP за них не повертає.
## Пише лише в user://verify_starting_skills/ (set_save_dir) — справжні сейви не чіпає.
##   godot --headless --path . --script res://SampleProject/UI/verify_starting_skills.gd

const TEST_DIR := "user://verify_starting_skills/"
const STARTING := ["shield_block", "healing_palm"]

var fails: Array[String] = []
var sl: Node
var game: Node
var sm: Node
var R


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


func _boot(new_game: bool, save_path: String = "") -> void:
	set_meta("start_new_game", new_game)
	if save_path != "":
		set_meta("save_file_path", save_path)
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain(sl.get_dialogue_manager())


func _close_game() -> void:
	game.queue_free()
	for i in 4: await process_frame


func _until(done: Callable, seconds: float) -> void:
	var start := Time.get_ticks_msec()
	while not done.call() and Time.get_ticks_msec() - start < seconds * 1000.0:
		await process_frame


func _hotbar_alpha() -> float:
	return (get_first_node_in_group(&"skill_hotbar").get_node(^"%Slots").get_child(0) as Control).modulate.a


func _learned_asleep(label: String) -> void:
	ck(STARTING.all(func(id: String) -> bool: return sm.is_unlocked(id) and sm.get_rank(id) == 1),
			"%s: Shield Block and Healing Palm learned at rank 1 (%s)" % [label, sm.get_unlocked_skills()])
	ck(sm.get_equipped_skill(0) == "healing_palm", "%s: Healing Palm on the first hotbar slot (%s)" % [label, sm.get_equipped_skills()])
	ck(not sm.skills_awakened() and sm.can_use_skill("healing_palm") == R.NOT_AWAKENED,
			"%s: not usable before the first meditation (%d)" % [label, sm.can_use_skill("healing_palm")])
	ck(is_equal_approx(sm.passive_value("shield_block"), 0.0), "%s: Shield Block does nothing yet" % label)


func _initialize() -> void:
	await process_frame
	await process_frame
	sl = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
	var save_system: Node = root.get_node("SaveSystem")
	save_system.set_save_dir(TEST_DIR)
	save_system.settings_module.settings.hints = true  # D744: повідомлення — тема туторіалу
	root.size = Vector2i(1920, 1080)
	sm = sl.get_skill_manager()
	R = load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd").Result

	print("[1] New Game: Shield Block and Healing Palm learned for free, asleep until the first meditation")
	save_system.set_current_slot(1)
	await _boot(true)
	_learned_asleep("new game")
	ck(sm.get_job_points() == 0 and sm.spent_points() == 0, "no skill points spent (JP %d, spent %d)" % [sm.get_job_points(), sm.spent_points()])
	ck(sm.tree_spent("") == 0, "the base tree counts nothing paid for them (%d)" % sm.tree_spent(""))
	ck(sm.base_jp_missing("radiant_smite") == 2, "but the free Shield Block counts 1 point toward the 3-point base-tree gate (D827): %d missing" % sm.base_jp_missing("radiant_smite"))
	ck(is_equal_approx(_hotbar_alpha(), load("res://SampleProject/UI/Components/skill_hotbar.gd").UNAVAILABLE_ALPHA), "the hotbar slot is dimmed like any unusable one (α %.2f)" % _hotbar_alpha())
	ck(sm.cast_slot(0) == R.NOT_AWAKENED, "pressing the slot does nothing")
	ck(not "starting_skills" in sl.get_game_manager().player_state.seen_tutorials, "no message before the meditation")

	print("[2] Save before the meditation, load: still learned and asleep")
	ck(game.save_game(), "saved in slot 1")
	await _close_game()
	await _boot(false, save_system.get_slot_path(1))
	_learned_asleep("loaded")

	print("[3] The Canyon summit meditation wakes them and tells the player, with the buttons from the input map")
	var all: Dictionary = game.get_quest_flags().duplicate()
	all["canyon_intro_complete"] = true
	game.set_quest_flags(all)
	await game.teleport_to_room("res://SampleProject/Maps/Canyon.tscn", ^"Arrival")
	for i in 20: await process_frame
	var layer: ModalLayer = sl.get_ui_manager().get_modal_layer()
	game.map.get_node(^"MeditationTrigger")._on_body_entered(game.player)
	var dm: Node = sl.get_dialogue_manager()
	await _until(func() -> bool:
		if dm.is_dialogue_active():
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		return layer.active_modal != null, 20.0)
	ck(layer.active_modal != null and layer.active_modal.scene_file_path.ends_with("tutorial_menu.tscn"), "the tutorial window opens at the meditation")
	var window: Node = layer.active_modal
	ck(window != null and window.topics[window.index].id == "starting_skills", "on the Your Skills topic")
	ck(paused, "the game waits while it is open")
	var skip: CanvasLayer = null
	for n: Node in root.find_children("*", "CanvasLayer", true, false):
		if n.scene_file_path.ends_with("cutscene_skip_prompt.tscn"):
			skip = n
	ck(skip != null and skip.visible, "the cutscene's skip prompt is up behind the window")
	ck(skip != null and layer.layer > skip.layer,
			"B196: the window covers the skip prompt (modal layer %d, skip %d)" % [layer.layer, skip.layer if skip else -1])
	ck(sm.skills_awakened() and sm.can_use_skill("healing_palm") == R.OK, "Healing Palm usable now (%d)" % sm.can_use_skill("healing_palm"))
	ck(is_equal_approx(sm.passive_value("shield_block"), 0.2), "Shield Block cuts a blow through a block by 20 %% (%.2f)" % sm.passive_value("shield_block"))
	await process_frame
	ck(is_equal_approx(_hotbar_alpha(), 1.0), "the hotbar slot lights up (α %.2f)" % _hotbar_alpha())
	var topics: GDScript = load("res://SampleProject/Scripts/UI/tutorial_topics.gd")
	var glyphs: GDScript = load("res://SampleProject/Scripts/UI/input_glyphs.gd")
	var text: String = topics.resolved(topics.by_id("starting_skills")).text
	for action: StringName in [&"block", &"skill_slot_1", &"game_menu"]:
		ck(text.contains(glyphs.label(action)), "the text names the %s button (%s)" % [action, glyphs.label(action)])
	ck(text.contains("Shield Block") and text.contains("Healing Palm") and text.contains("Skills"), "it names both skills and the Skills screen")
	ck(text.contains("[DRAFT]"), "marked as a draft for Sapega")
	TranslationServer.set_locale("uk")
	var uk: String = topics.resolved(topics.by_id("starting_skills")).text
	ck(uk.contains("Блок щитом") and uk.contains("Цілюща долоня") and uk.contains("[ЧЕРНЕТКА]"), "Ukrainian text, a draft too")
	TranslationServer.set_locale("en")
	if window != null:
		window.cancelled.emit()
	await _until(func() -> bool:
		if dm.is_dialogue_active():
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		return game.get_quest_flag("canyon_abduction_complete", false), 30.0)
	ck(not paused and game.get_quest_flag("canyon_abduction_complete", false), "the cutscene goes on to its end after the window")

	print("[4] Once a playthrough")
	var tray: Node = get_first_node_in_group(&"tip_tray")
	game.map._tell_starting_skills()
	await process_frame
	ck(not tray.has("starting_skills") and layer.active_modal == null, "a second call shows nothing (%s)" % [tray.ids()])

	print("[5] Save after the meditation, load: usable")
	ck(game.save_game(), "saved in slot 1 again")
	await _close_game()
	await _boot(false, save_system.get_slot_path(1))
	ck(sm.skills_awakened() and sm.can_use_skill("healing_palm") == R.OK and sm.get_equipped_skill(0) == "healing_palm",
			"still awake after a load (%d)" % sm.can_use_skill("healing_palm"))
	ck(STARTING.all(func(id: String) -> bool: return sm.is_starting_skill(id)), "and still the free starting ones")

	print("[6] A respec keeps the starting skills and refunds nothing for them")
	sm.add_job_points(1)
	ck(sm.upgrade_skill("healing_palm") == R.OK and sm.get_rank("healing_palm") == 2, "Healing Palm to rank 2 for 1 JP")
	var jp_before: int = sm.get_job_points()
	sm._forget_all()
	ck(STARTING.all(func(id: String) -> bool: return sm.is_unlocked(id) and sm.get_rank(id) == 1), "both still learned, rank 1")
	ck(sm.get_job_points() == jp_before + 1, "only the rank is refunded (%d → %d)" % [jp_before, sm.get_job_points()])
	ck(sm.get_equipped_skill(0) == "healing_palm", "Healing Palm keeps its slot")

	await _close_game()
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
