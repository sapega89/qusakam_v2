extends SceneTree

## Музика (music_plan): кожна кімната карти MetSys і головне меню мають вузол Music —
## AudioStreamPlayer на шині Music з autoplay; його підхоплює ProjectMusicController
## (maaacks) і сам перемикає трек між сценами. Трек зациклений і лежить у проєкті, не в assets/.
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
		ck(music.stream is AudioStreamOggVorbis and music.stream.loop, "%s: a looping OGG" % name)
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
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
