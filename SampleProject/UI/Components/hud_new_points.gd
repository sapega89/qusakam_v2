extends VBoxContainer

## Кнопки нових очок на HUD (D723; Sapega: «може кнопку як в Діабло 2?»). Поки в героя є невитрачені очки навичок —
## світиться «Нові вміння», поки є очки атрибутів — «Нові атрибути». Клік або клавіша на кнопці (open_skills_tab /
## open_status_tab: K / C, на геймпаді хрестовина ліворуч — перша вкладка, що чекає; клік — коли курсор показано Alt,
## як і всюди в грі, D417) відкриває Game Menu одразу на
## Skills або Status. Витратив — кнопка зникає. Кнопки немає, поки вкладку не відкрито сюжетом (game_menu.tscn,
## metadata/unlock_flag), і на час діалогу, як і підказок; кат-сцена ховає весь UICanvas сама (Cutscene).

const GameMenu = preload("res://SampleProject/Scripts/Menus/Game/game_menu.gd")
const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")

@onready var _skills: Button = %SkillPoints
@onready var _attributes: Button = %AttributePoints


func _ready() -> void:
	_skills.pressed.connect(open_tab.bind("Skills"))
	_attributes.pressed.connect(open_tab.bind("Status"))
	for sig: Signal in [EventBus.job_points_changed, EventBus.attribute_points_changed]:
		sig.connect(func(_current: int, _previous: int) -> void: refresh())
	EventBus.input_device_changed.connect(func(_pad: bool) -> void: refresh())
	# Сигнали діалогу йдуть до того, як DialogueManager перемкне is_dialogue_active(), — дивимось кадром пізніше.
	var dialogue: Node = ServiceLocator.get_dialogue_manager()
	dialogue.dialogue_started.connect(func(_id: String) -> void: refresh.call_deferred())
	dialogue.dialogue_finished.connect(func(_id: String) -> void: refresh.call_deferred())
	ServiceLocator.get_ui_manager().ui_refresh_requested.connect(refresh)
	visible = false
	_connect_game.call_deferred()


## Game стає синглтоном у власному _ready, тобто після HUD, — прапорці квестів слухаємо кадром пізніше.
func _connect_game() -> void:
	Game.get_singleton().quest_flag_changed.connect(func(_id: String, _value: Variant) -> void: refresh())
	visible = true
	refresh()


## Скільки очок кожна кнопка показує зараз: 0 — кнопки немає.
func skill_points() -> int:
	return ServiceLocator.get_skill_manager().get_job_points() if GameMenu.is_tab_unlocked("Skills") else 0


func attribute_points() -> int:
	return ServiceLocator.get_attribute_manager().get_unspent() if GameMenu.is_tab_unlocked("Status") else 0


func refresh() -> void:
	if not visible:
		return
	var talking: bool = ServiceLocator.get_dialogue_manager().is_dialogue_active()
	var skills := 0 if talking else skill_points()
	var attributes := 0 if talking else attribute_points()
	# Хрестовина відкриває першу вкладку, що чекає: її гліф — лише на тій кнопці; клавіатура має по клавіші на кожну.
	var pad := InputGlyphs.using_gamepad
	_skills.show_points(skills, InputGlyphs.label(&"open_skills_tab"))
	_attributes.show_points(attributes, InputGlyphs.label(&"open_status_tab") if not pad or skills == 0 else "")


## Game Menu одразу на вкладці [param tab_name].
func open_tab(tab_name: String) -> void:
	ServiceLocator.get_ui_manager().open_game_menu_on(tab_name)


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	# Хрестовина прив'язана до обох дій: спершу Skills, якщо там чекають очки.
	if event.is_action_pressed(&"open_skills_tab") and _skills.visible:
		open_tab("Skills")
	elif event.is_action_pressed(&"open_status_tab") and _attributes.visible:
		open_tab("Status")
	else:
		return
	get_viewport().set_input_as_handled()
