extends Control
class_name HealthBar

# Unified HealthBar class for Player, Enemy, and Boss HP bars (ЭТАП 2.2 ✅)

## Type of health bar - determines behavior and appearance
enum HealthBarType {
	PLAYER,   ## Static HP bar for player (UI element)
	ENEMY,    ## Dynamic HP bar following enemy
	BOSS      ## Boss HP bar (can be customized separately)
}

@export var bar_type: HealthBarType = HealthBarType.PLAYER

var bar: ProgressBar
var health_label: Label

var max_value := 100
var current_value := 100
var target_entity: CombatBody2D = null
var entity_name: String = "Entity"

# Настройки анимации
@export var animation_duration: float = 0.3
@export var damage_flash_duration: float = 0.2
@export var show_health_text: bool = true

# Цвета для разных уровней здоровья
@export var healthy_color: Color = Color(0.2, 0.8, 0.2, 1)  # Зеленый
@export var warning_color: Color = Color(0.8, 0.8, 0.2, 1)  # Желтый
@export var critical_color: Color = Color(0.8, 0.2, 0.2, 1) # Красный
@export var warning_threshold: float = 0.5  # 50% здоровья
@export var critical_threshold: float = 0.25 # 25% здоровья

# Enemy/Boss specific settings
@export var follow_entity: bool = false  ## Follow entity position (auto-enabled for ENEMY type)
@export var auto_hide: bool = false      ## Auto-hide after delay (auto-enabled for ENEMY type)
@export var auto_hide_delay: float = 3.0 ## Delay before auto-hiding
@export var offset_y: float = -60.0      ## Y offset from entity (for ENEMY/BOSS)
@export var offset_x: float = 0.0        ## X offset from entity (for ENEMY/BOSS)

# Internal state for enemy health bars
var hide_timer: Timer
var hp_bar_visible: bool = true

func _ready():
	# Configure based on bar_type
	match bar_type:
		HealthBarType.ENEMY:
			_configure_enemy_bar()
		HealthBarType.BOSS:
			_configure_boss_bar()
		HealthBarType.PLAYER:
			_configure_player_bar()

	# Инициализируем переменные, если они еще не инициализированы
	if not bar:
		bar = get_node_or_null("ProgressBar")
		if not bar:
			# Try enemy health bar path
			bar = get_node_or_null("HealthBar/ProgressBar")
	if not health_label:
		health_label = get_node_or_null("HealthLabel")
		if not health_label:
			# Try enemy health bar path
			health_label = get_node_or_null("HealthBar/HealthLabel")

	DebugLogger.info("HealthBar: _ready() - HP bar initialized (type: %s)" % HealthBarType.keys()[bar_type], "HealthBar")

	# Додаємо до групи для пошуку GameManager
	add_to_group(GameGroups.HEALTH_BAR)
	add_to_group(GameGroups.UI_ELEMENTS)
	DebugLogger.info("HealthBar: Added to groups 'health_bar' and 'ui_elements'", "HealthBar")
	
	# Підключаємо сигнал для відстеження зміни видимості
	visibility_changed.connect(_on_visibility_changed)
	
	# Спочатку перевіряємо, чи це гравець
	if entity_name == "Player":
		# Для гравця встановлюємо початкові значення
		# Значення вже встановлені в сцені (0/100)
		max_value = 100
		current_value = 0  # Встановлюємо в 0 для гравця
	else:
		# Для не-гравців використовуємо дефолтні значення
		current_value = 100  # Для не-гравців встановлюємо дефолтні значення
		if bar:
			bar.max_value = max_value
			bar.value = current_value
	
	# Настраиваем начальный цвет
	update_health_color(current_value)
	
	# Показываем/скрываем текст здоровья
	if health_label:
		health_label.visible = show_health_text
		update_health_text()

## Configure health bar for player (static UI element)
func _configure_player_bar():
	follow_entity = false
	auto_hide = false
	z_index = 0

## Configure health bar for enemy (follows enemy, auto-hides)
func _configure_enemy_bar():
	follow_entity = true
	auto_hide = true
	top_level = true
	z_index = 100
	custom_minimum_size = Vector2(150, 20)
	size = Vector2(150, 20)

	# Create auto-hide timer
	hide_timer = Timer.new()
	hide_timer.wait_time = auto_hide_delay
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_on_hide_timer_timeout)
	call_deferred("add_child", hide_timer)

	# Enable processing for following
	set_process(true)

## Configure health bar for boss (customizable, similar to enemy but larger)
func _configure_boss_bar():
	follow_entity = false  # Boss bars usually static on top of screen
	auto_hide = false
	z_index = 200
	# Can be customized per-boss

func _process(_delta):
	"""Update position for ENEMY/BOSS bars that follow entities"""
	if follow_entity and target_entity and is_instance_valid(target_entity):
		_update_follow_position()

func _update_follow_position():
	"""Update position to follow target entity"""
	var enemy_pos = target_entity.global_position

	# Center HP bar above enemy head
	var hp_bar_width = size.x if size.x > 0 else 150.0
	var centered_offset_x = -hp_bar_width / 2.0
	var hp_bar_world_pos = enemy_pos + Vector2(centered_offset_x + offset_x, offset_y)

	# Get camera for coordinate transformation
	var camera = get_viewport().get_camera_2d()
	if camera:
		# Transform world coordinates to screen coordinates for CanvasLayer
		var viewport_size = get_viewport().get_visible_rect().size
		var camera_center = camera.get_screen_center_position()
		var screen_pos = (hp_bar_world_pos - camera_center) + viewport_size / 2.0
		global_position = screen_pos
	else:
		global_position = hp_bar_world_pos

	# Ensure size is correct
	if size == Vector2.ZERO or size.x > 200:
		size = Vector2(150, 20)
		custom_minimum_size = Vector2(150, 20)

func setup_for_entity(entity: CombatBody2D, name_param: String = ""):
	"""Настройка HP бара для конкретной сущности"""
	target_entity = entity
	entity_name = name_param if name_param != "" else str(entity.name)

	# Подключаемся к сигналам
	if target_entity.has_signal("health_changed"):
		if not target_entity.health_changed.is_connected(_on_health_changed):
			target_entity.health_changed.connect(_on_health_changed)

	# For ENEMY type, position above entity
	if bar_type == HealthBarType.ENEMY and target_entity:
		_update_follow_position()
		visible = true
		hp_bar_visible = true

	# Инициализируем значения
	initialize_health_values()

func initialize_health_values():
	"""Инициализация значений здоровья"""
	if target_entity and bar:
		# Перевіряємо, чи значення вже встановлені (не дефолтні)
		var entity_max_health = int(target_entity.Max_Health)
		var entity_current_health = int(target_entity.current_health)
		
		# Якщо це гравець, НЕ встановлюємо значення - чекаємо на сигнал
		if entity_name == "Player":
			# НЕ встановлюємо значення для гравця - чекаємо на сигнал
			return
		else:
			# Для не-гравців використовуємо значення з сутності
			max_value = entity_max_health
			current_value = entity_current_health
		
		bar.max_value = max_value
		bar.value = current_value
		
		update_health_color(current_value)
		update_health_text()

func _on_health_changed(new_health: int, max_health: int, animate: bool = true):
	"""Обработчик изменения здоровья"""
	DebugLogger.verbose("HealthBar: _on_health_changed() called - new_health: %d, max_health: %d, animate: %s, visible: %s" % [new_health, max_health, animate, visible], "HealthBar")
	update_health_bar(new_health, max_health, animate)

func update_health_bar(new_health: int, max_health: int = -1, animate: bool = true):
	"""Обновление HP бара с анимацией"""
	DebugLogger.verbose("HealthBar: update_health_bar() called - new_health: %d, max_health: %d, animate: %s, visible: %s" % [new_health, max_health, animate, visible], "HealthBar")

	if not bar:
		DebugLogger.verbose("HealthBar: Bar not found, returning", "HealthBar")
		return
	
	# Обновляем максимальное значение, если оно изменилось
	if max_health != -1 and max_health != max_value:
		max_value = max_health
		bar.max_value = max_value
	
	# Сохраняем старое значение для эффектов
	var old_value = current_value
	current_value = new_health
	
	# Перевіряємо, чи значення дійсно змінилося
	# Але для гравця завжди оновлюємо, якщо це перший раз або bar.value = 0
	if entity_name == "Player" and (bar.value == 0 or old_value == 0):
		pass
	elif entity_name == "Player" and not animate:
		# Для гравця завжди оновлюємо при завантаженні стану (animate=false)
		pass
	elif old_value == new_health and not (max_health != -1 and max_health != max_value):
		return
	
	# Додаткова перевірка: якщо це завантаження стану без анімації, перевіряємо чи значення справді змінилося
	if not animate and old_value == new_health and entity_name != "Player":
		return
	
	# Анимируем изменение значения (только если включена анімація)
	if animate:
		animate_health_change(old_value, new_health)
	else:
		# Миттєво встановлюємо значення без анімації
		bar.value = new_health
	
	# Обновляем цвет и текст
	update_health_color(new_health)
	update_health_text()

	# Эффект при получении урона (только якщо включена анімація)
	if animate and new_health < old_value:
		create_damage_effect()

	# For ENEMY type: show bar and restart auto-hide timer
	if bar_type == HealthBarType.ENEMY and auto_hide:
		_show_health_bar()
		if hide_timer:
			hide_timer.start()

		# Special death effect for enemies
		if new_health <= 0:
			_create_death_effect()
			if hide_timer:
				hide_timer.wait_time = 1.0  # Quick hide for dead enemies

func animate_health_change(from_value: int, to_value: int):
	"""Анимация изменения здоровья"""
	var tween = create_tween()
	tween.tween_method(_update_bar_value, from_value, to_value, animation_duration)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

func _update_bar_value(value: int):
	"""Промежуточное обновление значения бара"""
	if bar:
		bar.value = value

func create_damage_effect():
	"""Создание эффекта при получении урона"""
	var tween = create_tween()
	tween.tween_property(bar, "modulate", Color.RED, damage_flash_duration / 2)
	tween.tween_property(bar, "modulate", Color.WHITE, damage_flash_duration / 2)

func update_health_color(current_health: int):
	"""Обновление цвета в зависимости от процента здоровья"""
	if not bar:
		return
	
	var health_percentage = float(current_health) / float(max_value)
	var fill_style = bar.get_theme_stylebox("fill")
	
	if not fill_style:
		return
	
	if health_percentage <= critical_threshold:
		fill_style.bg_color = critical_color
	elif health_percentage <= warning_threshold:
		fill_style.bg_color = warning_color
	else:
		fill_style.bg_color = healthy_color
	
	# Принудительно обновляем отображение
	bar.queue_redraw()

func update_health_text():
	"""Обновление текста здоровья"""
	if health_label and show_health_text:
		var percentage = int(get_health_percentage() * 100)
		health_label.text = str(current_value) + "/" + str(max_value) + " (" + str(percentage) + "%)"

func set_entity_name(name_param: String):
	"""Установка имени сущности"""
	self.entity_name = name_param
	if health_label:
		health_label.text = entity_name + ": " + str(current_value) + "/" + str(max_value)

func get_health_percentage() -> float:
	"""Получение процента здоровья"""
	if max_value <= 0:
		return 0.0
	return float(current_value) / float(max_value)

func is_healthy() -> bool:
	"""Проверка, здоров ли персонаж"""
	return get_health_percentage() > warning_threshold

func is_critical() -> bool:
	"""Проверка, критично ли здоровье"""
	return get_health_percentage() <= critical_threshold

func _on_visibility_changed():
	"""Відстежує зміну видимості HP бару"""
	DebugLogger.verbose("HealthBar: Visibility changed to: %s" % visible, "HealthBar")

## Auto-hide methods for ENEMY type bars

func _show_health_bar():
	"""Show HP bar (for ENEMY type)"""
	if not hp_bar_visible:
		visible = true
		hp_bar_visible = true

func _hide_health_bar():
	"""Hide HP bar (for ENEMY type)"""
	if hp_bar_visible:
		visible = false
		hp_bar_visible = false

func _on_hide_timer_timeout():
	"""Auto-hide HP bar after delay (for ENEMY type)"""
	if target_entity and "is_dead" in target_entity and not target_entity.is_dead:
		_hide_health_bar()
	elif target_entity and not "is_dead" in target_entity:
		_hide_health_bar()

func _create_death_effect():
	"""Special death effect for enemies"""
	if bar:
		var tween = create_tween()
		tween.set_loops(3)  # 3 flashes
		tween.tween_property(bar, "modulate", Color.RED, 0.1)
		tween.tween_property(bar, "modulate", Color.WHITE, 0.1)
