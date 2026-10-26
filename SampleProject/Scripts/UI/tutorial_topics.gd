extends RefCounted

## Теми туторіалу (D126, D289) — Resources/Data/tutorial.json. Загальні теми є завжди; тема підказки
## (hint_topic) з'являється в списку, щойно гравець її побачив (player_state.seen_tutorials, у сейві).
## Тексти й кнопка-бейдж — з {дія}, назви кнопок підставляє InputGlyphs за пристроєм.

const DATA_FILE := "res://SampleProject/Resources/Data/tutorial.json"
const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")


static func all() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA_FILE)).topics


static func seen() -> Array:
	return ServiceLocator.get_game_manager().player_state.seen_tutorials


## D727 (Sapega, 2026-10-26: «тільки один раз за гру це вискакує, коли перший раз зустрічається»): тема — раз за
## проходження. Запис один — seen_tutorials у сейві разом із playthrough_id (його дає нова гра). Завантаження сейва
## того самого проходження (смерть → останній сейв, Load ранішого сейва, новий запуск гри) не повертає вже бачених
## тем: Game бере знімок до reset_player_state() і після завантаження зводить його й записи інших слотів того самого
## проходження з тим, що прочитано (carry_over). Нова гра — новий playthrough_id, чистий запис.
static func snapshot() -> Dictionary:
	var state: Dictionary = ServiceLocator.get_game_manager().player_state
	return {"playthrough_id": state.playthrough_id, "seen": state.seen_tutorials.duplicate()}


static func carry_over(before: Dictionary) -> void:
	var state: Dictionary = ServiceLocator.get_game_manager().player_state
	var also: Array = SaveSystem.seen_tutorials_of(state.playthrough_id)
	if before.playthrough_id == state.playthrough_id:
		also.append_array(before.seen)
	for id in also:
		if not id in state.seen_tutorials:
			state.seen_tutorials.append(id)


static func is_seen(id: String) -> bool:
	return id in seen()


## Позначити тему баченою. Повертає true, якщо це вперше в цьому проходженні (D727).
static func mark_seen(id: String) -> bool:
	assert(all().any(func(t: Dictionary) -> bool: return t.id == id), "TutorialTopics: unknown topic %s" % id)
	if is_seen(id):
		return false
	seen().append(id)
	return true


## Те, що показує список Tutorial і листає вікно: загальні теми, потім побачені підказки в порядку файлу.
static func available() -> Array:
	return all().filter(func(t: Dictionary) -> bool: return not t.get("hint_topic", false) or is_seen(t.id))


## Тема з підставленими назвами кнопок для поточного пристрою.
static func resolved(topic: Dictionary) -> Dictionary:
	var out := topic.duplicate()
	# Текст і підпис — мовою гри (ключ — англійський текст з tutorial.json, BACKLOG 31); key — назва кнопки.
	for field in ["text", "hint"]:
		out[field] = InputGlyphs.resolve(TranslationServer.translate(String(topic.get(field, ""))))
	out.key = InputGlyphs.resolve(String(topic.get("key", "")))
	return out


static func by_id(id: String) -> Dictionary:
	return all().filter(func(t: Dictionary) -> bool: return t.id == id)[0]
