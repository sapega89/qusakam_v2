extends Node

## 🔊 AudioManager — гучність шин (налаштування) і єдиний шлях програвання звуків (D274).
## Звук — це подія з Resources/Data/sound_events.json: шина, файли (грає випадковий), гучність, висота.
## Події гри на звуки перекладає SoundHooks (дочірній вузол), рух героя — PlayerMover.
## Шини: Master → Music, SFX; Ambience і Voice ідуть у SFX — повзунок «Sound Effects» керує й ними (D274).

signal volume_changed(bus_name: String, volume: float)
## Кожен програний звук — для verify_audio.gd і налагодження.
signal sound_played(event: StringName, stream: AudioStream, bus: StringName)

const EVENTS_PATH := "res://SampleProject/Resources/Data/sound_events.json"
const AUDIO_ROOT := "res://SampleProject/Assets/Audio/"

# Кэш индексов bus для оптимизации
var _master_bus_index: int = -1
var _music_bus_index: int = -1
var _sfx_bus_index: int = -1

## Подія → {bus, files, volume_db, pitch, jitter}; кімната → {ambience, surface, interior}.
var events: Dictionary = {}
var rooms: Dictionary = {}
## Подія → Array[AudioStream], завантажені при старті: відсутній файл — помилка одразу, а не тиша в грі.
var _streams: Dictionary = {}


func _ready() -> void:
	_master_bus_index = AudioServer.get_bus_index("Master")
	_music_bus_index = AudioServer.get_bus_index("Music")
	_sfx_bus_index = AudioServer.get_bus_index("SFX")
	for bus in ["Music", "SFX", "Ambience", "Voice"]:
		assert(AudioServer.get_bus_index(bus) >= 0, "AudioManager: bus %s missing from default_bus_layout.tres" % bus)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EVENTS_PATH))
	events = data.events
	rooms = data.rooms
	for event: String in events:
		var list: Array[AudioStream] = []
		for file: String in events[event].files:
			var stream: AudioStream = load(AUDIO_ROOT + file)
			assert(stream != null, "AudioManager: %s → %s not found" % [event, file])
			list.append(stream)
		_streams[StringName(event)] = list


## Грає звук події [param event]; [param pitch_scale] множить висоту з таблиці (напр. голос ворога за типом).
func play(event: StringName, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	var player := _make_player(event, pitch_scale)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	sound_played.emit(event, player.stream, player.bus)
	return player


## Петля події [param event] (атмосфера кімнати) дочірньою [param parent] — живе й зникає разом із ним.
func play_loop(event: StringName, parent: Node) -> AudioStreamPlayer:
	var player := _make_player(event, 1.0)
	player.stream.loop = true
	parent.add_child(player)
	player.play()
	sound_played.emit(event, player.stream, player.bus)
	return player


func _make_player(event: StringName, pitch_scale: float) -> AudioStreamPlayer:
	assert(_streams.has(event), "AudioManager: unknown sound event '%s'" % event)
	var entry: Dictionary = events[event]
	var jitter: float = entry.get("jitter", 0.05)
	var player := AudioStreamPlayer.new()
	player.stream = _streams[event].pick_random()
	player.bus = StringName(entry.bus)
	player.volume_db = entry.get("volume_db", 0.0)
	player.pitch_scale = entry.get("pitch", 1.0) * pitch_scale * randf_range(1.0 - jitter, 1.0 + jitter)
	return player


func has_event(event: StringName) -> bool:
	return _streams.has(event)


## Звук кімнати [param room_name] ({ambience, surface, interior}); кімнати без запису в таблиці — помилка.
func room(room_name: String) -> Dictionary:
	assert(rooms.has(room_name), "AudioManager: room %s has no entry in sound_events.json → rooms" % room_name)
	return rooms[room_name]


## Установить громкость Master (0.0 - 1.0)
func set_master_volume(volume: float) -> void:
	AudioServer.set_bus_volume_db(_master_bus_index, linear_to_db(volume))
	volume_changed.emit("Master", volume)

## Установить громкость Music (0.0 - 1.0)
func set_music_volume(volume: float) -> void:
	AudioServer.set_bus_volume_db(_music_bus_index, linear_to_db(volume))
	volume_changed.emit("Music", volume)

## Установить громкость SFX (0.0 - 1.0) — разом з Ambience і Voice, що йдуть у SFX.
func set_sfx_volume(volume: float) -> void:
	AudioServer.set_bus_volume_db(_sfx_bus_index, linear_to_db(volume))
	volume_changed.emit("SFX", volume)

func get_master_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(_master_bus_index))

func get_music_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(_music_bus_index))

func get_sfx_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(_sfx_bus_index))

## Применить настройки громкости из словаря
func apply_volume_settings(settings: Dictionary) -> void:
	if settings.has("master_volume"):
		set_master_volume(settings.master_volume)
	if settings.has("music_volume"):
		set_music_volume(settings.music_volume)
	if settings.has("sfx_volume"):
		set_sfx_volume(settings.sfx_volume)
