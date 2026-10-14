extends BaseOptionsComponent
class_name OptionsComponent

## Екран налаштувань. Figma: settings-display 17:280, settings-audio 17:409,
## settings-gameplay 17:632, settings-controls 17:756.
##
## Показуємо ТІЛЬКИ те, що має реальну підсистему. Рядки Figma без бекенду
## (Resolution, Frame Rate Limit, Screen Brightness, Ambient, Text Speed,
## Screen Shake, Damage Numbers) свідомо відкладені — див.
## design/settings_mapping.md, D43–D48. Фейкових контролів тут немає.
##
## Персистенс — існуючий: SaveSystem.settings_module + save_game_settings().
## Другої системи налаштувань не заводимо.

# Mode: "main_menu" or "game_menu"
var mode: String = "game_menu"

const TABS := [
	{"id": "display", "eyebrow": "GRAPHICS OPTIONS", "heading": "Display Settings"},
	{"id": "audio", "eyebrow": "SOUND OPTIONS", "heading": "Audio Settings"},
	{"id": "game", "eyebrow": "GAME OPTIONS", "heading": "Game Settings"},
	{"id": "controls", "eyebrow": "INPUT OPTIONS", "heading": "Controls"},
]

## Підказка нижньої панелі для кожної вкладки — лише про реальні дії.
const TAB_HINTS := {
	"display": "Set the display mode.",
	"audio": "Adjust volume levels.",
	"game": "Choose the interface language.",
	"controls": "Select an action to rebind it.",
}

@onready var exit_to_main_menu_button: Button = %ExitToMainMenuButton
@onready var back_button: Button = %BackButton
@onready var _sidebar: VBoxContainer = %Sidebar
@onready var _eyebrow: Label = %Eyebrow
@onready var _heading: Label = %Heading
@onready var _header_icon: TextureRect = %HeaderIcon
@onready var _list: VBoxContainer = %SettingsList
@onready var _input_menu: Control = %InputOptionsMenu
@onready var _restore_button: Button = %RestoreButton

var current_tab: String = "display"
var _tab_buttons: Dictionary = {}
var _settings_module: Node = null
var _localization: Node = null
var _suppress_write: bool = false


func _initialize_component() -> void:
	add_to_group(&"settings_screen")
	_settings_module = SaveSystem.settings_module
	_localization = LocalizationManager
	_build_sidebar()
	if not _restore_button.pressed.is_connected(_on_restore_pressed):
		_restore_button.pressed.connect(_on_restore_pressed)
	switch_to_tab(current_tab)


func _build_sidebar() -> void:
	for child in _sidebar.get_children():
		_sidebar.remove_child(child)
		child.queue_free()
	_tab_buttons.clear()
	for tab in TABS:
		_sidebar.add_child(_make_tab(tab))


## Figma UI/Settings Tab 117:835 — 16px вказівник + 36×36 кнопка з іконкою.
func _make_tab(tab: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(UITokens.SETTINGS_SIDEBAR_WIDTH, UITokens.SETTINGS_TAB_HEIGHT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var pointer := TextureRect.new()
	pointer.name = "Pointer"
	pointer.custom_minimum_size = Vector2(UITokens.SETTINGS_POINTER, UITokens.SETTINGS_POINTER)
	pointer.texture = _icon("Pointer")
	pointer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pointer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pointer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pointer.modulate = UITokens.ACCENT
	row.add_child(pointer)

	var button := Button.new()
	button.name = "Tab_%s" % tab.id
	button.custom_minimum_size = Vector2(UITokens.SETTINGS_TAB_BOX, UITokens.SETTINGS_TAB_BOX)
	button.theme_type_variation = &"SettingsSidebarTab"
	button.toggle_mode = true
	button.icon = _icon(tab.id)
	button.expand_icon = true
	button.tooltip_text = tab.heading
	button.pressed.connect(switch_to_tab.bind(tab.id))
	row.add_child(button)

	_tab_buttons[tab.id] = {"row": row, "pointer": pointer, "button": button}
	return row


func _icon(icon_name: String) -> Texture2D:
	var holder: Node = $TabIcons
	var node: TextureRect = holder.get_node_or_null(NodePath(icon_name))
	return node.texture if node else null


func switch_to_tab(tab_id: String) -> void:
	current_tab = tab_id
	for id in _tab_buttons:
		var entry: Dictionary = _tab_buttons[id]
		var active: bool = id == tab_id
		entry.button.set_pressed_no_signal(active)
		# Figma: неактивна вкладка — 50% прозорості, без вказівника.
		entry.pointer.visible = active
		entry.button.modulate.a = 1.0 if active else 0.5
	for tab in TABS:
		if tab.id == tab_id:
			_eyebrow.text = tab.eyebrow
			_heading.text = tab.heading
			_header_icon.texture = _icon(tab.id)
	_rebuild_list()
	_set_hint(TAB_HINTS.get(tab_id, ""))


func _set_hint(text: String) -> void:
	var bar: Node = get_tree().get_first_node_in_group(&"ui_bottom_bar") if get_tree() else null
	# Нижня панель спільна: прихована вкладка не має права її перезаписувати.
	if bar and is_visible_in_tree():  # нижньої панелі немає в головному меню
		bar.set_context_hint(text)


# ── Rows ────────────────────────────────────────────────────────────────────

func _rebuild_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	# Controls — це віджет аддона Maaacks, а не наші рядки.
	var is_controls: bool = current_tab == "controls"
	_input_menu.visible = is_controls
	_list.visible = not is_controls
	if is_controls:
		_style_input_menu()
		return

	match current_tab:
		"display":
			_add_segment_row("Display Mode", ["Windowed", "Fullscreen"],
					1 if _cfg_get("fullscreen") else 0, _on_display_mode_changed)
			_add_separator()
			_add_segment_row("VSync", ["Enable", "Disable"],
					0 if _cfg_get("vsync") else 1, _on_vsync_changed)
		"audio":
			_add_slider_row("Master Volume", "master_volume")
			_add_separator()
			_add_slider_row("Music", "music_volume")
			_add_separator()
			_add_slider_row("Sound Effects", "sfx_volume")
		"game":
			_add_language_row()


func _add_separator() -> void:
	var line := HSeparator.new()
	var box := StyleBoxLine.new()
	box.color = UITokens.BORDER
	box.thickness = UITokens.BORDER_WIDTH
	line.add_theme_stylebox_override("separator", box)
	_list.add_child(line)


## Figma 17:325 — px16 py14, назва ліворуч, контрол праворуч.
func _make_row(label_text: String) -> HBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", UITokens.SETTINGS_ROW_PAD_H)
	margin.add_theme_constant_override("margin_right", UITokens.SETTINGS_ROW_PAD_H)
	margin.add_theme_constant_override("margin_top", UITokens.SETTINGS_ROW_PAD_V)
	margin.add_theme_constant_override("margin_bottom", UITokens.SETTINGS_ROW_PAD_V)
	var row := HBoxContainer.new()
	row.name = label_text
	margin.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.theme_type_variation = &"SettingsRowLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	_list.add_child(margin)
	return row


## Figma 17:350 — дві комірки в спільній рамці, вибрана має акцентну заливку.
func _add_segment_row(label_text: String, options: Array, selected: int,
		on_change: Callable) -> void:
	var row := _make_row(label_text)
	var frame := PanelContainer.new()
	frame.name = "Segments"
	var box := StyleBoxFlat.new()
	box.bg_color = UITokens.SURFACE
	box.set_border_width_all(UITokens.BORDER_WIDTH)
	box.border_color = UITokens.TEXT_PRIMARY
	box.set_corner_radius_all(UITokens.RADIUS)
	frame.add_theme_stylebox_override("panel", box)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cells := HBoxContainer.new()
	cells.add_theme_constant_override("separation", 0)
	frame.add_child(cells)
	for i in options.size():
		var active: bool = i == selected
		var cell := Button.new()
		cell.name = "Cell%d" % i
		cell.text = ("✓ " if active else "") + String(options[i])
		cell.custom_minimum_size = Vector2(UITokens.SETTINGS_SEGMENT_MIN_WIDTH, 0)
		cell.theme_type_variation = &"SettingsSegmentOn" if active else &"SettingsSegment"
		cell.pressed.connect(on_change.bind(i))
		cells.add_child(cell)
	row.add_child(frame)


## Figma 17:457 — мінус · 320px доріжка · плюс · значення 0–100.
func _add_slider_row(label_text: String, key: String) -> void:
	var row := _make_row(label_text)
	var group := HBoxContainer.new()
	group.name = "Slider"
	group.add_theme_constant_override("separation", UITokens.SPACE_LG)
	group.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var minus := Button.new()
	minus.name = "Minus"
	minus.text = "−"
	minus.theme_type_variation = &"SettingsStepper"
	group.add_child(minus)

	var slider := HSlider.new()
	slider.name = "Value"
	slider.custom_minimum_size = Vector2(UITokens.SETTINGS_SLIDER_WIDTH, 0)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value = roundf(float(_cfg_get(key)) * 100.0)
	group.add_child(slider)

	var plus := Button.new()
	plus.name = "Plus"
	plus.text = "+"
	plus.theme_type_variation = &"SettingsStepper"
	group.add_child(plus)

	var readout := Label.new()
	readout.name = "Readout"
	readout.custom_minimum_size = Vector2(36, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.theme_type_variation = &"SettingsValue"
	readout.text = str(int(slider.value))
	group.add_child(readout)

	minus.pressed.connect(func() -> void: slider.value -= 5.0)
	plus.pressed.connect(func() -> void: slider.value += 5.0)
	slider.value_changed.connect(_on_volume_changed.bind(key, readout))
	row.add_child(group)


## Мови беремо з LocalizationManager — жодних вигаданих локалей.
func _add_language_row() -> void:
	var codes: Array = Array(_localization.get_available_languages())
	var current: String = _localization.get_language()
	var names: Array = []
	for code in codes:
		names.append(_language_name(String(code)))
	var selected: int = maxi(0, codes.find(current))
	_add_segment_row("Language", names, selected,
			func(index: int) -> void: _on_language_changed(String(codes[index])))


func _language_name(code: String) -> String:
	match code:
		"en": return "English"
		"uk": return "Ukrainian"
		_: return code.to_upper()


# ── Handlers ────────────────────────────────────────────────────────────────

func _on_display_mode_changed(index: int) -> void:
	_cfg_set("fullscreen", index == 1)
	_apply_and_save()
	_rebuild_list()


func _on_vsync_changed(index: int) -> void:
	_cfg_set("vsync", index == 0)
	_apply_and_save()
	_rebuild_list()


func _on_volume_changed(value: float, key: String, readout: Label) -> void:
	readout.text = str(int(value))
	if _suppress_write:
		return
	_cfg_set(key, clampf(value / 100.0, 0.0, 1.0))
	# Гучність застосовується миттєво — це вже вміє SettingsModule.
	_apply_and_save()


func _on_language_changed(code: String) -> void:
	_localization.set_language(code)
	_cfg_set("language", code)
	_apply_and_save()
	_rebuild_list()


func _on_restore_pressed() -> void:
	_settings_module.settings = _settings_module.default_settings.duplicate()
	_localization.set_language(String(_cfg_get("language")))
	_apply_and_save()
	_rebuild_list()


## Усі ключі є в SettingsModule.default_settings — відсутній ключ є помилкою, не значенням за замовчуванням.
func _cfg_get(key: String) -> Variant:
	return _settings_module.settings[key]


func _cfg_set(key: String, value) -> void:
	_settings_module.settings[key] = value


func _apply_and_save() -> void:
	_settings_module.apply_settings()
	SaveSystem.save_game_settings()


## Аддон Maaacks лишається поведінковим джерелом правди для ремапінгу.
## Тему не застосовуємо до нього глобально — лише вирівнюємо межі контейнера.
func _style_input_menu() -> void:
	_input_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL


# ── Mode behaviour (без змін) ───────────────────────────────────────────────

func _setup_mode():
	"""Configure component based on usage mode"""
	if mode == "main_menu":
		# Кнопку Back прибрано (Sapega, 2026-10-12): з налаштувань виходять через Esc / ui_cancel.
		if back_button:
			back_button.visible = false
			back_button.focus_mode = Control.FOCUS_NONE
		if exit_to_main_menu_button:
			exit_to_main_menu_button.visible = false
	else:
		# Hide back button, show exit to main menu button
		if back_button:
			back_button.visible = false
			# Отключаем фокус на кнопке back, даже если она скрыта
			back_button.focus_mode = Control.FOCUS_NONE
		if exit_to_main_menu_button:
			exit_to_main_menu_button.visible = true
			if not exit_to_main_menu_button.pressed.is_connected(_on_exit_to_main_menu_pressed):
				exit_to_main_menu_button.pressed.connect(_on_exit_to_main_menu_pressed)


func _unhandled_input(event):
	"""Handle cancel action to close menu (only in main menu mode)"""
	if mode == "main_menu" and event.is_action_pressed(&"ui_cancel"):
		close_options_menu()


func _on_exit_to_main_menu_pressed() -> void:
	"""Handle exit to main menu button (game menu mode)"""
	close_options_menu()


func close_options_menu():
	"""Close options menu - behavior depends on mode"""
	if mode == "main_menu":
		_close_main_menu_mode()
	else:
		_close_game_menu_mode()


func _close_main_menu_mode():
	"""Close options menu (main menu mode)"""
	# Save settings when closing options menu
	SaveSystem.save_game_settings()
	# У режимі main_menu батько — MainMenu; анімацію повернення робить він.
	get_parent().show_main_menu()

	# Resume game (if it was paused)
	if get_tree().paused:
		get_tree().paused = false


func _close_game_menu_mode():
	"""Exit to main menu from the in-game Settings tab"""
	SaveSystem.save_game_settings()
	# Зміна сцени прибирає меню й UIRoot разом зі сценою, паузу знімає MainMenu._ready().
	# (Раніше тут читався GameManager.game_menu_instance — такої властивості немає.)
	get_tree().change_scene_to_file("res://SampleProject/MainMenu.tscn")
