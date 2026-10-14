extends SceneTree

## Знімок журналу з Прологом посеред гри (D120): Canyon I і Village пройдено,
## поточний Canyon II — з хронікою пройденого і ціллю. Потрібне ВІКНО — під --headless кадр чорний.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_journal_prologue.gd

const OUT := "res://design/shots/journal_prologue_1920.png"


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var flags := {}
	for flag in ["canyon_intro_complete", "canyon_exploration_complete", "canyon_abduction_complete",
			"village_abduction_complete", "village_arrival_complete", "village_fight_complete",
			"village_oldman_met", "village_oldman_healed", "village_oldman_complete", "village_left_complete", "canyon_relic_meditation_complete"]:
		flags[flag] = true
	game.set_quest_flags(flags)
	game.set_objective("Descend to the road")

	var ui: Node = root.get_node("ServiceLocator").get_ui_manager()
	ui.open_game_menu()
	for i in 20: await process_frame
	get_first_node_in_group("game_menu").switch_to_tab("Journal")
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT))
	print("shot %s" % OUT)
	quit()
