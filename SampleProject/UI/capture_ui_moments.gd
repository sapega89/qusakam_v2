extends SceneTree

## Знімки трьох моментів (cloud/ui-moments): сповіщення про рівень (D436), картка персонажа в журналі (D486),
## фінал демо (D473). Потрібне ВІКНО — під --headless кадр чорний.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 \
##       --script res://SampleProject/UI/capture_ui_moments.gd -- journal|level_up|finale [suffix]

const JournalRecords = preload("res://SampleProject/Scripts/Systems/journal_records.gd")

var _sl: Node
var _game: Node


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://design/shots/%s.png" % name
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("shot %s" % path)


func _close_modals() -> void:
	var modals: Node = _sl.get_ui_manager().get_modal_layer()
	if modals.active_modal != null:
		modals._close_with_result("", modals.active_modal)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0]
	var suffix: String = args[1] if args.size() > 1 else ""
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	set_meta("start_new_game", true)  # нова гра, а не slot_01 з user://
	_sl = root.get_node("ServiceLocator")
	_sl.get_dialogue_manager().bubble_time_scale = 0.0
	_game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(_game)
	current_scene = _game
	for i in 40: await process_frame
	match mode:
		"journal": await _journal(suffix)
		"level_up": await _level_up()
		"finale": await _finale()
	quit()


func _journal(suffix: String) -> void:
	for id in ["GRANDFATHER", "GATE_GUARD", "MERCHANT", "ALISIA"]:
		JournalRecords.meet_person(id)
	for i in 30:
		_close_modals()  # вікно туторіалу на старті гри
		await process_frame
	_sl.get_ui_manager().open_game_menu()
	for i in 20: await process_frame
	get_first_node_in_group("game_menu").switch_to_tab("Journal")
	for i in 8: await process_frame
	var journal: Node = get_first_node_in_group(&"journal_screen")
	journal.select_section("characters")
	for i in 12: await process_frame
	await _shot("ui_moments_journal_card%s" % suffix)
	if journal.has_method(&"show_next_person"):
		journal.show_next_person(1)
		journal.show_next_person(1)
		journal.toggle_description()
		for i in 12: await process_frame
		await _shot("ui_moments_journal_card_description%s" % suffix)


func _level_up() -> void:
	await _game.teleport_to_room("res://SampleProject/Maps/CraftQuarter.tscn", ^"ForgeDoor")
	for i in 30: await process_frame
	_close_modals()
	var xp: Node = _sl.get_xp_manager()
	xp.add_xp(xp.xp_for_next_level)
	await create_timer(0.6).timeout
	await _shot("ui_moments_level_up")


func _finale() -> void:
	for f in ["lab_companion_01_complete", "lab_companion_02_complete", "lab_companion_03_complete", "lab_cells_cutscene_complete", "lab_acquaintance_complete", "lab_corridors_complete", "lab_boss_fight_complete", "lab_after_boss_complete", "lab_outside_complete", "demo_end_complete"]:
		_game.set_quest_flag(f, true)
	await _game.teleport_to_room("res://SampleProject/Maps/LaboratoryOutside.tscn", ^"Arrival")
	var screen: Control = null
	while screen == null:
		await process_frame
		_close_modals()
		var found := _game.find_children("*", "Control", true, false).filter(func(n: Node) -> bool: return n.get_script() != null and n.get_script().resource_path.ends_with("DemoEndScreen.gd"))
		if not found.is_empty():
			screen = found[0]
	await create_timer(screen.HUD_FADE + screen.PAN_TIME * 0.5).timeout
	await _shot("ui_moments_finale_pan")
	await screen.finale_shown
	await _shot("ui_moments_finale_end")
