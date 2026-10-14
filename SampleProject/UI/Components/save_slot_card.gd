extends HBoxContainer
class_name SaveSlotCard

## Картка слота збереження — спільна для Save і Load (D80).
## Figma: save-slot-N у load-game-screen 150:1278 / save-game-screen 17:5.
##
## [курсор 60px] [картка: номер-водяний знак · дата/локація · рівень/ім'я · час гри]
## Порожній слот: "Empty Slot / No save data available".
## Показує лише реальні дані з SaveSystem.get_slot_summary() — відсутні поля ховаються.

signal activated(slot: int)

var slot: int = 0
var summary: Dictionary = {}

@onready var card: Button = %Card
@onready var _cursor: TextureRect = %Cursor
@onready var _watermark: Label = %Watermark
@onready var _info: HBoxContainer = %Info
@onready var _empty: VBoxContainer = %Empty
@onready var _date: Label = %Date
@onready var _location: Label = %Location
@onready var _character: VBoxContainer = %Character
@onready var _level: Label = %Level
@onready var _name: Label = %CharName
@onready var _playtime_row: HBoxContainer = %Playtime
@onready var _playtime: Label = %PlaytimeValue


func _ready() -> void:
	%CursorColumn.custom_minimum_size.x = UITokens.SAVE_CURSOR_COLUMN
	card.custom_minimum_size.y = UITokens.SAVE_CARD_HEIGHT
	# Номер-водяний знак (160px) вищий за картку — лежить поверх і обрізається, як у Figma.
	%WatermarkSpace.custom_minimum_size.x = UITokens.SAVE_WATERMARK_SPACE
	_watermark.offset_left = UITokens.SAVE_CARD_PAD_H
	%ClockIcon.custom_minimum_size = Vector2(UITokens.SAVE_CLOCK_ICON, UITokens.SAVE_CLOCK_ICON)
	card.pressed.connect(func(): activated.emit(slot))
	card.focus_entered.connect(_update_cursor)
	card.focus_exited.connect(_update_cursor)
	card.mouse_entered.connect(func(): if card.focus_mode != Control.FOCUS_NONE: card.grab_focus())
	_update_cursor()


## [param selectable] = false — картка видима, але вимкнена і не отримує фокус (D77).
func setup(slot_summary: Dictionary, selectable: bool) -> void:
	summary = slot_summary
	slot = int(slot_summary.get("slot", 0))
	_watermark.text = str(slot)
	var exists := bool(slot_summary.get("exists", false))
	_info.visible = exists
	_empty.visible = not exists
	if exists:
		_date.text = format_timestamp(str(slot_summary.get("timestamp", "")))
		_date.visible = _date.text != ""
		_location.text = str(slot_summary.get("location", ""))
		var has_level := slot_summary.has("level")
		var has_name := slot_summary.has("character_name")
		_level.visible = has_level
		_level.text = "Lv. %d" % int(slot_summary.get("level", 0))
		_name.visible = has_name
		_name.text = str(slot_summary.get("character_name", ""))
		_character.visible = has_level or has_name
		_playtime.text = format_playtime(float(slot_summary.get("playtime_sec", 0.0)))
	card.disabled = not selectable
	card.focus_mode = Control.FOCUS_ALL if selectable else Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if selectable else Control.CURSOR_ARROW
	_update_cursor()


func is_selectable() -> bool:
	return card.focus_mode != Control.FOCUS_NONE


## "2026-09-23T00:05:12" → "9/23/2026 00:05" (формат кадру Figma).
static func format_timestamp(iso: String) -> String:
	var parts := iso.split("T")
	if parts.size() < 2:
		return iso
	var d := parts[0].split("-")
	if d.size() < 3:
		return iso
	return "%d/%d/%s %s" % [int(d[1]), int(d[2]), d[0], parts[1].substr(0, 5)]


## Секунди → "011:05" (години:хвилини, як у Figma).
static func format_playtime(seconds: float) -> String:
	var total := int(maxf(0.0, seconds)) / 60
	return "%03d:%02d" % [total / 60, total % 60]


func _update_cursor() -> void:
	_cursor.visible = card.has_focus()
