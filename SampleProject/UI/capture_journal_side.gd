extends SceneTree

## Знімок сторінки «Побічні історії» журналу (D791, Figma 192:1636) англійською й українською: караван торговця
## і шолом коваля скінчено, зачарування й Малік — тривають; відкрита картка каравану (кінець і нагорода).
## Потрібне ВІКНО — під --headless кадр чорний.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_journal_side.gd

const OUT := "res://design/shots/journal_side_%s_1920.png"


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	set_meta("start_new_game", true)  # нова гра, а не slot_01 з user://
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	# Вступ Canyon — діалог; під час діалогу меню не відкривається (D136): проклацуємо, як verify_journal.
	var dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	for i in 600:
		if not dm.is_dialogue_active():
			break
		dm.current_dialogue_box.finish()
		dm.current_dialogue_player.accept()
		await process_frame
	var flags := {}
	for flag in ["canyon_intro_complete", "canyon_exploration_complete", "canyon_abduction_complete",
			"village_abduction_complete", "village_arrival_complete", "village_fight_complete",
			"village_oldman_met", "village_oldman_healed", "village_oldman_complete", "village_left_complete",
			"canyon_exit_complete", "desert_road_fight_complete", "city_gates_intro_complete",
			"city_gates_fight_complete", "city_gates_after_fight_complete", "lab_cells_cutscene_complete",
			"lab_acquaintance_complete", "task_merchant_caravan_taken", "task_merchant_caravan_done",
			"task_smith_helmet_taken", "task_smith_helmet_done", "task_smith_enchant_taken",
			"task_malik_escort_taken"]:
		flags[flag] = true
	game.set_quest_flags(flags)
	game.set_objective("Fight through the laboratory")

	var ui: Node = root.get_node("ServiceLocator").get_ui_manager()
	ui.open_game_menu()
	for i in 20: await process_frame
	get_first_node_in_group("game_menu").switch_to_tab("Journal")
	for locale in ["en", "uk"]:
		TranslationServer.set_locale(locale)
		var journal: Node = get_first_node_in_group("journal_screen")
		journal.select_section("side")
		journal.selected_id = "side/merchant_caravan"
		journal.update_display()
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT % locale))
		print("shot %s" % (OUT % locale))
	TranslationServer.set_locale("en")
	quit()
