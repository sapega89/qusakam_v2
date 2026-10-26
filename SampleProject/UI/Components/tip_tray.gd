extends VBoxContainer

## Єдина доставка підказок гри (D732, D744): кожна підказка — тема туторіалу (Resources/Data/tutorial.json,
## hint_topic), і кожна йде сюди, через show_tip(). Вікна-плашки з текстом підказки на екрані більше немає (Sapega,
## 2026-10-26: «вікно підказки прибрати взагалі, перенести все в туторіали»).
## Як у Lineage II (критик раунду 13): біля лівого краю екрана зʼявляється «?», що світиться; кілька — стосом,
## найстаріший угорі. Гра не стоїть. Гравець відкриває тему, коли схоче: клік по «?» або open_tip (клавіша на верхньому
## значку) — вікно туторіалу (tutorial_menu.tscn у ModalLayer) на ній, на паузі, і «?» зникає.
## Одна брама для всіх підказок (D746, Sapega: «якщо вимкнені підказки, то підказок не має бути»): Settings → Game → Hints
## Off — show_tip() нічого не показує й не позначає; вимкнули посеред гри — clear() прибирає «?», що чекали.
## Кожна тема — раз за проходження, за першої нагоди (D745; seen_tutorials у сейві, TutorialTopics.mark_seen).
## Значок — копія шаблону %TipIcon зі сцени (D117), стиль — KeyBadge з теми, як бейдж кнопки у вікні туторіалу.

signal opened(id: String)

const TutorialTopics = preload("res://SampleProject/Scripts/UI/tutorial_topics.gd")
const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")
const TopicWindow = preload("res://SampleProject/Scenes/Menus/Game/tutorial_menu.tscn")
## Перша тема гри — рух, за стільки секунд після входу в гру.
const MOVEMENT_DELAY := 2.0

@onready var _template: Control = %TipIcon

## Теми, що чекають, у порядку появи.
var _ids: Array[String] = []
## Вікно відкрили ми — ми ж і знімаємо паузу.
var _window_open := false


func _ready() -> void:
	add_theme_constant_override(&"separation", UITokens.TIP_TRAY_GAP)
	_template.visible = false
	_template.get_node(^"Badge").custom_minimum_size = Vector2.ONE * UITokens.TIP_ICON_SIZE
	# Відкладено: вікно не має отримати ту саму подію (D-pad left — ще й «попередня тема» у вікні).
	opened.connect(open_tip, CONNECT_DEFERRED)
	await get_tree().create_timer(MOVEMENT_DELAY).timeout
	show_tip("movement")


static func hints_on() -> bool:
	return SaveSystem.settings_module.settings.hints


## Брама всіх підказок: вимкнено — нічого; тему вже бачили в цьому проходженні — нічого; інакше «?».
func show_tip(id: String) -> void:
	if not hints_on() or not TutorialTopics.mark_seen(id):
		return
	_add(id)


## Дію, до якої кличе тема, уже виконано (вдягнув подарунок, вивчив Длань, покликав охоронця) — її «?» більше не чекає.
func retire(id: String) -> void:
	if id in _ids:
		_remove(id)


## Підказки вимкнули (options_component через групу tip_tray) — усі «?», що чекали, зникають.
func clear() -> void:
	for id in _ids.duplicate():
		_remove(id)


func ids() -> Array[String]:
	return _ids


func has(id: String) -> bool:
	return id in _ids


func icon_of(id: String) -> Control:
	return get_node(NodePath(id))


func _add(id: String) -> void:
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


func _remove(id: String) -> void:
	_ids.erase(id)
	var tip := icon_of(id)
	remove_child(tip)
	tip.queue_free()
	_refresh_keys()


## Гравець відкрив «?» (клік чи open_tip): вікно туторіалу на цій темі, гра на паузі, доки його не закрили.
## Поверх діалогу, модалки чи меню вікно не відкривається — «?» чекає далі.
func open_tip(id: String) -> void:
	if _window_open or not _game_is_free() or not id in _ids:
		return
	_remove(id)
	var layer: ModalLayer = ServiceLocator.get_ui_manager().get_modal_layer()
	layer.show_custom_modal(TopicWindow)
	layer.active_modal.open_id(id)
	_window_open = true
	get_tree().paused = true
	layer.modal_closed.connect(func(_result: String) -> void:
		get_tree().paused = false
		_window_open = false, CONNECT_ONE_SHOT)


## Вікно не перебиває діалог, модалку чи меню (усі вони або активні, або ставлять гру на паузу).
func _game_is_free() -> bool:
	return not get_tree().paused \
			and ServiceLocator.get_ui_manager().get_modal_layer().active_modal == null \
			and not ServiceLocator.get_dialogue_manager().is_dialogue_active()


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
