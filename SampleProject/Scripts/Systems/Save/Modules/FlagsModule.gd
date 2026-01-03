extends SaveModule
class_name FlagsModule

## 🚩 FlagsModule - Сохранение флагов
## Управляет: квесты, диалоги, катсцены, боссы, локации, DialogueQuest флаги

func _ready():
	module_name = "FlagsModule"

## Сохраняет все флаги
func save() -> Dictionary:
	var data = {
		"quest_flags": {},
		"cutscene_flags": {},
		"boss_flags": {},
		"location_flags": {},
		"dialogue_flags": {},
		"completed_dialogues": {}
	}

	# Сохраняем флаги из Game.gd
	_save_game_flags(data)

	# Сохраняем флаги DialogueQuest
	_save_dialogue_quest_flags(data)

	log_info("Flags saved: quests=%d, dialogues=%d, bosses=%d" % [
		data["quest_flags"].size(),
		data["dialogue_flags"].size(),
		data["boss_flags"].size()
	])

	return data

## Загружает все флаги
func load_data(data: Dictionary) -> void:
	if not validate_data(data):
		log_error("Invalid flags data")
		return

	# Загружаем флаги в Game.gd
	_load_game_flags(data)

	# Загружаем флаги DialogueQuest
	_load_dialogue_quest_flags(data)

	# Загружаем пройденные диалоги
	if "completed_dialogues" in data:
		log_info("Loaded completed dialogues: %d" % data.completed_dialogues.size())

	log_info("Flags loaded: quests=%d, dialogues=%d, bosses=%d" % [
		data.get("quest_flags", {}).size(),
		data.get("dialogue_flags", {}).size(),
		data.get("boss_flags", {}).size()
	])

## Возвращает данные без сохранения
func get_data() -> Dictionary:
	return save()

## Устанавливает данные без загрузки из файла
func set_data(data: Dictionary) -> void:
	load_data(data)

## Сохраняет флаги квестов/катсцен/боссов/локаций из Game.gd
func _save_game_flags(data: Dictionary) -> void:
	# Получаем Game singleton
	var game = Game.get_singleton() if Game.get_singleton() != null else null
	if not game:
		log_warning("Game singleton not found, cannot save game flags")
		return

	# Сохраняем флаги из Game.gd (если методы есть)
	if game.has_method("get_quest_flags"):
		data["quest_flags"] = game.get_quest_flags()
	if game.has_method("get_cutscene_flags"):
		data["cutscene_flags"] = game.get_cutscene_flags()
	if game.has_method("get_boss_flags"):
		data["boss_flags"] = game.get_boss_flags()
	if game.has_method("get_location_flags"):
		data["location_flags"] = game.get_location_flags()

## Загружает флаги квестов/катсцен/боссов/локаций в Game.gd
func _load_game_flags(data: Dictionary) -> void:
	# Получаем Game singleton
	var game = Game.get_singleton() if Game.get_singleton() != null else null
	if not game:
		log_warning("Game singleton not found, cannot load game flags")
		return

	# Загружаем флаги в Game.gd (если методы существуют)
	if "quest_flags" in data and game.has_method("set_quest_flags"):
		game.set_quest_flags(data.quest_flags)
	if "cutscene_flags" in data and game.has_method("set_cutscene_flags"):
		game.set_cutscene_flags(data.cutscene_flags)
	if "boss_flags" in data and game.has_method("set_boss_flags"):
		game.set_boss_flags(data.boss_flags)
	if "location_flags" in data and game.has_method("set_location_flags"):
		game.set_location_flags(data.location_flags)

## Сохраняет флаги DialogueQuest
func _save_dialogue_quest_flags(data: Dictionary) -> void:
	# Пробуем получить DialogueQuest
	var dq = null
	if Engine.has_singleton("DialogueQuest"):
		dq = Engine.get_singleton("DialogueQuest")
	elif get_tree() and get_tree().root:
		dq = get_tree().root.get_node_or_null("DialogueQuest")

	if dq and dq.has_method("get") and dq.get("Flags"):
		var flags = dq.Flags
		if flags and flags.has_method("get_flag"):
			var flag_registry = null
			if "flag_registry" in flags:
				flag_registry = flags.flag_registry
			else:
				flag_registry = flags.get("flag_registry")

			if flag_registry is Dictionary:
				data["dialogue_flags"] = flag_registry.duplicate()
				log_info("Saved DialogueQuest flags: %d" % data["dialogue_flags"].size())
			else:
				log_warning("DialogueQuest flag_registry is not Dictionary (type: %s)" % typeof(flag_registry))
		else:
			log_warning("DialogueQuest.Flags missing required methods")
	else:
		log_warning("DialogueQuest not found for saving flags")

## Загружает флаги DialogueQuest
func _load_dialogue_quest_flags(data: Dictionary) -> void:
	if not data.has("dialogue_flags") or data.dialogue_flags == null or data.dialogue_flags.is_empty():
		log_info("No saved DialogueQuest flags to load")
		return

	# Пробуем получить DialogueQuest
	var dq = null
	if Engine.has_singleton("DialogueQuest"):
		dq = Engine.get_singleton("DialogueQuest")
	elif get_tree() and get_tree().root:
		dq = get_tree().root.get_node_or_null("DialogueQuest")

	if dq and dq.has_method("get") and dq.get("Flags"):
		var flags = dq.Flags
		if flags and flags.has_method("set_flag"):
			var saved_flags = data.dialogue_flags
			for flag_name in saved_flags:
				var flag_value = saved_flags[flag_name]
				flags.set_flag(flag_name, flag_value)
			log_info("Loaded DialogueQuest flags: %d" % saved_flags.size())
		else:
			log_warning("DialogueQuest.Flags missing set_flag method")
	else:
		log_warning("DialogueQuest not found for loading flags")

## Валидация данных
func validate_data(data: Dictionary) -> bool:
	if not super.validate_data(data):
		return false

	# Флаги могут быть пустыми - это нормально
	return true
