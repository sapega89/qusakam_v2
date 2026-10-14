extends SaveModule
class_name FlagsModule

## 🚩 FlagsModule - Сохранение флагов
## Управляет: квесты, катсцены, боссы, локации (Game.gd) и флаги DialogueQuest

func _ready():
	module_name = "FlagsModule"

func save() -> Dictionary:
	var game := Game.get_singleton()
	var data := {
		"quest_flags": game.get_quest_flags(),
		"cutscene_flags": game.get_cutscene_flags(),
		"boss_flags": game.get_boss_flags(),
		"location_flags": game.get_location_flags(),
		"room_state": game.get_room_states(),
		"dialogue_flags": DialogueQuest.Flags.flag_registry.duplicate(),
	}
	log_info("Flags saved: quests=%d, dialogues=%d, bosses=%d" % [
		data.quest_flags.size(), data.dialogue_flags.size(), data.boss_flags.size()])
	return data

func load_data(data: Dictionary) -> void:
	var game := Game.get_singleton()
	game.set_quest_flags(data.quest_flags)
	game.set_cutscene_flags(data.cutscene_flags)
	game.set_boss_flags(data.boss_flags)
	game.set_location_flags(data.location_flags)
	game.set_room_states(data.room_state)
	for flag_name in data.dialogue_flags:
		DialogueQuest.Flags.set_flag(flag_name, data.dialogue_flags[flag_name])
	log_info("Flags loaded: quests=%d, dialogues=%d, bosses=%d" % [
		data.quest_flags.size(), data.dialogue_flags.size(), data.boss_flags.size()])
