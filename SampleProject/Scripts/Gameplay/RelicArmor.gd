extends Area2D
class_name RelicArmor

## 🛡️ RelicArmor - Интерактивный объект обладунков/реликвии
## Показывает диалог при нажатии E рядом с объектом

@export var dialogue_id: String = "RelicArmor_Examine"
@export var interaction_text: String = "Натисніть E щоб оглянути обладунки"

var player_nearby: bool = false
var dialogue_played: bool = false

@onready var interaction_label: Label = $InteractionLabel

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Создаем label если его нет
	if not interaction_label:
		interaction_label = Label.new()
		interaction_label.name = "InteractionLabel"
		interaction_label.text = interaction_text
		interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		interaction_label.add_theme_font_size_override("font_size", 16)
		interaction_label.add_theme_color_override("font_color", Color.WHITE)
		interaction_label.add_theme_color_override("font_outline_color", Color.BLACK)
		interaction_label.add_theme_constant_override("outline_size", 4)
		
		# Позиционируем label над объектом
		interaction_label.position = Vector2(-100, -40)
		interaction_label.size = Vector2(200, 30)
		add_child(interaction_label)
	
	interaction_label.visible = false
	
	# Добавляем в группу для поиска
	add_to_group("interactive_objects")

func _on_body_entered(body: Node2D) -> void:
	if body and body.is_in_group(GameGroups.PLAYER):
		player_nearby = true
		if interaction_label:
			interaction_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body and body.is_in_group(GameGroups.PLAYER):
		player_nearby = false
		if interaction_label:
			interaction_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	"""Обработка нажатия E для взаимодействия"""
	if not player_nearby:
		return
	
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		_interact_with_relic()
		get_viewport().set_input_as_handled()

func _interact_with_relic() -> void:
	"""Взаимодействие с реликвией - запуск диалога"""
	if dialogue_id.is_empty():
		DebugLogger.warning("RelicArmor: dialogue_id не установлен", "RelicArmor")
		return
	
	DebugLogger.info("RelicArmor: Игрок взаимодействует с обладунками", "RelicArmor")
	
	# Запускаем диалог
	var dm = _get_dialogue_manager()
	if not dm:
		DebugLogger.error("RelicArmor: DialogueManager не найден", "RelicArmor")
		return
	
	var path = "res://dialogue_quest/" + dialogue_id + ".dqd"
	dm.start_dialogue(path)
	
	dialogue_played = true
	
	# Скрываем label после взаимодействия
	if interaction_label:
		interaction_label.visible = false

func _get_dialogue_manager() -> Node:
	"""Получает DialogueManager через ServiceLocator"""
	if Engine.has_singleton("ServiceLocator"):
		var loc = Engine.get_singleton("ServiceLocator")
		if loc and loc.has_method("get_dialogue_manager"):
			return loc.get_dialogue_manager()
	return null
