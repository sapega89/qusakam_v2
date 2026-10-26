extends BaseOptionsComponent
class_name OptionsComponent

## Режим main_menu: налаштування закрито (Esc). Головне меню саме прибирає компонент і показує себе.
signal closed

## Екран налаштувань. Figma: settings-display 17:280, settings-audio 17:409,
## settings-gameplay 17:632, settings-controls 17:756.
##
## Показуємо ТІЛЬКИ те, що має реальну підсистему — фейкових контролів тут немає (design/settings_plan.md).
## Resolution і Frame Rate Limit — BACKLOG 41 / D418 (DisplayManager.RESOLUTIONS / FPS_LIMITS); Screen Brightness —
## D428, Ambient — D427, Text Speed — D425, Screen Shake — D426.
##
## Персистенс — існуючий: SaveSystem.settings_module + save_game_settings().
## Другої системи налаштувань не заводимо.
##
## D117: рядки — шаблони в .tscn (%Tab у бічній панелі; %SegmentRow, %StepperRow, %SliderRow, %Separator,
## %BrightnessPreview у прихованому RowTemplates). Рядок списку — копія шаблону, комірки й вкладки — RowFill;
## стилі — з теми.

const RowFill = preload("res://SampleProject/UI/Components/ui_rows.gd")
const GraphicsQuality := preload("res://SampleProject/Scripts/Systems/GraphicsQuality.gd")

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
	"display": "Set the display mode, window size, frame rate limit, screen brightness and graphics quality.",
	"audio": "Adjust volume levels.",
	"game": "Choose the interface language, how fast dialogue text runs, whether hints open tutorial windows, whether the camera shakes, whether damage numbers show and whether the game saves on every room change.",
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
@onready var _tab: HBoxContainer = %Tab
@onready var _segment_row: MarginContainer = %SegmentRow
@onready var _stepper_row: MarginContainer = %StepperRow
@onready var _slider_row: MarginContainer = %SliderRow
@onready var _separator: HSeparator = %Separator
@onready var _brightness_preview: HBoxContainer = %BrightnessPreview

var current_tab: String = "display"
var _tab_buttons: Dictionary = {}
var _settings_module: Node = null
var _localization: Node = null
var _suppress_write: bool = false


func _initialize_component() -> void:
	add_to_group(&"settings_screen")
	_settings_module = SaveSystem.settings_module
	_localization = LocalizationManager
	# Figma UI/Settings Section Header 218:4264: іконка 64×64 кольору text-primary (B12).
	_header_icon.modulate = UITokens.TEXT_PRIMARY
	_build_sidebar()
	if not _restore_button.pressed.is_connected(_on_restore_pressed):
		_restore_button.pressed.connect(_on_restore_pressed)
	switch_to_tab(current_tab)


## Figma UI/Settings Tab 117:835 — 16px вказівник + 36×36 кнопка з іконкою (шаблон %Tab).
func _build_sidebar() -> void:
	_tab_buttons.clear()
	var rows := RowFill.fill(_sidebar, _tab, TABS.size())
	for i in TABS.size():
		var tab: Dictionary = TABS[i]
		var row: HBoxContainer = rows[i]
		var pointer: TextureRect = row.get_node(^"Pointer")
		pointer.modulate = UITokens.ACCENT
		var button: Button = row.get_node(^"Button")
		button.name = "Tab_%s" % tab.id
		button.icon = _icon(tab.id)
		button.tooltip_text = tab.heading
		button.pressed.connect(switch_to_tab.bind(tab.id))
		_tab_buttons[tab.id] = {"row": row, "pointer": pointer, "button": button}


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
		# Figma: неактивна вкладка — 50% прозорості, без вказівника. Вказівник лише
		# ховаємо альфою: його місце в рядку лишається, кнопка не зсувається (B20).
		entry.pointer.modulate.a = 1.0 if active else 0.0
		entry.button.modulate.a = 1.0 if active else 0.5
	for tab in TABS:
		if tab.id == tab_id:
			_eyebrow.text = tab.eyebrow
			_heading.text = tab.heading
			_header_icon.texture = _icon(tab.id)
	_rebuild_list()
	_set_hint(TAB_HINTS.get(tab_id, ""))


## Фокус на вкладку бічної панелі, що зараз відкрита (головне меню відкриває налаштування без миші, BACKLOG 24).
func focus_current_tab() -> void:
	_tab_buttons[current_tab].button.grab_focus()


func _set_hint(text: String) -> void:
	var bar: Node = get_tree().get_first_node_in_group(&"ui_bottom_bar") if get_tree() else null
	# Нижня панель спільна: прихована вкладка не має права її перезаписувати.
	if bar and is_visible_in_tree():  # нижньої панелі немає в головному меню
		bar.set_context_hint(text)


# ── Rows ────────────────────────────────────────────────────────────────────

func _rebuild_list() -> void:
	# Рядок перебудовується з-під фокуса (Display Mode, VSync, Language…) — фокус повертається на ту саму
	# комірку нового рядка, інакше геймпад лишався без фокуса (BACKLOG 24). Шлях — за іменами рядків.
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var refocus := NodePath(_list.get_path_to(focused)) if focused and _list.is_ancestor_of(focused) else NodePath()
	_build_rows()
	_link_sidebar_to_list()
	if not refocus.is_empty():
		var again: Control = _list.get_node_or_null(refocus)
		if again:
			again.grab_focus()


## Вправо з вкладки — перший рядок списку, а не найближча за геометрією кнопка Restore внизу (BACKLOG 24).
func _link_sidebar_to_list() -> void:
	var first: Control = null
	for control in _list.find_children("*", "Control", true, false):
		if control.focus_mode == Control.FOCUS_ALL and not control is ScrollBar:
			first = control
			break
	for id in _tab_buttons:
		var button: Button = _tab_buttons[id].button
		button.focus_neighbor_right = button.get_path_to(first) if first else NodePath()


func _build_rows() -> void:
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
			_add_segment_row("Display Mode", ["Windowed", "Fullscreen", "Borderless"],
					DisplayManager.DISPLAY_MODES.find(String(_cfg_get("display_mode"))), _on_display_mode_changed)
			_add_separator()
			# D418 / D420: Fullscreen і Borderless завжди в рідній роздільності екрана — розмір вікна лише для Windowed;
			# у списку лише те, що вміщується в монітор (D429).
			_add_stepper_row("Resolution", _resolution_names(),
					DisplayManager.available_resolutions().find(DisplayManager.fitted_resolution(String(_cfg_get("resolution")))),
					_on_resolution_changed, _cfg_get("display_mode") == "windowed")
			_add_separator()
			_add_segment_row("VSync", ["Enable", "Disable"],
					0 if _cfg_get("vsync") else 1, _on_vsync_changed)
			_add_separator()
			_add_stepper_row("Frame Rate Limit", _fps_limit_names(),
					DisplayManager.FPS_LIMITS.find(int(_cfg_get("fps_limit"))), _on_fps_limit_changed)
			_add_separator()
			# D554: Low знімає світіння, колірні криві, розмиття глибини, тіні й частину частинок (GraphicsQuality).
			_add_segment_row("Quality", ["High", "Low"],
					GraphicsQuality.QUALITIES.find(String(_cfg_get("graphics_quality"))), _on_quality_changed)
			_add_separator()
			# D428: гамма поверх світу й UI (DisplayManager); зразки DARK / BRIGHT — під рядком.
			_add_slider_row("Screen Brightness", int(_cfg_get("brightness")), _on_brightness_changed,
					UITokens.SETTINGS_CHOICE_ROW_HEIGHT)  # висота рядків вкладки Display
			_add_brightness_preview()
		"audio":
			_add_volume_row("Master Volume", "master_volume")
			_add_separator()
			_add_volume_row("Music", "music_volume")
			_add_separator()
			_add_volume_row("Sound Effects", "sfx_volume")
			_add_separator()
			_add_volume_row("Ambient", "ambient_volume")  # D427: шина Ambience
		"game":
			_add_language_row()
			_add_separator()
			# D425: Quick — текст діалогу й облачка вдвічі швидше.
			_add_segment_row("Text Speed", ["Default", "Quick"],
					SettingsModule.TEXT_SPEEDS.keys().find(String(_cfg_get("text_speed"))), _on_text_speed_changed)
			_add_separator()
			# D739: набрана репліка йде далі сама; Off — лише «далі» (Enter / клік / A).
			_add_segment_row("Auto-Advance", ["On", "Off"],
					0 if _cfg_get("auto_advance") else 1, _on_auto_advance_changed)
			_add_separator()
			# Figma 17:632: Screen Shake одразу за Text Speed.
			# D426: Off — камера не смикається від ударів і вибухів; вібрація геймпада лишається.
			_add_segment_row("Screen Shake", ["On", "Off"],
					0 if _cfg_get("screen_shake") else 1, _on_screen_shake_changed)
			_add_separator()
			# D289: підказка відкриває вікно туторіалу; Off — лише плашка внизу.
			_add_segment_row("Tutorial Windows", ["On", "Off"],
					0 if _cfg_get("tutorial_windows") else 1, _on_tutorial_windows_changed)
			_add_separator()
			# D66: цифри урону над героєм і ворогами (DamageNumbers)
			_add_segment_row("Damage Numbers", ["On", "Off"],
					0 if _cfg_get("damage_numbers") else 1, _on_damage_numbers_changed)
			_add_separator()
			# D413: єдиний шлях автосейву — перехід між кімнатами (SaveSystem._on_room_entered).
			_add_segment_row("Auto-Save", ["On", "Off"],
					0 if _cfg_get("auto_save") else 1, _on_auto_save_changed)


func _add_separator() -> void:
	_list.add_child(_copy(_separator))


## Копія шаблону рядка; зв'язки сигналів не копіюються — їх ставить той, хто будує рядок.
func _copy(template: Control) -> Control:
	var copy: Control = template.duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS)
	copy.visible = true
	return copy


## Figma 17:325 — px16, назва ліворуч, контрол праворуч; висота рядка з Figma, вміст по центру (B21).
func _make_row(template: MarginContainer, label_text: String, height: int) -> HBoxContainer:
	var margin: MarginContainer = _copy(template)
	margin.name = "%sRow" % label_text  # стабільний шлях для повернення фокуса (_rebuild_list)
	margin.custom_minimum_size.y = height
	var row: HBoxContainer = margin.get_node(^"Row")
	row.name = label_text
	(row.get_node(^"Label") as Label).text = label_text
	_list.add_child(margin)
	return row


## Figma 17:350 — дві комірки в спільній рамці, вибрана має акцентну заливку.
func _add_segment_row(label_text: String, options: Array, selected: int,
		on_change: Callable) -> void:
	var row := _make_row(_segment_row, label_text, UITokens.SETTINGS_CHOICE_ROW_HEIGHT)
	var cells: HBoxContainer = row.get_node(^"Segments/Cells")
	var buttons := RowFill.fill(cells, cells.get_child(0), options.size())
	for i in options.size():
		var active: bool = i == selected
		var cell: Button = buttons[i]
		cell.name = "Cell%d" % i
		cell.text = ("✓ " if active else "") + tr(String(options[i]))
		cell.theme_type_variation = &"SettingsSegmentOn" if active else &"SettingsSegment"
		cell.pressed.connect(on_change.bind(i))


## Figma 17:280 Stepper — шеврон ліворуч · 280px значення · шеврон праворуч (Resolution, Frame Rate Limit).
## Крок по колу; рядок не перебудовується, тож фокус клавіатури / геймпада лишається на шевроні.
func _add_stepper_row(label_text: String, options: Array[String], selected: int,
		on_change: Callable, enabled: bool = true) -> void:
	if selected < 0:
		push_error("OptionsComponent: '%s' holds a value outside its option list" % label_text)
		return
	var row := _make_row(_stepper_row, label_text, UITokens.SETTINGS_CHOICE_ROW_HEIGHT)
	var value: Label = row.get_node(^"Stepper/Value")
	value.text = options[selected]
	if not enabled:
		value.theme_type_variation = &"SettingsValueDisabled"

	var index: Array[int] = [selected]  # лямбда змінює значення через масив
	var step := func(delta: int) -> void:
		index[0] = wrapi(index[0] + delta, 0, options.size())
		value.text = options[index[0]]
		on_change.call(index[0])
	for spec in [[^"Stepper/Prev", -1], [^"Stepper/Next", 1]]:
		var button: Button = row.get_node(spec[0])
		button.disabled = not enabled
		button.pressed.connect(step.bind(spec[1]))


func _resolution_names() -> Array[String]:
	var names: Array[String] = []
	for value in DisplayManager.available_resolutions():
		names.append(value.replace("x", " × "))
	return names


func _fps_limit_names() -> Array[String]:
	var names: Array[String] = []
	for fps in DisplayManager.FPS_LIMITS:
		names.append(tr("Unlimited") if fps == 0 else tr("%d FPS") % fps)
	return names


## Гучність шини: у налаштуваннях 0.0–1.0, на екрані 0–100.
func _add_volume_row(label_text: String, key: String) -> void:
	_add_slider_row(label_text, roundi(float(_cfg_get(key)) * 100.0), _on_volume_changed.bind(key))


## Figma 17:457 — мінус · 320px доріжка · плюс · значення 0–100. [param on_change] отримує ціле 0–100.
func _add_slider_row(label_text: String, value: int, on_change: Callable,
		height: int = UITokens.SETTINGS_SLIDER_ROW_HEIGHT) -> void:
	var row := _make_row(_slider_row, label_text, height)
	var slider: HSlider = row.get_node(^"Slider/Value")
	var readout: Label = row.get_node(^"Slider/Readout")
	slider.value = value
	readout.text = str(int(slider.value))
	(row.get_node(^"Slider/Minus") as Button).pressed.connect(func() -> void: slider.value -= 5.0)
	(row.get_node(^"Slider/Plus") as Button).pressed.connect(func() -> void: slider.value += 5.0)
	slider.value_changed.connect(func(v: float) -> void:
		readout.text = str(int(v))
		on_change.call(int(v)))


## D428: зразки під Screen Brightness — компас на чорному (DARK) і на білому (BRIGHT). Вони під тим самим
## шаром яскравості, що й уся гра, тож показують її наживо: добра яскравість — видно обидва компаси.
## Не MarginContainer: це не рядок налаштування (тести рядків рахують саме MarginContainer). Останній дочірній
## вузол Pad дає ще один проміжок SPACE_LG справа — правий відступ рядків (SETTINGS_ROW_PAD_H).
func _add_brightness_preview() -> void:
	var swatches: HBoxContainer = _copy(_brightness_preview)
	swatches.name = "BrightnessPreview"
	(swatches.get_node(^"Dark/Swatch/Compass") as TextureRect).modulate = UITokens.SETTINGS_PREVIEW_DARK_MARK
	(swatches.get_node(^"Bright/Swatch/Compass") as TextureRect).modulate = UITokens.SETTINGS_PREVIEW_BRIGHT_MARK
	_list.add_child(swatches)


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
	_cfg_set("display_mode", DisplayManager.DISPLAY_MODES[index])
	_apply_and_save()
	_rebuild_list()


func _on_resolution_changed(index: int) -> void:
	_cfg_set("resolution", DisplayManager.available_resolutions()[index])
	_apply_and_save()


func _on_fps_limit_changed(index: int) -> void:
	_cfg_set("fps_limit", DisplayManager.FPS_LIMITS[index])
	_apply_and_save()


func _on_brightness_changed(value: int) -> void:
	_cfg_set("brightness", value)
	_apply_and_save()


func _on_quality_changed(index: int) -> void:
	_cfg_set("graphics_quality", GraphicsQuality.QUALITIES[index])
	_apply_and_save()
	_rebuild_list()


func _on_text_speed_changed(index: int) -> void:
	_cfg_set("text_speed", SettingsModule.TEXT_SPEEDS.keys()[index])
	_apply_and_save()
	_rebuild_list()


func _on_auto_advance_changed(index: int) -> void:
	_cfg_set("auto_advance", index == 0)
	_apply_and_save()
	_rebuild_list()


func _on_screen_shake_changed(index: int) -> void:
	_cfg_set("screen_shake", index == 0)
	_apply_and_save()
	_rebuild_list()


func _on_tutorial_windows_changed(index: int) -> void:
	_cfg_set("tutorial_windows", index == 0)
	_apply_and_save()
	_rebuild_list()


func _on_damage_numbers_changed(index: int) -> void:
	_cfg_set("damage_numbers", index == 0)
	_apply_and_save()
	_rebuild_list()


func _on_auto_save_changed(index: int) -> void:
	_cfg_set("auto_save", index == 0)
	_apply_and_save()
	_rebuild_list()


func _on_vsync_changed(index: int) -> void:
	_cfg_set("vsync", index == 0)
	_apply_and_save()
	_rebuild_list()


func _on_volume_changed(value: int, key: String) -> void:
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
	# B21: та сама колонка, що й у рядків Audio/Game — внутрішній відступ рядка, без зсуву вгорі.
	for side in ["left", "right"]:
		_input_menu.add_theme_constant_override("margin_" + side, UITokens.SETTINGS_ROW_PAD_H)
	for side in ["top", "bottom"]:
		_input_menu.add_theme_constant_override("margin_" + side, 0)
	var actions: ScrollContainer = _input_menu.get_node(^"%InputActionsList")
	if not actions.sort_children.is_connected(_clip_input_rows):
		actions.sort_children.connect(_clip_input_rows)
		actions.get_node(^"%ParentBoxContainer").sort_children.connect(_clip_input_rows)


## B18: рядок біндингів або видно цілком, або не видно зовсім — половинок на краю вʼюпорта
## немає. Прихований рядок не ловить мишу, але лишається у фокус-навігації: follow_focus
## прокручує його у вʼюпорт, і він знову зʼявляється.
func _clip_input_rows() -> void:
	var actions: ScrollContainer = _input_menu.get_node(^"%InputActionsList")
	var view: Rect2 = actions.get_global_rect()
	for row in actions.get_node(^"%ParentBoxContainer").get_children():
		var whole: bool = view.encloses(row.get_global_rect())
		row.modulate.a = 1.0 if whole else 0.0
		for child in row.get_children():
			if child is BaseButton:
				child.mouse_filter = Control.MOUSE_FILTER_STOP if whole else Control.MOUSE_FILTER_IGNORE


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
	closed.emit()

	# Resume game (if it was paused)
	if get_tree().paused:
		get_tree().paused = false


func _close_game_menu_mode():
	"""Exit to main menu from the in-game Settings tab"""
	SaveSystem.save_game_settings()
	# B64: та сама дорога, що й Misc → Exit to Main Menu — підтвердження, закриття меню, зміна сцени.
	# Раніше тут лише зберігались налаштування: кнопка нічого не робила.
	get_tree().get_first_node_in_group(&"game_menu").request_exit_to_main_menu()
	# (Раніше тут читався GameManager.game_menu_instance — такої властивості немає.)
	get_tree().change_scene_to_file("res://SampleProject/MainMenu.tscn")
