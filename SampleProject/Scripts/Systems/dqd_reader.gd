extends RefCounted
class_name DqdReader

## Читає репліки .dqd лише для показу (D158, D161): "say|SPEAKER|text" → {speaker, text}.
## Інші рядки (exit, коментарі) пропускає. Вибір і розгалуження (перепис D727, вчинки D725) пропускає разом з усім,
## що всередині branch…branch|end: показ — лише спільні репліки, без відповідей гравця.
## [param path] — український шлях розмови; читається файл мовою гри (DialoguePaths, BACKLOG 31).

static func lines(path: String) -> Array[Dictionary]:
	assert(FileAccess.file_exists(path), "DqdReader: no dialogue at %s" % path)
	var out: Array[Dictionary] = []
	var depth := 0
	for raw in FileAccess.get_file_as_string(DialoguePaths.localized(path)).split("\n"):
		var parts := raw.split("|")
		if parts[0].strip_edges() == "branch":
			depth += -1 if parts.size() > 1 and parts[1].strip_edges() == "end" else 1
		elif depth == 0 and parts.size() >= 3 and parts[0].strip_edges() == "say":
			out.append({"speaker": parts[1].strip_edges(),
				"text": DialoguePaths.solve_names("|".join(parts.slice(2)).strip_edges())})
	return out
