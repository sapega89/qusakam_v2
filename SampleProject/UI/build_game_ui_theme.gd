extends SceneTree

## Генератор GameUITheme.tres з UITokens.
##
## Запуск:
##   godot --headless --path . --script res://SampleProject/UI/build_game_ui_theme.gd
##
## ⚠️ GameUITheme.tres згенерований. Не редагуй його вручну — зміни токени в
## UITokens.gd і перезапусти цей скрипт, інакше правки загубляться.

const OUT_PATH := "res://SampleProject/UI/Themes/GameUITheme.tres"

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
	_setup_progress_bar(theme)
	_setup_scrollbars(theme)
	_setup_line_edit(theme)
	_setup_slider(theme)
	_setup_tooltip(theme)

	var dir := OUT_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var err := ResourceSaver.save(theme, OUT_PATH)
	if err != OK:
		printerr("❌ Failed to save theme: %d" % err)
		quit(1)
		return

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
		"SectionLabel": [_font_regular, UITokens.SIZE_LABEL, UITokens.TEXT_SECONDARY],
		"TreeTitle": [_font_bold, UITokens.SIZE_TOPBAR, UITokens.ACCENT],
		"TooltipTitle": [_font_medium, UITokens.SIZE_LABEL, UITokens.ACCENT],
		"TooltipBody": [_font_regular, UITokens.SIZE_CAPTION_SM, UITokens.TEXT_PRIMARY],
		# Figma Game Scene / Combat HUD (434:6556)
		"BindBadge": [_font_bold, UITokens.SIZE_MICRO, UITokens.TEXT_PRIMARY],
		"CooldownLabel": [_font_bold, UITokens.SIZE_LABEL, UITokens.ACCENT],
		"VitalsName": [_font_bold, UITokens.SIZE_ROW_TITLE, UITokens.ACCENT],
		"VitalsLabel": [_font_semibold, UITokens.SIZE_LABEL, UITokens.TEXT_PRIMARY],
		"VitalsValue": [_font_semibold, UITokens.SIZE_SMALL, UITokens.TEXT_PRIMARY],
		"QuestCaption": [_font_regular, UITokens.SIZE_SMALL, UITokens.ACCENT],
		"QuestTitle": [_font_regular, UITokens.SIZE_BODY, UITokens.TEXT_PRIMARY],
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
		"SettingsHint": [_font_regular, UITokens.SIZE_BODY_SM, UITokens.TEXT_SECONDARY],
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
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), UITokens.ACCENT, UITokens.BORDER_WIDTH_SELECTED, pad_h, pad_v))
	theme.set_stylebox("disabled", "Button", _box(Color(UITokens.SURFACE, 0.25), UITokens.BORDER, UITokens.BORDER_WIDTH, pad_h, pad_v))


func _setup_button_variations(theme: Theme) -> void:
	_primary_button(theme)
	_tab_button(theme)
	_sidebar_tab(theme)
	_icon_button(theme)
	_filter_button(theme)
	_list_row(theme)
	_skill_row(theme)
	_settings_segment(theme)
	_settings_stepper(theme)
	_settings_sidebar_tab(theme)


## Figma settings-* сегментований перемикач (17:350).
## Вибраний сегмент — акцентна заливка з темним текстом; контейнер малює рамку.
func _settings_segment(theme: Theme) -> void:
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
		theme.set_stylebox("focus", t, _box(bg, UITokens.ACCENT,
				UITokens.BORDER_WIDTH_SELECTED, pad_h, pad_v))
		theme.set_stylebox("disabled", t, _box(bg, Color(0, 0, 0, 0), 0, pad_h, pad_v))


## Figma settings-* стрілки степера (17:546 / 17:549) — 16px, без фону.
func _settings_stepper(theme: Theme) -> void:
	var t := "SettingsStepper"
	theme.set_type_variation(t, "Button")
	theme.set_font("font", t, _font_regular)
	theme.set_font_size("font_size", t, UITokens.SIZE_LABEL)
	theme.set_color("font_color", t, UITokens.TEXT_PRIMARY)
	theme.set_color("font_hover_color", t, UITokens.ACCENT)
	theme.set_color("font_pressed_color", t, UITokens.ACCENT)
	theme.set_color("font_disabled_color", t, UITokens.TEXT_DISABLED)
	for state in ["normal", "hover", "pressed", "disabled"]:
		theme.set_stylebox(state, t, _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4, 2))
	theme.set_stylebox("focus", t, _box(Color(0, 0, 0, 0), UITokens.ACCENT,
			UITokens.BORDER_WIDTH_SELECTED, 4, 2))


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
	theme.set_stylebox("focus", t, _box(Color(0, 0, 0, 0), UITokens.ACCENT,
			UITokens.BORDER_WIDTH_SELECTED, UITokens.SPACE_SM, UITokens.SPACE_SM))
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
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := UITokens.ACCENT if state in ["hover", "pressed"] else Color(0, 0, 0, 0)
		var sb := _box(bg, UITokens.ACCENT, UITokens.BORDER_WIDTH, UITokens.SPACE_MD, 6)
		sb.set_corner_radius_all(3)
		theme.set_stylebox(state, t, sb)


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
	theme.set_stylebox("focus", t, _box(Color(0, 0, 0, 0), UITokens.ACCENT,
			UITokens.BORDER_WIDTH_SELECTED, pad_h, pad_v))
	theme.set_stylebox("disabled", t, _box(Color(UITokens.BACKGROUND, 0.5),
			Color(0, 0, 0, 0), 0, pad_h, pad_v))


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
	theme.set_stylebox("focus", t, _box(Color(0, 0, 0, 0), UITokens.TEXT_PRIMARY, UITokens.BORDER_WIDTH_SELECTED, pad_h, pad_v))
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
	theme.set_stylebox("focus", t, _box(Color(0, 0, 0, 0), UITokens.ACCENT, UITokens.BORDER_WIDTH_SELECTED, pad_h, pad_v))
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
	var pad_h := UITokens.SPACE_LG
	var pad_v := UITokens.SPACE_MD
	theme.set_stylebox("normal", t, _box(UITokens.SURFACE, UITokens.BORDER, UITokens.BORDER_WIDTH, pad_h, pad_v))
	theme.set_stylebox("hover", t, _box(UITokens.SURFACE_HOVER, UITokens.BORDER_STRONG, UITokens.BORDER_WIDTH, pad_h, pad_v))
	theme.set_stylebox("focus", t, _box(UITokens.SURFACE_HOVER, UITokens.ACCENT, UITokens.BORDER_WIDTH_SELECTED, pad_h, pad_v))
	theme.set_stylebox("disabled", t, _box(Color(UITokens.SURFACE, 0.25), UITokens.BORDER, UITokens.BORDER_WIDTH, pad_h, pad_v))
	# Активний пункт: акцентна ліва грань.
	var act := _box(UITokens.SURFACE_HOVER, UITokens.BORDER, UITokens.BORDER_WIDTH, pad_h, pad_v)
	act.border_width_left = UITokens.SPACE_XS
	act.border_color = UITokens.ACCENT
	theme.set_stylebox("pressed", t, act)


## Figma UI/IconButton — квадратна кнопка 36×36 з іконкою.
func _icon_button(theme: Theme) -> void:
	var t := "IconButton"
	theme.set_type_variation(t, "Button")
	var pad := UITokens.SPACE_SM
	theme.set_stylebox("normal", t, _box(UITokens.SURFACE, UITokens.BORDER, UITokens.BORDER_WIDTH, pad, pad))
	theme.set_stylebox("hover", t, _box(UITokens.SURFACE_HOVER, UITokens.BORDER_STRONG, UITokens.BORDER_WIDTH, pad, pad))
	theme.set_stylebox("pressed", t, _box(UITokens.ACCENT, UITokens.ACCENT, UITokens.BORDER_WIDTH, pad, pad))
	theme.set_stylebox("focus", t, _box(Color(0, 0, 0, 0), UITokens.ACCENT, UITokens.BORDER_WIDTH_SELECTED, pad, pad))
	theme.set_stylebox("disabled", t, _box(Color(UITokens.SURFACE, 0.25), UITokens.BORDER, UITokens.BORDER_WIDTH, pad, pad))


# ── Панелі ──────────────────────────────────────────────────────────────────

func _setup_panels(theme: Theme) -> void:
	# Figma UI/Panel
	var surface := _box(UITokens.SURFACE, UITokens.BORDER, UITokens.BORDER_WIDTH,
			UITokens.PANEL_PADDING, UITokens.PANEL_PADDING)
	theme.set_stylebox("panel", "PanelContainer", surface)
	theme.set_stylebox("panel", "Panel", surface.duplicate())

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
	theme.set_stylebox("panel", "CenterPanel", _box(UITokens.SURFACE, UITokens.ACCENT,
			UITokens.BORDER_WIDTH, UITokens.CENTER_PANEL_PADDING, UITokens.CENTER_PANEL_PADDING))

	# Figma UI/Party Status Panel (104:490) — звичайна рамка, padding 24.
	theme.set_type_variation("SidePanel", "PanelContainer")
	theme.set_stylebox("panel", "SidePanel", _box(UITokens.SURFACE, UITokens.BORDER,
			UITokens.BORDER_WIDTH, UITokens.SPACE_XL, UITokens.SPACE_XL))

	# Картка персонажа (Figma UI/Party Character Card 324:6127).
	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", _box(UITokens.SURFACE, UITokens.ACCENT,
			UITokens.BORDER_WIDTH, UITokens.SPACE_MD, UITokens.SPACE_MD))

	# Figma menu-status: job-box / weapon-box / action-card — surface + 1px рамка.
	theme.set_type_variation("BoxPanel", "PanelContainer")
	theme.set_stylebox("panel", "BoxPanel", _box(UITokens.SURFACE, UITokens.BORDER,
			UITokens.BORDER_WIDTH, UITokens.SPACE_MD, UITokens.SPACE_MD))

	theme.set_type_variation("ActionCard", "PanelContainer")
	theme.set_stylebox("panel", "ActionCard", _box(UITokens.SURFACE, UITokens.BORDER,
			UITokens.BORDER_WIDTH, 18, 18))

	# Figma menu-skills: колонка класового дерева — surface + 1px рамка, padding 32.
	theme.set_type_variation("TreePanel", "PanelContainer")
	theme.set_stylebox("panel", "TreePanel", _box(UITokens.SURFACE, UITokens.BORDER,
			UITokens.BORDER_WIDTH, UITokens.SPACE_2XL, UITokens.SPACE_2XL))

	# Вдавлена панель (Figma: Inner Shadow). У Godot немає inner shadow —
	# емулюємо темнішим фоном і рамкою. Див. design/ui_implementation_plan.md.
	theme.set_type_variation("InsetPanel", "PanelContainer")
	theme.set_stylebox("panel", "InsetPanel", _box(Color(UITokens.BACKGROUND, 0.75),
			UITokens.BORDER, UITokens.BORDER_WIDTH, UITokens.PANEL_PADDING, UITokens.PANEL_PADDING))


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

func _setup_scrollbars(theme: Theme) -> void:
	for t in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", t, _box(Color(UITokens.BACKGROUND, 0.6), Color(0, 0, 0, 0), 0, 0, 0))
		theme.set_stylebox("grabber", t, _box(UITokens.BORDER, Color(0, 0, 0, 0), 0, 0, 0))
		theme.set_stylebox("grabber_highlight", t, _box(UITokens.ACCENT, Color(0, 0, 0, 0), 0, 0, 0))
		theme.set_stylebox("grabber_pressed", t, _box(UITokens.ACCENT, Color(0, 0, 0, 0), 0, 0, 0))


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
