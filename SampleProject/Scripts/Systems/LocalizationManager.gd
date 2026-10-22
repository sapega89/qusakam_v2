## Менеджер локалізації (BACKLOG 31, design/localization_plan.md)
## Реєструє переклади і перемикає мову.
##
## Ключ перекладу — англійський текст (gettext msgid): сцени і код пишуть англійською (D121),
## Label / Button перекладають свій text самі (auto_translate), код обгортає складені рядки в tr().
## Переклади реєструються тут, а не в project.godot (він не комітиться — той самий підхід, що D270):
## кожен <мова>.po з translations_path іде в TranslationServer.add_translation.
extends Node
class_name GameLocalizationManager

## Доступні мови. Порядок = порядок у рядку Language у Settings.
var available_languages: Array[String] = ["en", "uk"]

## Шлях до папки з перекладами
const TRANSLATIONS_PATH := "res://SampleProject/Resources/Translations/"

## Поточна мова
var current_language: String = ""

## Сигнали
signal language_changed(language: String)

func _ready() -> void:
	_register_translations()
	apply_language(SaveSystem.get_language())


## Кожна мова має свій .po — відсутній файл є помилкою, не мовчазною англійською.
func _register_translations() -> void:
	for lang in available_languages:
		var translation: Translation = load(TRANSLATIONS_PATH + lang + ".po")
		assert(translation != null, "LocalizationManager: немає %s%s.po" % [TRANSLATIONS_PATH, lang])
		assert(translation.locale == lang, "LocalizationManager: %s.po має Language: %s" % [lang, translation.locale])
		TranslationServer.add_translation(translation)

## Змінює мову
func set_language(language: String) -> bool:
	if language not in available_languages:
		push_error("LocalizationManager: мова '%s' недоступна" % language)
		return false

	apply_language(language)
	# Зберігаємо вибір мови
	SaveSystem.set_language(language)
	return true


## Вмикає мову без запису в налаштування — для SettingsModule.apply_settings() (налаштування вже завантажені).
func apply_language(language: String) -> void:
	assert(language in available_languages, "LocalizationManager: мова '%s' не підтримується" % language)
	if language == current_language:
		return
	current_language = language
	TranslationServer.set_locale(language)
	language_changed.emit(language)

## Отримує поточну мову
func get_language() -> String:
	return current_language

## Отримує локалізований текст
func translate(key: String) -> String:
	return tr(key)

## Перевіряє, чи мова доступна
func is_language_available(language: String) -> bool:
	return language in available_languages

## Отримує список доступних мов
func get_available_languages() -> Array[String]:
	return available_languages.duplicate()
