extends VBoxContainer

## Кнопки нових очок на HUD (D742; Sapega: «може кнопку як в Діабло 2?»). Поки в героя є невитрачені очки навичок —
## світиться «Нові вміння», поки є очки атрибутів — «Нові атрибути». Клік або клавіша на кнопці (open_skills_tab /
## open_status_tab: K / C, на геймпаді хрестовина ліворуч — перша вкладка, що чекає; клік — коли курсор показано Alt,
## як і всюди в грі, D417) відкриває Game Menu одразу на
## Skills або Status. Витратив — кнопка зникає. Кнопки немає, поки вкладку не відкрито сюжетом (game_menu.tscn,
## metadata/unlock_flag), і на час діалогу, як і підказок; кат-сцена ховає весь UICanvas сама (Cutscene).

## Сцена меню читається load() під час гри, не preload: preload сцени меню під час компіляції скрипта — це B149.
const GAME_MENU_SCENE := "res://SampleProject/Scenes/Menus/Game/game_menu.tscn"
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
## Прапорці вкладок читаються з game_menu.tscn, а це вся Game Menu: синхронний load() тут компілював її на старті
## гри (~0,6 с під чорним, perf-check). Кнопки зʼявляються, коли меню довантажить у фоні SceneWarmer.
func _connect_game() -> void:
	Game.get_singleton().quest_flag_changed.connect(func(_id: String, _value: Variant) -> void: refresh())
	while not ResourceLoader.has_cached(GAME_MENU_SCENE):
		await get_tree().process_frame
	visible = true
	refresh()


## Скільки очок кожна кнопка показує зараз: 0 — кнопки немає.
func skill_points() -> int:
	return ServiceLocator.get_skill_manager().get_job_points() if is_tab_unlocked("Skills") else 0


func attribute_points() -> int:
	return ServiceLocator.get_attribute_manager().get_unspent() if is_tab_unlocked("Status") else 0


## Чи відкрита сюжетом вкладка [param tab_name]: metadata/unlock_flag її кнопки в game_menu.tscn (D151) — з SceneState,
## без створення меню; правило те саме, що в game_menu._lock_tabs. Прапорці читаються один раз.
static func is_tab_unlocked(tab_name: String) -> bool:
	var flags := _tab_unlock_flags()
	assert(flags.has(tab_name), "HudNewPoints: no tab '%s' in the game menu" % tab_name)
	return flags[tab_name] == "" or bool(Game.get_singleton().get_quest_flag(flags[tab_name]))


static var _flags_cache: Dictionary = {}


## Вкладка → прапорець, що її відкриває ("" — відкрита завжди), з game_menu.tscn.
static func _tab_unlock_flags() -> Dictionary:
	if _flags_cache.is_empty():
		var state := (load(GAME_MENU_SCENE) as PackedScene).get_state()
		for node in state.get_node_count():
			var props := {}
			for i in state.get_node_property_count(node):
				props[state.get_node_property_name(node, i)] = state.get_node_property_value(node, i)
			if props.has("metadata/tab"):
				_flags_cache[props["metadata/tab"]] = String(props.get("metadata/unlock_flag", ""))
	return _flags_cache


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
