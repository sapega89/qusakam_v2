extends SceneTree

## Журнал → Побічні історії (D791, Figma journal-side-stories 192:1636), справжній ввід:
##   godot --headless --path . --script res://SampleProject/UI/verify_side_stories.gd
##   1. Порожня сторінка до першого завдання; вкладки локацій унизу: All + кожна з locations.json.
##   2. Узяте в коваля «Шолом» → рядок «◆» під «THE CITY»; картка: замовник, мітки стану й локації, його слова, ціль,
##      нагорода; кінця ще немає. На сторінці Quests завдання немає.
##   3. Зданий шолом → «✓», мітка «Completed», кінець історії.
##   4. Вкладки локацій: ↓ з останнього рядка — на вкладку, →/Enter — Лабораторія (порожньо), мишею — знову All.
##   5. Українською: мітки, лапки «», чернетки слів і кінця перекладені.

const Kit = preload("res://SampleProject/UI/input_kit.gd")

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _rows(journal: Node) -> Array:
	return journal._entry_list.get_children().filter(func(r: Control) -> bool: return r.visible).map(func(r: Button) -> String: return r.text)


func _open_side(menu_key: bool = true) -> Node:
	if menu_key:
		await Kit.key(self, KEY_ESCAPE)
		await Kit.frames(self, 14)
	var menu: Node = get_first_node_in_group("game_menu")
	await Kit.mouse(self, menu.get_node("%JournalButton"))
	await Kit.frames(self, 6)
	var journal: Node = menu.find_child("JournalComponent", true, false)
	await Kit.pad(self, JOY_BUTTON_RIGHT_SHOULDER)
	await Kit.frames(self, 2)
	return journal


func _close() -> void:
	await Kit.key(self, KEY_ESCAPE)
	await Kit.frames(self, 8)


## Нагорода — вікно «You obtained:»; закриваємо його, як гравець (кнопка у фокусі).
func _close_obtained() -> void:
	var ui: Node = root.get_node("ServiceLocator").get_ui_manager()
	var layer: Node = ui.get_modal_layer()
	for i in 120:
		var ok_button: Control = layer.active_modal.get_viewport().gui_get_focus_owner() if layer.active_modal else null
		if ok_button != null:
			ok_button.pressed.emit()
		elif layer.active_modal == null and not ui.has_pending_obtained() and i > 10:
			break
		await process_frame


func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: без «?» у цьому прогоні
	var game: Node = await Kit.boot(self)
	game.set_quest_flag("village_abduction_complete", true)  # Журнал відкрито сюжетом (D151)
	var sl: Node = root.get_node("ServiceLocator")
	var inv: Node = sl.get_inventory_manager()

	print("[1] Empty before the first task; region tabs along the bottom")
	var journal: Node = await _open_side()
	ck(journal.section == "side" and journal.get_node("%SideTab").button_pressed and journal._heading.text == "Side Stories",
			"pad RB from Quests → Side Stories")
	ck(journal._empty_state.visible and journal._empty_state.text == "No side stories here yet.", "nothing taken yet → empty state")
	var tabs: Array = journal._region_tabs.get_children().filter(func(b: Control) -> bool: return b.visible).map(func(b: Button) -> String: return b.text)
	ck(journal._region_tabs.visible and tabs == ["ALL", "CANYON OF WHISPERS", "THE CITY", "THE LABORATORY"],
			"All + one tab per location (%s)" % [tabs])
	ck(journal.get_node("%RegionTabs/Region_all").button_pressed, "All is selected")
	await _close()

	print("[2] The Helmet taken from the Blacksmith → an active side story")
	var smith: Node = load("res://SampleProject/Scenes/Gameplay/Objects/NPCs/blacksmith.tscn").instantiate()
	game.add_child(smith)
	await process_frame
	smith.interactable.interacted.emit()
	await process_frame
	smith.npc_menu.chosen.emit(&"task")
	await Kit.frames(self, 6)
	await Kit.drain(self)
	ck(game.get_quest_flag("task_smith_helmet_taken"), "task_smith_helmet taken")
	journal = await _open_side()
	ck(_rows(journal) == ["THE CITY", "◆  The Helmet"], "under its location, marked ◆ (%s)" % [_rows(journal)])
	ck(journal.selected_id == "side/smith_helmet" and journal._detail_title.text == "The Helmet", "its card is open")
	ck(journal._client_label.visible and journal._client_label.text == "CLIENT: BLACKSMITH", "the client (%s)" % journal._client_label.text)
	var portrait: Texture2D = root.get_node("DialogueQuest").CharacterDB.get_character_from_id("BLACKSMITH").portrait
	ck(journal._portrait_frame.visible and journal._portrait.texture == portrait, "the client's portrait (D321)")
	ck(journal._story_tags.visible and journal._state_tag.text == "IN PROGRESS" and journal._region_tag.text == "THE CITY",
			"tags: state and location (%s / %s)" % [journal._state_tag.text, journal._region_tag.text])
	ck(not journal._detail_state.visible, "the tags replace the eyebrow line")
	ck(journal._quote.visible and journal._quote.text == "“A helmet you forged yourself sits better on the head than a bought one.”",
			"the client's words (%s)" % journal._quote.text)
	var goal: Array = journal._objective_list.get_children().filter(func(l: Control) -> bool: return l.visible)
	ck(journal._objectives_caption.visible and goal.size() == 1 and goal[0].text.contains("forge an Iron Helmet"), "the goal while it is active")
	ck(not journal._outcome.visible and not journal._outcome_caption.visible, "no outcome yet")
	var rewards: Array = journal._reward_list.get_children().filter(func(l: Control) -> bool: return l.visible).map(func(l: Label) -> String: return l.text)
	ck(journal._rewards_caption.visible and rewards == ["◆  Coin × 88"], "the reward (%s)" % [rewards])
	await Kit.pad(self, JOY_BUTTON_LEFT_SHOULDER)
	ck(journal.section == "quests" and journal.entries.all(func(e: Dictionary) -> bool: return not e.id.contains("smith_helmet")),
			"not on the Quests page")
	await _close()

	print("[3] The helmet shown → done, with its outcome")
	inv.add_item("iron_helmet", 1)
	smith.interactable.interacted.emit()
	await process_frame
	smith.npc_menu.chosen.emit(&"task")
	await Kit.frames(self, 6)
	await Kit.drain(self)
	await _close_obtained()
	ck(game.get_quest_flag("task_smith_helmet_done"), "task_smith_helmet done")
	journal = await _open_side()
	ck(_rows(journal) == ["THE CITY", "✓  The Helmet"], "marked ✓, the next task not taken yet (%s)" % [_rows(journal)])
	ck(journal._state_tag.text == "COMPLETED", "tag: Completed (%s)" % journal._state_tag.text)
	ck(journal._outcome.visible and journal._outcome_caption.visible and journal._outcome.text.begins_with("The rivets came out crooked"),
			"the outcome (%s)" % journal._outcome.text)
	ck(not journal._objectives_caption.visible, "no goal once it is done")

	print("[4] Region tabs: keyboard / pad and mouse")
	var last_row: Button = journal._entry_list.get_children().filter(func(r: Control) -> bool: return r.visible and r.focus_mode == Control.FOCUS_ALL)[-1]
	last_row.grab_focus()
	await process_frame
	await Kit.pad(self, JOY_BUTTON_DPAD_DOWN)
	ck(root.gui_get_focus_owner() == journal.get_node("%RegionTabs/Region_all"), "D-pad ↓ from the last row → the All tab (%s)" % root.gui_get_focus_owner())
	for i in 3:
		await Kit.key(self, KEY_RIGHT)
	ck(root.gui_get_focus_owner() == journal.get_node("%RegionTabs/Region_laboratory"), "→ to the Laboratory tab (%s)" % root.gui_get_focus_owner())
	await Kit.key(self, KEY_ENTER)
	ck(journal.region == "laboratory" and journal._empty_state.visible and journal._region_tabs.visible, "Enter → only the Laboratory: empty")
	ck(root.gui_get_focus_owner() == journal.get_node("%RegionTabs/Region_laboratory"), "focus stays on the tab")
	await Kit.mouse(self, journal.get_node("%RegionTabs/Region_city"))
	ck(journal.region == "city" and _rows(journal) == ["THE CITY", "✓  The Helmet"], "mouse → the City (%s)" % [_rows(journal)])
	await Kit.mouse(self, journal.get_node("%RegionTabs/Region_all"))
	ck(journal.region == "all" and journal.selected_id == "side/smith_helmet", "mouse → All again")

	print("[5] Ukrainian")
	TranslationServer.set_locale("uk")
	journal.select_section("side")
	await Kit.frames(self, 2)
	ck(journal._state_tag.text == "СКІНЧЕНО" and journal._region_tag.text == "МІСТО", "uk tags (%s / %s)" % [journal._state_tag.text, journal._region_tag.text])
	ck(journal._quote.text == "«Шолом, який сам скував, на голові сидить краще за куплений.»", "uk quote in «» (%s)" % journal._quote.text)
	ck(journal._client_label.text == "ЗАМОВНИК: КОВАЛЬ", "uk client (%s)" % journal._client_label.text)
	ck(journal._outcome.text.begins_with("Заклепки вийшли криві"), "uk outcome")
	var po_uk := FileAccess.get_file_as_string("res://SampleProject/Resources/Translations/uk.po")
	var po_en := FileAccess.get_file_as_string("res://SampleProject/Resources/Translations/en.po")
	var tasks: Array = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/quests.json")).tasks
	var drafts_ok := tasks.all(func(t: Dictionary) -> bool:
		return ["quote", "outcome"].all(func(k: String) -> bool:
			var key := 'msgid "%s"' % String(t[k]).replace('"', '\\"')
			return po_uk.contains("# [ЧЕРНЕТКА] D791\n" + key) and po_en.contains("# [DRAFT] D791\n" + key)))
	ck(drafts_ok, "every task's quote and outcome is a draft in uk.po and en.po")
	TranslationServer.set_locale("en")

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
