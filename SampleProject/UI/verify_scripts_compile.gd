extends SceneTree

## Кожен .gd у SampleProject/ компілюється. Ловить зламані скрипти, які жодна
## сцена в тестах не завантажує (2026-10-12: GameMusicManager, DialogueRunner).
## Скрипти вантажаться після autoload, тож посилання на ServiceLocator тощо — валідні.
## І кожен ext_resource у кожній сцені/ресурсі справді вживається (B42: Game.tscn вантажив ObjectiveHUD.tscn,
## якого жоден вузол не створював).
##   godot --headless --path . --script res://SampleProject/UI/verify_scripts_compile.gd

func _walk(dir: String, out: Array, exts: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in exts:
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_walk(dir.path_join(d), out, exts)

## ext_resource, на який у файлі немає жодного ExtResource("id"), — «id (path)».
func _unused_ext_resources(path: String) -> Array[String]:
	var text := FileAccess.get_file_as_string(path)
	var re := RegEx.create_from_string("\\[ext_resource [^\\]]*path=\"([^\"]+)\"[^\\]]*id=\"([^\"]+)\"\\]")
	var unused: Array[String] = []
	for m in re.search_all(text):
		if not text.contains("ExtResource(\"%s\")" % m.get_string(2)):
			unused.append("%s (%s)" % [m.get_string(2), m.get_string(1)])
	return unused

func _initialize() -> void:
	var files: Array = []
	_walk("res://SampleProject", files, ["gd"])
	var fails: Array[String] = []
	for f in files:
		var script: GDScript = load(f)
		if script == null or not script.can_instantiate():
			fails.append(f)
			print("  FAIL ", f)
	print("compiled %d scripts" % files.size())
	var scenes: Array = []
	_walk("res://SampleProject", scenes, ["tscn", "tres"])
	for f in scenes:
		var unused := _unused_ext_resources(f)
		if not unused.is_empty():
			fails.append("%s: unused %s" % [f, ", ".join(unused)])
			print("  FAIL %s declares ext_resource never used: %s" % [f, ", ".join(unused)])
	print("checked ext_resources in %d scenes/resources" % scenes.size())
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
