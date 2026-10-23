extends SceneTree

## Знімок вкладки Journal → Notes (Q87): порожній стан і знайдені дідові записи, en та uk.
## Потрібне ВІКНО — під --headless кадр чорний.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_journal_notes.gd

const JournalRecords = preload("res://SampleProject/Scripts/Systems/journal_records.gd")
const OUT := "res://design/shots/journal_notes_%s.png"


func _shot(tag: String) -> void:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT % tag))
	print("shot %s" % (OUT % tag))


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289: без вікон навчання
	set_meta("start_new_game", true)  # нова гра, а не slot_01 з user://
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	game.set_quest_flag("village_abduction_complete", true)

	var ui: Node = root.get_node("ServiceLocator").get_ui_manager()
	ui.open_game_menu()
	for i in 20: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Journal")
	for i in 6: await process_frame
	var journal: Node = menu.find_child("JournalComponent", true, false)
	journal.select_section("notes")
	await _shot("empty")
	JournalRecords.find_story("grandfather_notes")
	journal.select_section("notes")
	await _shot("en")
	TranslationServer.set_locale("uk")
	journal.select_section("notes")
	await _shot("uk")
	quit()
