extends RefCounted
class_name DqdReader

## Читає репліки .dqd лише для показу (D158, D161): "say|SPEAKER|text" → {speaker, text}.
## Інші рядки (exit, коментарі) пропускає. Розгалужень немає (D113), тож порядок файлу = порядок розмови.
## [param path] — український шлях розмови; читається файл мовою гри (DialoguePaths, BACKLOG 31).

static func lines(path: String) -> Array[Dictionary]:
	assert(FileAccess.file_exists(path), "DqdReader: no dialogue at %s" % path)
	var out: Array[Dictionary] = []
	for raw in FileAccess.get_file_as_string(DialoguePaths.localized(path)).split("\n"):
		var parts := raw.split("|")
		if parts.size() >= 3 and parts[0].strip_edges() == "say":
			out.append({"speaker": parts[1].strip_edges(), "text": "|".join(parts.slice(2)).strip_edges()})
	return out
