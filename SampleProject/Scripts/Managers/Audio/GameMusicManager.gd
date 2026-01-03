extends ManagerBase
class_name GameMusicManager

## 🎵 GameMusicManager - Управління музикою в GameManager
## Винесено з GameManager для розділення відповідальностей
## Дотримується принципу Single Responsibility

# Посилання на AudioStreamPlayer
var background_music: AudioStreamPlayer = null
var global_music_player: AudioStreamPlayer = null
var current_music_stream: AudioStream = null

# Сигнали
signal music_started(music_name: String)
signal music_stopped(music_name: String)

func _initialize():
	"""Ініціалізація GameMusicManager"""
	print("🎵 GameMusicManager: Initialized")

func initialize(music_player: AudioStreamPlayer, global_player: AudioStreamPlayer):
	"""Ініціалізує GameMusicManager з посиланнями на плеєри"""
	background_music = music_player
	global_music_player = global_player
	print("🎵 GameMusicManager: Initialized with music players")

func start_default_music():
	"""Запускає фонову музику за замовчуванням"""
	# Використовуємо MusicManager, якщо він доступний
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_music_manager"):
			var music_manager = service_locator.get_music_manager()
			if music_manager:
				music_manager.play_music("res://SampleProject/Resources/Audio/Music/Sands of Serenity.mp3")
		return
	# Fallback - используем локальный плеер
	if false:  # Заглушка для старого кода
		if Engine.has_singleton("ServiceLocator"):
			var service_locator = Engine.get_singleton("ServiceLocator")
			var music_manager = service_locator.get_music_manager() if service_locator and service_locator.has_method("get_music_manager") else null
			if music_manager:
				var scene_name = _get_current_scene_name()
			if scene_name != "Unknown":
				music_manager.play_scene_music(scene_name)
			else:
				music_manager.play_scene_music("village")
			return
	
	# Fallback - стара логіка
	if background_music:
		# MVP: різна музика для меню та гри (без MusicManager)
		var scene_name = _get_current_scene_name().to_lower()
		var music_path := ""
		var music_label := "gameplay"
		# Меню
		if scene_name.contains("main_menu") or scene_name.contains("title") or scene_name.contains("options") or scene_name.contains("load"):
			music_path = "res://SampleProject/Resources/Audio/Music/menu.ogg"
			music_label = "menu"
		# Бос (поки що той самий трек, але окремий маршрут)
		elif scene_name.contains("laboratory"):
			music_path = "res://SampleProject/Resources/Audio/Music/boss.ogg"
			music_label = "boss"
		else:
			music_path = "res://SampleProject/Resources/Audio/Music/main_theme.ogg"
		
		if music_path != "" and ResourceLoader.exists(music_path):
			var stream = load(music_path)
			if stream:
				play_music(stream, music_label)
			else:
				print("⚠️ GameMusicManager: Failed to load music from: ", music_path)
		else:
			print("⚠️ GameMusicManager: Music file not found at: ", music_path)

func play_music(stream: AudioStream, music_name: String = "unknown"):
	"""Відтворює музику"""
	if not background_music:
		push_error("❌ GameMusicManager: background_music is null!")
		return
	
	current_music_stream = stream
	background_music.stream = stream
	background_music.play()
	music_started.emit(music_name)
	print("🎵 GameMusicManager: Playing music: ", music_name)

func stop_music():
	"""Зупиняє музику"""
	if background_music:
		background_music.stop()
		var music_name = current_music_stream.resource_path.get_file() if current_music_stream else "unknown"
		music_stopped.emit(music_name)
		print("🎵 GameMusicManager: Stopped music: ", music_name)

func pause_music():
	"""Ставить музику на паузу"""
	if background_music:
		background_music.stream_paused = true
		print("🎵 GameMusicManager: Music paused")

func resume_music():
	"""Знімає музику з паузи"""
	if background_music:
		background_music.stream_paused = false
		print("🎵 GameMusicManager: Music resumed")

func set_music_volume(volume: float):
	"""Встановлює гучність музики"""
	if background_music:
		background_music.volume_db = linear_to_db(volume)
		print("🎵 GameMusicManager: Music volume set to: ", volume)

func _get_current_scene_name() -> String:
	"""Отримує ім'я поточної сцени"""
	var current_scene = get_tree().current_scene
	if current_scene:
		return current_scene.scene_file_path.get_file().get_basename()
	return "Unknown"

