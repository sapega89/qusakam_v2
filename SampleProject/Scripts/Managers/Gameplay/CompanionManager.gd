## Менеджер компаньйонів
## Управляє викликом компаньйонів, cooldown'ами та прив'язкою до HUD
extends ManagerBase
class_name CompanionManager

## Посилання на HUD з кнопками компаньйонів
@export var hud: Control

## Посилання на гравця
var player: Node = null

## Словник компаньйонів: assist_type -> PackedScene
var companion_scenes: Dictionary = {}

## Словник cooldown'ів: assist_type -> float
var cooldowns: Dictionary = {}

## Словник тривалості cooldown'ів: assist_type -> float
var cooldown_durations: Dictionary = {}

## Поточні активні компаньйони
var active_companions: Array[Node] = []

## Підключені кнопки HUD (для відключення в _exit_tree)
var _connected_buttons: Array[Dictionary] = []

## Сигнали
signal companion_summoned(companion: Node, assist_type: String)
signal companion_cooldown_updated(assist_type: String, remaining_time: float)

func _initialize() -> void:
	"""Ініціалізація CompanionManager"""
	# Знаходимо гравця
	player = GameGroups.get_first_node_in_group(GameGroups.PLAYER)

	# Підключаємося до HUD кнопок
	_connect_hud_buttons()

	# Ініціалізуємо cooldown'и
	_initialize_cooldowns()

func _process(delta: float) -> void:
	# Оновлюємо cooldown'и
	_update_cooldowns(delta)

## Реєструє сцену компаньйона
func register_companion(assist_type: String, scene: PackedScene, cooldown_duration: float = 5.0) -> void:
	companion_scenes[assist_type] = scene
	cooldown_durations[assist_type] = cooldown_duration
	cooldowns[assist_type] = 0.0

## Викликає компаньйона
func summon_companion(assist_type: String, target: Node = null) -> void:
	if not companion_scenes.has(assist_type):
		return
	
	# Перевірка cooldown'у
	if cooldowns.get(assist_type, 0.0) > 0.0:
		return
	
	# Якщо ціль не вказана, використовуємо гравця
	if not target:
		target = player
	
	if not target:
		return
	
	# Завантажуємо сцену компаньйона
	var companion_scene = companion_scenes[assist_type]
	if not companion_scene:
		return
	
	# Створюємо інстанс компаньйона
	var companion = companion_scene.instantiate()
	if not companion:
		return
	
	# Перевіряємо, чи компаньйон реалізує ICompanionAssist
	if not ICompanionAssist.is_implemented_by(companion):
		companion.queue_free()
		return
	
	# Додаємо компаньйона до сцени
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(companion)
		
		# Позиціонуємо біля цілі
		if is_instance_valid(target) and target is Node2D:
			var target_pos = (target as Node2D).global_position
			companion.global_position = target_pos + Vector2(50, -30)
		
		# Викликаємо assist
		ICompanionAssist.safe_assist(companion, target)
		
		# Додаємо до активних компаньйонів
		active_companions.append(companion)
		
		# Встановлюємо cooldown
		cooldowns[assist_type] = cooldown_durations.get(assist_type, 5.0)
		
		# Емітуємо сигнал
		companion_summoned.emit(companion, assist_type)
		
		# Видаляємо компаньйона після завершення
		companion.connect("tree_exiting", _on_companion_exiting.bind(companion))

## Перевіряє, чи компаньйон готовий до виклику
func can_summon(assist_type: String) -> bool:
	if not companion_scenes.has(assist_type):
		return false
	return cooldowns.get(assist_type, 0.0) <= 0.0

## Отримує залишковий час cooldown'у
func get_cooldown_remaining(assist_type: String) -> float:
	return cooldowns.get(assist_type, 0.0)

## Підключає кнопки HUD
func _connect_hud_buttons() -> void:
	if not hud:
		return

	# Шукаємо кнопки компаньйонів (очікуємо naming: CompanionButton_Fire, CompanionButton_Shield, тощо)
	var buttons = _find_companion_buttons(hud)

	for button_data in buttons:
		var button = button_data.button
		var assist_type = button_data.assist_type

		# Підключаємо сигнал pressed
		if button.pressed.is_connected(_on_companion_button_pressed.bind(assist_type)):
			continue

		button.pressed.connect(_on_companion_button_pressed.bind(assist_type))

		# Зберігаємо для відключення в _exit_tree
		_connected_buttons.append({"button": button, "assist_type": assist_type})

## Знаходить кнопки компаньйонів у HUD
func _find_companion_buttons(node: Node) -> Array:
	var buttons: Array = []
	
	# Перевіряємо поточний ноду
	if node is Button:
		var button_name = node.name
		if "Companion" in button_name or "companion" in button_name:
			# Витягуємо тип з назви (наприклад, "CompanionButton_Fire" -> "fire")
			var assist_type = _extract_assist_type(button_name)
			if assist_type != "":
				buttons.append({"button": node, "assist_type": assist_type})
	
	# Рекурсивно перевіряємо дочірні ноди
	for child in node.get_children():
		buttons.append_array(_find_companion_buttons(child))
	
	return buttons

## Витягує тип assist з назви кнопки
func _extract_assist_type(button_name: String) -> String:
	# Очікуємо формат: CompanionButton_Fire, Companion_Fire, тощо
	var parts = button_name.split("_")
	if parts.size() > 1:
		return parts[-1].to_lower()
	
	# Альтернативний формат: CompanionFire
	if "Companion" in button_name:
		var after_companion = button_name.substr(button_name.find("Companion") + 9)
		return after_companion.to_lower()
	
	return ""

## Обробник натискання кнопки компаньйона
func _on_companion_button_pressed(assist_type: String) -> void:
	summon_companion(assist_type)

## Ініціалізує cooldown'и
func _initialize_cooldowns() -> void:
	# Cooldown'и встановлюються при реєстрації компаньйонів
	pass

## Оновлює cooldown'и
func _update_cooldowns(delta: float) -> void:
	for assist_type in cooldowns.keys():
		if cooldowns[assist_type] > 0.0:
			cooldowns[assist_type] -= delta
			if cooldowns[assist_type] < 0.0:
				cooldowns[assist_type] = 0.0
			
			# Емітуємо сигнал оновлення cooldown'у
			companion_cooldown_updated.emit(assist_type, cooldowns[assist_type])

## Обробник виходу компаньйона зі сцени
func _on_companion_exiting(companion: Node) -> void:
	active_companions.erase(companion)

func _exit_tree() -> void:
	"""Відключаємося від сигналів при видаленні"""
	# Відключаємося від кнопок HUD
	for button_data in _connected_buttons:
		var button = button_data.button
		var assist_type = button_data.assist_type
		if is_instance_valid(button) and button.pressed.is_connected(_on_companion_button_pressed.bind(assist_type)):
			button.pressed.disconnect(_on_companion_button_pressed.bind(assist_type))

	_connected_buttons.clear()

