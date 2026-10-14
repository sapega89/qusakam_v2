extends SceneTree

## Кожне звернення EventBus.<signal>.emit/connect у SampleProject/ — до сигналу, що існує,
## і кожен обробник у connect() приймає стільки аргументів, скільки шле сигнал.
## Ловить те, що раніше ховалось за мертвими Engine.has_singleton-гілками:
## EventBus.enemy_state_changed / animation_changed (сигналів не було),
## TutorialManager._on_enemy_died(1 арг) на enemy_died(2 арг) — 2026-10-12.
##   godot --headless --path . --script res://SampleProject/UI/verify_eventbus_wiring.gd

var fails: Array[String] = []

func _walk(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_walk(dir.path_join(d), out)

func _initialize() -> void:
	var bus: Node = root.get_node("EventBus")
	var arg_count := {}
	for sig in bus.get_signal_list():
		arg_count[sig.name] = sig.args.size()

	var use_re := RegEx.create_from_string("EventBus\\.(\\w+)\\.(emit|connect|disconnect|is_connected)\\b")
	var connect_re := RegEx.create_from_string("EventBus\\.(\\w+)\\.connect\\((\\w+)(\\.bind\\(([^)]*)\\))?")
	var files: Array = []
	_walk("res://SampleProject", files)
	var checked := 0
	for path in files:
		if path.ends_with("verify_eventbus_wiring.gd"):
			continue
		var src := FileAccess.get_file_as_string(path)
		var lines := src.split("\n")
		for i in lines.size():
			var line := lines[i].strip_edges()
			if line.begins_with("#"):
				continue
			for m in use_re.search_all(line):
				checked += 1
				if not arg_count.has(m.get_string(1)):
					fails.append("%s:%d EventBus.%s — no such signal" % [path, i + 1, m.get_string(1)])
			for m in connect_re.search_all(line):
				var sig := m.get_string(1)
				if not arg_count.has(sig):
					continue
				var bound := 0
				if m.get_string(4).strip_edges() != "":
					bound = m.get_string(4).split(",").size()
				var func_re := RegEx.create_from_string("(?m)^func " + m.get_string(2) + "\\(([^)]*)\\)")
				var fm := func_re.search(src)
				if fm == null:
					continue  # обробник в іншому файлі або лямбда — не перевіряємо
				var params := fm.get_string(1).strip_edges()
				var total := 0 if params == "" else params.split(",").size()
				var required := 0
				if params != "":
					for p in params.split(","):
						if not "=" in p:
							required += 1
				var sent: int = arg_count[sig] + bound
				if sent < required or sent > total:
					fails.append("%s:%d %s takes %d..%d args, EventBus.%s sends %d" % [
						path, i + 1, m.get_string(2), required, total, sig, sent])
	for f in fails:
		print("  FAIL " + f)
	print("checked %d EventBus references in %d scripts" % [checked, files.size()])
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit(0 if fails.is_empty() else 1)
