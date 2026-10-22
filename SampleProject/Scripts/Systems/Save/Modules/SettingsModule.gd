extends SaveModule
class_name SettingsModule

## ⚙️ SettingsModule - Сохранение настроек игры
## Управляет: громкость, экран, язык, VSync

# Настройки игры по умолчанию
var default_settings = {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 0.9,
	# Settings plan slice 1: режим вікна — одне з DisplayManager.DISPLAY_MODES (Windowed / Fullscreen / Borderless).
	"display_mode": "windowed",
	"vsync": true,
	# BACKLOG 41: розмір вікна (DisplayManager.RESOLUTIONS) і ліміт кадрів (DisplayManager.FPS_LIMITS, 0 = без ліміту).
	# Значення за замовчуванням = project.godot: вʼюпорт 1920×1080, run/max_fps=60.
	"resolution": "1920x1080",
	"fps_limit": 60,
	"language": "en",  # BACKLOG 31: англійська — основна мова (D121); українська — у Settings → Game → Language
	"tutorial_windows": true,  # D289: підказка відкриває вікно туторіалу; вимкнено — лише плашка
	"damage_numbers": true,  # D66: цифри урону над героєм і ворогами (DamageNumbers)
	"auto_save": false  # D413: автосейв при переході між кімнатами (SaveSystem._on_room_entered); вимкнено — лише SavePoint
}

# Текущие настройки
var settings: Dictionary = {}

func _ready():
	module_name = "SettingsModule"
	# Инициализируем настройками по умолчанию
	settings = default_settings.duplicate()

## Сохраняет настройки игры
func save() -> Dictionary:
	log_info("Settings saved: master=%.1f, music=%.1f, display_mode=%s" % [
		settings["master_volume"],
		settings["music_volume"],
		settings["display_mode"]
	])
	return settings.duplicate()

## Загружает настройки игры
func load_data(data: Dictionary) -> void:
	read(data)
	apply_settings()

	log_info("Settings loaded: master=%.1f, music=%.1f, display_mode=%s" % [
		settings["master_volume"],
		settings["music_volume"],
		settings["display_mode"]
	])

## Лише значення, без застосування: під час старту менеджери, що їх застосовують, ще не готові.
func read(data: Dictionary) -> void:
	# Новий ключ налаштувань, якого ще немає у файлі, бере значення за замовчуванням.
	settings = default_settings.merged(data, true)

## Применяет настройки к игре
func apply_settings() -> void:
	_apply_audio_settings()
	_apply_display_settings()
	LocalizationManager.apply_language(settings["language"])

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
func toggle_vsync() -> void:
	settings["vsync"] = not settings["vsync"]
	_apply_display_settings()

