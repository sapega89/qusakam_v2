extends ManagerBase
class_name GameFlow

## 🎭 GameFlow - Менеджер глобального прогресу демо-версії
## Керує переходами між ключовими ігровими зонами та станом сюжету.
## Згідно з ЕТАПОМ 3: КРОК 1

enum StoryState {
	CANYON,      # Початок, перший бій, медитація
	VILLAGE,     # Викрадення, битва з бандитом, лікування
	DESERT_ROAD, # Циклічні бої на дорозі
	CITY_GATES,  # Ворота міста, фінальна битва перед лабою
	LABORATORY,  # Лабораторія, компаньйони, бос
	LAB_OUTSIDE, # Вихід, фінал демо
	DEMO_END     # Екран завершення
}

@export var current_state: StoryState = StoryState.CANYON:
	set(val):
		current_state = val
		_on_state_changed(val)

signal state_changed(new_state: StoryState)

func _initialize() -> void:
	print("🎭 GameFlow: Initialized at state ", StoryState.keys()[current_state])

## Прапорці квестів поточної гри. GameFlow живе в autoload GameManager і довше за Game:
## без запущеної гри прапорців немає — журнал показує стан нової гри (не запасний шлях).
func _quest_flags() -> Dictionary:
	var game := Game.get_singleton()
	return game.get_quest_flags() if game else {}


## Етап → підетапи (D120): дані в story.json, стан підетапу — зі збережених
## прапорців квестів (FlagsModule). Тож окремого стану сюжету в сейві не треба.
const STORY_FILE := "res://SampleProject/Resources/Data/story.json"
const LocationDB := preload("res://SampleProject/Scripts/Systems/LocationDB.gd")
var _stages: Array = []


func _load_stages() -> Array:
	if _stages.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORY_FILE))
		if data is Dictionary:
			_stages = data.get("stages", [])
		else:
			push_error("GameFlow: cannot read %s" % STORY_FILE)
	return _stages


## Підетапи етапу з позначкою done / current / locked: поточний — перший
## непройдений, усі після нього закриті. Підетап пройдено разом з його останньою ціллю.
func _zone_states(stage: Dictionary) -> Array:
	var flags := _quest_flags()
	var out: Array = []
	var current_found := false
	for zone in stage.zones:
		var state := "locked"
		if flags.get(zone.objectives.back().flag, false):
			state = "done"
		elif not current_found:
			state = "current"
			current_found = true
		var row: Dictionary = zone.duplicate()
		row.state = state
		out.append(row)
	return out


## Записи для журналу: етап, його підетапи і жива ціль під поточним (D120).
## Формат приймає journal_component.set_entries().
func journal_entries() -> Array:
	var flags := _quest_flags()
	var entries: Array = []
	for stage in _load_stages():
		var zones: Array = []
		var active := false
		for zone in _zone_states(stage):
			zones.append({"id": zone.id, "title": zone.title, "state": zone.state,
				"chronicle": _chronicle(zone, flags), "objectives": _objectives(zone, flags)})
			active = active or zone.state == "current"
		entries.append({
			"id": stage.id,
			"title": stage.title,
			"state": "active" if active else "complete",
			"zones": zones,
		})
	return entries


## Цілі підетапу, видимі в журналі: виконані лишаються, наступна — поточна,
## далі нічого (D125). У пройденому підетапі всі виконані; у закритому — жодної.
func _objectives(zone: Dictionary, flags: Dictionary) -> Array:
	if zone.state == "locked":
		return []
	var out: Array = []
	for objective in zone.objectives:
		var done: bool = zone.state == "done" or flags.get(objective.flag, false)
		out.append({"text": objective.text, "state": "done" if done else "current"})
		if not done:
			break
	return out


## Хроніка підетапу: рядки тих кроків, чиї прапорці вже виставлено, у порядку сюжету.
func _chronicle(zone: Dictionary, flags: Dictionary) -> Array:
	var lines: Array = []
	for beat in zone.get("chronicle", []):
		if flags.get(beat.flag, false):
			lines.append(beat.text)
	return lines


## Назва поточної зони журналу (перша непройдена) — підпис рядка основного квесту в списку Quest (D188).
func current_zone_title() -> String:
	for stage in _load_stages():
		for zone in _zone_states(stage):
			if zone.state == "current":
				return zone.title
	return ""


## Назва локації для картки сейва (D618, замість зон журналу D133): локація кімнати з locations.json.
## Повертає ключ (англійську назву, D121) — Label картки перекладає його мовою гри й після зміни мови.
func location_title(room_scene_path: String) -> String:
	return LocationDB.location(LocationDB.of_scene(room_scene_path)).name


## StoryState виводиться з тих самих прапорців, а не штовхається зі сцени (B43).
func sync_story_state() -> void:
	var state := StoryState.DEMO_END
	for stage in _load_stages():
		for zone in _zone_states(stage):
			if zone.state == "current":
				state = StoryState[zone.story_state]
				break
		if state != StoryState.DEMO_END:
			break
	if state != current_state:
		current_state = state


func _on_state_changed(new_state: StoryState) -> void:
	state_changed.emit(new_state)

	if new_state == StoryState.DEMO_END:
		_show_demo_end_screen()

func _show_demo_end_screen() -> void:
	"""Жорстка зупинка демо (КРОК 5)"""
	DebugLogger.info("🎭 GameFlow: DEMO STOP REACHED.", "Story")
	# Логіка показу екрану завершення демо
	var menu_manager = ServiceLocator.get_menu_manager()
	if menu_manager:
		# Припустимо, у MenuManager є такий метод або ми його додамо
		# menu_manager.show_demo_end() 
		pass
