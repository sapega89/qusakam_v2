extends Node

## 🔊 AudioManager — гучність шин (налаштування) і єдиний шлях програвання звуків (D274).
## Звук — це подія з Resources/Data/sound_events.json: шина, файли (грає випадковий), гучність, висота.
## Події гри на звуки перекладає SoundHooks (дочірній вузол), рух героя — PlayerMover.
## Шини: Master → Music, SFX; Ambience і Voice ідуть у SFX — повзунок «Sound Effects» керує й ними (D274).
## Ambience має ще й власний повзунок «Ambient» (D427): поверх мікшу шини з default_bus_layout.tres (−6 dB).

signal volume_changed(bus_name: String, volume: float)
## Кожен програний звук — для verify_audio.gd і налагодження.
signal sound_played(event: StringName, stream: AudioStream, bus: StringName, pitch_scale: float)

const EVENTS_PATH := "res://SampleProject/Resources/Data/sound_events.json"
const AUDIO_ROOT := "res://SampleProject/Assets/Audio/"

# Кэш индексов bus для оптимизации
var _master_bus_index: int = -1
var _music_bus_index: int = -1
var _sfx_bus_index: int = -1
var _ambience_bus_index: int = -1
## Гучність Ambience з default_bus_layout.tres — це «100» повзунка Ambient (D427), мікс не змінюється.
var _ambience_base_db: float = 0.0

## Подія → {bus, files, volume_db, pitch, jitter}; кімната → {ambience, surface, interior}.
var events: Dictionary = {}
var rooms: Dictionary = {}
## Персонаж DialogueQuest (character_id) → голос: бурмотіння babble_<голос>, привітання greet_<голос> (D277).
var voices: Dictionary = {}
## Тип ворога → висота його голосу (tank нижчий, fast вищий).
var enemy_voice_pitch: Dictionary = {}
## Тип боса → {roar, shout, death}: події його голосу (D278, D310).
var boss_voices: Dictionary = {}
## Музика бою (D414): "fight" — бій героя, "boss" — бій з босом; AudioStream, завантажені при старті.
var music: Dictionary = {}
## Події гри → звуки; сюди ж кличуть діалоги (бурмотіння) і NPC (привітання).
@onready var hooks: Node = $SoundHooks
## Подія → Array[AudioStream], завантажені при старті: відсутній файл — помилка одразу, а не тиша в грі.
var _streams: Dictionary = {}


func _ready() -> void:
	_master_bus_index = AudioServer.get_bus_index("Master")
	_music_bus_index = AudioServer.get_bus_index("Music")
	_sfx_bus_index = AudioServer.get_bus_index("SFX")
	_ambience_bus_index = AudioServer.get_bus_index("Ambience")
	_ambience_base_db = AudioServer.get_bus_volume_db(_ambience_bus_index)
	for bus in ["Music", "SFX", "Ambience", "Voice"]:
		assert(AudioServer.get_bus_index(bus) >= 0, "AudioManager: bus %s missing from default_bus_layout.tres" % bus)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EVENTS_PATH))
	events = data.events
	rooms = data.rooms
	voices = data.voices
	enemy_voice_pitch = data.enemy_voice_pitch
	boss_voices = data.boss_voices
	for use: String in data.music:
		if use == "_comment":
			continue
		var track: AudioStream = load(data.music[use])
		assert(track != null, "AudioManager: music %s → %s not found" % [use, data.music[use]])
		music[use] = track
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
	sound_played.emit(event, player.stream, player.bus, player.pitch_scale)
	return player


## Петля події [param event] (атмосфера кімнати) дочірньою [param parent] — живе й зникає разом із ним.
func play_loop(event: StringName, parent: Node) -> AudioStreamPlayer:
	var player := _make_player(event, 1.0)
	player.stream.loop = true
	parent.add_child(player)
	player.play()
	sound_played.emit(event, player.stream, player.bus, player.pitch_scale)
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
## Подія голосу боса [param kind] (roar, shout, death) за його enemy_type.
func boss_voice(enemy_type: String, kind: String) -> StringName:
	assert(boss_voices.has(enemy_type), "AudioManager: boss %s has no entry in sound_events.json → boss_voices" % enemy_type)
	return StringName(boss_voices[enemy_type][kind])


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

## Установить громкость Ambience (0.0 - 1.0) поверх мікшу шини (D427).
func set_ambient_volume(volume: float) -> void:
	AudioServer.set_bus_volume_db(_ambience_bus_index, _ambience_base_db + linear_to_db(volume))
	volume_changed.emit("Ambience", volume)

func get_master_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(_master_bus_index))

func get_music_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(_music_bus_index))

func get_sfx_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(_sfx_bus_index))

func get_ambient_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(_ambience_bus_index) - _ambience_base_db)

## Применить настройки громкости из словаря
func apply_volume_settings(settings: Dictionary) -> void:
	if settings.has("master_volume"):
		set_master_volume(settings.master_volume)
	if settings.has("music_volume"):
		set_music_volume(settings.music_volume)
	if settings.has("sfx_volume"):
		set_sfx_volume(settings.sfx_volume)
	if settings.has("ambient_volume"):
		set_ambient_volume(settings.ambient_volume)
