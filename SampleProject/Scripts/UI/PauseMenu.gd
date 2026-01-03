## Pause Menu з табами та slide transitions
## Використовує HD-2D UI стиль
extends Control
class_name PauseMenu

## Посилання на таби
@onready var tab_container: TabContainer = $TabContainer
@onready var items_tab: Control = $TabContainer/Items
@onready var equipment_tab: Control = $TabContainer/Equipment
@onready var skills_tab: Control = $TabContainer/Skills
@onready var settings_tab: Control = $TabContainer/Settings

## Посилання на кнопки табів
@onready var items_button: Button = $TopBar/ItemsButton
@onready var equipment_button: Button = $TopBar/EquipmentButton
@onready var skills_button: Button = $TopBar/SkillsButton
@onready var settings_button: Button = $TopBar/SettingsButton

## Посилання на анімації
@onready var animation_player: AnimationPlayer = $AnimationPlayer

## Поточний активний таб
var current_tab: int = 0

## Чи меню відкрите
var is_open: bool = false

## Сигнали
signal menu_opened()
signal menu_closed()
signal tab_changed(tab_index: int)

func _ready() -> void:
	# Приховуємо меню на старті
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Підключаємо кнопки табів
	if items_button:
		items_button.pressed.connect(_on_items_button_pressed)
	if equipment_button:
		equipment_button.pressed.connect(_on_equipment_button_pressed)
	if skills_button:
		skills_button.pressed.connect(_on_skills_button_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_button_pressed)
	
	# Блокуємо Equipment в демо
	if equipment_button:
		equipment_button.disabled = true
		equipment_button.text = "Equipment (Locked)"
	
	# Ініціалізуємо таби
	_initialize_tabs()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if is_open:
			close_menu()
		else:
			open_menu()

## Відкриває меню паузи
func open_menu() -> void:
	if is_open:
		return
	
	is_open = true
	visible = true
	get_tree().paused = true
	
	# Анімація відкриття
	if animation_player:
		animation_player.play("slide_in")
	
	# Оновлюємо поточний таб
	_switch_tab(0)
	
	menu_opened.emit()

## Закриває меню паузи
func close_menu() -> void:
	if not is_open:
		return
	
	# Анімація закриття
	if animation_player:
		animation_player.play("slide_out")
		await animation_player.animation_finished
	
	is_open = false
	visible = false
	get_tree().paused = false
	
	menu_closed.emit()

## Перемикає таб
func _switch_tab(tab_index: int) -> void:
	if tab_index == current_tab:
		return
	
	var old_tab = current_tab
	current_tab = tab_index
	
	# Оновлюємо TabContainer
	if tab_container:
		tab_container.current_tab = tab_index
	
	# Оновлюємо кнопки
	_update_tab_buttons()
	
	# Slide transition анімація
	_animate_tab_transition(old_tab, tab_index)
	
	tab_changed.emit(tab_index)

## Анімує перехід між табами
func _animate_tab_transition(from_tab: int, to_tab: int) -> void:
	if not animation_player:
		return
	
	# Створюємо анімацію slide transition
	var anim_name = "tab_slide_%d_to_%d" % [from_tab, to_tab]
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
	else:
		# Використовуємо загальну анімацію
		animation_player.play("tab_switch")

## Оновлює стан кнопок табів
func _update_tab_buttons() -> void:
	if items_button:
		items_button.button_pressed = (current_tab == 0)
	if equipment_button:
		equipment_button.button_pressed = (current_tab == 1)
	if skills_button:
		skills_button.button_pressed = (current_tab == 2)
	if settings_button:
		settings_button.button_pressed = (current_tab == 3)

## Ініціалізує таби
func _initialize_tabs() -> void:
	# Items tab
	if items_tab:
		_setup_items_tab()
	
	# Equipment tab (заблокований в демо)
	if equipment_tab:
		_setup_equipment_tab()
	
	# Skills tab
	if skills_tab:
		_setup_skills_tab()
	
	# Settings tab
	if settings_tab:
		_setup_settings_tab()

## Налаштовує Items tab
func _setup_items_tab() -> void:
	# Тут буде логіка для відображення інвентаря
	pass

## Налаштовує Equipment tab
func _setup_equipment_tab() -> void:
	# Заблокований в демо
	var locked_label = Label.new()
	locked_label.text = "Equipment system will be available in full release"
	locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	locked_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equipment_tab.add_child(locked_label)

## Налаштовує Skills tab
func _setup_skills_tab() -> void:
	# Тут буде логіка для відображення навичок
	pass

## Налаштовує Settings tab
func _setup_settings_tab() -> void:
	# Тут буде логіка для налаштувань
	pass

## Обробники кнопок табів
func _on_items_button_pressed() -> void:
	_switch_tab(0)

func _on_equipment_button_pressed() -> void:
	if equipment_button and not equipment_button.disabled:
		_switch_tab(1)

func _on_skills_button_pressed() -> void:
	_switch_tab(2)

func _on_settings_button_pressed() -> void:
	_switch_tab(3)

