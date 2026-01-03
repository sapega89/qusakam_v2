extends Node

# 💾 SaveSystem - Збереження стану інвентарю в файл
# Працює разом з GameManager для збереження централізованого інвентарю

# Сигнали
signal load_game(player_data: Dictionary)

# Система сохранения и загрузки данных игры

const SAVE_FILE_PATH = "user://savegames/"
const PLAYER_DATA_FILE = "player_data.json"
const GAME_SETTINGS_FILE = "game_settings.json"

# Структура данных игрока (тільки для збереження в файл)
# ИСКЛЮЧЕНО: level, experience, experience_to_next_level, stat_points
var player_data = {
	"player_name": "Player",
	"current_health": 0,  # 0 означає "не встановлено"
	"max_health": 0,      # 0 означає "не встановлено"
	"player_position": {"x": 100, "y": 549},
	"current_scene": "",  # Имя текущей сцены (например, "prolog5", "VillageScene")
	"save_location_name": "",  # Название локации, где было сделано сохранение (например, "Village Area 1")
	"unlocked_skills": [],
	"game_time": 0.0,
	"last_save_time": "",
	# Централізований інвентар
	"inventory": {
		"potions": 0,  # 0 означає "не встановлено"
		"coins": 0,
		"keys": 0,
		"items": []
	},
	# Характеристики (без level/experience)
	"strength": 10,
	"intelligence": 10,
	"dexterity": 10,
	"constitution": 10,
	# Экипировка
	"equipment": {
		"sword": null,
		"polearm": null,
		"dagger": null,
		"axe": null,
		"bow": null,
		"staff": null,
		"shield": null,
		"head": null,
		"body": null,
		"accessory_1": null,
		"accessory_2": null
	},
	# Информация о персонаже
	"class_id": "champion",
	"subclass_id": "paladin",
	"character_id": "player_1",
	# Пройденные диалоги: dialogue_id -> true
	"completed_dialogues": {},
	# Флаги DialogueQuest: flag_name -> value
	"dialogue_flags": {},
	# Флаги квестов, катсцен, боссов, локаций (для Game.gd)
	"quest_flags": {},
	"cutscene_flags": {},
	"boss_flags": {},
	"location_flags": {}
}

# Настройки игры
var game_settings = {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 0.9,
	"fullscreen": false,
	"vsync": true,
	"language": "en"
}

func _ready():
	# Создаем папку для сохранений если её нет
	_create_save_directory()
	
	# Загружаем настройки при запуске (используем call_deferred для получения менеджеров)
	call_deferred("load_game_settings")
	
	# Подключаем обработку выхода из игры
	# В Godot 4 используем сигнал close_requested если доступен
	if get_tree().root.has_signal("close_requested"):
		get_tree().root.close_requested.connect(_on_window_close_requested)
	
	# Підписуємося на події переходу сцен для автоматичного збереження
	call_deferred("_connect_scene_events")

func _connect_scene_events():
	"""Підписується на події переходу сцен для автоматичного збереження"""
	if Engine.has_singleton("EventBus"):
		EventBus.scene_transition_completed.connect(_on_scene_transition_completed)
		EventBus.dialogue_finished.connect(_on_dialogue_finished)
		print("💾 SaveSystem: Connected to scene and dialogue events")
	else:
		# EventBus може бути недоступний на початку - це нормально
		# Не виводимо попередження, щоб не засмічувати консоль
		pass

# Налаштування автоматичного збереження
var enable_auto_save_on_scene_transition: bool = false

func _on_scene_transition_completed(scene_path: String):
	"""Автоматично зберігає гру при переході в важливі сцени (якщо увімкнено)"""
	# Якщо автоматичне збереження вимкнено, не зберігаємо
	# За замовчуванням збереження відбувається тільки через SavePoint (NPC save point)
	if not enable_auto_save_on_scene_transition:
		return
	
	# Список сцен, при переході в які потрібно автоматично зберігати
	var auto_save_scenes = [
		"village1",
		"village",
		"town",
		"hub"
	]
	
	# Перевіряємо, чи це важлива сцена для збереження
	var should_save = false
	for save_scene in auto_save_scenes:
		if save_scene in scene_path.to_lower():
			should_save = true
			break
	
	if should_save:
		print("💾 SaveSystem: Auto-saving after transition to: ", scene_path)
		# Використовуємо call_deferred, щоб збереження відбулося після повного завантаження сцени
		call_deferred("save_player_data")

func _on_dialogue_finished(dialogue_id: String = ""):
	"""Отслеживает завершенные диалоги и сохраняет их"""
	if dialogue_id == "":
		return
	
	# Добавляем диалог в список пройденных
	if not player_data.has("completed_dialogues"):
		player_data.completed_dialogues = {}
	
	player_data.completed_dialogues[dialogue_id] = true
	print("💬 SaveSystem: Диалог добавлен в список пройденных: ", dialogue_id)

func _create_save_directory():
	"""Создает папку для сохранений если её не существует"""
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("savegames"):
		dir.make_dir("savegames")

func save_player_data():
	"""Сохраняет инвентар и состояние игрока в файл"""
	# Отримуємо дані з GameManager
	var game_manager = null
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_game_manager"):
			game_manager = service_locator.get_game_manager()
	
	if game_manager:
		# Зберігаємо інвентар
		if game_manager.has("inventory_manager") and game_manager.inventory_manager:
			player_data.inventory = game_manager.inventory_manager.save_to_dict()
		else:
			player_data.inventory = {}
		
		# Зберігаємо стан гравця
		if game_manager.has("player_state"):
			player_data.current_health = game_manager.player_state.current_health
			player_data.max_health = game_manager.player_state.max_health
			var pos = game_manager.player_state.player_position
			player_data.player_position = {"x": pos.x, "y": pos.y}
			player_data.current_scene = game_manager.player_state.current_scene
			
			# Зберігаємо характеристики (без level/experience)
			player_data.strength = game_manager.player_state.get("strength", 10)
			player_data.intelligence = game_manager.player_state.get("intelligence", 10)
			player_data.dexterity = game_manager.player_state.get("dexterity", 10)
			player_data.constitution = game_manager.player_state.get("constitution", 10)
			
			# Зберігаємо навички
			player_data.unlocked_skills = game_manager.player_state.get("unlocked_skills", []).duplicate()
			
			# Зберігаємо екіпіровку
			player_data.equipment = game_manager.player_state.get("equipment", {}).duplicate()
			
			# Зберігаємо інформацію про персонажа
			player_data.class_id = game_manager.player_state.get("class_id", "champion")
			player_data.subclass_id = game_manager.player_state.get("subclass_id", "paladin")
			player_data.character_id = game_manager.player_state.get("character_id", "player_1")
			
			# Зберігаємо ігровий час
			player_data.game_time = game_manager.player_state.get("game_time", 0.0)
		
		# Зберігаємо назву локації, де було зроблено збереження
		var location_name = ""
		
		# Сначала пробуем получить название из MetSys (текущая комната)
		if Engine.has_singleton("MetSys"):
			var metsys = Engine.get_singleton("MetSys")
			if metsys and metsys.has_method("get_current_room_name"):
				var room_name = metsys.get_current_room_name()
				if not room_name.is_empty():
					location_name = room_name
		
		# Если не получили из MetSys, пробуем LocationManager
		if location_name == "":
			var current_scene_name = player_data.current_scene
			var location_manager = get_tree().current_scene.get_node_or_null("LocationManager")
			if location_manager and location_manager.has_method("get_location_config_for_scene"):
				if current_scene_name != "":
					var location_config = location_manager.get_location_config_for_scene(current_scene_name)
					if location_config != null and not location_config.is_empty() and location_config.has("name"):
						location_name = location_config["name"]
		
		# Если не вдалося отримати з LocationManager, використовуємо fallback по имени сцены
		if location_name == "":
			var current_scene_name = player_data.current_scene
			if current_scene_name.begins_with("VillageScene"):
				var scene_manager = null
				if Engine.has_singleton("ServiceLocator"):
					var service_locator = Engine.get_singleton("ServiceLocator")
					if service_locator and service_locator.has_method("get_scene_manager"):
						scene_manager = service_locator.get_scene_manager()
				var area_number = 1
				if scene_manager and "current_area" in scene_manager:
					area_number = scene_manager.current_area
				location_name = "Village Area " + str(area_number)
			elif current_scene_name.begins_with("prolog"):
				var prolog_num = current_scene_name.replace("prolog", "")
				location_name = "Prolog " + prolog_num
			elif current_scene_name.begins_with("StartingPoint") or current_scene_name.contains("Starting"):
				location_name = "Лаборатория"
			elif not current_scene_name.is_empty():
				# Используем имя сцены как название локации
				location_name = current_scene_name
			else:
				# Только если совсем ничего не найдено, используем "Лаборатория" как fallback
				location_name = "Лаборатория"
		
		player_data.save_location_name = location_name
		
		# Зберігаємо пройденные диалоги (если список уже создан)
		if not player_data.has("completed_dialogues"):
			player_data.completed_dialogues = {}
		
		# Зберігаємо флаги DialogueQuest
		_save_dialogue_quest_flags()
		
		# Зберігаємо флаги квестов/катсцен/боссов/локаций из Game.gd
		_save_game_flags()
	else:
		print("❌ SaveSystem: GameManager not found!")
	
	# Обновляем время последнего сохранения
	player_data.last_save_time = Time.get_datetime_string_from_system()
	
	var file_path = SAVE_FILE_PATH + PLAYER_DATA_FILE
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file:
		var json_string = JSON.stringify(player_data, "\t")
		file.store_string(json_string)
		file.close()
		return true
	else:
		return false

func load_player_data():
	"""Загружает инвентар и состояние игрока в GameManager"""
	var file_path = SAVE_FILE_PATH + PLAYER_DATA_FILE
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			player_data = json.data
			
			# Завантажуємо дані в GameManager
			var game_manager = null
			if Engine.has_singleton("ServiceLocator"):
				var service_locator = Engine.get_singleton("ServiceLocator")
				if service_locator and service_locator.has_method("get_game_manager"):
					game_manager = service_locator.get_game_manager()
			
			if game_manager:
				# Завантажуємо інвентар (тільки якщо є збережені дані)
				if "inventory" in player_data:
					if game_manager.has("inventory_manager") and game_manager.inventory_manager:
						game_manager.inventory_manager.load_from_dict(player_data.inventory)
						if game_manager.has_method("_sync_inventory_dict"):
							game_manager._sync_inventory_dict()  # Для обратной совместимости
				else:
					print("💾 SaveSystem: No saved inventory, using default")
				
				# Завантажуємо стан гравця (тільки якщо є збережені дані)
				if game_manager.has("player_state"):
					if "current_health" in player_data and player_data.current_health > 0:
						game_manager.player_state.current_health = player_data.current_health
					if "max_health" in player_data and player_data.max_health > 0:
						game_manager.player_state.max_health = player_data.max_health
					if "player_position" in player_data:
						var pos_data = player_data.player_position
						if pos_data is Dictionary:
							game_manager.player_state.player_position = Vector2(pos_data.get("x", 100), pos_data.get("y", 549))
						else:
							game_manager.player_state.player_position = pos_data
					if "current_scene" in player_data:
						game_manager.player_state.current_scene = player_data.current_scene
					
					# Завантажуємо характеристики (без level/experience)
					if "strength" in player_data:
						game_manager.player_state.strength = player_data.strength
					if "intelligence" in player_data:
						game_manager.player_state.intelligence = player_data.intelligence
					if "dexterity" in player_data:
						game_manager.player_state.dexterity = player_data.dexterity
					if "constitution" in player_data:
						game_manager.player_state.constitution = player_data.constitution
					
					# Завантажуємо навички
					if "unlocked_skills" in player_data:
						var skills_data = player_data.unlocked_skills
						if skills_data is Array:
							var typed_skills: Array[String] = []
							for skill in skills_data:
								if skill is String:
									typed_skills.append(skill)
							game_manager.player_state.unlocked_skills = typed_skills
						else:
							game_manager.player_state.unlocked_skills = []
					
					# Завантажуємо екіпіровку
					if "equipment" in player_data:
						game_manager.player_state.equipment = player_data.equipment.duplicate() if player_data.equipment is Dictionary else {}
					
					# Завантажуємо інформацію про персонажа
					if "class_id" in player_data:
						game_manager.player_state.class_id = player_data.class_id
					if "subclass_id" in player_data:
						game_manager.player_state.subclass_id = player_data.subclass_id
					if "character_id" in player_data:
						game_manager.player_state.character_id = player_data.character_id
					
					# Завантажуємо ігровий час
					if "game_time" in player_data:
						game_manager.player_state.game_time = player_data.game_time
				
				# Завантажуємо пройденные диалоги
				if "completed_dialogues" in player_data:
					print("💾 SaveSystem: Завантажено пройденных диалогов: ", player_data.completed_dialogues.size())
				
				# Завантажуємо флаги DialogueQuest
				_load_dialogue_quest_flags()
				
				# Завантажуємо флаги квестов/катсцен/боссов/локаций в Game.gd
				_load_game_flags()
				
				print("💾 SaveSystem: Завантажено всі дані гравця (характеристики, навички, екіпіровка, діалоги)")
			
			# Відправляємо сигнал з даними гравця
			load_game.emit(player_data)
			
			return true
		else:
			return false
	else:
		return false

func save_game_settings():
	"""Сохраняет настройки игры"""
	var file_path = SAVE_FILE_PATH + GAME_SETTINGS_FILE
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file:
		var json_string = JSON.stringify(game_settings, "\t")
		file.store_string(json_string)
		file.close()
		print("💾 SaveSystem: Settings saved successfully")
		return true
	else:
		push_error("❌ SaveSystem: Failed to save game settings to " + file_path)
		return false

func load_game_settings():
	"""Загружает настройки игры"""
	var file_path = SAVE_FILE_PATH + GAME_SETTINGS_FILE
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			game_settings = json.data
			_apply_game_settings()
			print("✅ SaveSystem: Settings loaded successfully")
			return true
		else:
			push_error("❌ SaveSystem: Failed to parse game settings JSON: " + json.get_error_message())
			return false
	else:
		# Файл не существует - используем настройки по умолчанию
		print("ℹ️ SaveSystem: No settings file found, using defaults")
		_apply_game_settings()  # Применяем настройки по умолчанию
		return false

func _apply_game_settings():
	"""Применяет загруженные настройки игры"""
	# Применяем настройки звука через AudioManager
	var audio_manager = null
	# Сначала пытаемся получить через autoload напрямую
	if Engine.has_singleton("AudioManager"):
		audio_manager = Engine.get_singleton("AudioManager")
	# Если не найден, пытаемся через ServiceLocator
	if not audio_manager and Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_audio_manager"):
			audio_manager = service_locator.get_audio_manager()
	
	if audio_manager and audio_manager.has_method("apply_volume_settings"):
		audio_manager.apply_volume_settings(game_settings)
	else:
		# Fallback: прямое обращение к AudioServer если AudioManager не найден
		var master_bus = AudioServer.get_bus_index("Master")
		if master_bus >= 0:
			AudioServer.set_bus_volume_db(master_bus, linear_to_db(game_settings.master_volume))
		
		var music_bus = AudioServer.get_bus_index("Music")
		if music_bus >= 0:
			AudioServer.set_bus_volume_db(music_bus, linear_to_db(game_settings.music_volume))
		
		var sfx_bus = AudioServer.get_bus_index("SFX")
		if sfx_bus >= 0:
			AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(game_settings.sfx_volume))
	
	# Применяем настройки дисплея через DisplayManager
	var display_manager = null
	# Сначала пытаемся получить через autoload напрямую
	if Engine.has_singleton("DisplayManager"):
		display_manager = Engine.get_singleton("DisplayManager")
	# Если не найден, пытаемся через ServiceLocator
	if not display_manager and Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_display_manager"):
			display_manager = service_locator.get_display_manager()
	
	if display_manager and display_manager.has_method("apply_display_settings"):
		display_manager.apply_display_settings(game_settings)
	else:
		# Fallback: прямое обращение к DisplayServer если DisplayManager не найден
		var current_mode = DisplayServer.window_get_mode()
		if game_settings.fullscreen and current_mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			print("✅ SaveSystem: Fullscreen enabled")
		elif not game_settings.fullscreen and current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			print("✅ SaveSystem: Fullscreen disabled")
		
		# Применяем VSync
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if game_settings.vsync else DisplayServer.VSYNC_DISABLED)
		print("✅ SaveSystem: VSync ", "enabled" if game_settings.vsync else "disabled")

# Методы для обновления данных игрока
func update_player_health(current_health: int, max_health: int):
	player_data.current_health = current_health
	player_data.max_health = max_health

func update_player_potions(current_potions: int):
	player_data.current_potions = current_potions

func update_player_position(position: Vector2):
	player_data.player_position = {"x": position.x, "y": position.y}

func add_unlocked_skill(skill_name: String):
	if not player_data.unlocked_skills.has(skill_name):
		player_data.unlocked_skills.append(skill_name)

# Методы для обновления настроек (с автосохранением)
func update_master_volume(volume: float):
	game_settings.master_volume = volume
	var audio_manager = null
	if Engine.has_singleton("ServiceLocator"):
		if Engine.has_singleton("ServiceLocator"):
			var service_locator = Engine.get_singleton("ServiceLocator")
			if service_locator and service_locator.has_method("get_audio_manager"):
				audio_manager = service_locator.get_audio_manager()
	if audio_manager:
		audio_manager.set_master_volume(volume)
	else:
		push_warning("⚠️ SaveSystem: AudioManager not found")
	save_game_settings()  # Автосохранение при изменении

func update_music_volume(volume: float):
	game_settings.music_volume = volume
	var audio_manager = null
	if Engine.has_singleton("ServiceLocator"):
		if Engine.has_singleton("ServiceLocator"):
			var service_locator = Engine.get_singleton("ServiceLocator")
			if service_locator and service_locator.has_method("get_audio_manager"):
				audio_manager = service_locator.get_audio_manager()
	if audio_manager:
		audio_manager.set_music_volume(volume)
	else:
		push_warning("⚠️ SaveSystem: AudioManager not found")
	save_game_settings()  # Автосохранение при изменении

func update_sfx_volume(volume: float):
	game_settings.sfx_volume = volume
	var audio_manager = null
	if Engine.has_singleton("ServiceLocator"):
		if Engine.has_singleton("ServiceLocator"):
			var service_locator = Engine.get_singleton("ServiceLocator")
			if service_locator and service_locator.has_method("get_audio_manager"):
				audio_manager = service_locator.get_audio_manager()
	if audio_manager:
		audio_manager.set_sfx_volume(volume)
	else:
		push_warning("⚠️ SaveSystem: AudioManager not found")
	save_game_settings()  # Автосохранение при изменении

func toggle_fullscreen():
	game_settings.fullscreen = not game_settings.fullscreen
	if game_settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	save_game_settings()  # Автосохранение при изменении

func toggle_vsync():
	game_settings.vsync = not game_settings.vsync
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if game_settings.vsync else DisplayServer.VSYNC_DISABLED)
	save_game_settings()  # Автосохранение при изменении

# Автосохранение
func _save_dialogue_quest_flags():
	"""Сохраняет флаги DialogueQuest"""
	if not player_data.has("dialogue_flags"):
		player_data.dialogue_flags = {}
	
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
				player_data.dialogue_flags = flag_registry.duplicate()
				print("💾 SaveSystem: Збережено флагів DialogueQuest: ", player_data.dialogue_flags.size())
			else:
				print("⚠️ SaveSystem: flag_registry не является Dictionary или не найден (тип: ", typeof(flag_registry), ")")
		else:
			print("⚠️ SaveSystem: DialogueQuest.Flags не имеет нужных методов")
	else:
		print("⚠️ SaveSystem: DialogueQuest не найден для сохранения флагов")

func _load_dialogue_quest_flags():
	"""Загружает флаги DialogueQuest"""
	if not player_data.has("dialogue_flags") or player_data.dialogue_flags == null or player_data.dialogue_flags.is_empty():
		print("💾 SaveSystem: Нет сохраненных флагов DialogueQuest для загрузки")
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
			var saved_flags = player_data.dialogue_flags
			for flag_name in saved_flags:
				var flag_value = saved_flags[flag_name]
				flags.set_flag(flag_name, flag_value)
			print("💾 SaveSystem: Завантажено флагів DialogueQuest: ", saved_flags.size())
		else:
			print("⚠️ SaveSystem: DialogueQuest.Flags не имеет нужных методов для загрузки")
	else:
		print("⚠️ SaveSystem: DialogueQuest не найден для загрузки флагов")

func _save_game_flags():
	"""Сохраняет флаги квестов/катсцен/боссов/локаций из Game.gd"""
	if not player_data.has("quest_flags"):
		player_data.quest_flags = {}
	if not player_data.has("cutscene_flags"):
		player_data.cutscene_flags = {}
	if not player_data.has("boss_flags"):
		player_data.boss_flags = {}
	if not player_data.has("location_flags"):
		player_data.location_flags = {}
	
	# Получаем Game singleton
	var game = Game.get_singleton() if Game.get_singleton() != null else null
	if game:
		# Сохраняем флаги из Game.gd (если они есть)
		if game.has_method("get_quest_flags"):
			player_data.quest_flags = game.get_quest_flags()
		if game.has_method("get_cutscene_flags"):
			player_data.cutscene_flags = game.get_cutscene_flags()
		if game.has_method("get_boss_flags"):
			player_data.boss_flags = game.get_boss_flags()
		if game.has_method("get_location_flags"):
			player_data.location_flags = game.get_location_flags()

func _load_game_flags():
	"""Загружает флаги квестов/катсцен/боссов/локаций в Game.gd"""
	# Получаем Game singleton
	var game = Game.get_singleton() if Game.get_singleton() != null else null
	if game:
		# Загружаем флаги в Game.gd (если методы существуют)
		if "quest_flags" in player_data and game.has_method("set_quest_flags"):
			game.set_quest_flags(player_data.quest_flags)
		if "cutscene_flags" in player_data and game.has_method("set_cutscene_flags"):
			game.set_cutscene_flags(player_data.cutscene_flags)
		if "boss_flags" in player_data and game.has_method("set_boss_flags"):
			game.set_boss_flags(player_data.boss_flags)
		if "location_flags" in player_data and game.has_method("set_location_flags"):
			game.set_location_flags(player_data.location_flags)

func auto_save():
	"""Автоматическое сохранение данных игрока"""
	save_player_data()

# Проверка существования файла сохранения
func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH + PLAYER_DATA_FILE)

# Удаление файла сохранения
func delete_save_file():
	var file_path = SAVE_FILE_PATH + PLAYER_DATA_FILE
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		return true
	return false

func _on_window_close_requested():
	"""Обработка запроса на закрытие окна (для дебаг режима и обычного режима)"""
	# Сохраняем настройки при закрытии окна
	save_game_settings()
	print("💾 SaveSystem: Settings saved on window close")

func _notification(what):
	"""Обработка системных событий, включая выход из игры"""
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			# Сохраняем настройки при закрытии окна (для дебаг режима)
			save_game_settings()
			print("💾 SaveSystem: Settings saved on exit (notification)")
			get_tree().quit()  # Закрываем игру

func _exit_tree() -> void:
	"""Відписується від всіх сигналів при видаленні вузла (запобігання витоків пам'яті)"""
	_disconnect_all_signals()

func _disconnect_all_signals() -> void:
	"""Відписується від всіх сигналів EventBus для запобігання витоків пам'яті"""
	if not Engine.has_singleton("EventBus"):
		return
	
	# Перевіряємо та відписуємося від сигналів сцен та діалогів
	if EventBus.scene_transition_completed.is_connected(_on_scene_transition_completed):
		EventBus.scene_transition_completed.disconnect(_on_scene_transition_completed)
	if EventBus.dialogue_finished.is_connected(_on_dialogue_finished):
		EventBus.dialogue_finished.disconnect(_on_dialogue_finished)
	
	# Перевіряємо та відписуємося від сигналу закриття вікна
	if get_tree().root.has_signal("close_requested") and get_tree().root.close_requested.is_connected(_on_window_close_requested):
		get_tree().root.close_requested.disconnect(_on_window_close_requested)
	
	print("💾 SaveSystem: Disconnected from all EventBus signals")
