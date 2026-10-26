extends Control
class_name TutorialHintDisplay

## Підказки (BACKLOG 12, D289, D718). Кожна підказка — тема туторіалу (Resources/Data/tutorial.json, hint_topic);
## тема лишається в списку Tutorial (player_state.seen_tutorials).
## D718 (як у Lineage II): уперше тема не відкриває вікно на паузі, а кладе «?» у TipTray біля лівого краю — гра йде;
## гравець відкриває тему кліком чи open_tip, коли схоче, і тоді вікно туторіалу (tutorial_menu.tscn у ModalLayer) — на паузі.
## Лише перші основні керування (ESSENTIAL: рух, удар) показуються одразу, коротко — плашкою, щойно гра вільна.
## Settings → Game → Tutorial Windows: Off — замість «?» коротка плашка, як раніше.
## Повтор (force) — «?» знову (Off — плашка); «висячі» підказки (sticky: Длань, охоронець, подарунок діда) — плашка,
## доки дію не виконано: це заклик зробити щось зараз. Назви кнопок — за пристроєм (InputGlyphs).

const TutorialTopics = preload("res://SampleProject/Scripts/UI/tutorial_topics.gd")
const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")
const TopicWindow = preload("res://SampleProject/Scenes/Menus/Game/tutorial_menu.tscn")
## D718: лише ці теми першого разу — плашкою, без «?».
const ESSENTIAL: Array[String] = ["movement", "attack"]

@onready var hint_label: Label = $Banner/Panel/MarginContainer/HintLabel
@onready var panel: PanelContainer = $Banner/Panel
@onready var tip_tray: VBoxContainer = %TipTray
@onready var _banner: Control = $Banner

var current_hint: String = ""
var is_showing: bool = false
var display_duration: float = 4.0
## Місце плашки зі сцени — угорі по центру під панеллю квесту (B151: унизу вона лягала на героя); анімація зсуває
## шар плашки від нього, не саму плашку: плашка росте вниз під текст (D474), і її власні відступи міняються з висотою.
var _rest_y: float
var _refit_queued := false
## Основні теми (ESSENTIAL), що чекають на вільну гру, щоб показатись плашкою.
var _pending: Array[String] = []
## Вікно відкрили ми — ми ж і знімаємо паузу.
var _window_open := false

func _ready() -> void:
	_banner.visible = false
	is_showing = false
	_rest_y = _banner.position.y
	var margins: MarginContainer = $Banner/Panel/MarginContainer
	hint_label.custom_minimum_size.x = UITokens.HINT_BANNER_WIDTH \
			- margins.get_theme_constant(&"margin_left") - margins.get_theme_constant(&"margin_right")
	hint_label.minimum_size_changed.connect(_queue_refit)
	# Відкладено: вікно не має отримати ту саму подію (D-pad left — ще й «попередня тема» у вікні).
	tip_tray.opened.connect(open_tip, CONNECT_DEFERRED)
	# Перша тема гри — рух, за дві секунди після входу (плашка дочекається кінця вступного діалогу).
	await get_tree().create_timer(2.0).timeout
	show_hint("movement")


func _input(event: InputEvent) -> void:
	if InputGlyphs.note_event(event) and is_showing:
		_set_text(current_hint)


## Перша поява теми — «?» у TipTray (основна тема чи вимкнені вікна — плашка); повтор — лише з [param force].
## [param sticky] — плашка не ховається за таймером: її прибирає force_hide(), коли дію виконано.
func show_hint(hint_key: String, force: bool = false, sticky: bool = false) -> void:
	var first := TutorialTopics.mark_seen(hint_key)
	if not first and not force:
		return
	if sticky or not SaveSystem.settings_module.settings.tutorial_windows:
		_show_banner(hint_key, force, sticky)
	elif first and hint_key in ESSENTIAL:
		_pending.append(hint_key)
	else:
		tip_tray.add(hint_key)


func _process(_delta: float) -> void:
	if _pending.is_empty() or not _game_is_free():
		return
	_show_banner(_pending.pop_front(), true, false)


## Вікно не перебиває діалог, модалку чи меню (усі вони або активні, або ставлять гру на паузу).
func _game_is_free() -> bool:
	return not get_tree().paused \
			and ServiceLocator.get_ui_manager().get_modal_layer().active_modal == null \
			and not ServiceLocator.get_dialogue_manager().is_dialogue_active()


## Гравець відкрив «?» (клік чи open_tip): вікно туторіалу на цій темі, гра на паузі, доки його не закрили.
## Поверх діалогу, модалки чи меню вікно не відкривається — «?» чекає далі.
func open_tip(hint_key: String) -> void:
	if _window_open or not _game_is_free():
		return
	tip_tray.remove(hint_key)
	var layer: ModalLayer = ServiceLocator.get_ui_manager().get_modal_layer()
	layer.show_custom_modal(TopicWindow)
	layer.active_modal.open_id(hint_key)
	_window_open = true
	get_tree().paused = true
	layer.modal_closed.connect(func(_result: String) -> void:
		get_tree().paused = false
		_window_open = false, CONNECT_ONE_SHOT)


func _show_banner(hint_key: String, force: bool, sticky: bool) -> void:
	if is_showing and not force:
		return
	current_hint = hint_key
	_set_text(hint_key)
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
		_set_text(current_hint)


## Урок тренування — його один рядок (prompt, D719), решта тем — повний текст.
func _set_text(hint_key: String) -> void:
	var topic := TutorialTopics.resolved(TutorialTopics.by_id(hint_key))
	hint_label.text = topic.prompt if topic.prompt != "" else topic.text
	_queue_refit()


## B151 (як B122 у вікні діалогу): текст міняли, поки вузол схований, а Godot не оновлює для схованого вузла
## запамʼятований мінімальний розмір — плашка лишалась висотою попереднього тексту, і довгий (uk) звисав за неї.
## Тож розмір плашки задають відступи, щоразу як міняється текст чи видимість: ширина стала, низ — під текст.
func _queue_refit() -> void:
	if _refit_queued or not is_node_ready():
		return
	_refit_queued = true
	_refit.call_deferred()


func _refit() -> void:
	_refit_queued = false
	var fit := panel.get_combined_minimum_size()
	panel.offset_left = -fit.x / 2.0
	panel.offset_right = fit.x / 2.0
	panel.offset_bottom = panel.offset_top + fit.y

func _animate_in() -> void:
	"""Animates hint sliding in from above"""
	_banner.visible = true
	_queue_refit()
	panel.modulate.a = 0.0
	_banner.position.y = _rest_y - UITokens.HINT_BANNER_SLIDE

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(_banner, "position:y", _rest_y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_out() -> void:
	"""Animates hint sliding out"""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_property(_banner, "position:y", _rest_y - UITokens.HINT_BANNER_SLIDE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	await tween.finished
	_banner.visible = false
	is_showing = false
	current_hint = ""

func force_hide() -> void:
	"""Immediately hides the hint"""
	is_showing = false
	_banner.visible = false
	panel.modulate.a = 0.0
	current_hint = ""
