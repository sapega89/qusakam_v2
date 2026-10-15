extends RefCounted

## Завдання NPC (D162, D175) — дані в Resources/Data/quests.json, стан у прапорцях Game
## (task_<id>_taken, task_<id>_done), тож він зберігається разом із сейвом.
## Без UI: NPC питає, що в нього є, і викликає take() / turn_in().

const DATA := "res://SampleProject/Resources/Data/quests.json"
const ACTIVE := "active"
const DONE := "done"

static var _tasks: Array = []


static func tasks() -> Array:
	if _tasks.is_empty():
		_tasks = JSON.parse_string(FileAccess.get_file_as_string(DATA)).tasks
	return _tasks


static func status(task: Dictionary) -> String:
	var game := Game.get_singleton()
	if game.get_quest_flag("task_%s_done" % task.id):
		return DONE
	if game.get_quest_flag("task_%s_taken" % task.id):
		return ACTIVE
	return ""


static func _set_status(task: Dictionary, value: String) -> void:
	Game.get_singleton().set_quest_flag("task_%s_%s" % [task.id, "done" if value == DONE else "taken"], true)


## Чим NPC зараз може зайняти гравця: взяте й не здане або доступне до взяття.
static func open_tasks(giver: String) -> Array:
	return tasks().filter(func(t: Dictionary) -> bool:
		if t.giver != giver or status(t) == DONE:
			return false
		var after: String = t.get("after", "")
		return after == "" or status(_by_id(after)) == DONE)


static func _by_id(id: String) -> Dictionary:
	return tasks().filter(func(t: Dictionary) -> bool: return t.id == id)[0]


static func _inventory() -> Node:
	return ServiceLocatorHelper.get_service_locator().get_inventory_manager()


static func take(task: Dictionary) -> void:
	for item_id in task.gives:
		_inventory().add_item(item_id, int(task.gives[item_id]))
	_set_status(task, ACTIVE)


static func can_turn_in(task: Dictionary) -> bool:
	for item_id in task.needs:
		if _inventory().get_item_count(item_id) < int(task.needs[item_id]):
			return false
	return true


static func turn_in(task: Dictionary) -> void:
	for item_id in task.reward:
		_inventory().add_item(item_id, int(task.reward[item_id]))
	_set_status(task, DONE)
