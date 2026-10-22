extends SceneTree

## Цифри урону (D66; Sapega 2026-10-22 «цифри урону по мені і ворогу») у справжній фізиці DesertRoad:
## [1] удар героя — цифра над ворогом; [2] вона піднімається й гасне; [3] крит — більша й золота (D393);
## [4] удар по героєві — цифра іншого кольору над ним; [5] ухилення — слово замість 0;
## [6] Settings → Game → Damage Numbers: Off — цифр немає, збережено в налаштуваннях, Restore — знову On.
##   godot --headless --path . --script res://SampleProject/UI/verify_damage_numbers.gd

var fails: Array[String] = []
var rolls: GDScript = load("res://SampleProject/Scripts/Combat/CombatRolls.gd")
var tokens: GDScript = load("res://SampleProject/UI/Tokens/UITokens.gd")
const TEST_DIR := "user://verify_damage_numbers/"

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _finish_dialogue(dm: Node) -> void:
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

## Засів, з яким наступний кидок з шансом [param chance] випаде.
func _lucky(chance: float) -> void:
	var rng: RandomNumberGenerator = rolls.rng
	for s in range(1, 100000):
		rng.seed = s
		if rng.randf() < chance:
			rng.seed = s
			return
	ck(false, "no seed rolls under %.3f" % chance)

func _numbers() -> Array:
	return get_nodes_in_group(&"damage_numbers").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())

## Цифри зникли (попередні догоріли) — наступна перевірка бачить лише свою.
func _clear() -> void:
	while not _numbers().is_empty():
		await process_frame

## Верх тіла [param body] — звідки росте цифра.
func _top(body: Node2D) -> float:
	var shape: CollisionShape2D = body.get_node(^"CollisionShape2D")
	return shape.global_position.y - shape.shape.get_rect().size.y * absf(body.global_scale.y) / 2.0

func _describe(n: Node) -> String:
	var settings: LabelSettings = n.label.label_settings
	return "'%s' %s size %d at %s" % [n.label.text, settings.font_color.to_html(), settings.font_size, n.global_position]

func _segments(opts: Node, title: String) -> Array:
	for margin in opts._list.get_children():
		if margin.get_child_count() > 0 and margin.get_child(0).name == title:
			return margin.get_child(0).get_node(^"Segments").get_child(0).get_children()
	return []

func _active(opts: Node, title: String) -> String:
	for cell in _segments(opts, title):
		if cell.theme_type_variation == &"SettingsSegmentOn":
			return cell.text
	return ""

## Меню гри → Misc → Settings → вкладка Game.
func _open_settings(ui: Node) -> Node:
	ui.open_game_menu()
	for i in 14: await process_frame
	get_first_node_in_group("game_menu").switch_to_tab("Misc")
	for i in 10: await process_frame
	var opts: Node = get_first_node_in_group("settings_screen")
	opts.switch_to_tab("game")
	for i in 4: await process_frame
	return opts

func _initialize() -> void:
	rolls.calm()
	await process_frame
	var save_system: Node = root.get_node("SaveSystem")
	# Налаштування пишуться у файл слота — тест не чіпає справжніх сейвів гравця.
	save_system.set_save_dir(TEST_DIR)
	save_system.settings_module.settings.tutorial_windows = false  # D289
	await process_frame
	root.size = Vector2i(1920, 1080)
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	var eb: Node = root.get_node("EventBus")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	game.set_quest_flag("desert_road_monologue_complete", true)
	game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await create_timer(1.0).timeout
	var hero: Node = game.player
	var combat: Node = hero.combat
	var gm: Node = sl.get_game_manager()
	var module: Node = save_system.settings_module
	var enemies: Array = []
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			enemies.append(node)
			node.set_physics_process(false)
	while enemies.any(func(e: Node) -> bool: return e.enemy_logic.is_attacking) or combat.owns_animation():
		await physics_frame
	var target: Node = enemies[0]
	target.Max_Health = 9999
	target.current_health = 9999
	ck(module.default_settings.damage_numbers == true and module.settings.damage_numbers == true, "Damage Numbers default On")
	await _clear()

	print("[1] The hero's hit pops a number above the enemy")
	var dmg: int = gm.calculate_physical_damage()
	hero.global_position = target.global_position + Vector2(-26, 0)
	hero.velocity = Vector2.ZERO
	await create_timer(0.05).timeout
	combat.perform_attack(1)
	for i in 30:
		if not _numbers().is_empty():
			break
		await physics_frame
	var got: Array = _numbers()
	ck(got.size() == 1, "one number for one hit (%d)" % got.size())
	var n: Node = got[0]
	var first: Vector2 = n.global_position
	ck(n.label.text == str(dmg) and n.label.label_settings.font_color == tokens.DAMAGE_NUMBER_ENEMY
			and n.label.label_settings.font_size == tokens.DAMAGE_NUMBER_SIZE, "the enemy's number: %s" % _describe(n))
	ck(first.y < _top(target) and absf(first.x - target.global_position.x) <= 12.0,
			"above the enemy's head (number y %.1f, head %.1f)" % [first.y, _top(target)])
	ck(n.get_parent() == target.get_parent(), "it lives in the room, not on the enemy")

	print("[2] It rises and fades, then goes")
	await create_timer(tokens.DAMAGE_NUMBER_TIME * 0.75).timeout
	ck(is_instance_valid(n) and n.global_position.y < first.y - 10.0 and n.modulate.a < 1.0,
			"rose %.1f px, alpha %.2f" % [first.y - n.global_position.y, n.modulate.a])
	await create_timer(tokens.DAMAGE_NUMBER_TIME).timeout
	ck(not is_instance_valid(n), "freed after its %.1f s" % tokens.DAMAGE_NUMBER_TIME)

	print("[3] A crit reads bigger and brighter (D393)")
	await create_timer(0.6).timeout
	_lucky(gm.calculate_critical_chance())
	combat.perform_attack(1)
	await create_timer(0.1).timeout
	got = _numbers()
	ck(got.size() == 1 and got[0].label.text == str(roundi(dmg * 1.5)) and got[0].label.label_settings.font_color == tokens.DAMAGE_NUMBER_CRIT
			and got[0].label.label_settings.font_size == tokens.DAMAGE_NUMBER_CRIT_SIZE and tokens.DAMAGE_NUMBER_CRIT_SIZE > tokens.DAMAGE_NUMBER_SIZE,
			"the crit's number: %s" % ", ".join(got.map(_describe)))
	await _clear()

	print("[4] A hit on the hero pops his number in another colour")
	rolls.calm()
	await create_timer(0.6).timeout
	hero.current_health = hero.Max_Health
	var hurt: int = hero.mitigated_damage(10)
	rolls.calm()
	hero.take_damage(10, target)
	got = _numbers()
	ck(got.size() == 1 and got[0].label.text == str(hurt) and got[0].label.label_settings.font_color == tokens.DAMAGE_NUMBER_HERO
			and tokens.DAMAGE_NUMBER_HERO != tokens.DAMAGE_NUMBER_ENEMY, "the hero's number: %s" % ", ".join(got.map(_describe)))
	ck(got.size() == 1 and got[0].global_position.y < _top(hero), "above the hero's head")
	await _clear()

	print("[5] An evaded hit shows a word, not 0 (D393)")
	await create_timer(0.6).timeout
	_lucky(gm.calculate_dodge_chance())
	hero.take_damage(10, target)
	got = _numbers()
	ck(got.size() == 1 and got[0].label.text == TranslationServer.translate("Evade") and got[0].label.text != "0"
			and got[0].label.label_settings.font_color == tokens.DAMAGE_NUMBER_EVADED, "the evade word: %s" % ", ".join(got.map(_describe)))
	var uk: Translation = load("res://SampleProject/Resources/Translations/uk.po")
	ck(uk.get_message("Evade") != "" and uk.get_message("Damage Numbers") != "", "the word and the row are translated (uk: %s, %s)" % [uk.get_message("Evade"), uk.get_message("Damage Numbers")])
	await _clear()

	print("[6] Settings -> Game -> Damage Numbers On/Off, persisted, restored")
	var ui: Node = sl.get_ui_manager()
	var opts: Node = await _open_settings(ui)
	var cells: Array = _segments(opts, "Damage Numbers")
	ck(cells.size() == 2 and _active(opts, "Damage Numbers").ends_with("On"), "a segmented On/Off row, On lit (%s)" % _active(opts, "Damage Numbers"))
	cells[1].pressed.emit()
	for i in 4: await process_frame
	ck(module.settings.damage_numbers == false and _active(opts, "Damage Numbers").ends_with("Off"), "Off pressed: setting off, Off lit")
	FileAccess.open(save_system.get_slot_path(save_system.current_slot), FileAccess.WRITE).store_string(var_to_str({"current_room": ":test"}))
	save_system.save_game_settings()
	module.settings.damage_numbers = true
	save_system.load_game_settings()
	ck(module.settings.damage_numbers == false, "Off survives a settings reload")
	ui.close_game_menu()
	for i in 10: await process_frame
	await create_timer(0.6).timeout
	combat.perform_attack(1)
	await create_timer(0.3).timeout
	hero.take_damage(10, target)
	ck(_numbers().is_empty(), "Off: no number on a hit or a hurt (%d)" % _numbers().size())
	opts = await _open_settings(ui)
	opts._on_restore_pressed()
	for i in 4: await process_frame
	ck(module.settings.damage_numbers == true and _active(opts, "Damage Numbers").ends_with("On"), "Restore Default Settings puts it back On")

	ck(rolls.rolls <= rolls.CALM_ROLLS, "inside the calm rolls (%d of %d)" % [rolls.rolls, rolls.CALM_ROLLS])
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()
