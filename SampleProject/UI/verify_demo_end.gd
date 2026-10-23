extends SceneTree

## Кінець демо за лабораторією (B66): перший вихід у LaboratoryOutside — розмови й екран кінця демо;
## повернутися в лабораторію й вийти знову — екран кінця демо теж (раніше машина станів застрягала).
## Фінал (D473): HUD гасне, камера пливе в небо, музика тихо наростає, потім титул і кнопка у фокусі.
##   godot --headless --path . --script res://SampleProject/UI/verify_demo_end.gd

var fails: Array[String] = []

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

func _end_screens(game: Node) -> Array:
	return game.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.get_script() != null and n.get_script().resource_path.ends_with("DemoEndScreen.gd"))

func _finale(game: Node) -> void:
	print("[1b] The finale (D473)")
	var screen: Control = _end_screens(game)[0]
	var music: AudioStreamPlayer = game.map.get_node(^"Music")
	var sky_top: float = game.map.get_node(^"HighSky").global_position.y
	var camera: Camera2D = game.player.get_node(^"Camera2D")
	var start_y := camera.get_screen_center_position().y
	var start_db := music.volume_db
	ck(screen.get_node(^"VBoxContainer/GameTitle").modulate.a == 0.0 and screen.return_button.disabled, "title hidden and button off while the finale plays")
	ck(game.player.event, "control is off")
	await create_timer(screen.HUD_FADE + 0.3).timeout
	var hud: CanvasItem = game.get_node(^"UICanvas/CombatHUD")
	ck(hud.modulate.a == 0.0, "the HUD faded out (%.2f)" % hud.modulate.a)
	ck(camera.top_level, "the camera left the hero")
	var shown := [false]
	screen.finale_shown.connect(func() -> void: shown[0] = true)
	# Вікно туторіалу, що відкрилось після розмови, ставить гру на паузу — фінал чекає, доки його закриють.
	var modals: Node = game.get_tree().root.get_node("ServiceLocator").get_ui_manager().get_modal_layer()
	var deadline := Time.get_ticks_msec() + 15000
	while not shown[0] and Time.get_ticks_msec() < deadline:
		if modals.active_modal != null:
			modals._close_with_result("", modals.active_modal)
		await process_frame
	ck(shown[0], "the finale played to the end")
	var view_h: float = screen.get_viewport_rect().size.y / camera.zoom.y
	var end_y := camera.get_screen_center_position().y
	ck(end_y < start_y - 300.0 and absf(end_y - (sky_top + view_h / 2.0)) < 2.0, "the camera rose into the sky (%.0f → %.0f, sky top %.0f)" % [start_y, end_y, sky_top])
	ck(music.volume_db > start_db and music.pitch_scale < 1.0, "the music swelled low (%.1f dB, pitch %.2f)" % [music.volume_db, music.pitch_scale])
	ck(screen.get_node(^"VBoxContainer/GameTitle").modulate.a == 1.0 and screen.get_node(^"VBoxContainer/Farewell").modulate.a == 1.0, "title and farewell shown")
	ck(screen.get_node(^"VBoxContainer/GameTitle/TitleLabel").get_theme_font_size(&"font_size") == UITokens.SIZE_TITLE_KHALAHAS, "the main menu's title")
	ck(not screen.return_button.disabled and screen.get_viewport().gui_get_focus_owner() == screen.return_button, "Return to Main Menu has the focus")
	ck(screen.return_button.theme_type_variation == &"ModalButtonOn", "the kit HexButton")

func _initialize() -> void:
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await _drain(dm)
	for f in ["lab_companion_01_complete", "lab_companion_02_complete", "lab_companion_03_complete", "lab_cells_cutscene_complete", "lab_acquaintance_complete", "lab_corridors_complete", "lab_boss_fight_complete", "lab_after_boss_complete"]:
		game.set_quest_flag(f, true)

	print("[1] First time out of the laboratory: the talks, then the demo end screen")
	await game.teleport_to_room("res://SampleProject/Maps/LaboratoryOutside.tscn", ^"Arrival")
	for i in 20: await process_frame
	await _drain(dm)
	for i in 30: await process_frame
	ck(game.get_quest_flag("lab_outside_complete") and game.get_quest_flag("demo_end_complete"), "both closing talks read")
	ck(_end_screens(game).size() == 1, "the demo end screen shows (%d)" % _end_screens(game).size())
	await _finale(game)
	for s in _end_screens(game):
		s.queue_free()
	await process_frame

	print("[2] Back into the laboratory and out again: the demo still ends (B66)")
	await game.teleport_to_room("res://SampleProject/Maps/Laboratory.tscn", ^"SavePoint_PreBoss")
	for i in 20: await process_frame
	await _drain(dm)
	await game.teleport_to_room("res://SampleProject/Maps/LaboratoryOutside.tscn", ^"Arrival")
	for i in 30: await process_frame
	await _drain(dm)
	ck(_end_screens(game).size() == 1, "the demo end screen shows again (%d)" % _end_screens(game).size())

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()
