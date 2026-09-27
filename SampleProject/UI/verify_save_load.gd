extends SceneTree

## Самоперевірка slice 1b: Save/Load shared logic.
##   godot --headless --path . --script res://SampleProject/UI/verify_save_load.gd
##
## Figma: load-game-screen 150:1278, save-game-screen 17:5, overwrite 258:5162.
## Рішення: D74–D80, Q3/Q4/Q5/Q7 (типові відповіді).
## Працює в окремій теці user://verify_saves — справжні сейви не чіпає.

const MENU_SCENE := "res://SampleProject/Scenes/Menus/LoadGameMenu.tscn"
const TEST_DIR := "user://verify_saves/"

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

var ss: Node
var ui: Node


func _wipe_test_dir() -> void:
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)


## Тестовий сейв у тестовій теці — формат такий самий, як пише Game.save_game()
## (var_to_str словника SaveManager.data). SaveManager тут не завантажити: він
## посилається на autoload MetSys, недоступний під час компіляції --script.
func _make_slot(slot: int, room: String, meta: Dictionary) -> void:
	var f := FileAccess.open(ss.get_slot_path(slot), FileAccess.WRITE)
	f.store_string(var_to_str({"current_room": room}))
	f.close()
	ss.set_slot_metadata(slot, meta)


func _modal() -> Node:
	var layer = ui.get_modal_layer()
	return layer.active_modal if layer else null


func _press_modal(text: String) -> void:
	var modal := _modal()
	if modal == null:
		return
	for b in modal.buttons_container.get_children():
		if b is Button and b.visible and b.text == text:
			b.pressed.emit()
			return


func _menu(mode: String, handler: Callable = Callable()) -> Node:
	var menu: Node = load(MENU_SCENE).instantiate()
	menu.set_use_state_navigation(true)
	menu.load_target_scene = ""
	if handler.is_valid():
		menu.save_handler = handler
	menu.set_mode(mode)
	root.add_child(menu)
	return menu


func _initialize() -> void:
	await process_frame
	await process_frame
	var sl: Node = root.get_node("ServiceLocator")
	ss = sl.get_save_system()
	ui = sl.get_ui_manager()
	var theme: Theme = load("res://SampleProject/UI/Themes/GameUITheme.tres")

	ss.set_save_dir(TEST_DIR)
	_wipe_test_dir()
	ss.set_save_dir(TEST_DIR)

	print("[1] Shared theme + no local styling")
	ck(theme.has_stylebox("focus", "SaveSlotCard"), "SaveSlotCard focus style in GameUITheme")
	ck(theme.get_stylebox("focus", "SaveSlotCard").border_color == UITokens.ACCENT, "selected slot border is accent")
	ck(theme.get_stylebox("normal", "SaveSlotCard").border_color == UITokens.SAVE_CARD_BORDER, "unselected slot border is white")
	for path in [MENU_SCENE, "res://SampleProject/UI/Components/save_slot_card.tscn"]:
		var txt := FileAccess.open(path, FileAccess.READ).get_as_text()
		ck(txt.find("theme_override") == -1 and txt.find("StyleBox") == -1, "no local styles in %s" % path.get_file())

	print("[2] Player data is per slot (Q4)")
	ck(ss.get_player_data_path(1) != ss.get_player_data_path(2), "slots have distinct player-data files")
	ss.set_current_slot(2)
	ck(ss.save_player_data(), "save_player_data() succeeds")
	ck(FileAccess.file_exists(ss.get_player_data_path(2)), "slot 2 player data written")
	ck(not FileAccess.file_exists(ss.get_player_data_path(1)), "slot 1 untouched")
	ck(ss.save_dir == TEST_DIR, "tests write only to %s" % TEST_DIR)

	print("[3] Slot summary carries only real data (Q3)")
	_wipe_test_dir()
	ss.set_save_dir(TEST_DIR)
	# Поточний слот сесії отримує "живий" час гри — тестові дані кладемо в інші слоти.
	ss.set_current_slot(4)
	_make_slot(1, "Canyon", {"timestamp": "2026-09-23T00:05:12", "location": "Canyon",
			"level": 7, "character_name": "Kael", "playtime_sec": 3900.0})
	_make_slot(3, "Village", {"timestamp": "2026-09-22T17:27:00", "location": "Village",
			"playtime_sec": 120.0})
	var s1: Dictionary = ss.get_slot_summary(1)
	var s2: Dictionary = ss.get_slot_summary(2)
	var s3: Dictionary = ss.get_slot_summary(3)
	ck(s1.exists and s1.location == "Canyon" and s1.level == 7 and s1.character_name == "Kael", "slot 1 summary")
	ck(not s2.exists, "slot 2 empty")
	ck(s3.exists and not s3.has("level") and not s3.has("character_name"), "slot 3 has no invented level/name")

	print("[4] LOAD mode: empty slots disabled, occupied loads directly (D77, D78)")
	var menu := _menu("load")
	await process_frame
	await process_frame
	var cards: Array = menu._cards
	ck(cards.size() == 4, "4 slot cards")
	ck(menu._title.text == "Load Game", "title reads Load Game")
	ck(cards[0].is_selectable() and cards[2].is_selectable(), "occupied slots selectable")
	ck(not cards[1].is_selectable() and cards[1].card.disabled, "empty slot 2 disabled")
	ck(cards[1].card.focus_mode == Control.FOCUS_NONE and cards[3].card.focus_mode == Control.FOCUS_NONE,
			"empty slots cannot take focus")
	ck(cards[1]._empty.visible and not cards[1]._info.visible, "empty card shows the empty state")
	var focus = menu.get_viewport().gui_get_focus_owner()
	ck(focus == cards[0].card, "first occupied slot focused")
	ck(cards[0]._cursor.visible and not cards[2]._cursor.visible, "cursor marks the focused slot only")
	ck(cards[0]._location.text == "Canyon", "location shown")
	ck(cards[0]._date.text == "9/23/2026 00:05", "date in Figma format (%s)" % cards[0]._date.text)
	ck(cards[0]._level.text == "Lv. 7" and cards[0]._name.text == "Kael", "level + lead character")
	ck(cards[0]._playtime.text == "001:05", "playtime hhh:mm (%s)" % cards[0]._playtime.text)
	ck(not cards[2]._character.visible, "no level/name shown when not saved")
	ck(cards[0].card.size.y == UITokens.SAVE_CARD_HEIGHT, "card height 176 (%d)" % int(cards[0].card.size.y))
	var closed := [""]
	menu.menu_closed.connect(func(a): closed[0] = a)
	menu._on_slot_activated(2)
	await process_frame
	ck(closed[0] == "" and _modal() == null, "activating an empty slot in LOAD does nothing")
	menu._on_slot_activated(3)
	await process_frame
	ck(closed[0] == "load", "occupied slot loads immediately")
	ck(_modal() == null, "no load confirmation (D78)")
	ck(ss.current_slot == 3, "current slot switched to 3")
	ck(get_meta("save_file_path", "") == ss.get_slot_path(3), "load path handed to Game")
	remove_meta("save_file_path")
	remove_meta("start_new_game")
	menu.queue_free()
	await process_frame

	print("[5] SAVE mode: save, overwrite, success and failure (D76, D78, D79)")
	var calls := [0]
	var result := [true]
	var handler := func() -> bool:
		calls[0] += 1
		return result[0]
	menu = _menu("save", handler)
	await process_frame
	await process_frame
	cards = menu._cards
	ck(menu._title.text == "Save Game", "title reads Save Game")
	ck(cards.all(func(c): return c.is_selectable()), "all slots selectable in SAVE")
	closed[0] = ""
	menu.menu_closed.connect(func(a): closed[0] = a)
	menu._on_slot_activated(2)
	await process_frame
	ck(calls[0] == 1 and ss.current_slot == 2, "empty slot saves at once, into slot 2")
	ck(_modal() != null and _modal().title_label.text == "Game Saved", "\"Game Saved\" confirmation")
	ck(_modal() != null and _modal().description_label.text == "Your progress has been saved successfully.", "D76 body text")
	ck(closed[0] == "", "save UI stays until the player confirms")
	_press_modal("OK")
	await process_frame
	ck(closed[0] == "save", "OK closes the save UI")

	closed[0] = ""
	menu._on_slot_activated(1)
	await process_frame
	var m := _modal()
	ck(m != null and m.title_label.text == "Overwrite Save?", "occupied slot asks to overwrite")
	ck(m != null and m.description_label.text == "This will replace the existing save data.", "Figma overwrite copy")
	_press_modal("No")
	await process_frame
	ck(calls[0] == 1 and _modal() == null, "No cancels without saving")
	menu._on_slot_activated(1)
	await process_frame
	_press_modal("Yes")
	await process_frame
	ck(calls[0] == 2, "Yes saves")
	ck(_modal() != null and _modal().title_label.text == "Game Saved", "success after overwrite")
	_press_modal("OK")
	await process_frame

	result[0] = false
	closed[0] = ""
	menu._on_slot_activated(4)
	await process_frame
	ck(_modal() != null and _modal().title_label.text == "Save Failed", "failure shows the error modal (D79)")
	_press_modal("OK")
	await process_frame
	ck(closed[0] == "", "failure keeps the save UI open")
	ck(_modal() == null, "no success modal after a failure")
	menu.queue_free()
	await process_frame

	print("[6] Delete slot is kept (Q7)")
	menu = _menu("load")
	await process_frame
	menu._request_delete(3)
	await process_frame
	ck(_modal() != null and _modal().title_label.text == "Delete Save", "delete asks for confirmation")
	_press_modal("Delete")
	await process_frame
	ck(not ss.slot_has_save(3), "slot 3 deleted")
	ck(not menu._cards[2].is_selectable(), "deleted slot becomes an empty, disabled card")
	menu.queue_free()
	await process_frame

	print("[7] Save point: prompt → SAVE mode, no auto-save (D74, D75, Q5)")
	var sp := Area2D.new()
	sp.set_script(load("res://SampleProject/Scripts/SavePoint.gd"))
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	shape.shape = CircleShape2D.new()
	sp.add_child(shape)
	root.add_child(sp)
	await process_frame
	ck(sp.interactable != null and sp.interactable.action_text == "Save", "prompt reads \"Save\"")
	var src := FileAccess.open("res://SampleProject/Scripts/SavePoint.gd", FileAccess.READ).get_as_text()
	ck(src.find("body_entered.connect") == -1 and src.find(".save_game()") == -1, "no auto-save on touch")
	var files_before := DirAccess.get_files_at(TEST_DIR).size()
	var player := CharacterBody2D.new()
	player.add_to_group(GameGroups.PLAYER)
	root.add_child(player)
	sp.interactable._on_body_entered(player)
	await process_frame
	ck(DirAccess.get_files_at(TEST_DIR).size() == files_before, "walking onto the save point writes nothing")
	sp.interactable.interacted.emit()
	for i in 6: await process_frame
	ck(ui.current_state_name == "SaveGameState", "interact opens Save Slot Selection (%s)" % ui.current_state_name)
	var save_menu := get_first_node_in_group(&"save_slot_menu")
	ck(save_menu != null and save_menu.mode == "save", "opened in SAVE mode")
	ui.close_state()
	sp.queue_free()

	ss.set_save_dir(ss.SAVE_DIR)
	_wipe_dir_only()
	_done()


func _wipe_dir_only() -> void:
	var dir := DirAccess.open(TEST_DIR)
	if dir:
		for f in dir.get_files():
			dir.remove(f)
		DirAccess.remove_absolute(TEST_DIR)


func _done() -> void:
	print("")
	if fails.is_empty():
		print("RESULT: ALL PASS")
	else:
		print("RESULT: %d FAIL" % fails.size())
		for f in fails:
			print("    : " + f)
	quit(0 if fails.is_empty() else 1)
