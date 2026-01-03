## Сервіс запуску діалогів по ID
## Реалізує IDialogueRunner
## Мапить ID діалогів на шляхи до .dqd файлів
extends Node
class_name DialogueRunner

## Посилання на DialogueManager
var dialogue_manager: GameDialogueManager = null

## Словник мапінгу ID -> шлях до файлу
var dialogue_map: Dictionary = {}

## Чи діалог активний
var is_active: bool = false

## Сигнали
signal dialogue_started(dialogue_id: String)
signal dialogue_finished(dialogue_id: String)

func _ready() -> void:
	# Знаходимо DialogueManager через ServiceLocator
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_dialogue_manager"):
			dialogue_manager = service_locator.get_dialogue_manager()
	
	# Ініціалізуємо мапінг діалогів
	_initialize_dialogue_map()
	
	# Підключаємося до сигналів DialogueManager
	_connect_dialogue_manager_signals()
	
	# Підключаємося до всіх тригерів діалогів у сцені
	_connect_dialogue_triggers()

## Реалізація IDialogueRunner.start_dialogue()
func start_dialogue(dialogue_id: String) -> bool:
	if not dialogue_manager:
		return false
	
	# Отримуємо шлях до файлу діалогу
	var dialogue_path = _get_dialogue_path(dialogue_id)
	if dialogue_path == "":
		if not ResourceLoader.exists("res://dialogue_quest/dialogues/" + dialogue_id + ".dqd"):
			print("DialogueRunner: Діалог з ID '", dialogue_id, "' не знайдено")
		return false
	
	# Запускаємо діалог через DialogueManager
	var started = dialogue_manager.start_dialogue(dialogue_path)
	if started:
		is_active = true
		dialogue_started.emit(dialogue_id)
	
	return started

## Реалізація IDialogueRunner.is_dialogue_active()
func is_dialogue_active() -> bool:
	if dialogue_manager:
		return dialogue_manager.is_dialogue_active()
	return is_active

## Реалізація IDialogueRunner.stop_dialogue()
func stop_dialogue() -> void:
	if dialogue_manager:
		dialogue_manager.end_dialogue()
	is_active = false

## Реєструє діалог в мапінгу
func register_dialogue(dialogue_id: String, dialogue_path: String) -> void:
	dialogue_map[dialogue_id] = dialogue_path

## Отримує шлях до файлу діалогу за ID
func _get_dialogue_path(dialogue_id: String) -> String:
	if dialogue_map.has(dialogue_id):
		return dialogue_map[dialogue_id]
	
	# Fallback: спробувати стандартний шлях
	var default_path = "res://dialogue_quest/dialogues/" + dialogue_id + ".dqd"
	if ResourceLoader.exists(default_path) or FileAccess.file_exists(default_path):
		return default_path
	
	return ""

## Ініціалізує мапінг діалогів
func _initialize_dialogue_map() -> void:
	# Prolog діалоги
	register_dialogue("p09_trader", "res://dialogue_quest/dialogues/prolog1/p09_trader.dqd")
	register_dialogue("p10_training", "res://dialogue_quest/dialogues/prolog1/p10_training.dqd")
	
	# Demo локації діалоги
	register_dialogue("d01_settlement_intro", "res://dialogue_quest/dialogues/demo/d01_settlement_intro.dqd")
	register_dialogue("d02_desert_intro", "res://dialogue_quest/dialogues/demo/d02_desert_intro.dqd")
	register_dialogue("d03_city_arrival", "res://dialogue_quest/dialogues/demo/d03_city_arrival.dqd")
	register_dialogue("d04_lab_intro", "res://dialogue_quest/dialogues/demo/d04_lab_intro.dqd")
	register_dialogue("d05_boss_encounter", "res://dialogue_quest/dialogues/demo/d05_boss_encounter.dqd")
	register_dialogue("d06_oasis_intro", "res://dialogue_quest/dialogues/demo/d06_oasis_intro.dqd")
	register_dialogue("d07_cave_intro", "res://dialogue_quest/dialogues/demo/d07_cave_intro.dqd")
	register_dialogue("d08_mine_intro", "res://dialogue_quest/dialogues/demo/d08_mine_intro.dqd")
	register_dialogue("d09_tutorial_combat", "res://dialogue_quest/dialogues/demo/d09_tutorial_combat.dqd")
	register_dialogue("d10_tutorial_inventory", "res://dialogue_quest/dialogues/demo/d10_tutorial_inventory.dqd")

## Підключає сигнали DialogueManager
func _connect_dialogue_manager_signals() -> void:
	if not dialogue_manager:
		return
	
	# Підключаємося до сигналів завершення діалогу
	if dialogue_manager.dialogue_finished.is_connected(_on_dialogue_finished):
		return
	
	dialogue_manager.dialogue_finished.connect(_on_dialogue_finished)

## Обробник завершення діалогу
func _on_dialogue_finished(timeline_name: String) -> void:
	is_active = false
	
	# Витягуємо ID з шляху (якщо можливо)
	var dialogue_id = _extract_id_from_path(timeline_name)
	dialogue_finished.emit(dialogue_id)

## Витягує ID з шляху до файлу
func _extract_id_from_path(path: String) -> String:
	# Спробувати знайти ID в мапінгу
	for id in dialogue_map.keys():
		if dialogue_map[id] == path:
			return id
	
	# Якщо не знайдено, витягнути з шляху
	var file_name = path.get_file()
	if file_name.ends_with(".dqd"):
		return file_name.substr(0, file_name.length() - 4)
	
	return path

## Підключає тригери діалогів у сцені
func _connect_dialogue_triggers() -> void:
	# Шукаємо всі тригери діалогів у сцені
	var triggers = get_tree().get_nodes_in_group("dialogue_trigger")
	
	for trigger in triggers:
		if trigger.has_method("dialogue_triggered"):
			if not trigger.dialogue_triggered.is_connected(_on_dialogue_triggered):
				trigger.dialogue_triggered.connect(_on_dialogue_triggered)

## Обробник спрацювання тригера
func _on_dialogue_triggered(dialogue_id: String) -> void:
	start_dialogue(dialogue_id)

