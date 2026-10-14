extends Control

## Туторіал — одне повноекранне вікно поверх Game Menu (D126, Figma tutorial-content
## 135:1260). Відкривається через ModalLayer.show_custom_modal(), тож гра не
## вивантажується (B2). Теми — Resources/Data/tutorial.json, тільки про те, що є в грі.
## ↑/↓ (←/→, LB/RB) — сусідня тема; B / Esc — закрити.

## ModalLayer закриває вікно за цим сигналом (як Misc).
signal cancelled

const DATA_FILE := "res://SampleProject/Resources/Data/tutorial.json"

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _shot_frame: Control = %ShotFrame
@onready var _shot: TextureRect = %Shot
@onready var _hint_bar: Control = %HintBar
@onready var _key: Label = %Key
@onready var _hint_text: Label = %HintText
@onready var _bottom_bar: Node = %BottomBar

var topics: Array = []
var index := 0


func _ready() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_FILE))
	topics = data.get("topics", []) if data is Dictionary else []
	_bottom_bar.set_default_hint("Use the arrow keys or the left stick to choose a topic.")
	_bottom_bar.set_actions([{"key": "LS", "label": "Select"}, {"key": "B", "label": "Close"}])
	show_topic(0)
	grab_focus.call_deferred()


func show_topic(i: int) -> void:
	if topics.is_empty():
		return
	index = clampi(i, 0, topics.size() - 1)
	var topic: Dictionary = topics[index]
	_title.text = topic.get("title", "")
	_body.text = topic.get("text", "")
	var image: String = topic.get("image", "")
	_shot.texture = load(image) if ResourceLoader.exists(image) else null
	_shot_frame.visible = _shot.texture != null
	_key.text = topic.get("key", "")
	_hint_text.text = topic.get("hint", "")
	_hint_bar.visible = not _key.text.is_empty()


func _gui_input(event: InputEvent) -> void:
	_handle(event)


func _unhandled_input(event: InputEvent) -> void:
	_handle(event)


func _handle(event: InputEvent) -> void:
	var step := 0
	if event.is_action_pressed(&"ui_cancel"):
		cancelled.emit()
	elif event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_left") \
			or event.is_action_pressed(&"menu_prev_tab"):
		step = -1
	elif event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"ui_right") \
			or event.is_action_pressed(&"menu_next_tab"):
		step = 1
	else:
		return
	if step != 0:
		show_topic(index + step)
	accept_event()
	get_viewport().set_input_as_handled()
