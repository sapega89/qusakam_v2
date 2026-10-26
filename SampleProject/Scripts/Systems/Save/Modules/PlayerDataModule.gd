extends SaveModule
class_name PlayerDataModule

const Charms = preload("res://SampleProject/Scripts/Systems/Charms.gd")

## Старі id мовців DialogueQuest → нові (BACKLOG 31: id стали ASCII, імена — ключі перекладу).
const RENAMED_SPEAKERS := {"Торговец": "MERCHANT", "Алісия": "ALISIA", "Астрит": "ASTRIT", "Уризен": "URIZEN"}

## 🎮 PlayerDataModule - Сохранение данных игрока
## Управляет: позиция, здоровье, характеристики, навыки, экипировка

func _ready():
	module_name = "PlayerDataModule"

## Сохраняет данные игрока
func save() -> Dictionary:
	var data = {}

	# Получаем GameManager через ServiceLocator
	var game_manager = _get_game_manager()
	if not game_manager:
		log_error("GameManager not found, cannot save player data")
		return data

	# Получаем player_state
	if not "player_state" in game_manager:
		log_error("player_state not found in GameManager")
		return data

	var player_state = game_manager.player_state

	# Сохраняем здоровье
	data["current_health"] = player_state.get("current_health", 0)
	data["max_health"] = player_state.get("max_health", 0)

	# Сохраняем позицию
	# Позицію перед сейвом пише Game._save_full_game_data_to_save_system(); на завантаженні її ставить Game (B82).
	var pos: Vector2 = player_state.player_position
	data["player_position"] = {"x": pos.x, "y": pos.y}

	# Сохраняем текущую сцену
	data["current_scene"] = player_state.get("current_scene", "")

	# Сохраняем характеристики (без level/experience)
	data["strength"] = player_state.get("strength", 10)
	data["intelligence"] = player_state.get("intelligence", 10)
	data["dexterity"] = player_state.get("dexterity", 10)
	data["constitution"] = player_state.get("constitution", 10)

	# Сохраняем навыки
	data["unlocked_skills"] = player_state.get("unlocked_skills", []).duplicate()
	data["companion_party"] = player_state.companion_party.duplicate()  # D220
	data["seen_tutorials"] = player_state.seen_tutorials.duplicate()  # D289
	data["playthrough_id"] = player_state.playthrough_id  # D727
	data["journal"] = player_state.journal.duplicate(true)  # D290

	# Прогрес навичок. Схема розширювана: equipped_skills можна додати пізніше,
	# старі збереження просто не матимуть ключа і отримають значення за умовчанням.
	data["job_points"] = player_state.get("job_points", 0)
	data["equipped_skills"] = player_state.get("equipped_skills", []).duplicate()
	data["skill_ranks"] = player_state.get("skill_ranks", {}).duplicate()
	data["skill_charges"] = player_state.get("skill_charges", {}).duplicate()  # D504: заряди фляги
	data["oath"] = player_state.oath  # D280
	data["leanings"] = player_state.leanings.duplicate()  # D725
	data["attribute_points"] = player_state.attribute_points  # D335
	data["attributes"] = player_state.attributes.duplicate()
	var xp: XPManager = ServiceLocator.get_xp_manager()  # B79: рівень і досвід переживають сейв
	data["level"] = xp.current_level
	data["xp"] = xp.current_xp
	data["current_sp"] = player_state.get("current_sp", 0)
	data["max_sp"] = player_state.get("max_sp", 0)

	# Сохраняем экипировку
	data["equipment"] = player_state.get("equipment", {}).duplicate()
	data["weapon_in_hand"] = player_state.get("weapon_in_hand", "")  # D202
	data["charms"] = player_state.charms.duplicate(true)  # D592

	# Сохраняем информацию о персонаже
	data["class_id"] = player_state.get("class_id", "champion")
	data["subclass_id"] = player_state.get("subclass_id", "paladin")
	data["character_id"] = player_state.get("character_id", GameSettings.DEFAULT_CHARACTER_ID)

	# Сохраняем игровое время
	data["game_time"] = player_state.get("game_time", 0.0)

	# Сохраняем имя игрока
	data["player_name"] = player_state.get("player_name", "Player")

	log_info("Player data saved: position=%s, health=%d/%d" % [pos, data["current_health"], data["max_health"]])

	return data

## Загружает данные игрока
func load_data(data: Dictionary) -> void:
	# Получаем GameManager через ServiceLocator
	var game_manager = _get_game_manager()
	if not game_manager:
		log_error("GameManager not found, cannot load player data")
		return

	# Получаем player_state
	if not "player_state" in game_manager:
		log_error("player_state not found in GameManager")
		return

	var player_state = game_manager.player_state

	# Загружаем здоровье (только если есть сохраненные данные)
	if "current_health" in data and data.current_health > 0:
		player_state.current_health = data.current_health
	if "max_health" in data and data.max_health > 0:
		player_state.max_health = data.max_health

	# Загружаем позицию
	# Кожен сейв пише позицію; без неї Game поставив би героя в дефолтну точку — кажемо голосно (B82).
	if "player_position" in data:
		var pos_data: Dictionary = data.player_position
		player_state.player_position = Vector2(pos_data.x, pos_data.y)
	else:
		log_error("save slot has no player_position")

	# Загружаем текущую сцену
	if "current_scene" in data:
		player_state.current_scene = data.current_scene

	# Загружаем характеристики
	if "strength" in data:
		player_state.strength = data.strength
	if "intelligence" in data:
		player_state.intelligence = data.intelligence
	if "dexterity" in data:
		player_state.dexterity = data.dexterity
	if "constitution" in data:
		player_state.constitution = data.constitution

	# Загружаем навыки
	# Відсутні ключі = старе збереження: беремо поточне значення як типове.
	player_state.job_points = int(data.get("job_points", player_state.get("job_points", 0)))
	# Старі збереження не мають equipped_skills — тоді лишаємо поточний лоадаут.
	if "equipped_skills" in data and data.equipped_skills is Array:
		var loadout: Array = []
		for entry in data.equipped_skills:
			loadout.append(String(entry))
		player_state.equipped_skills = loadout
	player_state.skill_ranks = data.get("skill_ranks", {}).duplicate()
	player_state.skill_charges = data.get("skill_charges", {}).duplicate()  # D504: сейв без зарядів — фляга повна
	player_state.oath = String(data.get("oath", ""))  # D280: сейв без клятви — клятви немає
	# D725: сейв без нахилів — усі нулі
	var leanings: Dictionary = data.get("leanings", {})
	player_state.leanings = {"samal": float(leanings.get("samal", 0.0)), "contract": float(leanings.get("contract", 0.0)),
		"none": float(leanings.get("none", 0.0))}
	ServiceLocator.get_xp_manager().restore(int(data.level), int(data.xp))  # B79
	# D335: сейв до очок атрибутів — нічого не вкладено, а невкладених стільки, скільки дали б рівні.
	var spent_attributes: Dictionary = {}
	for attribute_id: String in data.get("attributes", {}):
		spent_attributes[attribute_id] = int(data.attributes[attribute_id])
	player_state.attributes = spent_attributes
	player_state.attribute_points = int(data.get("attribute_points",
			ServiceLocator.get_attribute_manager().points_for_level(int(data.level))))
	EventBus.attributes_changed.emit()
	player_state.max_sp = int(data.get("max_sp", player_state.get("max_sp", 0)))

	if "unlocked_skills" in data:
		var skills_data = data.unlocked_skills
		if skills_data is Array:
			var typed_skills: Array[String] = []
			for skill in skills_data:
				if skill is String:
					typed_skills.append(skill)
			player_state.unlocked_skills = typed_skills
		else:
			player_state.unlocked_skills = []

	ServiceLocator.get_skill_manager().fit_ranks()  # D674: сейв з рангами понад нові межі
	# Межа SP — з пасивками й Wisdom (D284, D335), тож після навичок і атрибутів.
	player_state.current_sp = clampi(int(data.get("current_sp", player_state.get("current_sp", 0))),
			0, ServiceLocator.get_skill_manager().get_max_sp())

	player_state.companion_party = data.companion_party.duplicate()  # D220
	player_state.seen_tutorials = data.seen_tutorials.duplicate()  # D289
	# Сейви до D727 не мають проходження — кожен лишає нове з reset_player_state(), наступний запис його вже несе.
	if "playthrough_id" in data:
		player_state.playthrough_id = String(data.playthrough_id)
	player_state.journal = data.journal.duplicate(true)  # D290
	# Сейви до BACKLOG 31 пишуть кириличні id мовців — переписуємо на нові (DialogueQuest їх уже не знає).
	player_state.journal.people = player_state.journal.people.map(func(id: String) -> String: return RENAMED_SPEAKERS.get(id, id))
	# Сейви до D621 не мають знайдених шматків історії.
	player_state.journal.get_or_add("stories", [])

	# Загружаем экипировку
	if "equipment" in data:
		player_state.equipment = data.equipment.duplicate() if data.equipment is Dictionary else {}
	player_state.weapon_in_hand = String(data.get("weapon_in_hand", ""))  # D202
	EventBus.weapon_in_hand_changed.emit(player_state.weapon_in_hand)  # профіль удару й HUD — під завантажену зброю
	# Сейви до D592 не мають оберегів — герой починає з порожніми слотами.
	player_state.charms = data.charms.duplicate(true) if "charms" in data else Charms.initial_state()
	EventBus.charms_changed.emit()

	# Загружаем информацию о персонаже
	if "class_id" in data:
		player_state.class_id = data.class_id
	if "subclass_id" in data:
		player_state.subclass_id = data.subclass_id
	if "character_id" in data:
		player_state.character_id = data.character_id

	# Загружаем игровое время
	if "game_time" in data:
		player_state.game_time = data.game_time

	# Загружаем имя игрока
	if "player_name" in data:
		player_state.player_name = data.player_name

	log_info("Player data loaded: position=%s, health=%d/%d" % [player_state.player_position, player_state.current_health, player_state.max_health])

func _get_game_manager():
	return ServiceLocator.get_game_manager()

