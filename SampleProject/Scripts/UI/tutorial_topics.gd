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


static func is_seen(id: String) -> bool:
	return id in seen()


## Позначити тему баченою. Повертає true, якщо це вперше.
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
	# prompt — один рядок уроку тренування на плашці (D733); у вікні й списку — повний text.
	for field in ["text", "hint", "prompt"]:
		out[field] = InputGlyphs.resolve(TranslationServer.translate(String(topic.get(field, ""))))
	out.key = InputGlyphs.resolve(String(topic.get("key", "")))
	return out


static func by_id(id: String) -> Dictionary:
	return all().filter(func(t: Dictionary) -> bool: return t.id == id)[0]
