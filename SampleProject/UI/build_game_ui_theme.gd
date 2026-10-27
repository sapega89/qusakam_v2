extends SceneTree

## Генератор GameUITheme.tres з UITokens.
##
## Запуск:
##   godot --headless --path . --script res://SampleProject/UI/build_game_ui_theme.gd
##
## ⚠️ GameUITheme.tres згенерований. Не редагуй його вручну — зміни токени в
## UITokens.gd і перезапусти цей скрипт, інакше правки загубляться.

const OUT_PATH := "res://SampleProject/UI/Themes/GameUITheme.tres"
const ArrowPlateStyle = preload("res://SampleProject/UI/Components/arrow_plate_style.gd")

var _font_regular: FontVariation
var _font_medium: FontVariation
var _font_semibold: FontVariation
var _font_bold: FontVariation


func _initialize() -> void:
	var theme := Theme.new()
	_make_fonts()

	theme.default_font = _font_regular
	theme.default_font_size = UITokens.SIZE_BODY

	_setup_label(theme)
	_setup_label_variations(theme)
	_setup_button(theme)
	_setup_button_variations(theme)
	_setup_panels(theme)
	_main_menu(theme)
	_shop(theme)
	_game_over(theme)
	_setup_progress_bar(theme)
	_hud_v2(theme)
	_new_points(theme)
	_skill_window(theme)
	_world_map(theme)
	_setup_scrollbars(theme)
	_setup_line_edit(theme)
	_setup_slider(theme)
	_setup_tooltip(theme)

	_scale_fonts(theme)

	var dir := OUT_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	# Новий Theme при кожному збереженні отримував новий UID, і сцени, що посилаються
	# на тему за UID, сипали "invalid UID" — тримаємо той, що вже був у файлі.
	var uid := ResourceLoader.get_resource_uid(OUT_PATH) if ResourceLoader.exists(OUT_PATH) \
			else ResourceUID.INVALID_ID
	var err := ResourceSaver.save(theme, OUT_PATH)
	if err != OK:
		printerr("❌ Failed to save theme: %d" % err)
		quit(1)
		return
	if uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(OUT_PATH, uid)

	print("✅ GameUITheme saved to %s" % OUT_PATH)
	print("   font=%s  types=%s" % [UITokens.FONT_PATH.get_file(), theme.get_type_list().size()])
	quit(0)


func _make_fonts() -> void:
	var base: FontFile = load(UITokens.FONT_PATH)
	if base == null:
		printerr("❌ Font not found at %s" % UITokens.FONT_PATH)
		quit(1)
		return
	_font_regular = _weight(base, UITokens.WEIGHT_REGULAR)
	_font_medium = _weight(base, UITokens.WEIGHT_MEDIUM)
	_font_semibold = _weight(base, UITokens.WEIGHT_SEMIBOLD)
	_font_bold = _weight(base, UITokens.WEIGHT_BOLD)


func _weight(base: FontFile, wght: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {"wght": wght}
	return fv


## Плоский стильбокс за токенами. Радіус завжди 0 (Figma: shape/radius-sm).
func _box(bg: Color, border_color: Color, border_width: int = UITokens.BORDER_WIDTH,
		pad_h: int = UITokens.SPACE_MD, pad_v: int = UITokens.SPACE_SM) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(border_width)
	sb.border_color = border_color
	sb.set_corner_radius_all(UITokens.RADIUS)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


func _empty_box() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


## Q33 (BACKLOG 41): єдиний стан "focus" для кожної кнопки в кожному меню — 2px рамка FOCUS_RING
## без заливки. Godot малює focus ПОВЕРХ поточного стану, тож заливка рядка (normal / pressed /
## варіація ...On) лишається своя, а рамка вибраного однакова всюди. [param on_accent] — кнопка
## з акцентною заливкою: там рамка біла, інакше її не видно.
func _focus_ring(pad_h: int = UITokens.SPACE_MD, pad_v: int = UITokens.SPACE_SM,
		on_accent: bool = false) -> StyleBoxFlat:
	return _box(Color(0, 0, 0, 0), UITokens.FOCUS_RING_ON_ACCENT if on_accent else UITokens.FOCUS_RING,
			UITokens.FOCUS_RING_WIDTH, pad_h, pad_v)


# ── Label ───────────────────────────────────────────────────────────────────

func _setup_label(theme: Theme) -> void:
	theme.set_font("font", "Label", _font_regular)
	theme.set_font_size("font_size", "Label", UITokens.SIZE_BODY)
	theme.set_color("font_color", "Label", UITokens.TEXT_PRIMARY)
	theme.set_color("font_outline_color", "Label", UITokens.BACKGROUND)
	theme.set_constant("outline_size", "Label", 0)


func _setup_label_variations(theme: Theme) -> void:
	# Figma typography roles. Body == базовий Label.
	var roles := {
		"DisplayLabel": [_font_bold, UITokens.SIZE_DISPLAY, UITokens.TEXT_PRIMARY],
		"TitleLabel": [_font_bold, UITokens.SIZE_TITLE, UITokens.TEXT_PRIMARY],
		"HeadingLabel": [_font_semibold, UITokens.SIZE_HEADING, UITokens.TEXT_PRIMARY],
		"UILabel": [_font_semibold, UITokens.SIZE_LABEL, UITokens.TEXT_PRIMARY],
		"SmallLabel": [_font_regular, UITokens.SIZE_SMALL, UITokens.TEXT_SECONDARY],
		"ValueLabel": [_font_semibold, UITokens.SIZE_VALUE, UITokens.TEXT_PRIMARY],
		"CaptionLabel": [_font_bold, UITokens.SIZE_CAPTION, UITokens.TEXT_SECONDARY],
		"ActionBadgeLabel": [_font_bold, UITokens.SIZE_CAPTION, UITokens.ON_ACCENT],  # літера на значку дії
		"AccentLabel": [_font_semibold, UITokens.SIZE_LABEL, UITokens.ACCENT],
		"MutedLabel": [_font_regular, UITokens.SIZE_SMALL, UITokens.TEXT_MUTED],
		# Виміряні з кадру menu-inventory (46:193) — поза задекларованою шкалою.
		"TopBarTitle": [_font_bold, UITokens.SIZE_TOPBAR, UITokens.TEXT_PRIMARY],
		"ListRowTitle": [_font_medium, UITokens.SIZE_ROW_TITLE, UITokens.TEXT_PRIMARY],
		"ListRowCount": [_font_semibold, UITokens.SIZE_LABEL, UITokens.TEXT_PRIMARY],
		"ColumnHeader": [_font_bold, UITokens.SIZE_SMALL, UITokens.TEXT_SECONDARY],
		"MicroLabel": [_font_bold, UITokens.SIZE_MICRO, UITokens.TEXT_SECONDARY],
		"StatLabel": [_font_bold, UITokens.SIZE_CAPTION, UITokens.TEXT_SECONDARY],
		"StatValue": [_font_regular, UITokens.SIZE_CAPTION, UITokens.TEXT_PRIMARY],
		"CardName": [_font_bold, UITokens.SIZE_HEADING, UITokens.TEXT_PRIMARY],
		"BigValue": [_font_bold, UITokens.SIZE_TITLE, UITokens.TEXT_PRIMARY],
		"BigValueAccent": [_font_bold, UITokens.SIZE_TITLE, UITokens.ACCENT],
		# Figma save/load (150:1278, 17:5)
		"SaveSystemLabel": [_font_regular, UITokens.SIZE_SAVE_SYSTEM, UITokens.TEXT_PRIMARY],
		"SlotDate": [_font_regular, UITokens.SIZE_BODY_SM, UITokens.TEXT_PRIMARY],
		"SlotLocation": [_font_bold, UITokens.SIZE_SAVE_LOCATION, UITokens.TEXT_PRIMARY],
		"SlotLevel": [_font_bold, UITokens.SIZE_SAVE_LEVEL, UITokens.ACCENT],
		"SlotName": [_font_semibold, UITokens.SIZE_SAVE_NAME, UITokens.TEXT_PRIMARY],
		"SlotWatermark": [_font_bold, UITokens.SIZE_SAVE_WATERMARK, UITokens.SAVE_WATERMARK_COLOR],
		"SlotEmptyText": [_font_regular, UITokens.SIZE_SMALL, UITokens.TEXT_PRIMARY],
		# Figma menu-status (58:719)
		"StatusName": [_font_bold, UITokens.SIZE_NAME, UITokens.TEXT_PRIMARY],
		"StatusLevel": [_font_bold, UITokens.SIZE_LEVEL, UITokens.ACCENT],
		"SectionCaption": [_font_regular, UITokens.SIZE_CAPTION_SM, UITokens.TEXT_SECONDARY],
		"SectionHeader": [_font_semibold, UITokens.SIZE_SMALL, UITokens.ACCENT],
		"MetaLabel": [_font_regular, UITokens.SIZE_SMALL, UITokens.TEXT_SECONDARY],
		"MetaValue": [_font_semibold, UITokens.SIZE_LABEL, UITokens.TEXT_PRIMARY],
		"MetaValueAccent": [_font_semibold, UITokens.SIZE_LABEL, UITokens.ACCENT],
		"JobName": [_font_semibold, UITokens.SIZE_ROW_TITLE, UITokens.TEXT_PRIMARY],
		"AttrLabel": [_font_regular, UITokens.SIZE_LABEL, UITokens.TEXT_PRIMARY],
		"AttrValue": [_font_bold, UITokens.SIZE_ROW_TITLE, UITokens.TEXT_PRIMARY],
		"MeterValue": [_font_bold, UITokens.SIZE_HEADING, UITokens.TEXT_PRIMARY],
		"CardTitle": [_font_bold, UITokens.SIZE_HEADING, UITokens.TEXT_PRIMARY],
		"CardCaption": [_font_regular, UITokens.SIZE_CAPTION_SM, UITokens.ACCENT],
		"CardBody": [_font_regular, UITokens.SIZE_BODY_SM, UITokens.TEXT_PRIMARY],
		# Figma UI/Equipment Panel (258:5110)
		"SlotCaption": [_font_regular, UITokens.SIZE_SMALL, UITokens.TEXT_SECONDARY],
		"SlotItemName": [_font_bold, UITokens.SIZE_HEADING, UITokens.TEXT_PRIMARY],
		"SlotItemEmpty": [_font_regular, UITokens.SIZE_HEADING, UITokens.TEXT_MUTED],
		"PanelEyebrow": [_font_regular, UITokens.SIZE_CAPTION_SM, UITokens.ACCENT],
		"PanelHeading": [_font_bold, UITokens.SIZE_TITLE, UITokens.ACCENT],
		"StatDelta": [_font_regular, UITokens.SIZE_CAPTION, UITokens.HP_FILL],
		# Figma menu-skills (58:453)
		"SkillName": [_font_medium, UITokens.SIZE_ROW_TITLE, UITokens.TEXT_PRIMARY],
		"SkillNameLocked": [_font_medium, UITokens.SIZE_ROW_TITLE, UITokens.TEXT_SECONDARY],
		"SkillNameSelected": [_font_bold, UITokens.SIZE_ROW_TITLE, UITokens.TEXT_PRIMARY],
		"SkillCost": [_font_regular, UITokens.SIZE_LABEL, UITokens.ACCENT],
		# Підпис стану вузла (D332): вивчено / заблоковано / на вибраному (акцентна заливка, D26).
		"SkillCostLearned": [_font_regular, UITokens.SIZE_LABEL, UITokens.TEXT_PRIMARY],
		"SkillCostLocked": [_font_regular, UITokens.SIZE_LABEL, UITokens.TEXT_MUTED],
		"SkillCostSelected": [_font_regular, UITokens.SIZE_LABEL, UITokens.ON_ACCENT],
		"SectionLabel": [_font_regular, UITokens.SIZE_LABEL, UITokens.TEXT_SECONDARY],
		"TreeTitle": [_font_bold, UITokens.SIZE_TOPBAR, UITokens.ACCENT],
		"TooltipTitle": [_font_medium, UITokens.SIZE_LABEL, UITokens.ACCENT],
		"TooltipBody": [_font_regular, UITokens.SIZE_CAPTION_SM, UITokens.TEXT_PRIMARY],
		# HUD v2 (Figma 501:6611 панель героя, 497:6587 хотбар; combat_hud_mapping → HUD v2)
		"BindBadge": [_font_bold, UITokens.SIZE_HUD_KEY, UITokens.HUD_INK],
		"CooldownLabel": [_font_bold, UITokens.SIZE_HUD_COOLDOWN, UITokens.TEXT_PRIMARY],
		"VitalsName": [_spaced(_font_bold, UITokens.HUD_NAME_SPACING), UITokens.SIZE_HUD_NAME, UITokens.HUD_GOLD_LIGHT],
		"VitalsLabel": [_font_bold, UITokens.SIZE_HUD_ROW_LABEL, UITokens.HUD_TEXT_SOFT],
		"VitalsValue": [_font_semibold, UITokens.SIZE_HUD_ROW_VALUE, UITokens.TEXT_PRIMARY],
		"HudClass": [_font_regular, UITokens.SIZE_HUD_CLASS, UITokens.HUD_TEXT_SOFT],
		"HudLevel": [_font_bold, UITokens.SIZE_HUD_LEVEL, UITokens.HUD_INK],
		"HudSpCost": [_font_bold, UITokens.SIZE_HUD_SP_COST, UITokens.TEXT_PRIMARY],
		"HudCount": [_font_bold, UITokens.SIZE_HUD_COUNT, UITokens.HUD_GOLD_LIGHT],
		"QuestCaption": [_font_regular, UITokens.SIZE_SMALL, UITokens.ACCENT],
		"QuestTitle": [_font_regular, UITokens.SIZE_BODY, UITokens.TEXT_PRIMARY],
		# Ті самі ролі в панелі квесту HUD (D474: ігрова поверхня); QuestCaption — ще й у Journal, QuestTitle — у боса.
		"HudQuestCaption": [_font_regular, UITokens.SIZE_SMALL, UITokens.ACCENT],
		"HudQuestTitle": [_font_regular, UITokens.SIZE_BODY, UITokens.TEXT_PRIMARY],
		# Вікно діалогу (D134): ім'я мовця й текст репліки — як базовий Label, але ігрова поверхня (D474).
		"DialogueName": [_font_regular, UITokens.SIZE_BODY, UITokens.TEXT_PRIMARY],
		"CurrencyGlyph": [_font_regular, UITokens.SIZE_LABEL, UITokens.ACCENT],
		"CurrencyValue": [_font_semibold, UITokens.SIZE_SMALL, UITokens.ACCENT],
		# Figma menu-world-map (94:609)
		"MapTitle": [_font_bold, UITokens.SIZE_MAP_TITLE, UITokens.ACCENT],
		"MapSubtitle": [_font_regular, UITokens.SIZE_ROW_TITLE, UITokens.TEXT_PRIMARY],
		# Figma settings-* (17:280 / 17:409 / 17:632 / 17:756)
		"SettingsSystem": [_font_regular, UITokens.SIZE_CAPTION, UITokens.TEXT_PRIMARY],
		"SettingsTitle": [_font_bold, UITokens.SIZE_OPTIONS_TITLE, UITokens.TEXT_PRIMARY],
		"SettingsEyebrow": [_font_regular, UITokens.SIZE_SMALL, UITokens.ACCENT],
		"SettingsHeading": [_font_bold, UITokens.SIZE_DISPLAY, UITokens.TEXT_PRIMARY],
		"SettingsRowLabel": [_font_medium, UITokens.SIZE_ROW_TITLE, UITokens.TEXT_PRIMARY],
		"SettingsValue": [_font_regular, UITokens.SIZE_BODY, UITokens.TEXT_PRIMARY],
		"SettingsValueDisabled": [_font_regular, UITokens.SIZE_BODY, UITokens.TEXT_DISABLED],  # Resolution не у Windowed
		"SettingsHint": [_font_regular, UITokens.SIZE_BODY_SM, UITokens.TEXT_SECONDARY],
		# Figma UI/Modal/Confirm (258:5332) — заголовок над описом (B34)
		"ModalTitle": [_font_regular, UITokens.SIZE_MODAL_TITLE, UITokens.TEXT_PRIMARY],
	}
	for name in roles:
		var spec: Array = roles[name]
		theme.set_type_variation(name, "Label")
		theme.set_font("font", name, spec[0])
		theme.set_font_size("font_size", name, spec[1])
		theme.set_color("font_color", name, spec[2])


# ── Button ──────────────────────────────────────────────────────────────────

## Базова Button == Figma UI/Button Type=Secondary.
func _setup_button(theme: Theme) -> void:
	theme.set_font("font", "Button", _font_semibold)
	theme.set_font_size("font_size", "Button", UITokens.SIZE_LABEL)
	theme.set_color("font_color", "Button", UITokens.TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", UITokens.ACCENT)
	theme.set_color("font_pressed_color", "Button", UITokens.ON_ACCENT)
	theme.set_color("font_focus_color", "Button", UITokens.TEXT_PRIMARY)
	theme.set_color("font_disabled_color", "Button", UITokens.TEXT_DISABLED)
	theme.set_constant("h_separation", "Button", UITokens.ICON_TEXT_GAP)

	var pad_h := UITokens.SPACE_LG
	var pad_v := UITokens.SPACE_MD
	theme.set_stylebox("normal", "Button", _box(UITokens.SURFACE, UITokens.BORDER, UITokens.BORDER_WIDTH, pad_h, pad_v))
	theme.set_stylebox("hover", "Button", _box(UITokens.SURFACE_HOVER, UITokens.BORDER_STRONG, UITokens.BORDER_WIDTH, pad_h, pad_v))
	theme.set_stylebox("pressed", "Button", _box(UITokens.ACCENT, UITokens.ACCENT, UITokens.BORDER_WIDTH_SELECTED, pad_h, pad_v))
	theme.set_stylebox("focus", "Button", _focus_ring(pad_h, pad_v))
	theme.set_stylebox("disabled", "Button", _box(Color(UITokens.SURFACE, 0.25), UITokens.BORDER, UITokens.BORDER_WIDTH, pad_h, pad_v))
	# B27 (#75): DialogueQuest Auto/Skip ставлять цю варіацію; без власних значень вона = базова Button.
	# Окремий стан "увімкнено" відкладено до D110 (#24).
	theme.set_type_variation("ButtonActivated", "Button")
	# Відповіді в ChoiceMenu діалогу (D474): базова Button з більшим текстом.
	theme.set_type_variation("DialogueChoice", "Button")
	theme.set_font_size("font_size", "DialogueChoice", UITokens.SIZE_LABEL)
	# Текст репліки (RichTextLabel) у вікні діалогу (D474).
	theme.set_type_variation("DialogueText", "RichTextLabel")
	for size_name in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		theme.set_font_size(size_name, "DialogueText", UITokens.SIZE_BODY)


func _setup_button_variations(theme: Theme) -> void:
	_primary_button(theme)
	_tab_button(theme)
	_sidebar_tab(theme)
	_icon_button(theme)
	_filter_button(theme)
	_list_row(theme)
	_side_story(theme)
	_tutorial(theme)
	_skill_row(theme)
	_settings_segment(theme)
	_settings_stepper(theme)
	_settings_sidebar_tab(theme)
	_settings_rows(theme)
	_misc_row(theme)


## Figma misc-sub-menu (84:589) — рядок 500px із градієнтом, що згасає вправо.
## Вибраний світліший; StyleBoxTexture дозволяє віддати градієнт темі,
## а не малювати його локально в сцені.
func _misc_row(theme: Theme) -> void:
	for t in ["MiscRow", "MiscRowOn"]:
		var on: bool = t == "MiscRowOn"
		theme.set_type_variation(t, "Button")
		theme.set_font("font", t, _font_regular)
		theme.set_font_size("font_size", t, UITokens.SIZE_ROW_TITLE)
		theme.set_color("font_color", t, UITokens.TEXT_PRIMARY if on else UITokens.TEXT_SECONDARY)
		theme.set_color("font_hover_color", t, UITokens.TEXT_PRIMARY)
		theme.set_color("font_pressed_color", t, UITokens.TEXT_PRIMARY)
		theme.set_color("font_focus_color", t, UITokens.TEXT_PRIMARY)
		var normal := _gradient_box(UITokens.MISC_ROW_ON if on else UITokens.MISC_ROW_OFF)
		theme.set_stylebox("normal", t, normal)
		theme.set_stylebox("hover", t, _gradient_box(UITokens.MISC_ROW_ON))
		theme.set_stylebox("pressed", t, _gradient_box(UITokens.MISC_ROW_ON))
		theme.set_stylebox("focus", t, _focus_ring(UITokens.MISC_ROW_PAD_H, UITokens.MISC_ROW_PAD_V))
		theme.set_stylebox("disabled", t, _gradient_box(UITokens.MISC_ROW_OFF))


func _gradient_box(colors: Array) -> StyleBoxTexture:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(UITokens.MISC_ROW_STOPS)
	gradient.colors = PackedColorArray(colors)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	tex.width = UITokens.MISC_ROW_WIDTH
	tex.height = 4
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.content_margin_left = UITokens.MISC_ROW_PAD_H
	box.content_margin_right = UITokens.MISC_ROW_PAD_H
	box.content_margin_top = UITokens.MISC_ROW_PAD_V
	box.content_margin_bottom = UITokens.MISC_ROW_PAD_V
	return box


## Figma settings-* сегментований перемикач (17:350).
## Вибраний сегмент — акцентна заливка з темним текстом; контейнер малює рамку.
func _settings_segment(theme: Theme) -> void:
	# Figma 17:350 — спільна рамка комірок (рядки Settings, вкладки пристроїв на Controls).
	theme.set_type_variation("SettingsSegmentFrame", "PanelContainer")
	theme.set_stylebox("panel", "SettingsSegmentFrame", _box(UITokens.SURFACE, UITokens.TEXT_PRIMARY,
			UITokens.BORDER_WIDTH, 0, 0))
	var pad_h := UITokens.SPACE_3XL
	var pad_v := UITokens.SPACE_SM
	for t in ["SettingsSegment", "SettingsSegmentOn"]:
		var on: bool = t == "SettingsSegmentOn"
		theme.set_type_variation(t, "Button")
		theme.set_font("font", t, _font_semibold)
		theme.set_font_size("font_size", t, UITokens.SIZE_LABEL)
		theme.set_color("font_color", t, UITokens.SETTINGS_ON_ACCENT if on else UITokens.TEXT_PRIMARY)
		theme.set_color("font_hover_color", t, UITokens.SETTINGS_ON_ACCENT if on else UITokens.ACCENT)
		theme.set_color("font_pressed_color", t, UITokens.SETTINGS_ON_ACCENT)
		theme.set_color("font_focus_color", t, UITokens.SETTINGS_ON_ACCENT if on else UITokens.TEXT_PRIMARY)
		var bg := UITokens.ACCENT if on else Color(0, 0, 0, 0)
		theme.set_stylebox("normal", t, _box(bg, Color(0, 0, 0, 0), 0, pad_h, pad_v))
		theme.set_stylebox("hover", t, _box(bg if on else UITokens.SURFACE_HOVER,
				Color(0, 0, 0, 0), 0, pad_h, pad_v))
		theme.set_stylebox("pressed", t, _box(UITokens.ACCENT, Color(0, 0, 0, 0), 0, pad_h, pad_v))
		theme.set_stylebox("focus", t, _focus_ring(pad_h, pad_v, on))
		theme.set_stylebox("disabled", t, _box(bg, Color(0, 0, 0, 0), 0, pad_h, pad_v))


## Figma settings-* стрілки степера (17:546 / 17:549) — 16px гліф. У Figma без фону; у грі — рамка 1px, як у
## сегментів, Reset і кнопок футера, інакше голий «−» / «+» не читається як кнопка (B22, агентське рішення).
## Квадрат SETTINGS_STEPPER_BOX ставить options_component.gd (тема не задає мінімальний розмір кнопки).
func _settings_stepper(theme: Theme) -> void:
	var t := "SettingsStepper"
	theme.set_type_variation(t, "Button")
	theme.set_font("font", t, _font_regular)
	theme.set_font_size("font_size", t, UITokens.SIZE_LABEL)
	theme.set_color("font_color", t, UITokens.TEXT_PRIMARY)
	theme.set_color("font_hover_color", t, UITokens.ACCENT)
	theme.set_color("font_pressed_color", t, UITokens.ACCENT)
	theme.set_color("font_disabled_color", t, UITokens.TEXT_DISABLED)
	var pad := UITokens.SPACE_XS
	theme.set_stylebox("normal", t, _box(Color(0, 0, 0, 0), UITokens.BORDER, UITokens.BORDER_WIDTH, pad, pad))
	theme.set_stylebox("hover", t, _box(UITokens.SURFACE_HOVER, UITokens.BORDER_STRONG, UITokens.BORDER_WIDTH, pad, pad))
	theme.set_stylebox("pressed", t, _box(UITokens.SURFACE_HOVER, UITokens.BORDER_STRONG, UITokens.BORDER_WIDTH, pad, pad))
	theme.set_stylebox("disabled", t, _box(Color(0, 0, 0, 0), UITokens.TEXT_DISABLED, UITokens.BORDER_WIDTH, pad, pad))
	theme.set_stylebox("focus", t, _focus_ring(pad, pad))


## D117: шаблони рядків Settings (options_component.tscn) — відступи, лінія між рядками, зразки яскравості.
func _settings_rows(theme: Theme) -> void:
	theme.set_type_variation("SettingsRow", "MarginContainer")
	theme.set_constant("margin_left", "SettingsRow", UITokens.SETTINGS_ROW_PAD_H)
	theme.set_constant("margin_right", "SettingsRow", UITokens.SETTINGS_ROW_PAD_H)
	theme.set_type_variation("SettingsSeparator", "HSeparator")
	var line := StyleBoxLine.new()
	line.color = UITokens.BORDER
	line.thickness = UITokens.SETTINGS_ROW_GAP
	theme.set_stylebox("separator", "SettingsSeparator", line)
	theme.set_constant("separation", "SettingsSeparator", UITokens.SETTINGS_ROW_GAP)
	for spec in [["SettingsControlGroup", "HBoxContainer", UITokens.SPACE_LG],
			["SettingsSegmentCells", "HBoxContainer", 0],
			["SettingsPreviewColumn", "VBoxContainer", UITokens.SPACE_XS]]:
		theme.set_type_variation(spec[0], spec[1])
		theme.set_constant("separation", spec[0], spec[2])
	# D428: зразок DARK / BRIGHT — заливка й 1px рамка.
	for spec in [["SettingsPreviewDark", UITokens.SETTINGS_PREVIEW_DARK_BG],
			["SettingsPreviewBright", UITokens.SETTINGS_PREVIEW_BRIGHT_BG]]:
		theme.set_type_variation(spec[0], "PanelContainer")
		theme.set_stylebox("panel", spec[0], _box(spec[1], UITokens.BORDER, UITokens.BORDER_WIDTH, 0, 0))


## Figma UI/Settings Tab (117:835) — 36×36, активний має акцентну рамку,
## неактивний іде на 50% прозорості.
func _settings_sidebar_tab(theme: Theme) -> void:
	var t := "SettingsSidebarTab"
	theme.set_type_variation(t, "Button")
	theme.set_font("font", t, _font_semibold)
	theme.set_font_size("font_size", t, UITokens.SIZE_LABEL)
	theme.set_color("font_color", t, UITokens.TEXT_PRIMARY)
	theme.set_color("font_hover_color", t, UITokens.ACCENT)
	theme.set_color("font_pressed_color", t, UITokens.ACCENT)
	theme.set_stylebox("normal", t, _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, UITokens.SPACE_SM, UITokens.SPACE_SM))
	theme.set_stylebox("hover", t, _box(UITokens.SURFACE_HOVER, UITokens.BORDER,
			UITokens.BORDER_WIDTH, UITokens.SPACE_SM, UITokens.SPACE_SM))
	theme.set_stylebox("pressed", t, _box(Color(0, 0, 0, 0), UITokens.BORDER_STRONG,
			UITokens.BORDER_WIDTH, UITokens.SPACE_SM, UITokens.SPACE_SM))
	theme.set_stylebox("focus", t, _focus_ring(UITokens.SPACE_SM, UITokens.SPACE_SM))
	theme.set_stylebox("disabled", t, _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, UITokens.SPACE_SM, UITokens.SPACE_SM))


## Figma menu-skills: рядок навички — px16 py10, 1px рамка,
## виділений = акцентна заливка (текст лишається світлим).
func _skill_row(theme: Theme) -> void:
	var t := "SkillRow"
	theme.set_type_variation(t, "Button")
	var pad_h := UITokens.PANEL_PADDING
	var pad_v := 10
	theme.set_stylebox("normal", t, _box(Color(0, 0, 0, 0), UITokens.BORDER,
			UITokens.BORDER_WIDTH, pad_h, pad_v))
	theme.set_stylebox("hover", t, _box(UITokens.SURFACE_HOVER, UITokens.BORDER_STRONG,
			UITokens.BORDER_WIDTH, pad_h, pad_v))
	theme.set_stylebox("pressed", t, _box(UITokens.ACCENT, UITokens.BORDER,
			UITokens.BORDER_WIDTH, pad_h, pad_v))
	theme.set_stylebox("focus", t, _box(Color(0, 0, 0, 0), UITokens.ACCENT,
			UITokens.BORDER_WIDTH_SELECTED, pad_h, pad_v))
	theme.set_stylebox("disabled", t, _box(Color(0, 0, 0, 0), UITokens.BORDER,
			UITokens.BORDER_WIDTH, pad_h, pad_v))


## Figma filter-trigger — єдине місце в киті з ненульовим радіусом (3px).
func _filter_button(theme: Theme) -> void:
	var t := "FilterButton"
	theme.set_type_variation(t, "Button")
	theme.set_font("font", t, _font_regular)
	theme.set_font_size("font_size", t, UITokens.SIZE_SMALL)
	theme.set_color("font_color", t, UITokens.ACCENT)
	theme.set_color("font_hover_color", t, UITokens.ON_ACCENT)
	theme.set_color("font_pressed_color", t, UITokens.ON_ACCENT)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var bg := UITokens.ACCENT if state in ["hover", "pressed"] else Color(0, 0, 0, 0)
		var sb := _box(bg, UITokens.ACCENT, UITokens.BORDER_WIDTH, UITokens.SPACE_MD, 6)
		sb.set_corner_radius_all(3)
		theme.set_stylebox(state, t, sb)
	# Раніше фокус = звичайний стан (на геймпаді не видно, де курсор) — тепер спільна рамка (Q33).
	var focus := _focus_ring(UITokens.SPACE_MD, 6)
	focus.set_corner_radius_all(3)
	theme.set_stylebox("focus", t, focus)


## Figma UI/ListRow у кадрі menu-inventory (250:4983 / 250:4988).
## Рядок — Button, щоб безкоштовно отримати фокус, hover і активацію з клавіатури.
func _list_row(theme: Theme) -> void:
	var t := "ListRow"
	theme.set_type_variation(t, "Button")
	var pad_h := UITokens.PANEL_PADDING
	var pad_v := UITokens.LIST_ROW_PADDING
	# normal: фон = color/background, без рамки
	theme.set_stylebox("normal", t, _box(UITokens.BACKGROUND, Color(0, 0, 0, 0), 0, pad_h, pad_v))
	theme.set_stylebox("hover", t, _box(UITokens.SURFACE_HOVER, UITokens.BORDER,
			UITokens.BORDER_WIDTH, pad_h, pad_v))
	# selected: акцентна заливка + 2px акцентна рамка
	theme.set_stylebox("pressed", t, _box(UITokens.ACCENT, UITokens.BORDER_STRONG,
			UITokens.BORDER_WIDTH_SELECTED, pad_h, pad_v))
	theme.set_stylebox("focus", t, _focus_ring(pad_h, pad_v))
	# Фокус на вибраному (акцентному) рядку — біле кільце (D329); малює list_row.gd, бо "focus" не знає pressed (B90).
	theme.set_stylebox("focus_selected", t, _focus_ring(pad_h, pad_v, true))
	theme.set_stylebox("disabled", t, _box(Color(UITokens.BACKGROUND, 0.5),
			Color(0, 0, 0, 0), 0, pad_h, pad_v))

	# Підпункт списку (ціль під підетапом у журналі, D125): той самий рядок,
	# дрібніший шрифт і відступ зліва, щоб читалась вкладеність.
	var sub := "ListSubRow"
	theme.set_type_variation(sub, t)
	theme.set_font_size("font_size", sub, UITokens.SIZE_BODY_SM)
	var sub_pad_v := UITokens.SPACE_SM
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := (theme.get_stylebox(state, t) as StyleBoxFlat).duplicate() as StyleBoxFlat
		box.content_margin_left = pad_h + UITokens.SPACE_XL
		box.content_margin_top = sub_pad_v
		box.content_margin_bottom = sub_pad_v
		theme.set_stylebox(state, sub, box)

	# Заголовок групи в списку журналу (D181, смуга регіону Figma 192:1636): рядок-напис у стилі QuestCaption —
	# без фону, не вибирається.
	var group := "ListGroupRow"
	theme.set_type_variation(group, t)
	theme.set_font("font", group, _font_regular)
	theme.set_font_size("font_size", group, UITokens.SIZE_SMALL)
	theme.set_color("font_disabled_color", group, UITokens.ACCENT)
	for state in ["normal", "hover", "pressed", "disabled"]:  # focus — спільне кільце від ListRow
		theme.set_stylebox(state, group, _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, pad_h, UITokens.SPACE_SM))
	# Підказка під ціллю (D159): ще глибше за підпункт, дрібніше й приглушено, без фону, не вибирається.
	var hint := "ListHintRow"
	theme.set_type_variation(hint, sub)
	theme.set_font_size("font_size", hint, UITokens.SIZE_SMALL)
	theme.set_color("font_disabled_color", hint, UITokens.TEXT_SECONDARY)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, pad_h, UITokens.SPACE_XS)
		box.content_margin_left = pad_h + 2 * UITokens.SPACE_XL
		theme.set_stylebox(state, hint, box)


## Картка побічної історії в Журналі (D767, Figma journal-side-stories 192:1636): мітки стану й локації
## (рамка accent, без фону) і слова замовника курсивом (нахил шрифту — курсивного накреслення немає).
func _side_story(theme: Theme) -> void:
	theme.set_type_variation("StoryTag", "PanelContainer")
	theme.set_stylebox("panel", "StoryTag", _box(Color(0, 0, 0, 0), UITokens.ACCENT, UITokens.BORDER_WIDTH,
			UITokens.STORY_TAG_PADDING_H, UITokens.STORY_TAG_PADDING_V))
	theme.set_type_variation("StoryTagLabel", "Label")
	theme.set_font("font", "StoryTagLabel", _font_semibold)
	theme.set_font_size("font_size", "StoryTagLabel", UITokens.SIZE_SMALL)
	theme.set_color("font_color", "StoryTagLabel", UITokens.ACCENT)
	var slanted := _weight(_font_regular.base_font, UITokens.WEIGHT_REGULAR)
	slanted.variation_transform = Transform2D(Vector2(1, 0), Vector2(UITokens.QUOTE_SLANT, 1), Vector2.ZERO)
	theme.set_type_variation("StoryQuote", "Label")
	theme.set_font("font", "StoryQuote", slanted)
	theme.set_font_size("font_size", "StoryQuote", UITokens.SIZE_BODY_SM)
	theme.set_color("font_color", "StoryQuote", UITokens.TEXT_SECONDARY)


## Figma tutorial-content 135:1260 — повноекранне вікно туторіалу (D126).
func _tutorial(theme: Theme) -> void:
	theme.set_type_variation("ScreenPanel", "Panel")
	theme.set_stylebox("panel", "ScreenPanel", _box(UITokens.BACKGROUND, Color(0, 0, 0, 0), 0, 0, 0))

	for spec in [["FrameRule", UITokens.BORDER, UITokens.BORDER_WIDTH],
			["AccentRule", UITokens.ACCENT, UITokens.BORDER_WIDTH_SELECTED]]:
		theme.set_type_variation(spec[0], "HSeparator")
		var rule := StyleBoxLine.new()
		rule.color = spec[1]
		rule.thickness = spec[2]
		theme.set_stylebox("separator", spec[0], rule)
		theme.set_constant("separation", spec[0], spec[2])

	# Рамка скріншота: 2px color/border, без фону.
	theme.set_type_variation("TutorialShot", "PanelContainer")
	theme.set_stylebox("panel", "TutorialShot", _box(Color(0, 0, 0, 0), UITokens.BORDER,
			UITokens.BORDER_WIDTH_SELECTED, 0, 0))
	# Бейдж клавіші (Figma UI/RB Controller Button): surface, акцентна рамка, Bold 14.
	theme.set_type_variation("KeyBadge", "PanelContainer")
	theme.set_stylebox("panel", "KeyBadge", _box(UITokens.SURFACE, UITokens.ACCENT,
			UITokens.BORDER_WIDTH_SELECTED, UITokens.SPACE_SM, UITokens.SPACE_2XS))

	var labels := {
		"TutorialBody": [_font_regular, UITokens.SIZE_TUTORIAL_BODY, UITokens.TEXT_PRIMARY],
		"TutorialHint": [_font_regular, UITokens.SIZE_ROW_TITLE, UITokens.TEXT_PRIMARY],
		"KeyBadgeLabel": [_font_bold, UITokens.SIZE_SMALL, UITokens.TEXT_PRIMARY],
		# Вікно туторіалу й «?» підказки — ігрові поверхні (D474); KeyBadgeLabel лишається в Controls.
		"TutorialKeyLabel": [_font_bold, UITokens.SIZE_SMALL, UITokens.TEXT_PRIMARY],
	}
	for name in labels:
		theme.set_type_variation(name, "Label")
		theme.set_font("font", name, labels[name][0])
		theme.set_font_size("font_size", name, labels[name][1])
		theme.set_color("font_color", name, labels[name][2])
	theme.set_constant("line_spacing", "TutorialBody", UITokens.SIZE_TUTORIAL_BODY / 2)


## Figma UI/Button Type=Primary — акцентна заливка, темний текст.
func _primary_button(theme: Theme) -> void:
	var t := "PrimaryButton"
	theme.set_type_variation(t, "Button")
	theme.set_font("font", t, _font_semibold)
	theme.set_font_size("font_size", t, UITokens.SIZE_LABEL)
	theme.set_color("font_color", t, UITokens.ON_ACCENT)
	theme.set_color("font_hover_color", t, UITokens.ON_ACCENT)
	theme.set_color("font_pressed_color", t, UITokens.ON_ACCENT)
	theme.set_color("font_disabled_color", t, UITokens.TEXT_DISABLED)
	var pad_h := UITokens.SPACE_LG
	var pad_v := UITokens.SPACE_MD
	theme.set_stylebox("normal", t, _box(UITokens.ACCENT, UITokens.ACCENT, UITokens.BORDER_WIDTH, pad_h, pad_v))
	theme.set_stylebox("hover", t, _box(UITokens.ACCENT.lightened(0.12), UITokens.ACCENT.lightened(0.12), UITokens.BORDER_WIDTH, pad_h, pad_v))
	theme.set_stylebox("pressed", t, _box(UITokens.ACCENT.darkened(0.18), UITokens.ACCENT, UITokens.BORDER_WIDTH_SELECTED, pad_h, pad_v))
	theme.set_stylebox("focus", t, _focus_ring(pad_h, pad_v, true))
	theme.set_stylebox("disabled", t, _box(Color(UITokens.ACCENT, 0.25), UITokens.BORDER, UITokens.BORDER_WIDTH, pad_h, pad_v))


## Figma UI/Tab у кадрі menu-inventory: Bold 18, px 20, py 10,
## виділений = акцентний текст + 2px акцентна нижня межа.
func _tab_button(theme: Theme) -> void:
	var t := "TabButton"
	theme.set_type_variation(t, "Button")
	theme.set_font("font", t, _font_bold)
	theme.set_font_size("font_size", t, UITokens.SIZE_ROW_TITLE)
	theme.set_color("font_color", t, UITokens.TEXT_SECONDARY)
	theme.set_color("font_hover_color", t, UITokens.TEXT_PRIMARY)
	theme.set_color("font_pressed_color", t, UITokens.ACCENT)
	theme.set_color("font_disabled_color", t, UITokens.TEXT_DISABLED)
	var pad_h := 20
	var pad_v := 10
	theme.set_stylebox("normal", t, _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, pad_h, pad_v))
	theme.set_stylebox("hover", t, _box(UITokens.SURFACE_HOVER, Color(0, 0, 0, 0), 0, pad_h, pad_v))
	theme.set_stylebox("focus", t, _focus_ring(pad_h, pad_v))
	theme.set_stylebox("disabled", t, _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, pad_h, pad_v))
	# Виділений таб: підкреслення акцентом знизу.
	var sel := _box(Color(0, 0, 0, 0), UITokens.ACCENT, 0, pad_h, pad_v)
	sel.border_width_bottom = UITokens.BORDER_WIDTH_SELECTED
	theme.set_stylebox("pressed", t, sel)


## Figma UI/Sidebar Tab — вертикальна навігація ігрового меню.
func _sidebar_tab(theme: Theme) -> void:
	var t := "SidebarTab"
	theme.set_type_variation(t, "Button")
	theme.set_font("font", t, _font_semibold)
	theme.set_font_size("font_size", t, UITokens.SIZE_LABEL)
	theme.set_color("font_color", t, UITokens.TEXT_SECONDARY)
	theme.set_color("font_hover_color", t, UITokens.TEXT_PRIMARY)
	theme.set_color("font_pressed_color", t, UITokens.TEXT_PRIMARY)
	theme.set_color("font_focus_color", t, UITokens.TEXT_PRIMARY)
	theme.set_color("font_disabled_color", t, UITokens.TEXT_DISABLED)
	# Вказівник ▶ — як у головному меню: іконка стоїть на кожній вкладці, але
	# прозора; видима лише у варіації SidebarTabOn (D118). Місце під неї
	# зарезервоване завжди — текст не стрибає.
	var icon_states := ["icon_normal_color", "icon_hover_color", "icon_focus_color",
			"icon_pressed_color", "icon_hover_pressed_color"]
	for c in icon_states:
		theme.set_color(c, t, Color(0, 0, 0, 0))
	# Закрита сюжетом вкладка показує замок (GameMenu._lock_tabs) — він видимий.
	theme.set_color("icon_disabled_color", t, UITokens.TEXT_DISABLED)
	theme.set_type_variation("SidebarTabOn", t)
	for c in icon_states:
		theme.set_color(c, "SidebarTabOn", UITokens.TEXT_PRIMARY)
	# D493: таблички-стрілки Figma (UI/Sidebar Tab 386:6642). Активну вкладку позначає лише вказівник ▶.
	var plate := _arrow_plate(UITokens.SIDEBAR_TAB_BG, UITokens.BORDER, UITokens.BORDER_WIDTH)
	theme.set_stylebox("normal", t, plate)
	theme.set_stylebox("pressed", t, plate)
	theme.set_stylebox("hover", t, _arrow_plate(UITokens.SIDEBAR_TAB_BG, UITokens.BORDER_STRONG, UITokens.BORDER_WIDTH))
	theme.set_stylebox("hover_pressed", t, _arrow_plate(UITokens.SIDEBAR_TAB_BG, UITokens.BORDER_STRONG, UITokens.BORDER_WIDTH))
	theme.set_stylebox("focus", t, _arrow_plate(Color(0, 0, 0, 0), UITokens.FOCUS_RING, UITokens.FOCUS_RING_WIDTH))
	theme.set_stylebox("disabled", t, _arrow_plate(Color(UITokens.SIDEBAR_TAB_BG, 0.25), UITokens.BORDER, UITokens.BORDER_WIDTH))


## Табличка-стрілка (arrow_plate_style.gd) з відступами вмісту вкладки.
func _arrow_plate(bg: Color, border_color: Color, border_width: int) -> StyleBox:
	var sb: StyleBox = ArrowPlateStyle.new()
	sb.bg_color = bg
	sb.border_color = border_color
	sb.border_width = border_width
	sb.tip_width = UITokens.SIDEBAR_TAB_TIP
	sb.content_margin_left = UITokens.SPACE_LG
	sb.content_margin_right = UITokens.SPACE_LG + UITokens.SIDEBAR_TAB_TIP
	sb.content_margin_top = UITokens.SPACE_MD
	sb.content_margin_bottom = UITokens.SPACE_MD
	return sb


## Figma UI/IconButton — квадратна кнопка 36×36 з іконкою.
func _icon_button(theme: Theme) -> void:
	var t := "IconButton"
	theme.set_type_variation(t, "Button")
	var pad := UITokens.SPACE_SM
	theme.set_stylebox("normal", t, _box(UITokens.SURFACE, UITokens.BORDER, UITokens.BORDER_WIDTH, pad, pad))
	theme.set_stylebox("hover", t, _box(UITokens.SURFACE_HOVER, UITokens.BORDER_STRONG, UITokens.BORDER_WIDTH, pad, pad))
	theme.set_stylebox("pressed", t, _box(UITokens.ACCENT, UITokens.ACCENT, UITokens.BORDER_WIDTH, pad, pad))
	theme.set_stylebox("focus", t, _focus_ring(pad, pad))
	theme.set_stylebox("disabled", t, _box(Color(UITokens.SURFACE, 0.25), UITokens.BORDER, UITokens.BORDER_WIDTH, pad, pad))


# ── Панелі ──────────────────────────────────────────────────────────────────

func _setup_panels(theme: Theme) -> void:
	# Figma UI/Panel
	var surface := _box(UITokens.SURFACE, UITokens.BORDER, UITokens.BORDER_WIDTH,
			UITokens.PANEL_PADDING, UITokens.PANEL_PADDING)
	theme.set_stylebox("panel", "PanelContainer", surface)
	theme.set_stylebox("panel", "Panel", surface.duplicate())

	# Модалки (modal_dialog.tscn): той самий UI/Panel, але фон непрозорий — крізь 56% surface
	# просвічував заголовок головного меню (D195, Sapega 2026-10-16; Figma 258:5332 має surface).
	theme.set_type_variation("ModalPanel", "PanelContainer")
	var modal: StyleBoxFlat = surface.duplicate()
	modal.bg_color = UITokens.BACKGROUND
	modal.content_margin_left = UITokens.MODAL_PAD_H
	modal.content_margin_right = UITokens.MODAL_PAD_H
	modal.content_margin_top = UITokens.MODAL_PAD_V
	modal.content_margin_bottom = UITokens.MODAL_PAD_V
	theme.set_stylebox("panel", "ModalPanel", modal)
	_modal_kit(theme)
	_level_up_kit(theme)
	_person_card_kit(theme)

	# Figma UI/Window — модалки, вікна. Непрозорий фон + тінь замість Panel Glow.
	theme.set_type_variation("WindowPanel", "PanelContainer")
	var window := _box(UITokens.BACKGROUND, UITokens.ACCENT, UITokens.BORDER_WIDTH,
			UITokens.SPACE_XL, UITokens.SPACE_XL)
	window.shadow_color = Color(0, 0, 0, 0.55)
	window.shadow_size = UITokens.SPACE_MD
	theme.set_stylebox("panel", "WindowPanel", window)

	# Без рамки — для контейнерів-обгорток, що не мають малювати межу.
	theme.set_type_variation("PlainPanel", "PanelContainer")
	theme.set_stylebox("panel", "PlainPanel", _empty_box())

	# Figma UI/Inventory Center Panel (355:6423) — акцентна рамка, padding 48.
	theme.set_type_variation("CenterPanel", "PanelContainer")
	theme.set_stylebox("panel", "CenterPanel", _box(UITokens.MENU_SURFACE, UITokens.ACCENT,
			UITokens.BORDER_WIDTH, UITokens.CENTER_PANEL_PADDING, UITokens.CENTER_PANEL_PADDING))

	# Figma UI/Party Status Panel (104:490) — звичайна рамка, padding 24.
	theme.set_type_variation("SidePanel", "PanelContainer")
	theme.set_stylebox("panel", "SidePanel", _box(UITokens.MENU_SURFACE, UITokens.BORDER,
			UITokens.BORDER_WIDTH, UITokens.SPACE_XL, UITokens.SPACE_XL))

	# Картка персонажа (Figma UI/Party Character Card 324:6127).
	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", _box(UITokens.MENU_SURFACE, UITokens.ACCENT,
			UITokens.BORDER_WIDTH, UITokens.SPACE_MD, UITokens.SPACE_MD))
	# Частини картки — тепер шаблон у сцені (D117), а не StyleBoxFlat.new() у коді.
	theme.set_type_variation("PortraitFrame", "PanelContainer")
	# Відступ = товщина рамки, інакше колір портрета лягає поверх неї.
	theme.set_stylebox("panel", "PortraitFrame", _box(Color(0, 0, 0, 0), UITokens.ACCENT,
			UITokens.BORDER_WIDTH, UITokens.BORDER_WIDTH, UITokens.BORDER_WIDTH))
	theme.set_type_variation("LevelBadge", "PanelContainer")
	theme.set_stylebox("panel", "LevelBadge", _box(UITokens.ACCENT, UITokens.ACCENT, 0,
			UITokens.SPACE_XS + UITokens.SPACE_2XS, UITokens.SPACE_2XS))
	theme.set_type_variation("LevelBadgeLabel", "Label")
	theme.set_font("font", "LevelBadgeLabel", _font_bold)
	theme.set_font_size("font_size", "LevelBadgeLabel", UITokens.SIZE_MICRO)
	theme.set_color("font_color", "LevelBadgeLabel", UITokens.ON_ACCENT)
	for spec in [["HpBar", UITokens.HP_FILL], ["SpBar", UITokens.SP_FILL]]:
		theme.set_type_variation(spec[0], "ProgressBar")
		theme.set_stylebox("background", spec[0], _box(UITokens.SURFACE, UITokens.SURFACE, 0, 0, 0))
		theme.set_stylebox("fill", spec[0], _box(spec[1], spec[1], 0, 0, 0))
	# Невидима кнопка поверх картки: вибір цілі (D127). Видно лише фокус / наведення.
	theme.set_type_variation("CardSelect", "Button")
	var none := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0)
	var ring := _box(Color(0, 0, 0, 0), UITokens.ACCENT, UITokens.BORDER_WIDTH_SELECTED, 0, 0)
	for state in ["normal", "pressed", "disabled"]:
		theme.set_stylebox(state, "CardSelect", none)
	for state in ["hover", "hover_pressed"]:
		theme.set_stylebox(state, "CardSelect", ring)
	theme.set_stylebox("focus", "CardSelect", _focus_ring(0, 0))

	# Figma menu-status: job-box / weapon-box / action-card — surface + 1px рамка.
	theme.set_type_variation("BoxPanel", "PanelContainer")
	theme.set_stylebox("panel", "BoxPanel", _box(UITokens.MENU_SURFACE, UITokens.BORDER,
			UITokens.BORDER_WIDTH, UITokens.SPACE_MD, UITokens.SPACE_MD))

	theme.set_type_variation("ActionCard", "PanelContainer")
	theme.set_stylebox("panel", "ActionCard", _box(UITokens.MENU_SURFACE, UITokens.BORDER,
			UITokens.BORDER_WIDTH, 18, 18))

	# Рядки Status / Equipment — шаблони в stats_component.tscn / equipment_component.tscn (D117), стилі лише тут.
	# Аватар: рамка під портретом героя (B129, Sprites/Player/portrait.tres у дочірньому Art).
	theme.set_type_variation("AvatarFrame", "Panel")
	theme.set_stylebox("panel", "AvatarFrame", _box(UITokens.ICON_SLOT_BG, UITokens.BORDER,
			UITokens.BORDER_WIDTH_SELECTED, 0, 0))
	# Аватар на Equipment — менший, з тонкою рамкою.
	theme.set_type_variation("AvatarChip", "Panel")
	theme.set_stylebox("panel", "AvatarChip", _box(UITokens.ICON_SLOT_BG, UITokens.BORDER,
			UITokens.BORDER_WIDTH, 0, 0))
	# Рядок атрибута (Status і Equipment): лише нижня лінія.
	theme.set_type_variation("AttrRow", "PanelContainer")
	var attr_line := _box(Color(0, 0, 0, 0), UITokens.BORDER, 0, 0, UITokens.SPACE_SM)
	attr_line.set_corner_radius_all(0)
	attr_line.border_width_bottom = UITokens.BORDER_WIDTH
	theme.set_stylebox("panel", "AttrRow", attr_line)
	theme.set_type_variation("IconSlot", "Panel")
	theme.set_stylebox("panel", "IconSlot", _box(UITokens.ICON_SLOT_BG, UITokens.ICON_SLOT_BG, 0, 0, 0))
	# Крапка «вдягнено» в рядку слота Equipment (6 px, радіус — половина).
	theme.set_type_variation("AccentDot", "Panel")
	var dot := _box(UITokens.ACCENT, UITokens.ACCENT, 0, 0, 0)
	dot.set_corner_radius_all(3)
	theme.set_stylebox("panel", "AccentDot", dot)
	# Іконка рядка предмета (UIItemRow): у звичайного — 1px рамка, у виділеного рамки немає (IconSlot).
	theme.set_type_variation("IconSlotFramed", "Panel")
	theme.set_stylebox("panel", "IconSlotFramed", _box(UITokens.ICON_SLOT_BG, UITokens.BORDER,
			UITokens.BORDER_WIDTH, 0, 0))

	# Нижня панель підказок (Figma UI/Bottom Bar 121:1073): фон шелу, лише верхня лінія.
	theme.set_type_variation("BottomBar", "PanelContainer")
	var bar := StyleBoxFlat.new()
	bar.bg_color = UITokens.BOTTOM_BAR_BG
	bar.border_width_top = UITokens.BORDER_WIDTH
	bar.border_color = UITokens.BORDER
	theme.set_stylebox("panel", "BottomBar", bar)
	# Підказка дії: значок + назва. Значки круглі — єдиний свідомий виняток із shape/radius-sm = 0,
	# бо Figma UI/Action Button (276:467) малює їх колами.
	theme.set_type_variation("ActionHint", "HBoxContainer")
	theme.set_constant("separation", "ActionHint", UITokens.ICON_TEXT_GAP)
	theme.set_type_variation("ActionBadge", "PanelContainer")
	var badge := _box(UITokens.ACCENT, UITokens.ACCENT, 0, UITokens.SPACE_XS, 0)
	badge.set_corner_radius_all(UITokens.ACTION_BADGE_SIZE / 2)
	theme.set_stylebox("panel", "ActionBadge", badge)

	# Риска між підписом і назвою в картці дії.
	theme.set_type_variation("AccentTick", "Panel")
	var tick := _box(UITokens.ACCENT, UITokens.ACCENT, 0, 0, 0)
	tick.set_corner_radius_all(0)
	theme.set_stylebox("panel", "AccentTick", tick)

	# Figma menu-skills: колонка класового дерева — surface + 1px рамка, padding 32.
	theme.set_type_variation("TreePanel", "PanelContainer")
	theme.set_stylebox("panel", "TreePanel", _box(UITokens.MENU_SURFACE, UITokens.BORDER,
			UITokens.BORDER_WIDTH, UITokens.SPACE_2XL, UITokens.SPACE_2XL))

	# Figma UI/Interaction/Prompt (461:6479): State=Default / Focused / Disabled.
	theme.set_type_variation("InteractionPrompt", "PanelContainer")
	theme.set_stylebox("panel", "InteractionPrompt", _box(UITokens.PROMPT_BG, UITokens.ACCENT, 0,
			UITokens.PROMPT_PAD_H, UITokens.PROMPT_PAD_V))
	theme.set_type_variation("InteractionPromptFocused", "PanelContainer")
	theme.set_stylebox("panel", "InteractionPromptFocused", _box(UITokens.PROMPT_BG_FOCUSED,
			UITokens.ACCENT, UITokens.BORDER_WIDTH, UITokens.PROMPT_PAD_H, UITokens.PROMPT_PAD_V))
	theme.set_type_variation("InteractionPromptDisabled", "PanelContainer")
	theme.set_stylebox("panel", "InteractionPromptDisabled", _box(UITokens.PROMPT_BG_DISABLED,
			UITokens.ACCENT, 0, UITokens.PROMPT_PAD_H, UITokens.PROMPT_PAD_V))
	theme.set_type_variation("PromptRow", "HBoxContainer")
	theme.set_constant("separation", "PromptRow", UITokens.ICON_TEXT_GAP)

	_save_slots(theme)


## Шрифт із міжлітерним інтервалом (Figma letterSpacing у px).
## Figma UI/Modal/Confirm 258:5332 (B119): заголовок · 1 px акцентна лінія · опис · кнопки стовпчиком.
## Кнопка — UI/HexButton 260×36 із загостреними кінцями: звичайна — контур hex_button.svg, вибрана
## (фокус) — заливка hex_button_selected.svg і шеврон. modal_dialog.gd перемикає ModalButton/ModalButtonOn.
func _modal_kit(theme: Theme) -> void:
	theme.set_type_variation("ModalColumn", "VBoxContainer")
	theme.set_constant("separation", "ModalColumn", UITokens.MODAL_GAP)
	theme.set_type_variation("ModalButtons", "VBoxContainer")
	theme.set_constant("separation", "ModalButtons", UITokens.MODAL_BUTTON_GAP)

	theme.set_type_variation("ModalRule", "HSeparator")
	var line := StyleBoxLine.new()
	line.color = UITokens.ACCENT
	line.thickness = UITokens.MODAL_RULE
	theme.set_stylebox("separator", "ModalRule", line)
	theme.set_constant("separation", "ModalRule", UITokens.MODAL_RULE)

	theme.set_type_variation("ModalBody", "Label")
	theme.set_font("font", "ModalBody", _font_regular)
	theme.set_font_size("font_size", "ModalBody", UITokens.SIZE_MODAL_BODY)
	theme.set_color("font_color", "ModalBody", UITokens.TEXT_PRIMARY)

	var font := _spaced(_font_semibold, UITokens.MODAL_BUTTON_SPACING)
	# Текст по центру кнопки: праве поле = ліве + місце шеврона.
	var pad_l := UITokens.MODAL_POINTER_X
	var pad_r := UITokens.MODAL_POINTER_X + UITokens.MODAL_POINTER + UITokens.ICON_TEXT_GAP
	# D329: та сама 2 px рамка фокусу, біла (вибрана кнопка — на акценті), повторює загострені кінці.
	var ring := _focus_ring(pad_l, 0, true)
	ring.set_corner_radius_all(UITokens.MODAL_BUTTON_HEIGHT / 2)
	ring.corner_detail = 1
	ring.draw_center = false
	for spec in [["ModalButton", UITokens.MODAL_BUTTON_TEXTURE, UITokens.TEXT_PRIMARY, Color(0, 0, 0, 0)],
			["ModalButtonOn", UITokens.MODAL_BUTTON_SELECTED_TEXTURE, UITokens.ON_ACCENT, UITokens.ON_ACCENT]]:
		var t: String = spec[0]
		theme.set_type_variation(t, "Button")
		var hex := _hex_box(spec[1], pad_l, pad_r)
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			theme.set_stylebox(state, t, hex)
		theme.set_stylebox("focus", t, ring)
		theme.set_font("font", t, font)
		theme.set_font_size("font_size", t, UITokens.SIZE_MODAL_BUTTON)
		for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			theme.set_color(c, t, spec[2])
		theme.set_color("font_disabled_color", t, UITokens.TEXT_DISABLED)
		for c in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color", "icon_hover_pressed_color"]:
			theme.set_color(c, t, spec[3])
		theme.set_color("icon_disabled_color", t, Color(0, 0, 0, 0))
		theme.set_constant("h_separation", t, UITokens.ICON_TEXT_GAP)
		theme.set_constant("icon_max_width", t, UITokens.MODAL_POINTER)


## Figma UI/Notification/LevelUp 484:6490 (D436): панель kit 320 px · «LEVEL UP» (UI/Title, accent) ·
## 1 px акцентна лінія · «Level N» (UI/Display) · рядки нагород (UI/Body text-secondary + UI/Label status/increase).
func _level_up_kit(theme: Theme) -> void:
	theme.set_type_variation("LevelUpPanel", "PanelContainer")
	theme.set_stylebox("panel", "LevelUpPanel", _box(UITokens.BACKGROUND, UITokens.BORDER, UITokens.BORDER_WIDTH,
			UITokens.LEVEL_UP_PAD_H, UITokens.LEVEL_UP_PAD_V))
	theme.set_type_variation("LevelUpColumn", "VBoxContainer")
	theme.set_constant("separation", "LevelUpColumn", UITokens.LEVEL_UP_GAP)
	theme.set_type_variation("LevelUpRows", "VBoxContainer")
	theme.set_constant("separation", "LevelUpRows", UITokens.LEVEL_UP_ROW_GAP)

	theme.set_type_variation("LevelUpRule", "HSeparator")
	var line := StyleBoxLine.new()
	line.color = UITokens.ACCENT
	line.thickness = UITokens.MODAL_RULE
	theme.set_stylebox("separator", "LevelUpRule", line)
	theme.set_constant("separation", "LevelUpRule", UITokens.MODAL_RULE)

	for spec in [["LevelUpTitle", _spaced(_font_bold, UITokens.LEVEL_UP_TITLE_SPACING), UITokens.SIZE_TITLE, UITokens.ACCENT],
			["LevelUpLevel", _font_bold, UITokens.SIZE_DISPLAY, UITokens.TEXT_PRIMARY],
			["LevelUpRowLabel", _font_regular, UITokens.SIZE_BODY, UITokens.TEXT_SECONDARY],
			["LevelUpRowValue", _font_semibold, UITokens.SIZE_LABEL, UITokens.STATUS_INCREASE]]:
		theme.set_type_variation(spec[0], "Label")
		theme.set_font("font", spec[0], spec[1])
		theme.set_font_size("font_size", spec[0], spec[2])
		theme.set_color("font_color", spec[0], spec[3])


## Figma journal-character-detail 192:1754 (D486): епітет — золоті розріджені великі літери, ім'я — великий serif,
## назва місця на пергаменті — малі золоті великі літери.
func _person_card_kit(theme: Theme) -> void:
	for spec in [["CardEpithet", _spaced(_font_semibold, UITokens.CARD_EPITHET_SPACING), UITokens.SIZE_CARD_EPITHET, UITokens.ACCENT],
			["CardName", _font_bold, UITokens.SIZE_NAME, UITokens.TEXT_PRIMARY],
			["CardPlace", _spaced(_font_semibold, UITokens.CARD_PLACE_SPACING), UITokens.SIZE_CARD_PLACE, UITokens.ACCENT]]:
		theme.set_type_variation(spec[0], "Label")
		theme.set_font("font", spec[0], spec[1])
		theme.set_font_size("font_size", spec[0], spec[2])
		theme.set_color("font_color", spec[0], spec[3])
	theme.set_type_variation("CardMargin", "MarginContainer")
	for side in ["left", "top", "right", "bottom"]:
		theme.set_constant("margin_" + side, "CardMargin", UITokens.SPACE_XL)
	theme.set_type_variation("CardColumns", "HBoxContainer")
	theme.set_constant("separation", "CardColumns", UITokens.CARD_GAP)


## Шестикутна кнопка з SVG: кінці (MODAL_BUTTON_POINT) не розтягуються, середина — так.
func _hex_box(path: String, pad_l: int, pad_r: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(path)
	box.texture_margin_left = UITokens.MODAL_BUTTON_POINT
	box.texture_margin_right = UITokens.MODAL_BUTTON_POINT
	box.content_margin_left = pad_l
	box.content_margin_right = pad_r
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box


func _spaced(base: Font, spacing: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = base
	fv.spacing_glyph = spacing
	return fv


## D674: вікно навичок Dragon Nest (Figma 533:6472): вкладки дерев, клітинки навичок, бейджі, панель деталей, кнопки.
func _skill_window(theme: Theme) -> void:
	theme.set_type_variation("SkillWindow", "PanelContainer")
	theme.set_stylebox("panel", "SkillWindow", _box(UITokens.MENU_SURFACE, UITokens.BORDER, UITokens.BORDER_WIDTH, 0, 0))

	var heading := _spaced(_font_bold, UITokens.SKILL_HEADING_SPACING)
	var caption := _spaced(_font_semibold, UITokens.SKILL_HEADING_SPACING)
	var labels := {
		"SkillWindowTitle": [heading, UITokens.SIZE_SKILL_WINDOW_TITLE, UITokens.ACCENT],
		"SkillTreeHeading": [heading, UITokens.SIZE_HEADING, UITokens.ACCENT],
		"SkillTreeStatus": [_font_regular, UITokens.SIZE_SMALL, UITokens.TEXT_SECONDARY],
		"SkillHero": [_font_regular, UITokens.SIZE_HEADING, UITokens.TEXT_PRIMARY],
		"SkillRank": [_font_regular, UITokens.SIZE_SKILL_RANK, UITokens.TEXT_SECONDARY],
		"SkillRankPlanned": [_font_bold, UITokens.SIZE_SKILL_RANK, UITokens.ACCENT],
		"SkillLevelBadgeLabel": [_font_regular, UITokens.SIZE_MICRO, UITokens.TEXT_SECONDARY],
		"SkillLevelBadgeLow": [_font_regular, UITokens.SIZE_MICRO, UITokens.SKILL_LEVEL_LOW],
		"SkillPlusLabel": [_font_bold, UITokens.SIZE_CAPTION, UITokens.ON_ACCENT],
		"SkillDetailName": [heading, UITokens.SIZE_TITLE, UITokens.ACCENT],
		"SkillDetailKind": [_font_regular, UITokens.SIZE_BODY, UITokens.TEXT_PRIMARY],
		"SkillDetailBody": [_font_regular, UITokens.SIZE_BODY, UITokens.TEXT_PRIMARY],
		"SkillFactLabel": [_font_regular, UITokens.SIZE_BODY, UITokens.TEXT_SECONDARY],
		"SkillFactValue": [_font_regular, UITokens.SIZE_BODY, UITokens.TEXT_PRIMARY],
		"SkillNextCaption": [caption, UITokens.SIZE_SMALL, UITokens.ACCENT],
		"SkillVerdict": [_font_regular, UITokens.SIZE_SMALL, UITokens.TEXT_SECONDARY],
		"SkillBottomCaption": [caption, UITokens.SIZE_SMALL, UITokens.TEXT_SECONDARY],
		"SkillPointsValue": [_font_bold, UITokens.SIZE_TITLE, UITokens.ACCENT],
		"SkillBudgets": [_font_regular, UITokens.SIZE_BODY, UITokens.TEXT_PRIMARY],
	}
	for type_name: String in labels:
		var role: Array = labels[type_name]
		theme.set_type_variation(type_name, "Label")
		theme.set_font("font", type_name, role[0])
		theme.set_font_size("font_size", type_name, role[1])
		theme.set_color("font_color", type_name, role[2])

	# Клітинка навички: невивчена — сіра рамка, вивчена (чи позначена) — золота; вибрана — золото зі сяйвом.
	for type_name: String in ["SkillSlot", "SkillSlotLearned"]:
		var learned := type_name == "SkillSlotLearned"
		var edge: Color = UITokens.ACCENT if learned else UITokens.BORDER
		var width: int = UITokens.BORDER_WIDTH_SELECTED if learned else UITokens.BORDER_WIDTH
		theme.set_type_variation(type_name, "Button")
		theme.set_stylebox("normal", type_name, _box(UITokens.SKILL_SLOT_BG, edge, width, 0, 0))
		theme.set_stylebox("disabled", type_name, _box(UITokens.SKILL_SLOT_BG, edge, width, 0, 0))
		theme.set_stylebox("hover", type_name, _box(UITokens.SKILL_SLOT_BG, UITokens.BORDER_STRONG, width, 0, 0))
		var selected := _box(UITokens.SKILL_SLOT_BG, UITokens.ACCENT, UITokens.BORDER_WIDTH_SELECTED + 1, 0, 0)
		selected.shadow_color = UITokens.SKILL_SLOT_GLOW
		selected.shadow_size = UITokens.SKILL_SLOT_GLOW_SIZE
		theme.set_stylebox("pressed", type_name, selected)
		theme.set_stylebox("hover_pressed", type_name, selected)
		theme.set_stylebox("focus", type_name, _focus_ring(0, 0))

	theme.set_type_variation("SkillLevelBadge", "PanelContainer")
	theme.set_stylebox("panel", "SkillLevelBadge", _box(UITokens.SKILL_SLOT_BG, UITokens.BORDER, UITokens.BORDER_WIDTH,
			UITokens.SPACE_XS, 0))
	theme.set_type_variation("SkillPlusBadge", "PanelContainer")
	var plus := _box(UITokens.ACCENT, UITokens.ACCENT, 0, 0, 0)
	plus.set_corner_radius_all(UITokens.SKILL_PLUS_SIZE / 2)
	theme.set_stylebox("panel", "SkillPlusBadge", plus)
	theme.set_type_variation("SkillDetailIcon", "Panel")
	theme.set_stylebox("panel", "SkillDetailIcon", _box(UITokens.SKILL_SLOT_BG, UITokens.ACCENT, UITokens.BORDER_WIDTH_SELECTED, 0, 0))

	theme.set_type_variation("SkillDetailRule", "HSeparator")
	var rule := StyleBoxLine.new()
	rule.color = UITokens.ACCENT
	rule.thickness = UITokens.BORDER_WIDTH
	theme.set_stylebox("separator", "SkillDetailRule", rule)
	theme.set_type_variation("SkillBarRule", "HSeparator")
	var bar_rule := StyleBoxLine.new()
	bar_rule.color = UITokens.BORDER
	bar_rule.thickness = UITokens.BORDER_WIDTH
	theme.set_stylebox("separator", "SkillBarRule", bar_rule)

	# Вкладка дерева: показане — темна заливка й золото; інше — контур; чужа клятва — приглушена.
	var tab := "SkillTreeTab"
	theme.set_type_variation(tab, "Button")
	theme.set_font("font", tab, _spaced(_font_semibold, 1))
	theme.set_font_size("font_size", tab, UITokens.SIZE_LABEL)
	theme.set_color("font_color", tab, UITokens.TEXT_SECONDARY)
	theme.set_color("font_hover_color", tab, UITokens.TEXT_PRIMARY)
	theme.set_color("font_pressed_color", tab, UITokens.ACCENT)
	theme.set_color("font_hover_pressed_color", tab, UITokens.ACCENT)
	theme.set_color("font_focus_color", tab, UITokens.TEXT_PRIMARY)
	theme.set_color("font_disabled_color", tab, UITokens.TEXT_MUTED)
	var pad := UITokens.SPACE_SM
	theme.set_stylebox("normal", tab, _box(Color(0, 0, 0, 0), UITokens.BORDER, UITokens.BORDER_WIDTH, pad, pad))
	theme.set_stylebox("disabled", tab, _box(Color(0, 0, 0, 0), UITokens.BORDER, UITokens.BORDER_WIDTH, pad, pad))
	theme.set_stylebox("hover", tab, _box(UITokens.SURFACE_HOVER, UITokens.BORDER_STRONG, UITokens.BORDER_WIDTH, pad, pad))
	theme.set_stylebox("pressed", tab, _box(UITokens.SKILL_TAB_BG_ON, UITokens.ACCENT, UITokens.BORDER_WIDTH, pad, pad))
	theme.set_stylebox("hover_pressed", tab, _box(UITokens.SKILL_TAB_BG_ON, UITokens.ACCENT, UITokens.BORDER_WIDTH, pad, pad))
	theme.set_stylebox("focus", tab, _focus_ring(pad, pad))

	# Learn +1 — золотий контур на темно-золотій заливці; Reset — сірий контур; текстові кнопки нижньої смуги.
	var buttons := {
		"SkillLearnButton": [Color(UITokens.ACCENT, 0.12), UITokens.ACCENT, UITokens.ACCENT],
		"SkillResetButton": [Color(0, 0, 0, 0), UITokens.BORDER, UITokens.TEXT_SECONDARY],
		"SkillTextButton": [Color(0, 0, 0, 0), Color(0, 0, 0, 0), UITokens.TEXT_SECONDARY],
	}
	for type_name: String in buttons:
		var look: Array = buttons[type_name]
		var border_width := 0 if type_name == "SkillTextButton" else UITokens.BORDER_WIDTH_SELECTED
		theme.set_type_variation(type_name, "Button")
		theme.set_font("font", type_name, caption)
		theme.set_font_size("font_size", type_name, UITokens.SIZE_LABEL)
		theme.set_color("font_color", type_name, look[2])
		theme.set_color("font_hover_color", type_name, UITokens.TEXT_PRIMARY)
		theme.set_color("font_pressed_color", type_name, UITokens.TEXT_PRIMARY)
		theme.set_color("font_focus_color", type_name, look[2])
		theme.set_color("font_disabled_color", type_name, UITokens.TEXT_DISABLED)
		theme.set_stylebox("normal", type_name, _box(look[0], look[1], border_width, UITokens.SPACE_LG, UITokens.SPACE_SM))
		theme.set_stylebox("hover", type_name, _box(UITokens.SURFACE_HOVER, look[1], border_width, UITokens.SPACE_LG, UITokens.SPACE_SM))
		theme.set_stylebox("pressed", type_name, _box(look[0], look[1], border_width, UITokens.SPACE_LG, UITokens.SPACE_SM))
		theme.set_stylebox("disabled", type_name, _box(Color(0, 0, 0, 0), UITokens.BORDER if border_width > 0 else Color(0, 0, 0, 0),
				border_width, UITokens.SPACE_LG, UITokens.SPACE_SM))
		theme.set_stylebox("focus", type_name, _focus_ring(UITokens.SPACE_LG, UITokens.SPACE_SM))


## Figma main-menu 9:26, UI/Splash Screen 258:5140, UI/Menu Item 248:62.
func _main_menu(theme: Theme) -> void:
	var labels := {
		"TitleKhalahas": [_spaced(_font_bold, UITokens.TITLE_SPACING_KHALAHAS), UITokens.SIZE_TITLE_KHALAHAS],
		"TitleHeroes": [_spaced(_font_bold, UITokens.TITLE_SPACING_HEROES), UITokens.SIZE_TITLE_HEROES],
		"SplashPrompt": [_spaced(_font_semibold, UITokens.SPLASH_PROMPT_SPACING), UITokens.SIZE_SPLASH_PROMPT],
		"CopyrightLabel": [_spaced(_font_regular, UITokens.COPYRIGHT_SPACING), UITokens.SIZE_CAPTION],
		# Фінал демо (D473): подяка під титулом, як у головному меню.
		"FinaleMessage": [_font_regular, UITokens.SIZE_HEADING],
	}
	for name in labels:
		theme.set_type_variation(name, "Label")
		theme.set_font("font", name, labels[name][0])
		theme.set_font_size("font_size", name, labels[name][1])
		theme.set_color("font_color", name, UITokens.TEXT_PRIMARY)

	# Лінії титульного блоку: 1.5 / 2.5 px у Figma → 2 / 3 px.
	for pair in [["TitleRule", UITokens.TITLE_RULE], ["TitleRuleBold", UITokens.TITLE_RULE_BOLD]]:
		theme.set_type_variation(pair[0], "HSeparator")
		var line := StyleBoxLine.new()
		line.color = UITokens.TEXT_PRIMARY
		line.thickness = pair[1]
		theme.set_stylebox("separator", pair[0], line)
		theme.set_constant("separation", pair[0], pair[1])

	var columns := {
		"TitleBlock": UITokens.TITLE_BLOCK_GAP,
		"MainMenuCenter": UITokens.MAIN_MENU_CENTER_GAP,
		"MainMenuList": UITokens.MAIN_MENU_LIST_GAP,
		"SplashCenter": UITokens.SPLASH_CENTER_GAP,
		"SplashPromptColumn": UITokens.SPLASH_PROMPT_GAP,
	}
	for name in columns:
		theme.set_type_variation(name, "VBoxContainer")
		theme.set_constant("separation", name, columns[name])

	# UI/Menu Item: без фону; неактивний — Regular 16, 70%, без вказівника;
	# активний (фокус) — SemiBold 16, 100%, з вказівником-шевроном.
	var clear := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0,
			UITokens.MENU_ITEM_PAD_H, UITokens.MENU_ITEM_PAD_V)
	var dim := Color(UITokens.TEXT_PRIMARY, UITokens.MENU_INACTIVE_ALPHA)
	for spec in [["MainMenuItem", _font_regular, dim, Color(0, 0, 0, 0)],
			["MainMenuItemOn", _font_semibold, UITokens.TEXT_PRIMARY, UITokens.TEXT_PRIMARY]]:
		var t: String = spec[0]
		theme.set_type_variation(t, "Button")
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			theme.set_stylebox(state, t, clear)
		# Q33: шеврон і яскравий текст лишаються (Figma UI/Menu Item), рамка фокусу — спільна.
		theme.set_stylebox("focus", t, _focus_ring(UITokens.MENU_ITEM_PAD_H, UITokens.MENU_ITEM_PAD_V))
		theme.set_font("font", t, spec[1])
		theme.set_font_size("font_size", t, UITokens.SIZE_LABEL)
		for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			theme.set_color(c, t, spec[2])
		theme.set_color("font_disabled_color", t, UITokens.TEXT_DISABLED)
		for c in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color", "icon_hover_pressed_color"]:
			theme.set_color(c, t, spec[3])
		theme.set_color("icon_disabled_color", t, Color(0, 0, 0, 0))
		theme.set_constant("h_separation", t, UITokens.MENU_ITEM_GAP)
		theme.set_constant("icon_max_width", t, UITokens.MENU_ITEM_POINTER)


## Figma game-over-screen 41:83. Пункти меню — ті самі NpcMenuItem/On (UI/Menu Item з фоном).
func _game_over(theme: Theme) -> void:
	theme.set_type_variation("GameOverTitle", "Label")
	theme.set_font("font", "GameOverTitle", _font_bold)
	theme.set_font_size("font_size", "GameOverTitle", UITokens.SIZE_GAME_OVER)
	theme.set_color("font_color", "GameOverTitle", UITokens.GAME_OVER_RED)
	theme.set_color("font_shadow_color", "GameOverTitle", UITokens.GAME_OVER_SHADOW)
	theme.set_constant("shadow_offset_x", "GameOverTitle", 0)
	theme.set_constant("shadow_offset_y", "GameOverTitle", 3)
	theme.set_constant("shadow_outline_size", "GameOverTitle", 3)

	var labels := {
		"GameOverEyebrow": [_font_semibold, UITokens.SIZE_GAME_OVER_EYEBROW, UITokens.GAME_OVER_FRAME],
		"GameOverHint": [_font_regular, UITokens.SIZE_BODY, UITokens.TEXT_PRIMARY],
		"GameOverKey": [_spaced(_font_bold, 1), UITokens.SIZE_CAPTION, UITokens.TEXT_PRIMARY],
	}
	for name in labels:
		theme.set_type_variation(name, "Label")
		theme.set_font("font", name, labels[name][0])
		theme.set_font_size("font_size", name, labels[name][1])
		theme.set_color("font_color", name, labels[name][2])

	var clear := Color(0, 0, 0, 0)
	var inner := Color(UITokens.GAME_OVER_FRAME, UITokens.GAME_OVER_FRAME_INNER_ALPHA)
	for spec in [["GameOverInset", UITokens.GAME_OVER_FRAME, 0, 0], ["GameOverInsetInner", inner, 0, 0],
			["GameOverKeycap", inner, UITokens.SPACE_SM, UITokens.SPACE_2XS]]:
		theme.set_type_variation(spec[0], "PanelContainer")
		theme.set_stylebox("panel", spec[0], _box(clear, spec[1], UITokens.BORDER_WIDTH, spec[2], spec[3]))

	for pair in [["GameOverRule", Color(UITokens.GAME_OVER_RED, UITokens.GAME_OVER_RULE_ALPHA)],
			["GameOverFrameRule", UITokens.GAME_OVER_FRAME]]:
		theme.set_type_variation(pair[0], "HSeparator")
		var line := StyleBoxLine.new()
		line.color = pair[1]
		line.thickness = UITokens.BORDER_WIDTH
		theme.set_stylebox("separator", pair[0], line)
		theme.set_constant("separation", pair[0], UITokens.BORDER_WIDTH)

	theme.set_type_variation("GameOverInsetMargin", "MarginContainer")
	for side in ["left", "right", "top", "bottom"]:
		theme.set_constant("margin_" + side, "GameOverInsetMargin", UITokens.GAME_OVER_INSET_INNER)

	var cols := {"GameOverColumn": ["VBoxContainer", UITokens.GAME_OVER_COLUMN_GAP],
		"GameOverEyebrowColumn": ["VBoxContainer", UITokens.GAME_OVER_EYEBROW_GAP],
		"GameOverOptions": ["VBoxContainer", UITokens.GAME_OVER_OPTIONS_GAP],
		"GameOverRow": ["HBoxContainer", UITokens.SPACE_MD],
		"GameOverFooter": ["HBoxContainer", UITokens.SPACE_SM]}
	for name in cols:
		theme.set_type_variation(name, cols[name][0])
		theme.set_constant("separation", name, cols[name][1])


## Figma shop-buy 153:1289 / shop-sell 153:1523; NPC-меню 164:1302 / 176:1357.
func _shop(theme: Theme) -> void:
	theme.set_type_variation("ShopPanel", "PanelContainer")
	theme.set_stylebox("panel", "ShopPanel", _box(UITokens.SHOP_PANEL_BG, UITokens.BORDER,
			UITokens.BORDER_WIDTH, 0, 0))
	theme.set_type_variation("ShopDescBox", "PanelContainer")
	theme.set_stylebox("panel", "ShopDescBox", _box(UITokens.SHOP_ROW_BG, UITokens.TEXT_PRIMARY,
			UITokens.BORDER_WIDTH, UITokens.SHOP_DESC_PAD, UITokens.SHOP_DESC_PAD))
	theme.set_type_variation("ShopHeader", "PanelContainer")
	var header := _box(Color(0, 0, 0, 0), UITokens.TEXT_PRIMARY, 0, 0, UITokens.SHOP_HEADER_PAD_V)
	header.border_width_bottom = UITokens.BORDER_WIDTH
	# Правий відступ = відступ рядка, щоб колонки заголовка закінчувались там само, де в рядках (B25).
	header.content_margin_right = UITokens.SHOP_ROW_PAD_H
	theme.set_stylebox("panel", "ShopHeader", header)

	var labels := {
		"ShopTitle": [_font_semibold, UITokens.SIZE_SHOP_TITLE, UITokens.ACCENT],
		"ShopColumnHeader": [_font_semibold, UITokens.SIZE_SMALL, UITokens.TEXT_PRIMARY],
		"ShopDescText": [_font_regular, UITokens.SIZE_SMALL, UITokens.TEXT_PRIMARY],
		# Рядок: звичайний — білий текст; вибраний — темний на accent (правило D26).
		"ShopRowName": [_font_medium, UITokens.SIZE_ROW_TITLE, UITokens.TEXT_PRIMARY],
		"ShopRowNameOn": [_font_medium, UITokens.SIZE_ROW_TITLE, UITokens.ON_ACCENT],
		"ShopRowCount": [_font_regular, UITokens.SIZE_BODY, UITokens.TEXT_PRIMARY],
		"ShopRowCountOn": [_font_regular, UITokens.SIZE_BODY, UITokens.ON_ACCENT],
		"ShopRowPrice": [_font_semibold, UITokens.SIZE_BODY, UITokens.TEXT_PRIMARY],
		"ShopRowPriceOn": [_font_semibold, UITokens.SIZE_BODY, UITokens.ON_ACCENT],
		# D433: не вистачає золота — сірі назва й ціна; на вибраному рядку (accent) — темніший сірий.
		"ShopRowDisabled": [_font_medium, UITokens.SIZE_ROW_TITLE, UITokens.TEXT_MUTED],
		"ShopRowDisabledOn": [_font_medium, UITokens.SIZE_ROW_TITLE, UITokens.SHOP_TEXT_DISABLED_ON_ACCENT],
		"ShopRowPriceDisabled": [_font_semibold, UITokens.SIZE_BODY, UITokens.TEXT_MUTED],
		"ShopRowPriceDisabledOn": [_font_semibold, UITokens.SIZE_BODY, UITokens.SHOP_TEXT_DISABLED_ON_ACCENT],
		# Другий рядок рецепта крафту ("Requires: …").
		"ShopRowDetail": [_font_regular, UITokens.SIZE_CAPTION_SM, UITokens.TEXT_PRIMARY],
		"ShopRowDetailOn": [_font_regular, UITokens.SIZE_CAPTION_SM, UITokens.ON_ACCENT],
		"StatusIncrease": [_font_semibold, UITokens.SIZE_ROW_TITLE, UITokens.STATUS_INCREASE],
	}
	for name in labels:
		theme.set_type_variation(name, "Label")
		theme.set_font("font", name, labels[name][0])
		theme.set_font_size("font_size", name, labels[name][1])
		theme.set_color("font_color", name, labels[name][2])

	var cols := {"ShopColumn": ["VBoxContainer", UITokens.SHOP_LIST_GAP],
		"ShopRowList": ["VBoxContainer", UITokens.SHOP_ROW_GAP],
		"ShopCategories": ["VBoxContainer", UITokens.SHOP_CATEGORY_GAP],
		"ShopDescColumn": ["VBoxContainer", UITokens.SHOP_DESC_GAP],
		"ShopRowLine": ["HBoxContainer", UITokens.SPACE_MD],
		"ShopRowNameBlock": ["VBoxContainer", UITokens.CRAFT_ROW_NAME_GAP],
		"NpcMenuList": ["VBoxContainer", UITokens.NPC_MENU_GAP],
		# Спільний сайдбар base_menu (Game Menu, Shop): таби через 16px, відступ до вмісту 24px.
		"MenuLayout": ["HBoxContainer", UITokens.SECTION_GAP],
		"MenuSidebar": ["VBoxContainer", UITokens.LG_TAB_GAP]}
	for name in cols:
		theme.set_type_variation(name, cols[name][0])
		theme.set_constant("separation", name, cols[name][1])
	theme.set_type_variation("ShopListMargin", "MarginContainer")
	for side in ["left", "right", "top", "bottom"]:
		theme.set_constant("margin_" + side, "ShopListMargin", UITokens.SHOP_LIST_PAD)
	# Колонка категорій 64px: кнопки 48px по центру, 16px зверху/знизу.
	theme.set_type_variation("ShopCategoryMargin", "MarginContainer")
	var side_pad := (UITokens.SHOP_CATEGORY_COLUMN - UITokens.SHOP_CATEGORY_SIZE) / 2
	theme.set_constant("margin_left", "ShopCategoryMargin", side_pad)
	theme.set_constant("margin_right", "ShopCategoryMargin", side_pad)
	theme.set_constant("margin_top", "ShopCategoryMargin", UITokens.SHOP_CATEGORY_PAD_V)
	theme.set_constant("margin_bottom", "ShopCategoryMargin", UITokens.SHOP_CATEGORY_PAD_V)
	theme.set_type_variation("ShopRowMargin", "MarginContainer")
	for side in ["left", "right"]:
		theme.set_constant("margin_" + side, "ShopRowMargin", UITokens.SHOP_ROW_PAD_H)
	for side in ["top", "bottom"]:
		theme.set_constant("margin_" + side, "ShopRowMargin", UITokens.SHOP_ROW_PAD_V)

	# Рядок товару: чорний 56%; вибраний (фокус/наведення) — заливка accent.
	var t := "ShopRow"
	theme.set_type_variation(t, "Button")
	var row := _box(UITokens.SHOP_ROW_BG, UITokens.SHOP_ROW_BG, UITokens.BORDER_WIDTH, 0, 0)
	var row_on := _box(UITokens.ACCENT, UITokens.BORDER, UITokens.BORDER_WIDTH, 0, 0)
	for state in ["normal", "pressed", "disabled"]:
		theme.set_stylebox(state, t, row)
	for state in ["hover", "hover_pressed"]:
		theme.set_stylebox(state, t, row_on)
	# Q33: вибраний рядок товару лишається акцентним (темний текст ...On не читається на чорному),
	# але має ту саму рамку фокусу — білу, бо вона на акцентній заливці.
	var row_focus := _focus_ring(0, 0, true)
	row_focus.bg_color = UITokens.ACCENT
	theme.set_stylebox("focus", t, row_focus)
	# Рядок під відкритою модалкою купівлі: фокус у модалці, рядок лишається вибраним (B24).
	theme.set_type_variation("ShopRowOn", t)
	for state in ["normal", "pressed", "disabled", "hover", "hover_pressed"]:
		theme.set_stylebox(state, "ShopRowOn", row_on)
	theme.set_stylebox("focus", "ShopRowOn", row_focus)

	# Кнопки категорій 48×48: звичайна — чорний 56% + біла рамка; активна — accent.
	for spec in [["ShopCategory", UITokens.SHOP_ROW_BG, UITokens.TEXT_PRIMARY, UITokens.SHOP_ICON_TINT, UITokens.TEXT_PRIMARY],
			["ShopCategoryOn", UITokens.ACCENT, UITokens.BORDER, UITokens.ON_ACCENT, UITokens.ON_ACCENT]]:
		var c: String = spec[0]
		theme.set_type_variation(c, "Button")
		var box := _box(spec[1], spec[2], UITokens.BORDER_WIDTH, 0, 0)
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			theme.set_stylebox(state, c, box)
		theme.set_stylebox("focus", c, _focus_ring(0, 0, c == "ShopCategoryOn"))
		theme.set_font("font", c, _font_bold)
		theme.set_font_size("font_size", c, UITokens.SIZE_CAPTION)
		for col in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			theme.set_color(col, c, spec[4])
		for col in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color"]:
			theme.set_color(col, c, spec[3])
		theme.set_constant("icon_max_width", c, UITokens.SHOP_CATEGORY_ICON)

	# NPC-меню: UI/Menu Item зі своїм фоном (#111118) і рамкою (#3a3a42).
	var npc_box := _box(UITokens.BACKGROUND, UITokens.BORDER, UITokens.BORDER_WIDTH,
			UITokens.MENU_ITEM_PAD_H, UITokens.MENU_ITEM_PAD_V)
	var dim := Color(UITokens.TEXT_PRIMARY, UITokens.MENU_INACTIVE_ALPHA)
	# Game Over — той самий рядок під власними іменами: NPC-меню — ігрова поверхня з більшим текстом (D474).
	for spec in [["NpcMenuItem", _font_regular, dim, Color(0, 0, 0, 0)],
			["NpcMenuItemOn", _font_semibold, UITokens.TEXT_PRIMARY, UITokens.TEXT_PRIMARY],
			["GameOverItem", _font_regular, dim, Color(0, 0, 0, 0)],
			["GameOverItemOn", _font_semibold, UITokens.TEXT_PRIMARY, UITokens.TEXT_PRIMARY]]:
		var n: String = spec[0]
		theme.set_type_variation(n, "Button")
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			theme.set_stylebox(state, n, npc_box)
		# Q33: NPC-меню і Game Over раніше показували фокус лише шевроном і альфою тексту.
		theme.set_stylebox("focus", n, _focus_ring(UITokens.MENU_ITEM_PAD_H, UITokens.MENU_ITEM_PAD_V))
		theme.set_font("font", n, spec[1])
		theme.set_font_size("font_size", n, UITokens.SIZE_LABEL)
		for col in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			theme.set_color(col, n, spec[2])
		for col in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color", "icon_hover_pressed_color"]:
			theme.set_color(col, n, spec[3])
		theme.set_constant("h_separation", n, UITokens.MENU_ITEM_GAP)
		theme.set_constant("icon_max_width", n, UITokens.MENU_ITEM_POINTER)


## Figma load-game-screen 150:1278 / save-game-screen 17:5.
func _save_slots(theme: Theme) -> void:
	# Figma: "Save Data Management" — Regular 11, letter-spacing 3.
	theme.set_font("font", "SaveSystemLabel", _spaced(_font_regular, 3))

	# Картка слота: рамка 1px — біла; у вибраного (фокус) — accent 2px (B32). Заливка — MENU_SURFACE:
	# у Figma картка без заливки, але тоді мапа-фон іде крізь текст слота (B8).
	var t := "SaveSlotCard"
	theme.set_type_variation(t, "Button")
	var normal := _box(UITokens.MENU_SURFACE, UITokens.SAVE_CARD_BORDER, UITokens.BORDER_WIDTH,
			UITokens.SAVE_CARD_PAD_H, UITokens.SAVE_CARD_PAD_V)
	var selected := _box(UITokens.MENU_SURFACE, UITokens.ACCENT, UITokens.BORDER_WIDTH_SELECTED,
			UITokens.SAVE_CARD_PAD_H, UITokens.SAVE_CARD_PAD_V)
	for state in ["normal", "pressed", "disabled"]:
		theme.set_stylebox(state, t, normal)
	theme.set_stylebox("hover", t, selected)
	theme.set_stylebox("hover_pressed", t, selected)
	theme.set_stylebox("focus", t, _focus_ring(UITokens.SAVE_CARD_PAD_H, UITokens.SAVE_CARD_PAD_V))
	# B31 (#66): ціль відкритої модалки (Overwrite Save?) лишається вибраною без фокусу.
	theme.set_type_variation("SaveSlotCardTargeted", t)
	theme.set_stylebox("normal", "SaveSlotCardTargeted", selected)

	var rows := {
		"SaveTopSection": ["VBoxContainer", UITokens.SAVE_TOP_GAP],
		"SaveOrnament": ["HBoxContainer", UITokens.SAVE_ORNAMENT_GAP],
		"SaveSlotList": ["VBoxContainer", UITokens.SAVE_LIST_GAP],
		"SlotInfoColumn": ["VBoxContainer", UITokens.SAVE_INFO_GAP],
		"SlotRightInfo": ["HBoxContainer", UITokens.SAVE_RIGHT_GAP],
		"SlotPlaytime": ["HBoxContainer", UITokens.SAVE_PLAYTIME_GAP],
		"SlotRow": ["HBoxContainer", 0],
	}
	for name in rows:
		theme.set_type_variation(name, rows[name][0])
		theme.set_constant("separation", name, rows[name][1])

	theme.set_type_variation("SaveScreenMargin", "MarginContainer")
	theme.set_constant("margin_left", "SaveScreenMargin", UITokens.SAVE_SCREEN_MARGIN_H)
	theme.set_constant("margin_right", "SaveScreenMargin", UITokens.SAVE_SCREEN_MARGIN_H)
	theme.set_constant("margin_top", "SaveScreenMargin", UITokens.SAVE_SCREEN_MARGIN_TOP)

	# Button не розкладає дочірні вузли — внутрішній відступ картки дає MarginContainer.
	theme.set_type_variation("SlotCardMargin", "MarginContainer")
	for side in ["left", "right"]:
		theme.set_constant("margin_" + side, "SlotCardMargin", UITokens.SAVE_CARD_PAD_H)
	for side in ["top", "bottom"]:
		theme.set_constant("margin_" + side, "SlotCardMargin", UITokens.SAVE_CARD_PAD_V)

	# Тонкі білі лінії верхньої секції (Figma: Line, stroke #ffffff 1px).
	theme.set_type_variation("SaveRule", "HSeparator")
	var line := StyleBoxLine.new()
	line.color = UITokens.TEXT_PRIMARY
	line.thickness = UITokens.BORDER_WIDTH
	theme.set_stylebox("separator", "SaveRule", line)
	theme.set_constant("separation", "SaveRule", UITokens.BORDER_WIDTH)

	# Вдавлена панель (Figma: Inner Shadow). У Godot немає inner shadow —
	# емулюємо темнішим фоном і рамкою. Див. design/ui_implementation_plan.md.
	theme.set_type_variation("InsetPanel", "PanelContainer")
	theme.set_stylebox("panel", "InsetPanel", _box(Color(UITokens.BACKGROUND, 0.75),
			UITokens.BORDER, UITokens.BORDER_WIDTH, UITokens.PANEL_PADDING, UITokens.PANEL_PADDING))


# ── HUD v2: смуги HP / SP і XP на всю ширину, пігулка зілля (combat_hud_mapping → HUD v2) ──

func _hud_v2(theme: Theme) -> void:
	for spec in [["HudHpBar", UITokens.HP_FILL], ["HudSpBar", UITokens.SP_FILL]]:
		theme.set_type_variation(spec[0], "ProgressBar")
		var track := _box(UITokens.HUD_BAR_BG, UITokens.HUD_RIM, UITokens.BORDER_WIDTH, 0, 0)
		theme.set_stylebox("background", spec[0], track)
		theme.set_stylebox("fill", spec[0], _hud_fill(spec[1], UITokens.HUD_BAR_HIGHLIGHT_ROW, UITokens.BORDER_WIDTH))
	# D552: тло з 1 px верхнім краєм, золота заливка під ним; ні підпису, ні чисел.
	theme.set_type_variation("HudXpBar", "ProgressBar")
	var xp_track := _box(UITokens.HUD_BAR_BG, UITokens.HUD_RIM, 0, 0, 0)
	xp_track.border_width_top = UITokens.BORDER_WIDTH
	theme.set_stylebox("background", "HudXpBar", xp_track)
	var xp_fill := _hud_fill(UITokens.ACCENT, UITokens.HUD_BAR_HIGHLIGHT_XP, 0)
	xp_fill.expand_margin_top = -UITokens.BORDER_WIDTH
	theme.set_stylebox("fill", "HudXpBar", xp_fill)
	# Пігулка з кількістю зілля на чипі Q.
	theme.set_type_variation("HudCountPill", "PanelContainer")
	var pill := _box(Color(UITokens.HUD_INK, UITokens.HUD_PILL_ALPHA), UITokens.HUD_RIM, UITokens.BORDER_WIDTH, 0, 0)
	pill.set_corner_radius_all(UITokens.HUD_PILL_RADIUS)
	theme.set_stylebox("panel", "HudCountPill", pill)


# ── Нові очки (D742): сяйво, лічильник на вкладці, кнопка на HUD ────────────

func _new_points(theme: Theme) -> void:
	# Сяйво навколо кнопки HUD: золота рамка й тінь без заливки; пульсує вузол (points_glow.gd).
	var halo := _box(Color(0, 0, 0, 0), UITokens.POINTS_GLOW_COLOR, UITokens.POINTS_GLOW_BORDER, 0, 0)
	halo.set_corner_radius_all(UITokens.NEW_POINTS_RADIUS)
	halo.shadow_color = Color(UITokens.POINTS_GLOW_COLOR, UITokens.POINTS_GLOW_ALPHA)
	halo.shadow_size = UITokens.POINTS_GLOW_SIZE
	theme.set_type_variation("PointsGlow", "Panel")
	theme.set_stylebox("panel", "PointsGlow", halo)
	# На вкладці бічної панелі — та сама табличка-стрілка, золота рамка й легка золота підсвітка.
	theme.set_type_variation("PointsGlowTab", "Panel")
	var tab_glow := _arrow_plate(UITokens.POINTS_GLOW_TAB_FILL, UITokens.POINTS_GLOW_COLOR, UITokens.POINTS_GLOW_BORDER)
	theme.set_stylebox("panel", "PointsGlowTab", tab_glow)
	theme.set_type_variation("PointsBadge", "PanelContainer")
	var badge := _box(UITokens.POINTS_BADGE_BG, UITokens.POINTS_BADGE_BG, 0, UITokens.POINTS_BADGE_PAD_H, 0)
	badge.set_corner_radius_all(UITokens.POINTS_BADGE_RADIUS)
	theme.set_stylebox("panel", "PointsBadge", badge)
	theme.set_type_variation("PointsBadgeLabel", "Label")
	theme.set_font("font", "PointsBadgeLabel", _font_bold)
	theme.set_font_size("font_size", "PointsBadgeLabel", UITokens.SIZE_CAPTION)
	theme.set_color("font_color", "PointsBadgeLabel", UITokens.POINTS_BADGE_TEXT)
	# Кнопка на HUD: темна пігулка з рамкою HUD_RIM, як пігулка зілля; наведена / у фокусі — золота рамка.
	theme.set_type_variation("NewPointsButton", "Button")
	var plate := _box(UITokens.NEW_POINTS_BG, UITokens.NEW_POINTS_BORDER, UITokens.BORDER_WIDTH,
			UITokens.NEW_POINTS_PAD_H, UITokens.NEW_POINTS_PAD_V)
	plate.set_corner_radius_all(UITokens.NEW_POINTS_RADIUS)
	var lit := plate.duplicate() as StyleBoxFlat
	lit.border_color = UITokens.POINTS_GLOW_COLOR
	for state in ["normal", "disabled"]:
		theme.set_stylebox(state, "NewPointsButton", plate)
	for state in ["hover", "pressed", "hover_pressed"]:
		theme.set_stylebox(state, "NewPointsButton", lit)
	theme.set_stylebox("focus", "NewPointsButton", _focus_ring(UITokens.NEW_POINTS_PAD_H, UITokens.NEW_POINTS_PAD_V))
	var labels := {
		"NewPointsCount": [_font_bold, UITokens.SIZE_NEW_POINTS_COUNT, UITokens.NEW_POINTS_TEXT],
		"NewPointsCaption": [_font_semibold, UITokens.SIZE_NEW_POINTS_CAPTION, UITokens.NEW_POINTS_TEXT],
		"NewPointsKey": [_font_bold, UITokens.SIZE_NEW_POINTS_KEY, UITokens.HUD_INK],
	}
	for name in labels:
		var spec: Array = labels[name]
		theme.set_type_variation(name, "Label")
		theme.set_font("font", name, spec[0])
		theme.set_font_size("font_size", name, spec[1])
		theme.set_color("font_color", name, spec[2])


## Заливка смуги: колір і світла смужка зверху (білий HUD_BAR_HIGHLIGHT поверх кольору), утоплена на [param inset] px.
func _hud_fill(fill: Color, highlight: int, inset: int) -> StyleBoxFlat:
	var box := _box(fill, fill.lerp(Color.WHITE, UITokens.HUD_BAR_HIGHLIGHT), 0, 0, 0)
	box.border_width_top = highlight
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_expand_margin(side, -inset)
	return box


# ── ProgressBar (Figma UI/ProgressBar, UI/ResourceBar) ──────────────────────

func _setup_progress_bar(theme: Theme) -> void:
	var bg := _box(Color(UITokens.BACKGROUND, 0.8), UITokens.BORDER, UITokens.BORDER_WIDTH, 0, 0)
	var fill := _box(UITokens.ACCENT, UITokens.ACCENT, 0, 0, 0)
	theme.set_stylebox("background", "ProgressBar", bg)
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_font("font", "ProgressBar", _font_semibold)
	theme.set_font_size("font_size", "ProgressBar", UITokens.SIZE_CAPTION)
	theme.set_color("font_color", "ProgressBar", UITokens.TEXT_PRIMARY)


# ── Скролбари (Figma UI/Scrollbar — 10px, без заокруглень) ──────────────────

## Карта World Map (world_map_spec): шпильки локацій, картка, легенда, вуаль рівня 2 і написи на них.
func _world_map(theme: Theme) -> void:
	var labels := {
		"MapPinName": [_font_bold, UITokens.SIZE_MAP_PIN_NAME, UITokens.MAP_PIN_NAME],
		"MapPinNameLocked": [_font_bold, UITokens.SIZE_MAP_PIN_NAME, UITokens.MAP_LOCKED],
		"MapPinState": [_font_bold, UITokens.SIZE_MAP_PIN_STATE, UITokens.TEXT_PRIMARY],
		"MapCardTitle": [_font_bold, UITokens.SIZE_MAP_CARD_TITLE, UITokens.MAP_GOLD],
		"MapCardText": [_font_regular, UITokens.SIZE_MAP_CARD_TEXT, UITokens.TEXT_PRIMARY],
		"MapLegendTitle": [_font_bold, UITokens.SIZE_MAP_LEGEND_TITLE, UITokens.MAP_GOLD],
		"MapRoomName": [_font_bold, UITokens.SIZE_MAP_ROOM, UITokens.MAP_INK],
		"MapPassage": [_font_bold, UITokens.SIZE_MAP_PASSAGE, UITokens.MAP_PASSAGE],
	}
	for name in labels:
		var spec: Array = labels[name]
		theme.set_type_variation(name, "Label")
		theme.set_font("font", name, spec[0])
		theme.set_font_size("font_size", name, spec[1])
		theme.set_color("font_color", name, spec[2])
	var plates := {
		"MapPin": [UITokens.MAP_PLATE, UITokens.MAP_GOLD, UITokens.MAP_PIN_BORDER],
		"MapPinSelected": [UITokens.MAP_PLATE, UITokens.MAP_GOLD, UITokens.MAP_PIN_SELECTED_BORDER],
		"MapPinHere": [UITokens.MAP_PLATE, UITokens.MAP_HERE, UITokens.MAP_PIN_HERE_BORDER],
		"MapPinLocked": [UITokens.MAP_PLATE_LOCKED, UITokens.MAP_GOLD, UITokens.MAP_PIN_BORDER],
	}
	for name in plates:
		var spec: Array = plates[name]
		var plate := _box(spec[0], spec[1], spec[2], UITokens.MAP_PIN_PAD_H, UITokens.MAP_PIN_PAD_V)
		plate.set_corner_radius_all(UITokens.MAP_PIN_RADIUS)
		theme.set_type_variation(name, "PanelContainer")
		theme.set_stylebox("panel", name, plate)
	var dots := {"MapPinDotHere": UITokens.MAP_HERE, "MapPinDotVisited": UITokens.MAP_GOLD,
		"MapPinDotLocked": UITokens.MAP_LOCKED}
	for name in dots:
		var dot := _box(dots[name], dots[name], 0, 0, 0)
		@warning_ignore("integer_division")
		dot.set_corner_radius_all(UITokens.MAP_PIN_DOT / 2)
		theme.set_type_variation(name, "Panel")
		theme.set_stylebox("panel", name, dot)
	var card := _box(UITokens.MAP_CARD_BG, UITokens.MAP_GOLD, UITokens.BORDER_WIDTH,
			UITokens.MAP_CARD_PAD_H, UITokens.MAP_CARD_PAD_V)
	card.set_corner_radius_all(UITokens.MAP_CARD_RADIUS)
	theme.set_type_variation("MapCard", "PanelContainer")
	theme.set_stylebox("panel", "MapCard", card)
	theme.set_type_variation("MapVeil", "Panel")
	theme.set_stylebox("panel", "MapVeil", _box(UITokens.MAP_VEIL, UITokens.MAP_VEIL, 0, 0, 0))


func _setup_scrollbars(theme: Theme) -> void:
	# Товщину смуги дають поля стилю (B18: з нульовими полями смуга була 0px — невидима).
	var half: int = int(UITokens.SCROLLBAR_WIDTH / 2.0)
	for t in ["VScrollBar", "HScrollBar"]:
		var pad_h: int = half if t == "VScrollBar" else 0
		var pad_v: int = 0 if t == "VScrollBar" else half
		theme.set_stylebox("scroll", t, _box(Color(UITokens.BACKGROUND, 0.6), Color(0, 0, 0, 0), 0, pad_h, pad_v))
		# Figma UI/Scrollbar 222:4768: повзунок — color/accent (сірий BORDER зливався з фоном, #79).
		theme.set_stylebox("grabber", t, _box(UITokens.ACCENT, Color(0, 0, 0, 0), 0, pad_h, pad_v))
		theme.set_stylebox("grabber_highlight", t, _box(UITokens.ACCENT, Color(0, 0, 0, 0), 0, pad_h, pad_v))
		theme.set_stylebox("grabber_pressed", t, _box(UITokens.ACCENT, Color(0, 0, 0, 0), 0, pad_h, pad_v))


# ── LineEdit / HSlider (потрібні для екрана налаштувань) ────────────────────

func _setup_line_edit(theme: Theme) -> void:
	theme.set_font("font", "LineEdit", _font_regular)
	theme.set_font_size("font_size", "LineEdit", UITokens.SIZE_BODY)
	theme.set_color("font_color", "LineEdit", UITokens.TEXT_PRIMARY)
	theme.set_color("font_placeholder_color", "LineEdit", UITokens.TEXT_MUTED)
	theme.set_color("caret_color", "LineEdit", UITokens.ACCENT)
	theme.set_color("selection_color", "LineEdit", Color(UITokens.ACCENT, 0.35))
	theme.set_stylebox("normal", "LineEdit", _box(UITokens.SURFACE, UITokens.BORDER))
	theme.set_stylebox("focus", "LineEdit", _box(UITokens.SURFACE, UITokens.ACCENT, UITokens.BORDER_WIDTH_SELECTED))
	theme.set_stylebox("read_only", "LineEdit", _box(Color(UITokens.SURFACE, 0.25), UITokens.BORDER))


## Figma settings-audio 17:465 — доріжка 320×8. Вертикальні поля тримають
## висоту: з нульовими доріжка схлопувалась і візуально зникала.
func _setup_slider(theme: Theme) -> void:
	theme.set_stylebox("slider", "HSlider", _box(Color(UITokens.BACKGROUND, 0.8), UITokens.BORDER, UITokens.BORDER_WIDTH, 0, 4))
	theme.set_stylebox("grabber_area", "HSlider", _box(UITokens.ACCENT, Color(0, 0, 0, 0), 0, 0, 0))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(UITokens.ACCENT.lightened(0.15), Color(0, 0, 0, 0), 0, 0, 0))


# ── Tooltip (Figma UI/Tooltip) ──────────────────────────────────────────────

func _setup_tooltip(theme: Theme) -> void:
	theme.set_stylebox("panel", "TooltipPanel", _box(UITokens.BACKGROUND, UITokens.BORDER,
			UITokens.BORDER_WIDTH, UITokens.SPACE_MD, UITokens.SPACE_SM))
	theme.set_font("font", "TooltipLabel", _font_regular)
	theme.set_font_size("font_size", "TooltipLabel", UITokens.SIZE_SMALL)
	theme.set_color("font_color", "TooltipLabel", UITokens.TEXT_PRIMARY)


## D166: один прохід по всіх розмірах шрифтів теми — жоден тип не пропущено, хоч би як його задали вище.
## Типи ігрових поверхонь (UITokens.INGAME_FONT_TYPES) — ×1.5 з порогами (D474).
func _scale_fonts(theme: Theme) -> void:
	theme.default_font_size = UITokens.font_px(theme.default_font_size)
	for type_name in theme.get_font_size_type_list():
		if type_name in UITokens.FIGMA_FONT_TYPES:
			continue  # HUD v2: Figma-розмір як є (UITokens.FIGMA_FONT_TYPES)
		var in_game := type_name in UITokens.INGAME_FONT_TYPES
		for size_name in theme.get_font_size_list(type_name):
			theme.set_font_size(size_name, type_name, UITokens.font_px(theme.get_font_size(size_name, type_name), in_game))
