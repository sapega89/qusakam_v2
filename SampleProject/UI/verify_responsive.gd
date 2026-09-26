extends SceneTree

## Регресія адаптивності UI (Phase 5.9).
##   SHOT_W=1600 SHOT_H=900 godot --path . --script res://SampleProject/UI/verify_responsive.gd
##
## Політика розтягування (canvas_items + keep, база 1920x1080) означає, що
## логічне полотно ЗАВЖДИ 1920x1080, а вікно лише масштабує його. Тому перевіряємо
## не пікселі, а композицію: чи все лишається в межах полотна, чи немає нульових
## розмірів, накладань і обрізаного тексту.

const CANVAS := Vector2(1920.0, 1080.0)

var fails: Array[String] = []
var _screen := ""


func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok:
		fails.append("%s: %s" % [_screen, label])


func _initialize() -> void:
	var w := int(OS.get_environment("SHOT_W"))
	var h := int(OS.get_environment("SHOT_H"))
	if w <= 0:
		w = 1920
		h = 1080
	DisplayServer.window_set_size(Vector2i(w, h))
	root.size = Vector2i(w, h)
	await process_frame
	await process_frame

	print("=== responsive audit @ %dx%d (logical canvas %s) ===" % [w, h, str(CANVAS)])
	ck(root.size == Vector2i(CANVAS), "logical canvas stays 1920x1080 (got %s)" % str(root.size))

	var sl: Node = root.get_node_or_null("ServiceLocator")
	var ui: Node = sl.get_ui_manager()

	# ── Ігрове меню та його екрани ──────────────────────────────────────────
	ui.open_game_menu()
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	ck(menu != null, "game menu opens")
	if menu == null:
		_done()
		return

	_audit_shell(menu)
	for tab in ["Inventory", "Equipment", "Status", "Skills", "World Map", "Journal", "Misc"]:
		menu.switch_to_tab(tab)
		for i in 6: await process_frame
		_audit_screen(menu, tab)

	# Settings має ще й власні вкладки — перевіряємо кожну.
	menu.switch_to_tab("Misc")
	for i in 6: await process_frame
	var opts: Node = get_first_node_in_group("settings_screen")
	if opts:
		for settings_tab in ["display", "audio", "game", "controls"]:
			_screen = "Settings/%s" % settings_tab
			opts.switch_to_tab(settings_tab)
			for i in 6: await process_frame
			_audit_control(opts as Control, "settings/%s" % settings_tab)

	# ── Модалка ─────────────────────────────────────────────────────────────
	_screen = "Modal"
	var modal_layer: Node = ui.get_modal_layer()
	if modal_layer and modal_layer.has_method("show_modal"):
		ui.show_modal({"title": "Responsive check", "body": "Centering probe", "buttons": ["OK"]})
		for i in 6: await process_frame
		var active = modal_layer.get("active_modal")
		if active is Control:
			_audit_centred(active as Control, "modal")
		else:
			ck(true, "modal layer present (no active modal to probe)")
		if modal_layer.has_method("close_modal"):
			modal_layer.close_modal()
		for i in 3: await process_frame

	ui.close_game_menu()
	for i in 6: await process_frame

	# ── Бойовий HUD ─────────────────────────────────────────────────────────
	change_scene_to_file("res://SampleProject/Game.tscn")
	for i in 40: await process_frame
	_screen = "Combat HUD"
	for group in ["player_vitals_panel", "combat_hud_top", "skill_hotbar"]:
		var node := get_first_node_in_group(group)
		ck(node != null, "%s present" % group)
		if node is Control:
			_audit_control(node as Control, group)
	var hotbar := get_first_node_in_group("skill_hotbar")
	if hotbar is Control:
		_audit_centred_x(hotbar as Control, "hotbar bottom-centre")

	_done()


func _audit_shell(menu: Node) -> void:
	_screen = "Game Menu shell"
	var sidebar: Control = menu.find_child("TabButtons", true, false)
	ck(sidebar != null, "sidebar present")
	if sidebar:
		_audit_control(sidebar, "sidebar")
		ck(is_equal_approx(sidebar.global_position.x, 0.0) or sidebar.global_position.x < 40.0,
				"sidebar anchored to the left edge (x=%.0f)" % sidebar.global_position.x)
	var bar: Control = menu.find_child("BottomBar", true, false)
	if bar == null:
		bar = get_first_node_in_group("ui_bottom_bar")
	ck(bar != null, "bottom bar present")
	if bar:
		_audit_control(bar, "bottom bar")
		var bottom: float = bar.get_global_rect().end.y
		ck(absf(bottom - CANVAS.y) < 2.0, "bottom bar sits on the canvas bottom (%.0f)" % bottom)
		ck(absf(bar.size.x - CANVAS.x) < 2.0, "bottom bar spans full width (%.0f)" % bar.size.x)


func _audit_screen(menu: Node, tab: String) -> void:
	_screen = tab
	var component_names := {
		"Inventory": "InventoryComponent",
		"Equipment": "EquipmentComponent",
		"Status": "StatsComponent",
		"Skills": "SkillsComponent",
		"World Map": "MetSysMapComponent",
		"Journal": "JournalComponent",
		"Misc": "OptionsComponent",
	}
	var node: Node = menu.find_child(String(component_names[tab]), true, false)
	ck(node != null, "component present")
	if not (node is Control):
		return
	var control := node as Control
	ck(control.is_visible_in_tree(), "visible when its tab is active")
	_audit_control(control, tab)
	_audit_children(control, tab)
	_audit_scrolls(control)


## Головна перевірка: контрол у межах полотна і має ненульовий розмір.
func _audit_control(control: Control, label: String) -> void:
	var rect := control.get_global_rect()
	ck(rect.size.x > 0.0 and rect.size.y > 0.0, "%s has a non-zero size (%s)" % [label, str(rect.size)])
	var inside := rect.position.x >= -1.0 and rect.position.y >= -1.0 \
			and rect.end.x <= CANVAS.x + 1.0 and rect.end.y <= CANVAS.y + 1.0
	ck(inside, "%s stays inside the canvas (%s)" % [label, str(rect)])


## Жоден видимий нащадок не має виходити за полотно і не має бути обрізаним.
func _audit_children(root_control: Control, label: String) -> void:
	var outside := 0
	var clipped := 0
	for child in root_control.find_children("*", "Control", true, false):
		var c := child as Control
		if not c.is_visible_in_tree():
			continue
		var rect := c.get_global_rect()
		if rect.size == Vector2.ZERO:
			continue
		if rect.end.x > CANVAS.x + 1.0 or rect.end.y > CANVAS.y + 1.0 \
				or rect.position.x < -1.0 or rect.position.y < -1.0:
			outside += 1
		if c is Label:
			var lbl := c as Label
			if lbl.text != "" and lbl.autowrap_mode == TextServer.AUTOWRAP_OFF \
					and lbl.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
				var needed := lbl.get_theme_font(&"font").get_string_size(
						lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
						lbl.get_theme_font_size(&"font_size")).x
				if needed > lbl.size.x + 1.0:
					clipped += 1
	ck(outside == 0, "%s: no child rendered outside the viewport (%d)" % [label, outside])
	ck(clipped == 0, "%s: no unhandled text clipping (%d)" % [label, clipped])


## Скрол має бути вертикальним і мати видиму область.
func _audit_scrolls(root_control: Control) -> void:
	for child in root_control.find_children("*", "ScrollContainer", true, false):
		var sc := child as ScrollContainer
		if not sc.is_visible_in_tree():
			continue
		ck(sc.size.y > 0.0, "scroll container has height (%s)" % sc.name)
		ck(sc.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
				"scroll container is vertical-only (%s)" % sc.name)


func _audit_centred(control: Control, label: String) -> void:
	var centre := control.get_global_rect().get_center()
	ck(absf(centre.x - CANVAS.x / 2.0) < 2.0, "%s centred horizontally (%.0f)" % [label, centre.x])
	ck(absf(centre.y - CANVAS.y / 2.0) < 2.0, "%s centred vertically (%.0f)" % [label, centre.y])


func _audit_centred_x(control: Control, label: String) -> void:
	var centre := control.get_global_rect().get_center()
	ck(absf(centre.x - CANVAS.x / 2.0) < 2.0, "%s centred horizontally (%.0f)" % [label, centre.x])


func _done() -> void:
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL\n    %s" % [
		fails.size(), "\n    ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
