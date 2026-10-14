## Менеджер локалізації
## Керує перекладами та перемиканням мов
extends Node
class_name GameLocalizationManager

## Поточна мова
var current_language: String = "uk"

## Доступні мови
var available_languages: Array[String] = ["en", "uk"]

## Шлях до папки з перекладами
var translations_path: String = "res://SampleProject/Resources/Translations/"

## Сигнали
signal language_changed(language: String)

func _ready() -> void:
	# Завантажуємо збережену мову з налаштувань
	_load_saved_language()

	# Завантажуємо переклади
	_load_translations()

	print("🌍 LocalizationManager: Initialized with language: ", current_language)

## Завантажує збережену мову
func _load_saved_language() -> void:
	current_language = SaveSystem.get_language()
	if current_language not in available_languages:
		push_error("LocalizationManager: збережена мова '%s' не підтримується" % current_language)

## Завантажує переклади
func _load_translations() -> void:
	var translation_files: Array[String] = []

	# Додаємо файли перекладів для кожної мови
	for lang in available_languages:
		var po_path = translations_path + lang + ".po"
		if ResourceLoader.exists(po_path):
			translation_files.append(po_path)
		else:
			push_warning("LocalizationManager: Translation file not found: ", po_path)

	# Завантажуємо переклади через TranslationServer
	if translation_files.size() > 0:
		TranslationServer.set_locale(current_language)
		ProjectSettings.set_setting("internationalization/locale/translations", translation_files)
		print("🌍 LocalizationManager: Loaded ", translation_files.size(), " translation files")
	else:
		push_warning("LocalizationManager: No translation files found")

## Змінює мову
func set_language(language: String) -> bool:
	if language not in available_languages:
		push_warning("LocalizationManager: Language '", language, "' not available")
		return false

	current_language = language
	TranslationServer.set_locale(language)

	# Зберігаємо вибір мови
	_save_language(language)

	# Емітуємо сигнал
	language_changed.emit(language)

	print("🌍 LocalizationManager: Language changed to: ", language)
	return true

## Отримує поточну мову
func get_language() -> String:
	return current_language

## Отримує локалізований текст
func translate(key: String) -> String:
	return tr(key)

## Зберігає вибір мови
func _save_language(language: String) -> void:
	SaveSystem.set_language(language)

## Перевіряє, чи мова доступна
func is_language_available(language: String) -> bool:
	return language in available_languages

## Отримує список доступних мов
func get_available_languages() -> Array[String]:
	return available_languages.duplicate()

