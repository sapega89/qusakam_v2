extends SceneTree

## Фінальна наскрізна регресія UI (Phase 5.15).
##   godot --headless --path . --script res://SampleProject/UI/verify_full_regression.gd
##
## Не дублює перевірки окремих екранів — перевіряє, що всі вони співіснують:
## шел, кожна вкладка, модалка, бойовий HUD, і що нічого не ламається при
## багаторазовому перемиканні.

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

const TABS := {
	"Inventory": "InventoryComponent",
	"Equipment": "EquipmentComponent",
	"Status": "StatsComponent",
	"Skills": "SkillsComponent",
	"World Map": "MetSysMapComponent",
	"Journal": "JournalComponent",
	"Misc": "OptionsComponent",
}


func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289: hints as banners, the game never pauses under a window
	await process_frame
	await process_frame
	var sl: Node = root.get_node_or_null("ServiceLocator")
	var ui: Node = sl.get_ui_manager()
	var tokens = load("res://SampleProject/UI/Tokens/UITokens.gd")

	print("[1] gameplay scene + combat HUD")
	set_meta("start_new_game", true)  # нова гра, а не slot_01 з user://
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	# Вступ Canyon — діалог; під час діалогу меню не відкривається (D136).
	var intro_dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	intro_dm.bubble_time_scale = 0.0  # облачка (D178) без очікування
	for intro_round in 10:
		for i in 200:
			if not intro_dm.is_dialogue_active():
				break
			intro_dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
			intro_dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
	var hud: Node = game.get_node_or_null(^"UICanvas/CombatHUD")
	ck(hud != null, "combat HUD wrapper present")
	ck(hud != null and hud.theme != null, "HUD carries GameUITheme")
	for widget in ["SkillHotbar", "PlayerVitalsPanel", "CombatHudTop"]:
		ck(hud != null and hud.get_node_or_null(NodePath(widget)) != null,
				"%s inside the themed wrapper" % widget)
	var vitals: Node = get_first_node_in_group("player_vitals_panel")
	ck(vitals != null and vitals._name_label.get_theme_font_size("font_size", "VitalsName")
			== tokens.font_px(tokens.SIZE_ROW_TITLE), "HUD resolves theme variations at runtime")

	print("[2] menu shell")
	ui.open_game_menu()
	for i in 16: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	ck(menu != null, "game menu opens")
	if menu == null:
		_done()
		return
	ck(paused, "opening pauses the game")
	var bar: Node = get_first_node_in_group("ui_bottom_bar")
	ck(bar != null, "shared bottom bar present")
	ck(menu.focus_router != null, "focus router resolved")
	var sidebar: Node = menu.find_child("Sidebar", true, false)
	ck(sidebar != null, "sidebar present")

	print("[3] every tab renders")
	for tab in TABS:
		menu.switch_to_tab(tab)
		for i in 8: await process_frame
		var node: Node = menu.find_child(String(TABS[tab]), true, false)
		ck(node != null, "%s: component found" % tab)
		if node is Control:
			ck((node as Control).is_visible_in_tree(), "%s: visible" % tab)
			var r: Rect2 = (node as Control).get_global_rect()
			ck(r.size.x > 0 and r.size.y > 0, "%s: non-zero rect %s" % [tab, str(r.size)])
			ck(r.position.x >= 0 and r.end.x <= 1920.0 + 1.0,
					"%s: inside the canvas" % tab)

	print("[4] only one screen visible at a time")
	menu.switch_to_tab("Skills")
	for i in 8: await process_frame
	var visible_count := 0
	for tab in TABS:
		var node: Node = menu.find_child(String(TABS[tab]), true, false)
		if node is Control and (node as Control).is_visible_in_tree():
			visible_count += 1
	ck(visible_count == 1, "exactly one screen visible (got %d)" % visible_count)

	print("[5] rapid tab cycling stays stable")
	for pass_index in 3:
		for tab in TABS:
			menu.switch_to_tab(tab)
			for i in 2: await process_frame
	for i in 6: await process_frame
	ck(get_first_node_in_group("game_menu") == menu, "menu survived 21 switches")
	ck(is_instance_valid(bar), "bottom bar survived")
	menu.switch_to_tab("Inventory")
	for i in 6: await process_frame
	var inv: Node = menu.find_child("InventoryComponent", true, false)
	ck(inv != null and inv.is_visible_in_tree(), "Inventory still renders after cycling")

	print("[6] modals")
	var modal_layer: Node = ui.get_modal_layer()
	ck(modal_layer != null, "modal layer present")
	if modal_layer and modal_layer.has_method("show_modal"):
		ui.show_modal({"title": "Regression", "body": "Probe", "buttons": ["OK"]})
		for i in 8: await process_frame
		var active = modal_layer.get("active_modal")
		ck(active != null, "modal opens over the menu")
		if active is Control:
			ck((active as Control).get_theme_font_size("font_size", "TitleLabel")
					== tokens.font_px(tokens.SIZE_TITLE), "modal inherits the shared theme")
		# ModalLayer не має публічного close — модалка закривається власними
		# сигналами (confirmed / cancelled / chosen).
		if active is Control and active.has_signal(&"cancelled"):
			active.cancelled.emit()
		for i in 6: await process_frame
		ck(modal_layer.get("active_modal") == null, "modal closes")
		ck(paused, "closing a modal does not unpause the menu")

	print("[7] no fabricated content anywhere in the menu")
	var texts: Array = []
	for tab in TABS:
		menu.switch_to_tab(tab)
		for i in 4: await process_frame
		_collect(menu, texts)
	# "Path Action" / "Talent" НЕ в списку: на екрані Status це схвалені порожні
	# картки-структура з Figma без вигаданого вмісту (рішення фази Status).
	# Заборонені тут — відхилені імена кодексу і відкладені рядки Settings.
	# Frame Rate Limit і Resolution — уже не відкладені (BACKLOG 41, verify_settings_graphics.gd); Borderless — settings plan slice 1.
	var forbidden := ["Lyra", "Ashveil", "Valen", "Selene",
		"All Chapters", "Screen Brightness",
		"Ambient", "Damage Numbers", "Screen Shake", "Text Speed"]
	var leaked: Array = []
	for term in forbidden:
		for text in texts:
			if String(text).findn(term) >= 0:
				leaked.append(term)
				break
	ck(leaked.is_empty(), "no deferred/rejected content rendered (leaked: %s)" % str(leaked))

	print("[8] exit path")
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	menu._unhandled_input(ev)
	for i in 10: await process_frame
	ck(get_first_node_in_group("game_menu") == null, "ui_cancel closes the menu")
	ck(not paused, "gameplay resumed")
	ck(ui.is_gameplay_input_allowed(), "gameplay input restored")
	ck(get_first_node_in_group("player_vitals_panel") != null, "combat HUD survived the menu")
	_done()


func _collect(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	for child in node.get_children():
		_collect(child, out)


func _done() -> void:
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
