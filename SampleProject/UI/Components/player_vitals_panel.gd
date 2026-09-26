extends PanelContainer
class_name UIPlayerVitalsPanel

## Панель життєвих показників гравця.
## Figma: Game Scene / Combat HUD → Player Vitals Panel (434:6558).
##
## Три рядки з кадру: HP, SP, XP. Значення беруться з наявних власників —
## HealthComponent, SkillManager і XPManager. Формул тут немає.

const BAR_WIDTH := 200
const BAR_HEIGHT := 8

@onready var _name_label: Label = %VitalsName
@onready var _level_label: Label = %LevelValue
@onready var _rows: VBoxContainer = %VitalsBars

var _skill_manager: Node = null
var _rows_by_id: Dictionary = {}


func _ready() -> void:
	add_to_group(&"player_vitals_panel")
	var sl: Node = ServiceLocatorHelper.get_service_locator()
	if sl:
		_skill_manager = sl.get_skill_manager()
	_build_rows()
	if not EventBus.sp_changed.is_connected(_on_sp_changed):
		EventBus.sp_changed.connect(_on_sp_changed)
	refresh()


func _on_sp_changed(_current: int, _max: int) -> void:
	refresh()


func _build_rows() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_rows_by_id.clear()
	_rows.add_child(_make_row("HP", UITokens.HP_FILL, false))
	_rows.add_child(_make_row("SP", UITokens.SP_FILL, false))
	_rows.add_child(_make_row("XP", UITokens.ACCENT, true))


func _make_row(id: String, fill: Color, muted: bool) -> Control:
	var row := HBoxContainer.new()
	row.name = id
	row.add_theme_constant_override("separation", UITokens.SPACE_SM)

	var label := Label.new()
	label.text = id
	label.custom_minimum_size = Vector2(30, 0)
	label.theme_type_variation = &"VitalsLabel"
	if muted:
		label.add_theme_color_override("font_color", UITokens.TEXT_SECONDARY)
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = UITokens.BACKGROUND
	track.set_corner_radius_all(UITokens.RADIUS)
	track.set_border_width_all(UITokens.BORDER_WIDTH)
	track.border_color = UITokens.BORDER
	bar.add_theme_stylebox_override("background", track)
	var fill_box := StyleBoxFlat.new()
	fill_box.bg_color = fill
	fill_box.set_corner_radius_all(UITokens.RADIUS)
	bar.add_theme_stylebox_override("fill", fill_box)
	row.add_child(bar)

	var value := Label.new()
	value.name = "Value"
	value.custom_minimum_size = Vector2(80, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.theme_type_variation = &"VitalsValue"
	if muted:
		value.add_theme_color_override("font_color", UITokens.TEXT_SECONDARY)
	row.add_child(value)

	_rows_by_id[id] = row
	return row


func refresh() -> void:
	if not is_node_ready():
		return
	var sl: Node = ServiceLocatorHelper.get_service_locator()
	if sl == null:
		return
	var gm = sl.get_game_manager()
	var character = gm.get_active_character() if gm else null
	_name_label.text = String(character.name).to_upper() if character else "—"

	var xp_manager = sl.get_xp_manager()
	_level_label.text = "LV.%d" % (xp_manager.get_level() if xp_manager else 1)
	_style_level_badge()

	if gm:
		_set_row("HP", _current_hp(gm), gm.calculate_max_health())
	if _skill_manager:
		_set_row("SP", _skill_manager.get_current_sp(), _skill_manager.get_max_sp())
	if xp_manager:
		_set_row("XP", xp_manager.current_xp, xp_manager.xp_for_next_level)


## Figma 434:6561 — акцентна заливка, темний текст.
func _style_level_badge() -> void:
	_level_label.add_theme_color_override("font_color", UITokens.ON_ACCENT)
	var badge := _level_label.get_parent() as PanelContainer
	if badge == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = UITokens.ACCENT
	box.set_corner_radius_all(UITokens.RADIUS)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", box)


func _set_row(id: String, current: int, maximum: int) -> void:
	var row: Control = _rows_by_id.get(id)
	if row == null:
		return
	var bar: ProgressBar = row.get_node(^"Bar")
	var value: Label = row.get_node(^"Value")
	bar.max_value = maxf(1.0, float(maximum))
	bar.value = float(clampi(current, 0, maxi(maximum, 0)))
	value.text = "%s / %s" % [_thousands(current), _thousands(maximum)]


func _thousands(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0 else "") + out


func _current_hp(gm) -> int:
	var player: Node = gm.get_current_player()
	if player:
		var health: Node = player.get_node_or_null(^"HealthComponent")
		if health and "current_health" in health:
			return int(health.current_health)
	return gm.calculate_max_health()
