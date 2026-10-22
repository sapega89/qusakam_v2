extends RefCounted
class_name DialoguePaths

## Файл розмови мовою гри (BACKLOG 31, design/localization_plan.md §4).
## Українська — dialogue_quest/<id>.dqd (джерело: Sapega пише українською), англійська — її близнюк
## dialogue_quest/en/<id>.dqd з тими самими рядками й мовцями. Сцени й тригери знають лише український шлях:
## він же — id розмови в dialogue_started / dialogue_finished, тож слухачі кінця розмови не залежать від мови.
## Мову бере лише читання файлу: DialogueManager.start_dialogue() і DqdReader.lines().

const ROOT := "res://dialogue_quest/"
const EN_DIR := "en/"


## Шлях до файлу [param path] (український шлях розмови) для поточної мови.
static func localized(path: String) -> String:
	if TranslationServer.get_locale() == "uk":
		return path
	assert(path.begins_with(ROOT) and not path.begins_with(ROOT + EN_DIR), "DialoguePaths: %s is not a source dialogue" % path)
	var twin := ROOT + EN_DIR + path.trim_prefix(ROOT)
	assert(FileAccess.file_exists(twin), "DialoguePaths: %s has no English twin %s" % [path, twin])
	return twin
