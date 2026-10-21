extends Control

## Туторіал — одне повноекранне вікно поверх Game Menu (D126, Figma tutorial-content
## 135:1260). Відкривається через ModalLayer.show_custom_modal(), тож гра не
## вивантажується (B2). Теми — Resources/Data/tutorial.json, тільки про те, що є в грі.
## ↑/↓ (←/→, LB/RB) — сусідня тема; B / Esc — закрити.

## Ті самі теми, що й у списку (загальні + побачені підказки, D289); підказка в грі відкриває вікно на своїй темі.
## Назви кнопок — за пристроєм (клавіатура / геймпад), міняються, щойно гравець змінив пристрій.

## ModalLayer закриває вікно за цим сигналом (як Misc).
signal cancelled

const TutorialTopics = preload("res://SampleProject/Scripts/UI/tutorial_topics.gd")
const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")
## Кадри руху (BACKLOG 28, D-28e): тема з "frames" крутить 0.png, 1.png… з цієї теки, записані з гри
## (capture_tutorial_frames.gd); вікно на паузі гри, тож кадри гортає _process цього вікна (ModalLayer — завжди).
const FRAMES_DIR := "res://SampleProject/Assets/UI/Tutorial/%s/%d.png"
const FRAME_TIME := 0.1

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
var frames: Array[Texture2D] = []
var _frame := 0
var _frame_left := 0.0


func _ready() -> void:
	topics = TutorialTopics.available()
	_bottom_bar.set_default_hint("Use the arrow keys or the left stick to choose a topic.")
	_bottom_bar.set_actions([{"key": "LS", "label": "Select"}, {"key": "B", "label": "Close"}])
	show_topic(0)
	grab_focus.call_deferred()


func show_topic(i: int) -> void:
	if topics.is_empty():
		return
	index = clampi(i, 0, topics.size() - 1)
	var topic: Dictionary = TutorialTopics.resolved(topics[index])
	_title.text = topic.get("title", "")
	_body.text = topic.get("text", "")
	var image: String = topic.get("image", "")
	frames = load_frames(topic.get("frames", ""))
	_frame = 0
	_frame_left = FRAME_TIME
	_shot.texture = frames[0] if not frames.is_empty() else (load(image) if ResourceLoader.exists(image) else null)
	_shot_frame.visible = _shot.texture != null
	_key.text = topic.get("key", "")
	_hint_text.text = topic.get("hint", "")
	_hint_bar.visible = not _key.text.is_empty()


static func load_frames(set_name: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	while set_name != "" and ResourceLoader.exists(FRAMES_DIR % [set_name, out.size()]):
		out.append(load(FRAMES_DIR % [set_name, out.size()]))
	return out


func _process(delta: float) -> void:
	if frames.size() < 2:
		return
	_frame_left -= delta
	if _frame_left <= 0.0:
		_frame_left += FRAME_TIME
		_frame = (_frame + 1) % frames.size()
		_shot.texture = frames[_frame]


## Підказка в грі (D289): вікно на темі [param id]; нижня панель нагадує, де вимкнути такі вікна.
func open_id(id: String) -> void:
	show_topic(topics.find(TutorialTopics.by_id(id)))
	_bottom_bar.set_default_hint("Tutorial windows can be turned off in Settings → Game.")


func _input(event: InputEvent) -> void:
	if InputGlyphs.note_event(event):
		show_topic(index)


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
