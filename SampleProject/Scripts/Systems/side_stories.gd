extends RefCounted

## Побічні історії Журналу (D180, D791; Figma journal-side-stories 192:1636) — без окремого списку:
## кожне завдання NPC з quests.json, яке герой узяв або здав, — побічна історія.
## Порядок — локації з locations.json, у кожній — завдання в порядку quests.json.
##   const SideStories = preload("res://SampleProject/Scripts/Systems/side_stories.gd")
##   SideStories.entries("city")  # лише Місто; ALL — усі локації

const LocationDB = preload("res://SampleProject/Scripts/Systems/LocationDB.gd")
## load(), не preload: сервіс тягне Game (як у NpcBase).
const TASKS_PATH := "res://SampleProject/Scripts/Tasks/task_service.gd"
const ALL := "all"
const DONE := "done"
const ACTIVE := "active"


## Записи для списку журналу: {id, title, state, group, description, side: {...}}.
## objectives — ціль, поки історія триває; side — лише в побічної історії: замовник, його слова, локація, кінець, нагороди.
static func entries(region: String) -> Array:
	var tasks: GDScript = load(TASKS_PATH)
	var by_location: Dictionary = {}
	for loc: Dictionary in LocationDB.all():
		by_location[loc.id] = []
	for task: Dictionary in tasks.tasks():
		var status: String = tasks.status(task)
		if status == "" or (region != ALL and task.location != region):
			continue
		var location: String = LocationDB.location(task.location).name
		var client: Resource = _client(task.giver)
		var state := DONE if status == tasks.DONE else ACTIVE
		# Ціль — лише поки історія триває; скінчена показує свій кінець.
		by_location[task.location].append({"id": "side/" + task.id, "title": task.title, "state": state,
			"group": location, "description": task.description, "portrait": client.portrait,
			"objectives": [task.objective] if state == ACTIVE else [],
			"side": {"client": client.character_name, "location": location, "quote": task.quote,
				"outcome": task.outcome, "rewards": reward_lines(task.reward)}})
	var out: Array = []
	for items: Array in by_location.values():
		out.append_array(items)
	return out


## Замовник — персонаж DialogueQuest з id = giver великими літерами (merchant → MERCHANT): ім'я й портрет ті самі,
## що у вікні діалогу (D321).
static func _client(giver: String) -> Resource:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var character: Resource = root.get_node("DialogueQuest").CharacterDB.get_character_from_id(giver.to_upper())
	assert(character != null, "SideStories: no DialogueQuest character for giver %s" % giver)
	return character


## Нагорода рядками «Coin × 60» мовою гри, як у вікні «You obtained:».
static func reward_lines(reward: Dictionary) -> Array:
	var database: Node = (Engine.get_main_loop() as SceneTree).root.get_node("ItemDatabase")
	var lines: Array = []
	for item_id: String in reward:
		lines.append("%s × %d" % [database.get_item_name(item_id), int(reward[item_id])])
	return lines
