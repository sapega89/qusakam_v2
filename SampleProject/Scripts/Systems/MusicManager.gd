extends Node

# 🎵 MusicManager - Керування музичними треками
# Відповідає за:
# - Завантаження конфігурації музики з JSON
# - Переключення між треками з плавними переходами
# - Керування гучністю та ефектами

var music_config: Dictionary = {}
var current_track: String = ""
var music_player: AudioStreamPlayer
var fade_tween: Tween

# Сигнали
signal track_changed(track_name: String)
signal music_faded_out()
signal music_faded_in()

func _ready():
	"""Ініціалізація MusicManager"""
	# Ініціалізуємо music_config як порожній Dictionary
	music_config = {}
	
	# Створюємо глобальний плеєр музики
	music_player = AudioStreamPlayer.new()
	music_player.name = "GlobalMusicPlayer"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS  # Не призупиняється
	add_child(music_player)
	
	# Завантажуємо конфігурацію
	load_music_config()
	
	print("🎵 MusicManager: Initialized")

func load_music_config():
	"""Завантажує конфігурацію музики з JSON файлу"""
	var config_file = FileAccess.open("res://SampleProject/Resources/Data/music_config.json", FileAccess.READ)
	if config_file:
		var json_string = config_file.get_as_text()
		config_file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			music_config = json.data
			if music_config and music_config.has("music_tracks"):
				print("🎵 MusicManager: Music config loaded successfully")
				print("🎵 MusicManager: Available tracks: ", music_config.music_tracks.keys())
			else:
				print("❌ MusicManager: Invalid music config structure")
				create_default_config()
		else:
			print("❌ MusicManager: Failed to parse music config JSON")
			create_default_config()
	else:
		print("❌ MusicManager: Music config file not found, creating default")
		create_default_config()

func create_default_config():
	"""Створює конфігурацію за замовчуванням"""
	music_config = {
		"music_tracks": {
			"main_theme": {
				"path": "res://SampleProject/Resources/Audio/Music/main_theme.ogg",
				"volume": 0.0,
				"loop": true,
				"fade_in": 2.0,
				"fade_out": 2.0
			}
		},
		"scenes": {
			"village": "main_theme",
			"menu": "main_theme"
		},
		"settings": {
			"master_volume": 0.0,
			"music_volume": 0.0,
			"crossfade_duration": 2.0
		}
	}

func play_track(track_name: String, fade_in: bool = true):
	"""Відтворює музичний трек"""
	if not music_config or not music_config.has("music_tracks") or not music_config.music_tracks.has(track_name):
		print("❌ MusicManager: Track '", track_name, "' not found in config")
		return
	
	var track_config = music_config.music_tracks[track_name]
	if not track_config or not track_config.has("path"):
		print("❌ MusicManager: Invalid track config for '", track_name, "'")
		return
	
	# Перевіряємо, чи файл існує
	if not ResourceLoader.exists(track_config.path):
		print("❌ MusicManager: Audio file not found: ", track_config.path)
		# Fallback: спробуємо завантажити альтернативний трек
		if track_name != "main_theme" and music_config.music_tracks.has("main_theme"):
			print("🎵 MusicManager: Trying fallback to main_theme")
			play_track("main_theme", fade_in)
		return
	
	# Завантажуємо аудіо файл
	var audio_stream = load(track_config.path) as AudioStream
	if not audio_stream:
		print("❌ MusicManager: Failed to load audio file: ", track_config.path)
		# Fallback: спробуємо завантажити альтернативний трек
		if track_name != "main_theme" and music_config.music_tracks.has("main_theme"):
			print("🎵 MusicManager: Trying fallback to main_theme")
			play_track("main_theme", fade_in)
		return
	
	# Якщо це той самий трек, не перезапускаємо
	if current_track == track_name and music_player.playing:
		print("🎵 MusicManager: Track '", track_name, "' already playing")
		return
	
	# Встановлюємо трек
	music_player.stream = audio_stream
	
	# Безпечний доступ до налаштувань гучності
	var music_volume = 0.0
	if music_config.has("settings") and music_config.settings.has("music_volume"):
		music_volume = music_config.settings.music_volume
	
	var track_volume = 0.0
	if track_config.has("volume"):
		track_volume = track_config.volume
	
	music_player.volume_db = track_volume + music_volume
	
	# Запускаємо музику
	if fade_in and track_config.has("fade_in"):
		# Плавне появлення
		music_player.volume_db = -80.0  # Починаємо з тихо
		music_player.play()
		fade_music_in(track_config.fade_in)
	else:
		# Миттєве появлення
		music_player.play()
	
	current_track = track_name
	track_changed.emit(track_name)
	print("🎵 MusicManager: Playing track '", track_name, "'")

func play_scene_music(scene_type: String):
	"""Відтворює музику для конкретного типу сцени"""
	if not music_config or not music_config.has("scenes"):
		print("❌ MusicManager: Music config not loaded or missing scenes section")
		# Fallback to main_theme
		play_track("main_theme")
		return
		
	if not music_config.scenes.has(scene_type):
		print("❌ MusicManager: Scene type '", scene_type, "' not found in config")
		print("🎵 MusicManager: Available scenes: ", music_config.scenes.keys())
		
		# Розумний fallback на основі назви сцени
		if "menu" in scene_type.to_lower():
			print("🎵 MusicManager: Detected menu scene, using menu music")
			play_track("menu")
		elif "boss" in scene_type.to_lower():
			print("🎵 MusicManager: Detected boss scene, using boss music")
			play_track("boss")
		elif "combat" in scene_type.to_lower():
			print("🎵 MusicManager: Detected combat scene, using combat music")
			play_track("combat")
		else:
			print("🎵 MusicManager: Using default main_theme")
			play_track("main_theme")
		return
	
	var track_name = music_config.scenes[scene_type]
	play_track(track_name)

func stop_music(fade_out: bool = true):
	"""Зупиняє музику"""
	if not music_player.playing:
		return
	
	if fade_out and current_track != "":
		if music_config.has("music_tracks") and music_config.music_tracks.has(current_track):
			var track_config = music_config.music_tracks[current_track]
			if track_config.has("fade_out"):
				fade_music_out(track_config.fade_out)
			else:
				music_player.stop()
		else:
			music_player.stop()
	else:
		music_player.stop()
	
	current_track = ""
	print("🎵 MusicManager: Music stopped")

func fade_music_in(duration: float):
	"""Дуже плавне появлення музики"""
	if fade_tween:
		fade_tween.kill()
	
	# Починаємо з дуже тихого рівня
	music_player.volume_db = -60.0
	
	fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_OUT)  # Плавне сповільнення
	fade_tween.set_trans(Tween.TRANS_CUBIC)  # Кубічна крива для дуже плавного переходу
	
	# Безпечний доступ до налаштувань гучності
	var track_volume = 0.0
	if music_config.has("music_tracks") and music_config.music_tracks.has(current_track) and music_config.music_tracks[current_track].has("volume"):
		track_volume = music_config.music_tracks[current_track].volume
	
	var settings_volume = 0.0
	if music_config.has("settings") and music_config.settings.has("music_volume"):
		settings_volume = music_config.settings.music_volume
	
	var target_volume = track_volume + settings_volume
	fade_tween.tween_property(music_player, "volume_db", target_volume, duration)
	fade_tween.tween_callback(func(): music_faded_in.emit())
	
	print("🎵 MusicManager: Starting very smooth fade-in over ", duration, " seconds")

func fade_music_out(duration: float):
	"""Дуже плавне зникнення музики"""
	if fade_tween:
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_IN)  # Плавне прискорення
	fade_tween.set_trans(Tween.TRANS_CUBIC)  # Кубічна крива для дуже плавного переходу
	
	fade_tween.tween_property(music_player, "volume_db", -80.0, duration)
	fade_tween.tween_callback(func(): 
		music_player.stop()
		music_faded_out.emit()
	)
	
	print("🎵 MusicManager: Starting very smooth fade-out over ", duration, " seconds")

func set_master_volume(volume_db: float):
	"""Встановлює загальну гучність"""
	if music_config.has("settings"):
		music_config.settings.master_volume = volume_db
		update_volume()

func set_music_volume(volume_db: float):
	"""Встановлює гучність музики"""
	if music_config.has("settings"):
		music_config.settings.music_volume = volume_db
		update_volume()

func update_volume():
	"""Оновлює гучність поточного треку"""
	if current_track != "" and music_player.playing:
		if music_config.has("music_tracks") and music_config.music_tracks.has(current_track):
			var track_config = music_config.music_tracks[current_track]
			var track_volume = 0.0
			if track_config.has("volume"):
				track_volume = track_config.volume
			
			var settings_volume = 0.0
			if music_config.has("settings") and music_config.settings.has("music_volume"):
				settings_volume = music_config.settings.music_volume
			
			music_player.volume_db = track_volume + settings_volume

func get_current_track() -> String:
	"""Повертає назву поточного треку"""
	return current_track

func is_playing() -> bool:
	"""Перевіряє, чи грає музика"""
	return music_player.playing

