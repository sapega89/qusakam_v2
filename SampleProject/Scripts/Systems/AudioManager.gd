extends Node

## 🔊 AudioManager - Управление звуком в игре
## Отвечает за установку громкости через AudioServer
## Используется SaveSystem и BaseOptionsComponent

signal volume_changed(bus_name: String, volume: float)

# Кэш индексов bus для оптимизации
var _master_bus_index: int = -1
var _music_bus_index: int = -1
var _sfx_bus_index: int = -1

# SFX конфигурация
var _sfx_config: Dictionary = {}

func _ready():
	# Пытаемся загрузить bus layout, если он существует
	var bus_layout_path = "res://SampleProject/Resources/Audio/default_bus_layout.tres"
	if ResourceLoader.exists(bus_layout_path):
		var bus_layout = load(bus_layout_path) as AudioBusLayout
		if bus_layout:
			AudioServer.set_bus_layout(bus_layout)
			print("🔊 AudioManager: Bus layout loaded from ", bus_layout_path)
	
	# Инициализируем индексы bus при старте
	# Master bus всегда существует (индекс 0)
	_master_bus_index = AudioServer.get_bus_index("Master")
	
	# Music и SFX bus могут не существовать - это нормально
	_music_bus_index = AudioServer.get_bus_index("Music")
	_sfx_bus_index = AudioServer.get_bus_index("SFX")
	
	# Master bus должен существовать всегда
	if _master_bus_index < 0:
		# Если Master bus не найден, используем индекс 0 (по умолчанию)
		_master_bus_index = 0
	
	# Music и SFX bus опциональны - не выдаем предупреждения, если их нет
	# Если bus не найдены, функции просто не будут работать, но не будут выдавать ошибки
	
	# Загружаем SFX конфигурацию
	_load_sfx_config()

## Установить громкость Master
func set_master_volume(volume: float):
	"""Устанавливает громкость Master (0.0 - 1.0)"""
	if _master_bus_index >= 0:
		AudioServer.set_bus_volume_db(_master_bus_index, linear_to_db(volume))
		volume_changed.emit("Master", volume)
		print("🔊 AudioManager: Master volume set to ", int(volume * 100), "%")
	# Если bus не найден, просто игнорируем (не выдаем ошибку)

## Установить громкость Music
func set_music_volume(volume: float):
	"""Устанавливает громкость Music (0.0 - 1.0)"""
	if _music_bus_index >= 0:
		AudioServer.set_bus_volume_db(_music_bus_index, linear_to_db(volume))
		volume_changed.emit("Music", volume)
		print("🎵 AudioManager: Music volume set to ", int(volume * 100), "%")
	# Если bus не найден, просто игнорируем (не выдаем ошибку)

## Установить громкость SFX
func set_sfx_volume(volume: float):
	"""Устанавливает громкость SFX (0.0 - 1.0)"""
	if _sfx_bus_index >= 0:
		AudioServer.set_bus_volume_db(_sfx_bus_index, linear_to_db(volume))
		volume_changed.emit("SFX", volume)
		print("🔊 AudioManager: SFX volume set to ", int(volume * 100), "%")
	# Если bus не найден, просто игнорируем (не выдаем ошибку)

## Получить текущую громкость Master
func get_master_volume() -> float:
	"""Возвращает текущую громкость Master (0.0 - 1.0)"""
	if _master_bus_index >= 0:
		return db_to_linear(AudioServer.get_bus_volume_db(_master_bus_index))
	return 1.0

## Получить текущую громкость Music
func get_music_volume() -> float:
	"""Возвращает текущую громкость Music (0.0 - 1.0)"""
	if _music_bus_index >= 0:
		return db_to_linear(AudioServer.get_bus_volume_db(_music_bus_index))
	return 0.8

## Получить текущую громкость SFX
func get_sfx_volume() -> float:
	"""Возвращает текущую громкость SFX (0.0 - 1.0)"""
	if _sfx_bus_index >= 0:
		return db_to_linear(AudioServer.get_bus_volume_db(_sfx_bus_index))
	return 0.9

## Применить настройки громкости из словаря
func apply_volume_settings(settings: Dictionary):
	"""Применяет настройки громкости из словаря"""
	if settings.has("master_volume"):
		set_master_volume(settings.master_volume)
	if settings.has("music_volume"):
		set_music_volume(settings.music_volume)
	if settings.has("sfx_volume"):
		set_sfx_volume(settings.sfx_volume)

## Загрузить SFX конфигурацию
func _load_sfx_config() -> void:
	"""Загружает конфигурацию звуковых эффектов"""
	var config_file = FileAccess.open("res://SampleProject/Resources/Data/sfx_config.json", FileAccess.READ)
	if config_file:
		var json_string = config_file.get_as_text()
		config_file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			_sfx_config = json.data
			if _sfx_config.has("sfx"):
				print("🔊 AudioManager: SFX config loaded")
			else:
				print("⚠️ AudioManager: Invalid SFX config structure")
		else:
			print("⚠️ AudioManager: Failed to parse SFX config JSON")
	else:
		print("⚠️ AudioManager: SFX config file not found")

## Воспроизвести звуковой эффект по имени
func play_sfx(sfx_name: String) -> void:
	"""Воспроизводит звуковой эффект по имени из конфигурации"""
	if not _sfx_config.has("sfx") or not _sfx_config.sfx.has(sfx_name):
		print("⚠️ AudioManager: SFX '", sfx_name, "' not found in config")
		return
	
	var sfx_config = _sfx_config.sfx[sfx_name]
	if not sfx_config.has("path"):
		print("⚠️ AudioManager: Invalid SFX config for '", sfx_name, "'")
		return
	
	var volume_db = sfx_config.get("volume", 0.0)
	play_sfx_path(sfx_config.path, volume_db)

## Воспроизвести звуковой эффект по пути к файлу
func play_sfx_path(sfx_path: String, volume_db: float = 0.0) -> void:
	"""Воспроизводит звуковой эффект по пути к файлу"""
	if not ResourceLoader.exists(sfx_path):
		print("⚠️ AudioManager: SFX file not found: ", sfx_path)
		return
	
	var audio_stream = load(sfx_path) as AudioStream
	if not audio_stream:
		print("⚠️ AudioManager: Failed to load SFX: ", sfx_path)
		return
	
	var player = AudioStreamPlayer.new()
	player.stream = audio_stream
	player.volume_db = volume_db
	if _sfx_bus_index >= 0:
		player.bus = "SFX"
	else:
		player.bus = "Master"
	
	add_child(player)
	player.play()
	player.finished.connect(func(): player.queue_free())

