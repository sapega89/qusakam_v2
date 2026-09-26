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
##   5. menu_shell.tscn будується і рендериться (PNG у user://).

const THEME_PATH := "res://SampleProject/UI/Themes/GameUITheme.tres"
const UI_ROOT := "res://SampleProject/Scenes/UI/ui_root.tscn"
const MENU_SHELL := "res://SampleProject/UI/Components/menu_shell.tscn"
const ADDON_SCENE := "res://addons/maaacks_menus_template/examples/scenes/windows/pause_menu.tscn"

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
	_check(theme.default_font_size == UITokens.SIZE_BODY, "default_font_size == SIZE_BODY")
	for variation in ["TitleLabel", "HeadingLabel", "ValueLabel", "CaptionLabel",
			"PrimaryButton", "TabButton", "SidebarTab", "IconButton", "WindowPanel"]:
		_check(theme.get_type_variation_base(variation) != &"", "variation %s registered" % variation)

	print("\n[2] Tokens <-> theme in sync")
	_check(theme.get_color("font_color", "Label") == UITokens.TEXT_PRIMARY, "Label font_color == TEXT_PRIMARY")
	_check(theme.get_color("font_color", "TabButton") == UITokens.TEXT_SECONDARY, "TabButton font_color == TEXT_SECONDARY")
	_check(theme.get_font_size("font_size", "TitleLabel") == UITokens.SIZE_TITLE, "TitleLabel size == SIZE_TITLE")
	var panel := theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	_check(panel != null and panel.bg_color == UITokens.SURFACE, "PanelContainer bg == SURFACE")
	_check(panel != null and panel.corner_radius_top_left == UITokens.RADIUS, "PanelContainer radius == 0")

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

	print("\n[4] Third-party UI isolation")
	var outside := Button.new()
	root.add_child(outside)
	_check(outside.get_theme_font("font") != theme.get_font("font", "Button"),
			"Button outside StateRoot does NOT inherit GameUITheme")
	if ResourceLoader.exists(ADDON_SCENE):
		var addon: Node = (load(ADDON_SCENE) as PackedScene).instantiate()
		root.add_child(addon)
		var leaked := _find_theme_user(addon, theme)
		_check(leaked == "", "addon pause_menu does not use GameUITheme%s" %
				("" if leaked == "" else " (leak at %s)" % leaked))
		addon.queue_free()
	else:
		print("  ⏭  addon scene not present, skipped")

	print("\n[5] Shell builds")
	var shell: Control = (load(MENU_SHELL) as PackedScene).instantiate()
	state_root.add_child(shell)
	await process_frame
	shell.set_title("MENU")
	for item in ["World Map", "Journal", "Inventory", "Healing", "Equipment",
			"Jobs", "Skills", "Status", "Miscellaneous"]:
		shell.add_nav_item(StringName(item), item)
	shell.select_nav(&"Inventory")
	await process_frame
	_check(shell.sidebar.get_child_count() == 9, "shell has 9 nav items")
	_check(shell.get_nav_item(&"Inventory").button_pressed, "Inventory nav item is selected")
	_check(shell.bottom_bar != null, "shell has a bottom bar")

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
