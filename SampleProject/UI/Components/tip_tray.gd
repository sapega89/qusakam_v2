extends VBoxContainer

## Підказки як у Lineage II (D718, критик раунду 13: «Дуже багато туторіалів вискакує… може питаннями, як в L2?»).
## Нова тема туторіалу не відкриває вікно на паузі: біля лівого краю екрана зʼявляється «?», що світиться; кілька —
## стосом, найстаріший угорі. Гра не стоїть. Гравець відкриває тему, коли схоче: клік по «?» або open_tip (клавіша
## на верхньому значку) — TutorialHintDisplay відкриває вікно туторіалу на ній, і «?» зникає.
## Значок — копія шаблону %TipIcon зі сцени (D117), стиль — KeyBadge з теми, як бейдж кнопки у вікні туторіалу.

signal opened(id: String)

const TutorialTopics = preload("res://SampleProject/Scripts/UI/tutorial_topics.gd")
const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")

@onready var _template: Control = %TipIcon

## Теми, що чекають, у порядку появи.
var _ids: Array[String] = []


func _ready() -> void:
	add_theme_constant_override(&"separation", UITokens.TIP_TRAY_GAP)
	_template.visible = false
	_template.get_node(^"Badge").custom_minimum_size = Vector2.ONE * UITokens.TIP_ICON_SIZE


func ids() -> Array[String]:
	return _ids


func has(id: String) -> bool:
	return id in _ids


func add(id: String) -> void:
	if id in _ids:
		return
	_ids.append(id)
	var tip: Control = _template.duplicate()
	tip.unique_name_in_owner = false
	tip.name = id
	tip.visible = true
	tip.tooltip_text = tr(String(TutorialTopics.by_id(id).title))
	tip.gui_input.connect(_on_icon_input.bind(id))
	add_child(tip)
	_glow(tip.get_node(^"Badge"))
	_refresh_keys()


func remove(id: String) -> void:
	if not id in _ids:
		return
	_ids.erase(id)
	var tip := icon_of(id)
	remove_child(tip)
	tip.queue_free()
	_refresh_keys()


func icon_of(id: String) -> Control:
	return get_node(NodePath(id))


## Пульс світіння: modulate значка туди й назад, доки значок живий.
func _glow(badge: Control) -> void:
	var tween := badge.create_tween().set_loops()
	tween.tween_property(badge, "modulate", UITokens.TIP_GLOW, UITokens.TIP_GLOW_TIME).set_trans(Tween.TRANS_SINE)
	tween.tween_property(badge, "modulate", Color.WHITE, UITokens.TIP_GLOW_TIME).set_trans(Tween.TRANS_SINE)


## Клавіша open_tip відкриває найстарішу тему — її назва лише на верхньому значку.
func _refresh_keys() -> void:
	for id in _ids:
		var key: Label = icon_of(id).get_node(^"Key")
		key.text = InputGlyphs.badge(&"open_tip")
		key.visible = id == _ids[0]


func _on_icon_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()  # клік по «?» — не удар (attack теж на лівій кнопці миші)
		opened.emit(id)


func _unhandled_input(event: InputEvent) -> void:
	if not _ids.is_empty() and event.is_action_pressed(&"open_tip"):
		get_viewport().set_input_as_handled()
		opened.emit(_ids[0])


func _input(event: InputEvent) -> void:
	if InputGlyphs.note_event(event) and not _ids.is_empty():
		_refresh_keys()
