extends SceneTree

## Музика (music_plan): кожна кімната карти MetSys і головне меню мають вузол Music —
## AudioStreamPlayer на шині Music з autoplay; його підхоплює ProjectMusicController
## (maaacks) і сам перемикає трек між сценами. Трек зациклений і лежить у проєкті, не в assets/.
## Музика бою (D414, slice 3a): бій → бойовий трек, бос → трек боса поверх бою, кінець → знову трек кімнати;
## усе через той самий ProjectMusicController.play_stream, без другого програвача.
##   godot --headless --path . --script res://SampleProject/UI/verify_music.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _check(path: String) -> void:
	var scene: Node = load(path).instantiate()
	var music := scene.get_node_or_null(^"Music") as AudioStreamPlayer
	var name := path.get_file().get_basename()
	ck(music != null, "%s has a Music player" % name)
	if music:
		ck(music.autoplay and music.bus == &"Music", "%s: autoplay on the Music bus" % name)
		ck(music.process_mode == Node.PROCESS_MODE_ALWAYS, "%s: keeps playing under pause — Game Menu, shop" % name)
		ck((music.stream is AudioStreamOggVorbis or music.stream is AudioStreamMP3) and music.stream.loop, "%s: a looping track" % name)
		ck(music.stream.resource_path.begins_with("res://SampleProject/Resources/Audio/Music/"), "%s: track is in the project (%s)" % [name, music.stream.resource_path])
	scene.free()

func _initialize() -> void:
	await process_frame
	_check("res://SampleProject/MainMenu.tscn")
	# Кімнати — з MapData.txt, а не списком: нова кімната без музики теж провалить тест.
	var rooms := {}
	for line in FileAccess.get_file_as_string("res://SampleProject/Maps/MapData.txt").split("\n"):
		if line.contains(":") and not line.begins_with("["):
			rooms[line.get_slice(":", line.get_slice_count(":") - 1)] = true
	for uid in rooms:
		_check(ResourceUID.get_id_path(ResourceUID.text_to_id("uid://" + uid)))
	await _fight_music()
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)


## Що зараз грає ProjectMusicController.
func _music() -> AudioStream:
	var player: AudioStreamPlayer = root.get_node("ProjectMusicController").music_stream_player
	return player.stream if is_instance_valid(player) else null

## Музичні програвачі, що грають (шина Music або змішувальна шина контролера): має бути один.
func _players_playing() -> int:
	var count := 0
	for node in root.find_children("*", "AudioStreamPlayer", true, false):
		var player := node as AudioStreamPlayer
		if player.playing and String(player.bus).ends_with("Music"):
			count += 1
	return count

func _expect(track: AudioStream, label: String) -> void:
	for i in 3: await process_frame
	ck(_music() == track, "%s (%s)" % [label, _music().resource_path if _music() else "none"])
	ck(_players_playing() == 1, "%s: one music player plays (%d)" % [label, _players_playing()])

func _fight_music() -> void:
	var am: Node = root.get_node("AudioManager")
	var eb: Node = root.get_node("EventBus")
	var fight: AudioStream = am.music["fight"]
	var boss: AudioStream = am.music["boss"]
	ck(fight != null and boss != null and fight != boss, "sound_events.json → music: fight and boss tracks load, different")
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: no «?» tips in this run
	set_meta("start_new_game", true)
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var room: AudioStream = game.map.get_node(^"Music").stream
	ck(_music() == room, "the room's Music plays (%s)" % room.resource_path)
	ck(room != fight and room != boss, "the start room's track differs from both fight tracks")

	eb.combat_state_changed.emit(true)
	await _expect(fight, "fight in → the battle track")
	eb.combat_state_changed.emit(false)
	await _expect(room, "fight out → the room's track")

	var arena := Node.new()
	game.map.add_child(arena)
	eb.boss_fight_changed.emit(arena, true)
	await _expect(boss, "boss fight → the boss track")
	eb.combat_state_changed.emit(true)
	await _expect(boss, "a fight inside the boss fight → still the boss track")
	eb.combat_state_changed.emit(false)
	await _expect(boss, "that fight ends inside the boss fight → still the boss track")
	eb.boss_fight_changed.emit(arena, false)
	await _expect(room, "boss fight over → the room's track")

	eb.combat_state_changed.emit(true)
	eb.boss_fight_changed.emit(arena, true)
	await _expect(boss, "boss fight during a fight → the boss track")
	eb.boss_fight_changed.emit(arena, false)
	await _expect(fight, "boss down, hero still fighting → the battle track")
	eb.combat_state_changed.emit(false)
	await _expect(room, "then the room's track")

	eb.boss_fight_changed.emit(arena, true)
	arena.free()  # зала зникла посеред бою (телепорт, меню)
	eb.combat_state_changed.emit(true)
	await _expect(fight, "the arena gone → no boss fight left, a new fight → the battle track")
	eb.combat_state_changed.emit(false)
	await _expect(room, "and back to the room's track")
	game.queue_free()
	for i in 4: await process_frame
