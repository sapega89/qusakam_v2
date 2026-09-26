extends PanelContainer
class_name UIBottomBar

## Нижня панель підказок ігрового меню.
## Figma: UI/Bottom Bar (121:1073), варіанти input=gamepad / input=keyboard.
##
## Зліва — контекстна підказка, справа — підказки дій (значок + назва).
## Панель лише відображає стан; вона НЕ обробляє ввід.
## Реальна навігація лишається в focus_router.gd та game_menu.gd.

@onready var _hint_label: Label = %HintLabel
@onready var _actions: HBoxContainer = %Actions

## Значки дій круглі — це єдиний свідомий виняток із shape/radius-sm = 0,
## бо Figma UI/Action Button (276:467) малює їх колами.
const _BADGE_SIZE := 24


## Стандартна підказка з кадрів ігрового меню у Figma.
const DEFAULT_HINT := "Select a category."

var _default_hint: String = DEFAULT_HINT


func _ready() -> void:
	# Екрани знаходять панель через групу, щоб не залежати від шляху в дереві.
	add_to_group(&"ui_bottom_bar")
	if _hint_label.text.is_empty():
		set_hint(DEFAULT_HINT)
	if _actions.get_child_count() == 0:
		set_actions([
			{"key": "LB", "label": "Select"},
			{"key": "A", "label": "Confirm"},
			{"key": "B", "label": "Return"},
		])


## Ліва контекстна підказка.
func set_hint(text: String) -> void:
	_hint_label.text = text


## Тимчасова підказка (опис предмета під фокусом). Порожній рядок — повернути типову.
func set_context_hint(text: String) -> void:
	_hint_label.text = text if not text.is_empty() else _default_hint


## Підказка, до якої повертаємось, коли контекст зникає.
func set_default_hint(text: String) -> void:
	_default_hint = text
	_hint_label.text = text


## Праві підказки дій. [code]actions[/code] — масив {key, label}.
func set_actions(actions: Array) -> void:
	for child in _actions.get_children():
		child.queue_free()
	for action in actions:
		_actions.add_child(_make_action(
			String(action.get("key", "")),
			String(action.get("label", ""))
		))


func _make_action(key: String, label_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITokens.ICON_TEXT_GAP)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(_BADGE_SIZE, _BADGE_SIZE)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = UITokens.ACCENT
	badge_style.set_corner_radius_all(_BADGE_SIZE / 2)
	badge_style.content_margin_left = UITokens.SPACE_XS
	badge_style.content_margin_right = UITokens.SPACE_XS
	badge.add_theme_stylebox_override("panel", badge_style)

	var key_label := Label.new()
	key_label.text = key
	key_label.theme_type_variation = &"CaptionLabel"
	key_label.add_theme_color_override("font_color", UITokens.ON_ACCENT)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(key_label)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.theme_type_variation = &"SmallLabel"
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	row.add_child(badge)
	row.add_child(name_label)
	return row
