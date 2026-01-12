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
	"language": "uk"
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
		settings.get("master_volume", 1.0),
		settings.get("music_volume", 0.8),
		settings.get("fullscreen", false)
	])
	return settings.duplicate()

## Загружает настройки игры
func load_data(data: Dictionary) -> void:
	if not validate_data(data):
		log_error("Invalid settings data, using defaults")
		settings = default_settings.duplicate()
		return

	settings = data.duplicate()
	apply_settings()

	log_info("Settings loaded: master=%.1f, music=%.1f, fullscreen=%s" % [
		settings.get("master_volume", 1.0),
		settings.get("music_volume", 0.8),
		settings.get("fullscreen", false)
	])

## Применяет настройки к игре
func apply_settings() -> void:
	_apply_audio_settings()
	_apply_display_settings()

## Применяет настройки звука
func _apply_audio_settings() -> void:
	# Пытаемся получить AudioManager
	var audio_manager = null
	if Engine.has_singleton("AudioManager"):
		audio_manager = Engine.get_singleton("AudioManager")
	elif Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_audio_manager"):
			audio_manager = service_locator.get_audio_manager()

	if audio_manager and audio_manager.has_method("apply_volume_settings"):
		audio_manager.apply_volume_settings(settings)
		log_info("Audio settings applied via AudioManager")
	else:
		# Fallback: прямое обращение к AudioServer
		var master_bus = AudioServer.get_bus_index("Master")
		if master_bus >= 0:
			AudioServer.set_bus_volume_db(master_bus, linear_to_db(settings.get("master_volume", 1.0)))

		var music_bus = AudioServer.get_bus_index("Music")
		if music_bus >= 0:
			AudioServer.set_bus_volume_db(music_bus, linear_to_db(settings.get("music_volume", 0.8)))

		var sfx_bus = AudioServer.get_bus_index("SFX")
		if sfx_bus >= 0:
			AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(settings.get("sfx_volume", 0.9)))

		log_info("Audio settings applied via AudioServer fallback")

## Применяет настройки дисплея
func _apply_display_settings() -> void:
	# Пытаемся получить DisplayManager
	var display_manager = null
	if Engine.has_singleton("DisplayManager"):
		display_manager = Engine.get_singleton("DisplayManager")
	elif Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_display_manager"):
			display_manager = service_locator.get_display_manager()

	if display_manager and display_manager.has_method("apply_display_settings"):
		display_manager.apply_display_settings(settings)
		log_info("Display settings applied via DisplayManager")
	else:
		# Fallback: прямое обращение к DisplayServer
		var current_mode = DisplayServer.window_get_mode()
		var fullscreen = settings.get("fullscreen", false)

		if fullscreen and current_mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			log_info("Fullscreen enabled")
		elif not fullscreen and current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			log_info("Fullscreen disabled")

		# Применяем VSync
		var vsync = settings.get("vsync", true)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		log_info("VSync %s" % ("enabled" if vsync else "disabled"))

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
	settings["fullscreen"] = not settings.get("fullscreen", false)
	_apply_display_settings()

func toggle_vsync() -> void:
	settings["vsync"] = not settings.get("vsync", true)
	_apply_display_settings()

## Возвращает данные без сохранения
func get_data() -> Dictionary:
	return save()

## Устанавливает данные без загрузки из файла
func set_data(data: Dictionary) -> void:
	load_data(data)

## Валидация данных
func validate_data(data: Dictionary) -> bool:
	if not super.validate_data(data):
		return false

	# Проверяем что есть хотя бы одна настройка
	if data.is_empty():
		log_warning("Settings data is empty")
		return false

	return true
