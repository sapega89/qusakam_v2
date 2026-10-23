extends Control
class_name TutorialHintDisplay

## Підказки (BACKLOG 12, D289). Кожна підказка — тема туторіалу (Resources/Data/tutorial.json, hint_topic):
## уперше вона відкриває вікно туторіалу (tutorial_menu.tscn у ModalLayer, гра на паузі), щойно гра вільна —
## без діалогу, модалки й меню; так нічого не пропускається. Тема лишається в списку Tutorial (player_state.seen_tutorials).
## Settings → Game → Tutorial Windows: Off — замість вікна коротка плашка внизу, як раніше.
## Повтор (force) і «висячі» підказки (sticky: Длань, охоронець, подарунок діда) — плашка; sticky — після вікна.
## Назви кнопок — за пристроєм (InputGlyphs).

const TutorialTopics = preload("res://SampleProject/Scripts/UI/tutorial_topics.gd")
const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")
const TopicWindow = preload("res://SampleProject/Scenes/Menus/Game/tutorial_menu.tscn")

@onready var hint_label: Label = $Panel/MarginContainer/HintLabel
@onready var panel: PanelContainer = $Panel

var current_hint: String = ""
var is_showing: bool = false
var display_duration: float = 4.0
## Місце плашки зі сцени (над панеллю навичок); анімація зсуває від нього, а не від нуля — інакше плашка лягала на панель.
## Зсуваємо весь вузол, не плашку: плашка росте вгору під текст (D474), і її власна позиція міняється з висотою.
var _rest_y: float
## Теми, що чекають на вільну гру, щоб відкрити вікно: [id, sticky].
var _pending: Array = []
## Вікно відкрили ми — ми ж і знімаємо паузу.
var _window_open := false

func _ready() -> void:
	visible = false
	is_showing = false
	_rest_y = position.y
	# Перша тема гри — рух, за дві секунди після входу (вікно дочекається кінця вступного діалогу).
	await get_tree().create_timer(2.0).timeout
	show_hint("movement")


func _input(event: InputEvent) -> void:
	if InputGlyphs.note_event(event) and is_showing:
		hint_label.text = TutorialTopics.resolved(TutorialTopics.by_id(current_hint)).text


## Перша поява теми — вікно (або плашка, якщо вікна вимкнено); повтор — лише з [param force], плашкою.
## [param sticky] — плашка не ховається за таймером: її прибирає force_hide(), коли дію виконано.
func show_hint(hint_key: String, force: bool = false, sticky: bool = false) -> void:
	var first := TutorialTopics.mark_seen(hint_key)
	if first and SaveSystem.settings_module.settings.tutorial_windows:
		_pending.append([hint_key, sticky])
		return
	if not first and not force:
		return
	_show_banner(hint_key, force, sticky)


func _process(_delta: float) -> void:
	if _pending.is_empty() or _window_open or not _game_is_free():
		return
	var entry: Array = _pending.pop_front()
	_open_window(entry[0], entry[1])


## Вікно не перебиває діалог, модалку чи меню (усі вони або активні, або ставлять гру на паузу).
func _game_is_free() -> bool:
	return not get_tree().paused 			and ServiceLocator.get_ui_manager().get_modal_layer().active_modal == null 			and not ServiceLocator.get_dialogue_manager().is_dialogue_active()


func _open_window(hint_key: String, sticky: bool) -> void:
	var layer: ModalLayer = ServiceLocator.get_ui_manager().get_modal_layer()
	layer.show_custom_modal(TopicWindow)
	layer.active_modal.open_id(hint_key)
	_window_open = true
	get_tree().paused = true
	layer.modal_closed.connect(func(_result: String) -> void:
		get_tree().paused = false
		_window_open = false
		if sticky:
			_show_banner(hint_key, true, true), CONNECT_ONE_SHOT)


func _show_banner(hint_key: String, force: bool, sticky: bool) -> void:
	if is_showing and not force:
		return
	current_hint = hint_key
	hint_label.text = TutorialTopics.resolved(TutorialTopics.by_id(hint_key)).text
	is_showing = true
	_animate_in()
	if sticky:
		return
	await get_tree().create_timer(display_duration).timeout
	if is_showing and current_hint == hint_key:
		_animate_out()

## Текст підказки складається один раз у _show_banner; при зміні мови показану підказку перекладаємо заново.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_showing:
		hint_label.text = TutorialTopics.resolved(TutorialTopics.by_id(current_hint)).text

func _animate_in() -> void:
	"""Animates hint sliding in from bottom"""
	visible = true
	panel.modulate.a = 0.0
	position.y = _rest_y + 50

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "position:y", _rest_y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_out() -> void:
	"""Animates hint sliding out"""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_property(self, "position:y", _rest_y + 50, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	await tween.finished
	visible = false
	is_showing = false
	current_hint = ""

func force_hide() -> void:
	"""Immediately hides the hint"""
	is_showing = false
	visible = false
	panel.modulate.a = 0.0
	current_hint = ""
