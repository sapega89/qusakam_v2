extends Control
class_name QuestProgressUI

## 📊 QuestProgressUI - UI компонент для відображення прогресу квестів у сцені
## Показує список діалогів, поточний етап та прогрес

@export_group("References")
@export var quest_manager: SceneQuestManager  # Автоматично знайдеться, якщо не встановлено

@export_group("UI Nodes")
@onready var stage_label: Label = $VBoxContainer/StageLabel
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var dialogue_list: VBoxContainer = $VBoxContainer/DialogueList
@export var dialogue_item_scene: PackedScene  # Опціональна сцена для елемента діалогу

@export_group("Settings")
@export var auto_find_manager: bool = true  # Автоматично знайти SceneQuestManager в сцені
@export var update_interval: float = 0.5  # Інтервал оновлення (секунди)

var dialogue_items: Dictionary = {}  # dialogue_id -> QuestDialogueItem

func _ready() -> void:
	"""Ініціалізація UI"""
	# Автоматично знаходимо Quest Manager, якщо не встановлено
	if auto_find_manager and not quest_manager:
		quest_manager = _find_quest_manager()
	
	# Підключаємося до сигналів
	_connect_to_quest_manager()
	
	# Початкове оновлення
	call_deferred("update_progress")
	
	# Періодичне оновлення
	if update_interval > 0:
		_update_timer()

func _find_quest_manager() -> SceneQuestManager:
	"""Знаходить SceneQuestManager в поточній сцені"""
	var scene = get_tree().current_scene
	if scene:
		return scene.find_child("SceneQuestManager", true, false) as SceneQuestManager
	return null

func _connect_to_quest_manager() -> void:
	"""Підключається до сигналів Quest Manager"""
	if not quest_manager:
		return
	
	if not quest_manager.dialogue_completed.is_connected(_on_dialogue_completed):
		quest_manager.dialogue_completed.connect(_on_dialogue_completed)
	
	if not quest_manager.stage_completed.is_connected(_on_stage_completed):
		quest_manager.stage_completed.connect(_on_stage_completed)
	
	if not quest_manager.progress_updated.is_connected(_on_progress_updated):
		quest_manager.progress_updated.connect(_on_progress_updated)
	
	if not quest_manager.all_stages_completed.is_connected(_on_all_stages_completed):
		quest_manager.all_stages_completed.connect(_on_all_stages_completed)

func _update_timer() -> void:
	"""Таймер для періодичного оновлення"""
	await get_tree().create_timer(update_interval).timeout
	update_progress()
	_update_timer()

func update_progress() -> void:
	"""Оновлює відображення прогресу"""
	if not quest_manager or not quest_manager.quest_config:
		_show_no_quest_message()
		return
	
	var current_stage = quest_manager.get_current_stage()
	
	# Оновлюємо інформацію про етап
	if current_stage:
		if stage_label:
			stage_label.text = "Етап: %s" % current_stage.stage_name
	else:
		if stage_label:
			stage_label.text = "Всі етапи завершені!"
	
	# Оновлюємо прогрес-бар
	if progress_bar:
		var progress = quest_manager.get_progress_percentage()
		progress_bar.value = progress * 100.0
	
	# Оновлюємо список діалогів
	_update_dialogue_list()

func _update_dialogue_list() -> void:
	"""Оновлює список діалогів"""
	if not dialogue_list or not quest_manager or not quest_manager.quest_config:
		return
	
	var all_dialogues = quest_manager.quest_config.get_all_required_dialogues()
	var completed = quest_manager.get_completed_dialogues()
	
	# Створюємо або оновлюємо елементи списку
	for dialogue_id in all_dialogues:
		if not dialogue_id in dialogue_items:
			_create_dialogue_item(dialogue_id)
		
		var item = dialogue_items[dialogue_id]
		if item:
			var is_completed = dialogue_id in completed
			item.set_completed(is_completed)

func _create_dialogue_item(dialogue_id: String) -> void:
	"""Створює елемент списку для діалогу"""
	if not dialogue_list:
		return
	
	# Якщо є сцена для елемента, використовуємо її
	if dialogue_item_scene:
		var item = dialogue_item_scene.instantiate()
		if item.has_method("set_dialogue_id"):
			item.set_dialogue_id(dialogue_id)
		dialogue_list.add_child(item)
		dialogue_items[dialogue_id] = item
	else:
		# Fallback: створюємо простий Label
		var label = Label.new()
		label.text = "• %s" % dialogue_id
		dialogue_list.add_child(label)
		dialogue_items[dialogue_id] = label

func _show_no_quest_message() -> void:
	"""Показує повідомлення про відсутність квесту"""
	if stage_label:
		stage_label.text = "Квест не налаштовано"
	if progress_bar:
		progress_bar.value = 0.0

func _on_dialogue_completed(dialogue_id: String) -> void:
	"""Обробник завершення діалогу"""
	update_progress()

func _on_stage_completed(stage_id: String, stage_name: String) -> void:
	"""Обробник завершення етапу"""
	update_progress()

func _on_progress_updated(completed: int, total: int) -> void:
	"""Обробник оновлення прогресу"""
	update_progress()

func _on_all_stages_completed() -> void:
	"""Обробник завершення всіх етапів"""
	update_progress()
	if stage_label:
		stage_label.text = "✅ Всі етапи завершені!"
