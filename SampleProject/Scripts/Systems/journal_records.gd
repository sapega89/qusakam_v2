extends RefCounted

## Що Кусакам зустрів (BACKLOG 13, D290, design/journal_codex_plan.md): люди, з якими говорив, і вороги —
## бачені та скільки вбито, і знайдені шматки історії (D583, D606). Живе в player_state.journal (у сейві):
## {"people": [id], "enemies": {kind: kills}, "stories": [id]}.
## Тексти — Resources/Data/journal_people.json і bestiary.json. Записують тригери, не списки:
## DialogueManager (перша літера репліки — мовець), DefaultEnemy (з'явився / загинув).

const PEOPLE_FILE := "res://SampleProject/Resources/Data/journal_people.json"
const BESTIARY_FILE := "res://SampleProject/Resources/Data/bestiary.json"
const STORIES_FILE := "res://SampleProject/Resources/Data/journal_stories.json"


## Автозавантаження — через дерево, а не за іменем: скрипт тягнуть class_name-класи (DefaultEnemy,
## GameDialogueManager), а їх компілюють і до появи автозавантажень (тести --script).
static func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


static func _state() -> Dictionary:
	return _root().get_node("ServiceLocator").get_game_manager().player_state.journal


static func _people_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(PEOPLE_FILE))


## Мовець репліки [param character_id] (id DialogueQuest). Ті, кого кодекс не веде (not_listed), не пишуться.
static func meet_person(character_id: String) -> void:
	var data := _people_data()
	if character_id in data.not_listed or character_id in _state().people:
		return
	assert(data.people.any(func(p: Dictionary) -> bool: return p.id == character_id),
			"JournalRecords: %s speaks but has no entry in journal_people.json (add one or list it in not_listed)" % character_id)
	_state().people.append(character_id)


static func meet_enemy(kind: String) -> void:
	if not _state().enemies.has(kind):
		_state().enemies[kind] = 0


static func kill_enemy(kind: String) -> void:
	meet_enemy(kind)
	_state().enemies[kind] += 1


## Зустрінуті люди в порядку зустрічі: {id, name і portrait (як у вікні діалогу, D321; без портрета — null), title, text}.
static func people() -> Array:
	var data := _people_data()
	var by_id := {}
	for p: Dictionary in data.people:
		by_id[p.id] = p
	var out: Array = []
	for id: String in _state().people:
		if id in data.not_listed:  # D440: кодекс не веде перехожих, навіть якщо їх уже записали раніше
			continue
		var entry: Dictionary = by_id[id].duplicate()
		var character: Resource = _root().get_node("DialogueQuest").CharacterDB.get_character_from_id(id)
		entry.name = character.character_name
		entry.portrait = character.portrait
		out.append(entry)
	return out


## Бачені вороги в порядку bestiary.json: {kind, name, text, kills}.
static func enemies() -> Array:
	var out: Array = []
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BESTIARY_FILE))
	for e: Dictionary in data.enemies:
		if _state().enemies.has(e.kind):
			var entry := e.duplicate()
			entry.kills = int(_state().enemies[e.kind])
			out.append(entry)
	return out


static func _stories_data() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string(STORIES_FILE)).stories


## Прочитаний шматок історії [param story_id] (StoryNote); id без запису в journal_stories.json — помилка даних.
static func find_story(story_id: String) -> void:
	assert(_stories_data().any(func(s: Dictionary) -> bool: return s.id == story_id),
			"JournalRecords: story %s is not in journal_stories.json" % story_id)
	if not story_id in _state().stories:
		_state().stories.append(story_id)


## Запис шматка історії: {id, title, text, draft} (англійські ключі).
static func story(story_id: String) -> Dictionary:
	for entry: Dictionary in _stories_data():
		if entry.id == story_id:
			return entry
	assert(false, "JournalRecords: story %s is not in journal_stories.json" % story_id)
	return {}


## Знайдені шматки історії в порядку знахідок.
static func stories() -> Array:
	return _state().stories.map(func(id: String) -> Dictionary: return story(id))
