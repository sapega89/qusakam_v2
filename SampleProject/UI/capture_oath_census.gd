extends SceneTree

## Перепис біля брами (D727, D728) і герби шляхів у Журналі (D725) — кадри в теку з аргументу
## (за замовчуванням design/shots/oath_census):
##   census_scribe — писар біля брами після бою, перша репліка (uk);
##   census_serve  — «Кому служиш?» з чотирма відповідями (uk);
##   census_advice — порада писаря і «Та ні, краще…» (uk);
##   census_en     — «Whom do you serve?» англійською;
##   journal_emblems — «Персонажі» в Журналі: три герби, яскравіші з нахилом;
##   priests       — троє жерців шляхів у місті (жрець контрактів у чорному й золоті).
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 \
##       --script res://SampleProject/UI/capture_oath_census.gd -- <dir>

const Kit = preload("res://SampleProject/UI/input_kit.gd")

var out: String
var dm: Node


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("%s.png" % name))


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
	await process_frame


## Enter гортає, доки не з'являться відповіді; репліку перед ними набирає до кінця.
func _to_choice() -> void:
	for i in 400:
		if dm.current_dialogue_player.choice_menu.visible:
			return
		await _key(KEY_ENTER)
	await Kit.frames(self, 20)


func _choose(index: int) -> void:
	for i in index:
		await _key(KEY_DOWN)
	await _key(KEY_ENTER)


func _gate_fight(game: Node) -> void:
	game.set_quest_flag("city_gates_intro_complete", true)
	await game.teleport_to_room("res://SampleProject/Maps/CityGates.tscn", ^"Arrival")
	await Kit.frames(self, 30)
	await Kit.drain(self)
	await Kit.frames(self, 30)
	for enemy in game.map.find_children("*", "CharacterBody2D", true, false):
		if enemy.is_in_group(&"enemies") and enemy.is_alive():
			enemy.take_damage(99999, game.player)
	for i in 300:
		await process_frame
		if dm.is_dialogue_active():
			break
	game.player.global_position = game.map.get_node("GateScribe").global_position + Vector2(-70, -10)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://design/shots/oath_census")
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false
	var game: Node = await Kit.boot(self)
	var sl: Node = root.get_node("ServiceLocator")
	dm = sl.get_dialogue_manager()
	var sm: Node = sl.get_skill_manager()
	var loc: Node = root.get_node("LocalizationManager")

	# Перепис українською: «Не знаю» → питання → порада.
	loc.apply_language("uk")
	await _gate_fight(game)
	await Kit.frames(self, 40)
	dm.current_dialogue_box.finish()
	await Kit.frames(self, 4)
	await _shot("census_scribe")
	await _to_choice()
	await Kit.frames(self, 10)
	await _shot("census_serve")
	await _choose(3)
	for q in 3:
		await _to_choice()
		await _choose(0)
	await _to_choice()
	await Kit.frames(self, 10)
	await _shot("census_advice")
	await _choose(1)
	await Kit.drain(self)

	# Те саме питання англійською (старий сейв: клятви немає — перепис з меню писаря).
	loc.apply_language("en")
	sl.get_game_manager().player_state.oath = ""
	var scribe: Node = game.map.get_node("GateScribe")
	scribe.start_census()
	await _to_choice()
	await Kit.frames(self, 10)
	await _shot("census_en")
	await _choose(0)
	await Kit.drain(self)

	# Журнал: герби (Самаль сильний, контракт — середній, без бога — слабкий).
	sm.leanings.add("samal", 9.0 - sm.leanings.values().samal)
	sm.leanings.add("contract", 5.0 - sm.leanings.values().contract)
	sm.leanings.add("none", 1.5 - sm.leanings.values().none)
	loc.apply_language("uk")
	game.set_quest_flag("city_gates_after_fight_complete", true)
	sl.get_ui_manager().open_game_menu()
	await Kit.frames(self, 14)
	get_first_node_in_group("game_menu").switch_to_tab("Journal")
	await Kit.frames(self, 10)
	get_first_node_in_group("journal_screen").select_section("characters")
	await Kit.frames(self, 20)
	await _shot("journal_emblems")
	sl.get_ui_manager().close_game_menu()
	await Kit.frames(self, 10)

	# Жерці шляхів у місті.
	await game.teleport_to_room("res://SampleProject/Maps/City.tscn", ^"SavePoint")
	for i in 40: await physics_frame
	await Kit.drain(self)
	game.player.global_position = game.map.get_node("OathWitch").global_position + Vector2(-60, -10)
	for i in 60: await physics_frame
	await _shot("priests")
	quit()
