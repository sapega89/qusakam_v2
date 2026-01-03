extends Node
class_name GameDialogueManager

## 💬 GameDialogueManager - Менеджер диалогов через DialogueQuest
## Интегрирует DialogueQuest с игровой системой

# Ссылка на DialogueQuest singleton
var dialogue_quest_available: bool = false

# Текущий активный диалог (DialoguePlayer)
var current_dialogue_player: DQDialoguePlayer = null

# DialogueBox для очистки placeholder текста
var current_dialogue_box: DQDialogueBox = null

# DialoguePlayer с настроенными компонентами
var dialogue_player_instance: Node = null

# Сигналы
signal dialogue_started(timeline_name: String)
signal dialogue_finished(timeline_name: String)
signal dialogue_choice_selected(choice_index: int)

func _ready():
	"""Проверяет доступность DialogueQuest"""
	_check_dialogue_quest_availability()
	# НЕ создаём компоненты автоматически - они должны быть в .tscn сценах

func _check_dialogue_quest_availability():
	"""Проверяет, установлен ли DialogueQuest"""
	# Используем call_deferred, так как singleton может загружаться после _ready()
	call_deferred("_check_dialogue_quest_availability_deferred")

func _check_dialogue_quest_availability_deferred():
	"""Проверка доступности DialogueQuest с задержкой"""
	if Engine.has_singleton("DialogueQuest"):
		dialogue_quest_available = true
		print("💬 DialogueManager: DialogueQuest доступен")
	else:
		# Пробуем найти через дерево сцены (для runtime)
		var tree = get_tree()
		if tree and tree.root:
			var dq = tree.root.get_node_or_null("DialogueQuest")
			if dq:
				dialogue_quest_available = true
				print("💬 DialogueManager: DialogueQuest найден через дерево сцены")
				return
		
		dialogue_quest_available = false
		push_warning("⚠️ DialogueManager: DialogueQuest не установлен. Убедитесь, что плагин включен в project.godot")

func _find_dialogue_system_in_scene() -> bool:
	"""Ищет DialogueSystem в текущей сцене и настраивает компоненты"""
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return false
	
	# Проверяем, что это не меню (диалоги не должны быть в меню)
	var scene_name = tree.current_scene.scene_file_path
	if scene_name and ("menu" in scene_name.to_lower() or "Menu" in scene_name):
		return false
	
	# Ищем DialogueSystem в сцене (может быть в корне или в CanvasLayer)
	var dialogue_system = tree.current_scene.get_node_or_null("DialogueSystem")
	if not dialogue_system:
		# Пробуем найти в дочерних узлах (может быть в CanvasLayer)
		dialogue_system = _find_dialogue_system_recursive(tree.current_scene)
	
	if dialogue_system:
		# Находим компоненты внутри DialogueSystem
		current_dialogue_player = dialogue_system.get_node_or_null("DialoguePlayer")
		current_dialogue_box = dialogue_system.get_node_or_null("DialogueBox")
		var choice_menu = dialogue_system.get_node_or_null("ChoiceMenu")

		# Настраиваем DialoguePlayer
		if current_dialogue_player and current_dialogue_player is DQDialoguePlayer:
			if current_dialogue_box:
				current_dialogue_player.dialogue_box = current_dialogue_box
			if choice_menu:
				current_dialogue_player.choice_menu = choice_menu

			# Подключаем сигналы DialogueQuest
			_connect_dialogue_quest_signals()
			return true
	
	# НЕ ищем компоненты напрямую в сцене - они должны быть в DialogueSystem.tscn
	# Это гарантирует, что диалоги не появятся в меню
	return false

func _find_dialogue_system_recursive(node: Node) -> Node:
	"""Рекурсивно ищет DialogueSystem в дереве узлов"""
	if node.name == "DialogueSystem":
		return node
	
	for child in node.get_children():
		var result = _find_dialogue_system_recursive(child)
		if result:
			return result
	
	return null

func _connect_dialogue_quest_signals():
	"""Подключает сигналы DialogueQuest"""
	if Engine.has_singleton("DialogueQuest"):
		var dq = Engine.get_singleton("DialogueQuest")
		if dq and dq.has_method("get") and dq.get("Signals"):
			var signals = dq.Signals
			if not signals.dialogue_started.is_connected(_on_dialogue_quest_started):
				signals.dialogue_started.connect(_on_dialogue_quest_started)
			if not signals.dialogue_ended.is_connected(_on_dialogue_quest_ended):
				signals.dialogue_ended.connect(_on_dialogue_quest_ended)
			if not signals.dialogue_signal.is_connected(_on_dialogue_quest_signal):
				signals.dialogue_signal.connect(_on_dialogue_quest_signal)

func start_dialogue(timeline_name: String, _character_name: String = "") -> bool:
	"""
	Запускает диалог по пути к .dqd файлу
	@param timeline_name: Путь к .dqd файлу (например, "res://dialogue_quest/dialogues/prologue/p01_cliff_intro.dqd")
	@param _character_name: Имя персонажа (опционально, для совместимости, не используется)
	@return: true если диалог успешно запущен
	"""
	if not dialogue_quest_available:
		push_error("❌ DialogueManager: DialogueQuest не доступен!")
		return false
	
	# Ищем DialogueSystem в сцене (только в игровых сценах, не в меню)
	if not _find_dialogue_system_in_scene():
		push_error("❌ DialogueManager: DialogueSystem не найден в сцене! Добавьте DialogueSystem.tscn в игровую сцену.")
		return false
	
	# Проверяем, что файл существует
	var dialogue_path = timeline_name
	
	# Если это уже полный путь (начинается с "res://"), используем его как есть
	if not timeline_name.begins_with("res://"):
		# Если только имя файла (без пути), ищем в стандартной директории
		if not timeline_name.contains("/"):
			dialogue_path = "res://dialogue_quest/dialogues/" + timeline_name
			# Добавляем расширение, если его нет
			if not dialogue_path.ends_with(".dqd"):
				dialogue_path += ".dqd"
		else:
			# Если есть относительный путь, пробуем добавить к стандартной директории
			dialogue_path = "res://dialogue_quest/dialogues/" + timeline_name
			if not dialogue_path.ends_with(".dqd"):
				dialogue_path += ".dqd"
	
	# Проверяем существование файла через FileAccess (для .dqd файлов это более надежно)
	var file_exists = ResourceLoader.exists(dialogue_path) or FileAccess.file_exists(dialogue_path)
	
	if not file_exists:
		push_error("❌ DialogueManager: Файл диалога не найден: " + timeline_name + " (пробовали: " + dialogue_path + ")")
		return false
	
	if dialogue_path != timeline_name:
		timeline_name = dialogue_path
		print("💬 DialogueManager: Найден файл диалога: ", timeline_name)
	
	# Проверяем, не запущен ли уже диалог
	if is_dialogue_active():
		push_warning("⚠️ DialogueManager: Диалог уже активен, пропускаем запуск '", timeline_name, "'")
		return false
	
	# Очищаем DialogueBox перед запуском нового диалога (убираем placeholder "Lorem ipsum")
	if current_dialogue_box:
		current_dialogue_box.set_text("")
		current_dialogue_box.set_name_text("")
		current_dialogue_box.set_portrait_image(null)
		# Показываем DialogueBox - он будет виден во время диалога
		current_dialogue_box.visible = true
		print("💬 DialogueManager: DialogueBox очищен и показан")
	
	# Запускаем диалог
	if current_dialogue_player.has_method("play"):
		current_dialogue_player.play(timeline_name)
		dialogue_started.emit(timeline_name)
		print("💬 DialogueManager: Запущен диалог '", timeline_name, "'")
		return true
	else:
		push_error("❌ DialogueManager: DialoguePlayer не имеет метода play()")
		return false

func start_dialogue_with_character(character_name: String, timeline_name: String = "") -> bool:
	"""
	Запускает диалог с конкретным персонажем
	@param character_name: Имя персонажа (используется для поиска файла)
	@param timeline_name: Путь к .dqd файлу (опционально)
	@return: true если диалог успешно запущен
	"""
	if not dialogue_quest_available:
		push_error("❌ DialogueManager: DialogueQuest не доступен!")
		return false
	
	# Если timeline не указан, используем дефолтный для персонажа
	if timeline_name.is_empty():
		timeline_name = character_name + "_default.dqd"
	
	return start_dialogue(timeline_name, character_name)

func end_dialogue():
	"""Завершает текущий диалог"""
	if current_dialogue_player and is_instance_valid(current_dialogue_player):
		if current_dialogue_player.has_method("stop"):
			current_dialogue_player.stop()
	
	# Скрываем DialogueBox после завершения диалога
	if current_dialogue_box and is_instance_valid(current_dialogue_box):
		current_dialogue_box.visible = false
		current_dialogue_box.set_text("")
		current_dialogue_box.set_name_text("")
		current_dialogue_box.set_portrait_image(null)
		print("💬 DialogueManager: DialogueBox скрыт после завершения диалога")
	
	print("💬 DialogueManager: Диалог завершен")

func _on_dialogue_quest_started(dialogue_id: String):
	"""Обработчик начала диалога из DialogueQuest"""
	dialogue_started.emit(dialogue_id)
	print("💬 DialogueManager: DialogueQuest начал диалог '", dialogue_id, "'")

func _on_dialogue_quest_ended(dialogue_id: String):
	"""Обработчик завершения диалога из DialogueQuest"""
	# Скрываем DialogueBox после завершения диалога
	if current_dialogue_box and is_instance_valid(current_dialogue_box):
		current_dialogue_box.visible = false
		current_dialogue_box.set_text("")
		current_dialogue_box.set_name_text("")
		current_dialogue_box.set_portrait_image(null)
		print("💬 DialogueManager: DialogueBox скрыт после завершения диалога '", dialogue_id, "'")
	
	dialogue_finished.emit(dialogue_id)
	print("💬 DialogueManager: DialogueQuest завершил диалог '", dialogue_id, "'")
	
	# Отправляем сигнал через EventBus
	if Engine.has_singleton("EventBus"):
		EventBus.dialogue_finished.emit(dialogue_id)

func _on_dialogue_quest_signal(params: Array):
	"""Обработчик сигналов из DialogueQuest"""
	# params[0] - имя сигнала, params[1..] - аргументы
	if params.size() > 0:
		var signal_name = params[0] as String
		match signal_name:
			"choice_selected":
				if params.size() > 1:
					var choice_index = params[1] as int
					dialogue_choice_selected.emit(choice_index)
			_:
				# Другие сигналы можно обработать здесь
				pass

func is_dialogue_active() -> bool:
	"""Проверяет, активен ли диалог"""
	if current_dialogue_player and is_instance_valid(current_dialogue_player):
		return current_dialogue_player.current_dialogue != ""
	return false

