extends PanelContainer
class_name UIBottomBar

## Нижня панель підказок ігрового меню.
## Figma: UI/Bottom Bar (121:1073), варіанти input=gamepad / input=keyboard.
##
## Зліва — контекстна підказка, справа — підказки дій (значок + назва).
## Панель лише відображає стан; вона НЕ обробляє ввід.
## Реальна навігація лишається в focus_router.gd та game_menu.gd.
## Підказки дій — копії шаблону %ActionHint зі сцени (D117), стилі — з теми (BottomBar, ActionHint,
## ActionBadge, ActionBadgeLabel).

const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")
const RowFill = preload("res://SampleProject/UI/Components/ui_rows.gd")

@onready var _hint_label: Label = %HintLabel
@onready var _actions: HBoxContainer = %Actions
@onready var _action_hint: HBoxContainer = %ActionHint

## Стандартна підказка з кадрів ігрового меню у Figma.
const DEFAULT_HINT := "Select a category."

var _default_hint: String = DEFAULT_HINT
## Поточний текст підказки. Зберігається окремо від мітки: компоненти меню пишуть у панель
## під час власного _ready(), коли @onready-мітка цієї панелі ще не готова.
var _hint: String = ""
## Останні set_actions — щоб перемалювати бейджі, коли змінився пристрій вводу.
var _action_list: Array = []


func _enter_tree() -> void:
	# Екрани знаходять панель через групу, щоб не залежати від шляху в дереві.
	# Саме _enter_tree, а не _ready: _ready сусідніх компонентів меню (Inventory, Journal…)
	# спрацьовує раніше, і підказка першого предмета губилась (панелі ще не було в групі).
	add_to_group(&"ui_bottom_bar")


func _ready() -> void:
	if _hint.is_empty():
		_hint = _hint_label.text if not _hint_label.text.is_empty() else DEFAULT_HINT
	_apply_hint()
	if _action_list.is_empty():
		set_actions([
			{"action": &"navigate", "label": "Select"},
			{"action": &"ui_accept", "label": "Confirm"},
			{"action": &"ui_cancel", "label": "Return"},
		])
	EventBus.input_device_changed.connect(_on_input_device_changed)


func _on_input_device_changed(_pad: bool) -> void:
	set_actions(_action_list)


## Ліва контекстна підказка.
func set_hint(text: String) -> void:
	_hint = text
	_apply_hint()


## Тимчасова підказка (опис предмета під фокусом). Порожній рядок — повернути типову.
func set_context_hint(text: String) -> void:
	_hint = text if not text.is_empty() else _default_hint
	_apply_hint()


## Підказка, до якої повертаємось, коли контекст зникає.
func set_default_hint(text: String) -> void:
	_default_hint = text
	_hint = text
	_apply_hint()


func _apply_hint() -> void:
	if is_node_ready():
		_hint_label.text = _hint


## Праві підказки дій. [code]actions[/code] — масив {action, label}: action — дія InputMap, масив дій
## (бейдж «Q/E» / «LB/RB») або &"navigate"; бейдж називає кнопку пристрою, яким грали останнім (BACKLOG 24).
func set_actions(actions: Array) -> void:
	_action_list = actions
	var rows := RowFill.fill(_actions, _action_hint, actions.size())
	for i in rows.size():
		rows[i].get_node(^"Badge/Key").text = InputGlyphs.badge(actions[i].action)
		rows[i].get_node(^"Name").text = String(actions[i].get("label", ""))
