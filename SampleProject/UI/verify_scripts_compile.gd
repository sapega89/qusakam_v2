extends SceneTree

## Кожен .gd у SampleProject/ компілюється. Ловить зламані скрипти, які жодна
## сцена в тестах не завантажує (2026-10-12: GameMusicManager, DialogueRunner).
## Скрипти вантажаться після autoload, тож посилання на ServiceLocator тощо — валідні.
##   godot --headless --path . --script res://SampleProject/UI/verify_scripts_compile.gd

func _walk(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_walk(dir.path_join(d), out)

func _initialize() -> void:
	var files: Array = []
	_walk("res://SampleProject", files)
	var fails: Array[String] = []
	for f in files:
		var script: GDScript = load(f)
		if script == null or not script.can_instantiate():
			fails.append(f)
			print("  FAIL ", f)
	print("compiled %d scripts" % files.size())
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
