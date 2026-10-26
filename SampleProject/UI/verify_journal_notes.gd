extends SceneTree

## Journal → Notes (Q87, D622): знайдені шматки історії, справжнім вводом:
##   godot --headless --path . --script res://SampleProject/UI/verify_journal_notes.gd
##   1. Нова гра: четверта вкладка NOTES після BESTIARY (E / RB), порожній стан.
##   2. Горище діда: E на записах — одна модалка з текстом, друге E при відкритій модалці нічого не додає;
##      вкладка показує «Grandfather's notes» з повним текстом.
##   3. Порядок знахідок: ще два шматки (фікстура в user://) — список у тому порядку, як їх прочитано;
##      ↓ / ↑ по списку міняють текст справа, ↑ з першого рядка — на вкладки, Q / LB — назад до Bestiary.
##   4. Сейв → завантаження: ті самі записи в тому ж порядку.
## Пише лише в user://verify_journal_notes/ (сейв і фікстура текстів).

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const JournalRecords = preload("res://SampleProject/Scripts/Systems/journal_records.gd")
const ELDER := "res://SampleProject/Maps/ElderHouse.tscn"
const TEST_DIR := "user://verify_journal_notes/"
const FIXTURE := TEST_DIR + "journal_stories.json"
const TEST_SLOT := 1

var fails: Array[String] = []
var sl: Node

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _boot() -> Node:
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 60: await physics_frame
	return game


func _rows(journal: Node) -> Array:
	return journal._entry_list.get_children().filter(func(r: Control) -> bool: return r.visible).map(func(r: Button) -> String: return r.text)


func _open_notes() -> Node:
	await Kit.key(self, KEY_ESCAPE)
	await Kit.frames(self, 14)
	var menu: Node = get_first_node_in_group("game_menu")
	await Kit.mouse(self, menu.get_node("%JournalButton"))
	await Kit.frames(self, 6)
	var journal: Node = menu.find_child("JournalComponent", true, false)
	await Kit.key(self, KEY_E)
	await Kit.pad(self, JOY_BUTTON_RIGHT_SHOULDER)
	await Kit.key(self, KEY_E)
	return journal


func _close_menu() -> void:
	sl.get_ui_manager().close_game_menu()
	await Kit.frames(self, 6)


func _close_modal() -> void:
	var layer: Node = sl.get_ui_manager().get_modal_layer()
	layer.active_modal.get_viewport().gui_get_focus_owner().pressed.emit()
	await Kit.frames(self, 6)


func _initialize() -> void:
	await process_frame
	await process_frame
	root.size = Vector2i(1920, 1080)
	sl = root.get_node("ServiceLocator")
	var save_system: Node = root.get_node("SaveSystem")
	save_system.settings_module.settings.hints = false  # D728: no «?» tips in this run
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(TEST_SLOT)
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var layer: Node = sl.get_ui_manager().get_modal_layer()

	set_meta("start_new_game", true)
	var game: Node = await _boot()
	await Kit.drain(self)
	game.set_quest_flag("village_abduction_complete", true)  # Journal відкрита сюжетом (D151)

	print("[1] The fourth tab, empty at the start")
	var journal: Node = await _open_notes()
	var tabs: Array = journal.get_node("%SectionTabs").get_children().map(func(t: Button) -> String: return t.text)
	ck(tabs == ["QUESTS", "CHARACTERS", "BESTIARY", "NOTES"], "tabs: %s" % [tabs])
	ck(journal.section == "notes" and journal.get_node("%NotesTab").button_pressed and journal._heading.text == "Notes",
			"E, RB, E → Notes (%s)" % journal.section)
	ck(journal._empty_state.visible and journal._empty_state.text == "No notes found yet." and not journal._columns.visible,
			"empty state (%s)" % journal._empty_state.text)
	await _close_menu()

	print("[2] Reading the grandfather's notes in the attic")
	game.set_quest_flag("village_oldman_complete", true)
	await game.teleport_to_room(ELDER, ^"Arrival")
	for i in 20: await physics_frame
	var notes: Node = game.map.get_node("Attic/GrandfatherNotes")
	game.place_player(notes.global_position + Vector2(-20, -8))
	game.player.velocity = Vector2.ZERO
	for i in 30: await physics_frame
	ck(notes.get_node("Interactable").player_nearby, "next to the notes")
	await Kit.key(self, KEY_E)
	await Kit.frames(self, 6)
	var modal: Node = layer.active_modal
	ck(modal != null and Kit.modal_text(self).contains("The barrier is growing quiet"), "E: the modal with the notes")
	await Kit.key(self, KEY_E)
	await Kit.frames(self, 6)
	ck(layer.active_modal == modal, "E again while it is open: the same modal, no second one")
	ck(JournalRecords.stories().map(func(s: Dictionary) -> String: return s.id) == ["grandfather_notes"], "found once")
	await _close_modal()
	ck(layer.active_modal == null, "closed")
	journal = await _open_notes()
	ck(_rows(journal) == ["Grandfather's notes"] and journal._columns.visible and not journal._empty_state.visible,
			"Notes lists them (%s)" % [_rows(journal)])
	ck(journal._detail_title.text == "Grandfather's notes" and journal._detail_description.text.begins_with("The barrier is growing quiet")
			and journal._detail_description.text.ends_with("Someone must stay."), "the full text on the right")
	ck(not journal._detail_state.visible and not journal._portrait_frame.visible and not journal._objectives_caption.visible,
			"no state, portrait or objectives on a note")
	ck(journal._list_header.text == "NOTES FOUND", "list caption (%s)" % journal._list_header.text)
	await _close_menu()

	print("[3] Order of finding; keys and pad in the list")
	var real: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(JournalRecords.STORIES_FILE))
	real.stories.append({"id": "test_mural", "title": "Test mural", "text": "A mural of the Maiden.", "draft": true})
	real.stories.append({"id": "test_papers", "title": "Test papers", "text": "The alchemist's papers.", "draft": true})
	var f := FileAccess.open(FIXTURE, FileAccess.WRITE)
	f.store_string(JSON.stringify(real))
	f.close()
	JournalRecords.stories_file = FIXTURE
	JournalRecords.find_story("test_papers")  # у файлі після муралу, але знайдено раніше
	JournalRecords.find_story("test_mural")
	journal = await _open_notes()
	ck(_rows(journal) == ["Grandfather's notes", "Test papers", "Test mural"], "in the order found (%s)" % [_rows(journal)])
	var first: Control = journal._entry_list.get_children().filter(func(r: Control) -> bool: return r.visible)[0]
	first.grab_focus()
	await process_frame
	await Kit.key(self, KEY_DOWN)
	ck(journal.selected_id == "test_papers" and journal._detail_description.text == "The alchemist's papers.", "↓: the papers (%s)" % journal.selected_id)
	await Kit.pad(self, JOY_BUTTON_DPAD_DOWN)
	ck(journal.selected_id == "test_mural" and journal._detail_title.text == "Test mural", "D-pad ↓: the mural (%s)" % journal.selected_id)
	await Kit.mouse(self, first)
	ck(journal.selected_id == "grandfather_notes", "a click on the first title")
	first.grab_focus()
	await process_frame
	await Kit.pad(self, JOY_BUTTON_DPAD_UP)
	ck(root.gui_get_focus_owner() == journal.get_node("%NotesTab"), "D-pad ↑ from the first row: the Notes tab (%s)" % root.gui_get_focus_owner())
	await Kit.key(self, KEY_DOWN)
	ck(root.gui_get_focus_owner() == first, "↓ from the tab: back to the list (%s)" % root.gui_get_focus_owner())
	await Kit.pad(self, JOY_BUTTON_LEFT_SHOULDER)
	ck(journal.section == "bestiary", "LB → Bestiary")
	await Kit.key(self, KEY_E)
	await Kit.key(self, KEY_E)
	ck(journal.section == "quests", "E past Notes wraps to Quests")
	await _close_menu()

	print("[4] Save → load")
	ck(game.save_game(), "saved to slot %d" % TEST_SLOT)
	game.queue_free()
	for i in 4: await process_frame
	set_meta("start_new_game", false)
	set_meta("save_file_path", save_system.get_slot_path(TEST_SLOT))
	game = await _boot()
	ck(JournalRecords.stories().map(func(s: Dictionary) -> String: return s.id) == ["grandfather_notes", "test_papers", "test_mural"],
			"the same notes, the same order")
	journal = await _open_notes()
	ck(_rows(journal) == ["Grandfather's notes", "Test papers", "Test mural"], "the tab after loading (%s)" % [_rows(journal)])
	await _close_menu()

	JournalRecords.stories_file = JournalRecords.STORIES_FILE
	for file in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + file)
	DirAccess.remove_absolute(TEST_DIR)
	save_system.set_save_dir(save_system.SAVE_DIR)
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
