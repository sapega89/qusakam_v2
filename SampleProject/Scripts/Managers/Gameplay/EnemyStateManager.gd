extends ManagerBase
class_name EnemyStateManager

## 👹 EnemyStateManager - Управление состоянием врагов
## Отвечает только за управление состоянием врагов между сценами
## Согласно SRP: одна ответственность - управление состоянием врагов

# Enemy state (saved between scenes until player death)
var enemy_states: Dictionary[String, Dictionary] = {}  # {scene_name: {enemy_name: is_dead}}
var visited_scenes: Array[String] = []  # List of all scenes player has visited
var total_scenes_visited: int = 0  # Total counter of visited scenes (for merchant)

# Keys for local storage
const ENEMY_STATES_KEY = "enemy_states"
const VISITED_SCENES_KEY = "visited_scenes"

# Сигналы
signal enemy_state_changed(scene_name: String, enemy_name: String, is_dead: bool)
signal scene_visited(scene_name: String)

func _initialize():
	"""Инициализация EnemyStateManager"""
	pass  # No initialization needed

func save_enemy_state(scene_name: String, enemy_name: String, is_dead: bool):
	"""Сохраняет состояние врага для конкретной сцены"""
	if not enemy_states.has(scene_name):
		enemy_states[scene_name] = {}
	
	# Создаем уникальный ID врага: scene_name + "_" + enemy_name
	var unique_enemy_id = scene_name + "_" + enemy_name
	enemy_states[scene_name][unique_enemy_id] = is_dead
	
	enemy_state_changed.emit(scene_name, enemy_name, is_dead)
	print("💾 EnemyStateManager: Saved enemy state - Scene: ", scene_name, ", Enemy: ", enemy_name, ", Is Dead: ", is_dead)

func get_enemy_state(scene_name: String, enemy_name: String) -> bool:
	"""Получает состояние врага для конкретной сцены"""
	if not enemy_states.has(scene_name):
		return false
	
	var unique_enemy_id = scene_name + "_" + enemy_name
	return enemy_states[scene_name].get(unique_enemy_id, false)

func clear_enemy_states():
	"""Очищает все состояния врагов"""
	enemy_states.clear()
	print("💾 EnemyStateManager: All enemy states cleared")

func save_enemy_states_to_storage():
	"""Сохраняет состояния врагов в локальное хранилище"""
	var _config = ConfigFile.new()
	for scene_name in enemy_states.keys():
		for enemy_id in enemy_states[scene_name].keys():
			var is_dead = enemy_states[scene_name][enemy_id]
			_config.set_value(ENEMY_STATES_KEY, scene_name + "/" + enemy_id, is_dead)
	
	var config_path = "user://enemy_states.ini"
	_config.save(config_path)
	print("💾 EnemyStateManager: Enemy states saved to storage")

func load_enemy_states_from_storage():
	"""Загружает состояния врагов из локального хранилища"""
	var _config = ConfigFile.new()
	var config_path = "user://enemy_states.ini"
	var err = _config.load(config_path)
	
	if err != OK:
		print("⚠️ EnemyStateManager: Could not load enemy states from storage")
		return
	
	enemy_states.clear()
	var sections = _config.get_sections()
	for section in sections:
		if section == ENEMY_STATES_KEY:
			var keys = _config.get_section_keys(section)
			for key in keys:
				var scene_and_enemy = key.split("/")
				if scene_and_enemy.size() == 2:
					var scene_name = scene_and_enemy[0]
					var enemy_id = scene_and_enemy[1]
					var is_dead = _config.get_value(section, key, false)
					
					if not enemy_states.has(scene_name):
						enemy_states[scene_name] = {}
					enemy_states[scene_name][enemy_id] = is_dead
	
	print("💾 EnemyStateManager: Enemy states loaded from storage")

func clear_enemy_states_from_storage():
	"""Очищает состояния врагов из локального хранилища"""
	var config_path = "user://enemy_states.ini"
	if FileAccess.file_exists(config_path):
		DirAccess.remove_absolute(config_path)
		print("💾 EnemyStateManager: Enemy states cleared from storage")

func save_current_scene_enemies():
	"""Сохраняет состояние всех врагов в текущей сцене"""
	var scene_name = get_current_scene_name()
	save_scene_enemies(scene_name)

func save_scene_enemies(scene_name: String):
	"""Сохраняет состояние всех врагов в конкретной сцене"""
	# Додаємо сцену до списку відвіданих
	if scene_name not in visited_scenes:
		add_visited_scene(scene_name)
	
	# Ищем всех врагов в сцене
	var enemies = GameGroups.get_nodes_in_group(GameGroups.ENEMIES)
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			var enemy_name = enemy.name
			var is_dead = false
			
			# Проверяем, мертв ли враг
			if enemy.has_method("is_dead"):
				is_dead = enemy.is_dead()
			else:
				# Безопасная проверка свойства is_dead через get()
				var is_dead_value = enemy.get("is_dead")
				if is_dead_value != null:
					is_dead = bool(is_dead_value)
				elif not enemy.visible:
					is_dead = true
			
			save_enemy_state(scene_name, enemy_name, is_dead)
	
	# Зберігаємо стан ворогів в локальне сховище
	save_enemy_states_to_storage()

func load_enemy_states():
	"""Загружает состояния врагов для текущей сцены"""
	var scene_name = get_current_scene_name()
	var enemies = GameGroups.get_nodes_in_group(GameGroups.ENEMIES)
	
	print("💀 EnemyStateManager: Loading enemy states for scene: ", scene_name, " (", enemies.size(), " enemies)")
	
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			var enemy_name = enemy.name
			var is_dead = get_enemy_state(scene_name, enemy_name)
			print("💀 EnemyStateManager: Enemy ", enemy_name, " state: is_dead=", is_dead)
			
			# Встановлюємо правильний стан без виклику die()/revive() при завантаженні
			if is_dead:
				# Ворог повинен бути мертвим - просто приховуємо його
				enemy.visible = false
				enemy.set_process(false)
				enemy.set_physics_process(false)
				if enemy.has_method("set_dead_state"):
					enemy.set_dead_state(true)
				print("💀 EnemyStateManager: Enemy ", enemy_name, " set to DEAD state (invisible)")
			else:
				# Ворог повинен бути живим - показуємо його
				enemy.visible = true
				enemy.set_process(true)
				enemy.set_physics_process(true)
				if enemy.has_method("set_dead_state"):
					enemy.set_dead_state(false)
				print("💀 EnemyStateManager: Enemy ", enemy_name, " set to ALIVE state (visible)")
			
			# Зберігаємо поточний стан ворога в enemy_states
			save_enemy_state(scene_name, enemy_name, is_dead)

func save_all_visited_scenes():
	"""Сохраняет список всех посещенных сцен"""
	var _config = ConfigFile.new()
	_config.set_value("visited_scenes", "scenes", visited_scenes)
	_config.set_value("visited_scenes", "total", total_scenes_visited)
	
	var config_path = "user://visited_scenes.ini"
	_config.save(config_path)
	print("💾 EnemyStateManager: Visited scenes saved to storage")

func add_visited_scene(scene_name: String):
	"""Добавляет сцену в список посещенных"""
	if scene_name not in visited_scenes:
		visited_scenes.append(scene_name)
		total_scenes_visited += 1
		scene_visited.emit(scene_name)
		print("💾 EnemyStateManager: Scene added to visited: ", scene_name)

func get_current_scene_name() -> String:
	"""Получает имя текущей сцены"""
	var current_scene = get_tree().current_scene
	if current_scene:
		return current_scene.scene_file_path.get_file().get_basename()
	return "Unknown"

func get_visited_scenes() -> Array:
	"""Получает список посещенных сцен"""
	return visited_scenes.duplicate()

func get_total_scenes_visited() -> int:
	"""Получает общее количество посещенных сцен"""
	return total_scenes_visited

