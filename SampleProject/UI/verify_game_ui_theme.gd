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

	print("\n[3b] Dialogue bar Auto/Skip take the shared Button look (B27, #75)")
	var dsys: Node = (load(DIALOGUE_SYSTEM) as PackedScene).instantiate()
	root.add_child(dsys)
	await process_frame
	var dbox = dsys.get_node("DialogueBox")
	var dpanel: StyleBox = dbox.get_theme_stylebox("panel")
	_check(dpanel is StyleBoxFlat and (dpanel as StyleBoxFlat).bg_color.a == 1.0,
			"dialogue box background is opaque (D254)")
	for on in [false, true]:
		dbox.set_auto_button_active(on)
		dbox.set_skip_button_active(on)
		for b: Button in [dbox.get_auto_button(), dbox.get_skip_button()]:
			var v: StringName = b.theme_type_variation
			_check(v == &"" or theme.get_type_variation_base(v) == &"Button",
					"%s (on=%s) variation '%s' is a Button type in GameUITheme" % [b.name, on, v])
			for state in ["normal", "focus"]:
				_check(b.get_theme_stylebox(state) == theme.get_stylebox(state, "Button"),
						"%s (on=%s) %s == shared Button %s" % [b.name, on, state, state])
	dsys.queue_free()

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
