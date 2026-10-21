extends SaveModule
class_name SettingsModule

## ⚙️ SettingsModule - Сохранение настроек игры
## Управляет: громкость, экран, язык, VSync

# Настройки игры по умолчанию
var default_settings = {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 0.9,
	"fullscreen": false,
	"vsync": true,
	"language": "uk",
	"tutorial_windows": true  # D289: підказка відкриває вікно туторіалу; вимкнено — лише плашка
}

# Текущие настройки
var settings: Dictionary = {}

func _ready():
	module_name = "SettingsModule"
	# Инициализируем настройками по умолчанию
	settings = default_settings.duplicate()

## Сохраняет настройки игры
func save() -> Dictionary:
	log_info("Settings saved: master=%.1f, music=%.1f, fullscreen=%s" % [
		settings["master_volume"],
		settings["music_volume"],
		settings["fullscreen"]
	])
	return settings.duplicate()

## Загружает настройки игры
func load_data(data: Dictionary) -> void:
	# Новий ключ налаштувань, якого ще немає у файлі, бере значення за замовчуванням.
	settings = default_settings.merged(data, true)
	apply_settings()

	log_info("Settings loaded: master=%.1f, music=%.1f, fullscreen=%s" % [
		settings["master_volume"],
		settings["music_volume"],
		settings["fullscreen"]
	])

## Применяет настройки к игре
func apply_settings() -> void:
	_apply_audio_settings()
	_apply_display_settings()

## Применяет настройки звука
func _apply_audio_settings() -> void:
	AudioManager.apply_volume_settings(settings)
	log_info("Audio settings applied via AudioManager")

## Применяет настройки дисплея
func _apply_display_settings() -> void:
	DisplayManager.apply_display_settings(settings)
	log_info("Display settings applied via DisplayManager")

## Обновляет настройку звука
func update_master_volume(volume: float) -> void:
	settings["master_volume"] = volume
	_apply_audio_settings()

func update_music_volume(volume: float) -> void:
	settings["music_volume"] = volume
	_apply_audio_settings()

func update_sfx_volume(volume: float) -> void:
	settings["sfx_volume"] = volume
	_apply_audio_settings()

## Обновляет настройки дисплея
func toggle_fullscreen() -> void:
	settings["fullscreen"] = not settings["fullscreen"]
	_apply_display_settings()

func toggle_vsync() -> void:
	settings["vsync"] = not settings["vsync"]
	_apply_display_settings()

