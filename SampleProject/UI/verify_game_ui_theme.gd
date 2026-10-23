extends SceneTree

## Самоперевірка спільної теми UI (Phase 4).
##
## Запуск:
##   godot --path . --script res://SampleProject/UI/verify_game_ui_theme.gd
##
## Перевіряє:
##   1. GameUITheme.tres завантажується і містить очікувані типи/варіації.
##   2. Кольори та розміри теми збігаються з UITokens (немає розсинхрону).
##   3. Контроли під UIRoot/UILayer/StateRoot успадковують тему.
##   4. Сторонні / addon-сцени тему НЕ успадковують.

const THEME_PATH := "res://SampleProject/UI/Themes/GameUITheme.tres"
const UI_ROOT := "res://SampleProject/Scenes/UI/ui_root.tscn"
const DIALOGUE_SYSTEM := "res://SampleProject/Scenes/DialogueSystem.tscn"
# Вікно аддона, яке гра справді показує (підтвердження Reset на Controls). Приклад pause_menu
# тягнув AppConfig аддона, а той ми замінили своїм InputConfig.
const ADDON_SCENE := "res://addons/maaacks_menus_template/base/nodes/windows/confirmation_overlaid_window.tscn"
const ArrowPlateStyle = preload("res://SampleProject/UI/Components/arrow_plate_style.gd")

var _failures: Array[String] = []


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✅ %s" % label)
	else:
		print("  ❌ %s" % label)
		_failures.append(label)


func _initialize() -> void:
	print("\n=== GameUITheme verification ===\n")
	var theme: Theme = load(THEME_PATH)
	if theme == null:
		printerr("❌ Cannot load %s" % THEME_PATH)
		quit(1)
		return

	print("[1] Theme content")
	_check(theme.default_font != null, "default_font is set")
	_check(theme.default_font_size == UITokens.font_px(UITokens.SIZE_BODY), "default_font_size == font_px(SIZE_BODY) (D166)")
	for variation in ["TitleLabel", "HeadingLabel", "ValueLabel", "CaptionLabel",
			"PrimaryButton", "TabButton", "SidebarTab", "IconButton", "WindowPanel"]:
		_check(theme.get_type_variation_base(variation) != &"", "variation %s registered" % variation)

	print("\n[2] Tokens <-> theme in sync")
	_check(theme.get_color("font_color", "Label") == UITokens.TEXT_PRIMARY, "Label font_color == TEXT_PRIMARY")
	_check(theme.get_color("font_color", "TabButton") == UITokens.TEXT_SECONDARY, "TabButton font_color == TEXT_SECONDARY")
	_check(theme.get_font_size("font_size", "SmallLabel") == 18 and theme.get_font_size("font_size", "TitleLabel") == 30, "D166: 14 → 18, 24 → 30")
	_check(theme.get_font_size("font_size", "TitleLabel") == UITokens.font_px(UITokens.SIZE_TITLE), "TitleLabel size == font_px(SIZE_TITLE) (D166)")
	# D474: чотири ігрові поверхні — ×1.5, тіло ≥ 24, підписи й клавіші ≥ 20; меню гри лишається ×1.25.
	for t in UITokens.INGAME_FONT_TYPES:
		for size_name in theme.get_font_size_list(t):
			var px := theme.get_font_size(size_name, t)
			_check(px >= UITokens.INGAME_LABEL_MIN, "D474: %s/%s = %d ≥ %d" % [t, size_name, px, UITokens.INGAME_LABEL_MIN])
	for t in ["DialogueText", "NpcMenuItem", "HudQuestTitle", "TutorialBody", "TutorialBanner"]:
		for size_name in theme.get_font_size_list(t):
			_check(theme.get_font_size(size_name, t) >= UITokens.INGAME_BODY_MIN, "D474: body %s/%s ≥ %d" % [t, size_name, UITokens.INGAME_BODY_MIN])
	_check(theme.get_font_size("font_size", "QuestTitle") == UITokens.font_px(UITokens.SIZE_BODY)
			and theme.get_font_size("font_size", "HudQuestTitle") == UITokens.font_px(UITokens.SIZE_BODY, true) and UITokens.font_px(UITokens.SIZE_BODY, true) == 24,
			"D474: QuestTitle (boss bar) ×1.25 = 20, HudQuestTitle ×1.5 = 24")
	_check(theme.get_font_size("font_size", "KeyBadgeLabel") == UITokens.font_px(UITokens.SIZE_SMALL)
			and theme.get_font_size("font_size", "GameOverItem") == UITokens.font_px(UITokens.SIZE_LABEL),
			"D474: Controls key badge and Game Over items stay ×1.25")
	_check(theme.get_font_size("font_size", "StatusName") == UITokens.SIZE_NAME, "D474: titles keep their size (StatusName 48)")
	var panel := theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	_check(panel != null and panel.bg_color == UITokens.SURFACE, "PanelContainer bg == SURFACE")
	_check(panel != null and panel.corner_radius_top_left == UITokens.RADIUS, "PanelContainer radius == 0")
	# B32 (#67): вибраний слот — accent 2px з усіх боків, невибраний — 1px.
	for state in ["focus", "hover", "hover_pressed"]:
		var sel: StyleBoxFlat = theme.get_stylebox(state, "SaveSlotCard")
		_check(sel.border_width_left == UITokens.BORDER_WIDTH_SELECTED and sel.border_width_top == UITokens.BORDER_WIDTH_SELECTED
				and sel.border_width_right == UITokens.BORDER_WIDTH_SELECTED and sel.border_width_bottom == UITokens.BORDER_WIDTH_SELECTED,
				"SaveSlotCard/%s border == BORDER_WIDTH_SELECTED" % state)
	var unsel: StyleBoxFlat = theme.get_stylebox("normal", "SaveSlotCard")
	_check(unsel.border_width_left == UITokens.BORDER_WIDTH, "SaveSlotCard/normal border == BORDER_WIDTH")
	# B8: панелі меню з текстом і слоти збереження непрозорі — мапа-фон не йде крізь текст.
	for variation in ["CenterPanel", "SidePanel", "CardPanel", "BoxPanel", "ActionCard", "TreePanel"]:
		var box: StyleBoxFlat = theme.get_stylebox("panel", variation)
		_check(box.bg_color == UITokens.MENU_SURFACE and box.bg_color.a == 1.0, "B8: %s bg == MENU_SURFACE, opaque" % variation)
	for state in ["normal", "hover", "focus"]:
		var card: StyleBoxFlat = theme.get_stylebox(state, "SaveSlotCard")
		_check(state == "focus" or card.bg_color == UITokens.MENU_SURFACE, "B8: SaveSlotCard/%s bg == MENU_SURFACE" % state)
	_check((theme.get_stylebox("panel", "ShopPanel") as StyleBoxFlat).bg_color.a == 1.0, "B8: ShopPanel opaque")
	# B22: кнопки −/+ і ‹/› у Settings мають рамку 1px, як решта контролів екрана.
	var step: StyleBoxFlat = theme.get_stylebox("normal", "SettingsStepper")
	_check(step.border_width_left == UITokens.BORDER_WIDTH and step.border_color == UITokens.BORDER,
			"B22: SettingsStepper/normal has a 1px BORDER frame")
	# B90: на вибраному (акцентному) рядку фокус — біле кільце (D329), його малює list_row.gd.
	var ring: StyleBoxFlat = theme.get_stylebox("focus_selected", "ListRow")
	_check(ring.border_color == UITokens.FOCUS_RING_ON_ACCENT and ring.border_width_left == UITokens.FOCUS_RING_WIDTH
			and ring.bg_color.a == 0.0, "B90: ListRow/focus_selected is the on-accent ring")
	var sub_row := Button.new()
	sub_row.theme = theme
	sub_row.theme_type_variation = &"ListSubRow"
	_check(sub_row.get_theme_stylebox(&"focus_selected") == ring, "B90: ListSubRow inherits focus_selected")
	sub_row.free()

	print("\n[3] Inheritance under StateRoot")
	var ui_root: Node = (load(UI_ROOT) as PackedScene).instantiate()
	root.add_child(ui_root)
	var state_root: Control = ui_root.get_node("UILayer/StateRoot")
	_check(state_root.theme == theme, "StateRoot.theme is GameUITheme")

	var probe := Button.new()
	state_root.add_child(probe)
	await process_frame
	# Явний тип обов'язковий: Button.get_theme_font("font") без типу падає на
	# дефолтну тему навіть коли кастомна успадкована. Для Label це не так.
	_check(probe.get_theme_font("font", "Button") == theme.get_font("font", "Button"),
			"Button under StateRoot resolves theme font")
	# Стильбокс — найнадійніший доказ успадкування: дефолтна тема таких кольорів не має.
	var probe_box := probe.get_theme_stylebox("normal") as StyleBoxFlat
	_check(probe_box != null and probe_box.bg_color == UITokens.SURFACE,
			"Button under StateRoot resolves SURFACE stylebox")

	var probe_label := Label.new()
	state_root.add_child(probe_label)
	await process_frame
	_check(probe_label.get_theme_font("font") == theme.default_font,
			"Label under StateRoot resolves Cormorant Garamond")

	var modal_container: Control = ui_root.get_node("ModalLayer/Container")
	_check(modal_container.theme == theme, "ModalLayer/Container.theme is GameUITheme")

	print("\n[3b] Dialogue box: opaque background, no Auto/Skip buttons (D254, B10)")
	var dsys: Node = (load(DIALOGUE_SYSTEM) as PackedScene).instantiate()
	root.add_child(dsys)
	await process_frame
	var dbox = dsys.get_node("DialogueBox")
	var dpanel: StyleBox = dbox.get_theme_stylebox("panel")
	_check(dpanel is StyleBoxFlat and (dpanel as StyleBoxFlat).bg_color.a == 1.0,
			"dialogue box background is opaque (D254)")
	var dplayer_settings: Resource = dsys.get_node("DialoguePlayer").settings
	_check(not dplayer_settings.autoplay_enabled and not dplayer_settings.skip_enabled,
			"dialogue player has autoplay and skip off (B10, D254)")
	for b: Button in [dbox.get_auto_button(), dbox.get_skip_button()]:
		_check(not b.visible, "%s is hidden (B10)" % b.name)
	dsys.queue_free()

	print("\n[3c] One focus look in every menu (Q33, BACKLOG 41)")
	# Кожна кнопкова варіація: focus — StyleBoxFlat з рамкою FOCUS_RING (або білою на акценті)
	# шириною FOCUS_RING_WIDTH з усіх боків.
	var off_ring: Array[String] = []
	var buttons: Array = [&"Button"]
	for variation in theme.get_type_variation_list(&"Button"):
		buttons.append(variation)
	for type in buttons:
		if not theme.has_stylebox("focus", type):
			continue
		var focus_box := theme.get_stylebox("focus", type)
		# D493: табличка-стрілка Game Menu — та сама рамка FOCUS_RING, лише за формою стрілки.
		if focus_box.get_script() == ArrowPlateStyle:
			if not (focus_box.border_color == UITokens.FOCUS_RING and focus_box.border_width == UITokens.FOCUS_RING_WIDTH
					and focus_box.bg_color.a == 0.0):
				off_ring.append(String(type))
			continue
		var focus := focus_box as StyleBoxFlat
		var ok: bool = focus != null \
				and (focus.border_color == UITokens.FOCUS_RING or focus.border_color == UITokens.FOCUS_RING_ON_ACCENT) \
				and focus.border_width_left == UITokens.FOCUS_RING_WIDTH \
				and focus.border_width_top == UITokens.FOCUS_RING_WIDTH \
				and focus.border_width_right == UITokens.FOCUS_RING_WIDTH \
				and focus.border_width_bottom == UITokens.FOCUS_RING_WIDTH
		if not ok:
			off_ring.append(String(type))
	_check(buttons.size() > 20, "%d button types inspected" % buttons.size())
	_check(off_ring.is_empty(), "every button focus is the shared ring (off: %s)" % str(off_ring))

	print("\n[4] Third-party UI isolation")
	var outside := Button.new()
	root.add_child(outside)
	_check(outside.get_theme_font("font") != theme.get_font("font", "Button"),
			"Button outside StateRoot does NOT inherit GameUITheme")
	if ResourceLoader.exists(ADDON_SCENE):
		var addon: Node = (load(ADDON_SCENE) as PackedScene).instantiate()
		root.add_child(addon)
		var leaked := _find_theme_user(addon, theme)
		_check(leaked == "", "addon confirmation window does not use GameUITheme%s" %
				("" if leaked == "" else " (leak at %s)" % leaked))
		addon.queue_free()
	else:
		print("  ⏭  addon scene not present, skipped")

	print("\n=== %s ===" % ("ALL CHECKS PASSED" if _failures.is_empty()
			else "%d FAILURE(S): %s" % [_failures.size(), ", ".join(_failures)]))
	quit(0 if _failures.is_empty() else 1)


## Повертає шлях першого вузла, що використовує задану тему, або "".
func _find_theme_user(node: Node, theme: Theme) -> String:
	if node is Control and (node as Control).theme == theme:
		return str(node.get_path())
	for child in node.get_children():
		var found := _find_theme_user(child, theme)
		if found != "":
			return found
	return ""
