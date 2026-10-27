extends Node2D
class_name InteractableComponent

## Спільний компонент взаємодії (D74). Дочірній вузол будь-якого Area2D:
## показує UI/Interaction/Prompt, поки гравець в зоні, і випромінює `interacted`
## на дію `interact` (E / геймпад A). Жодних захардкоджених клавіш.
##
## Використання: додай як дочірній вузол Area2D, задай action_text,
## підключись до `interacted`.

signal interacted
signal player_entered
signal player_exited

const PROMPT_SCENE := preload("res://SampleProject/UI/Components/interaction_prompt.tscn")
const WORLD_UI := preload("res://SampleProject/UI/Components/world_ui.gd")
const ACTION := &"interact"

@export var action_text: String = "Interact":
	set(value):
		action_text = value
		if _prompt:
			_prompt.action_text = value
			_place_prompt()

## Вимкнений компонент не показує підказку і не реагує на ввід.
@export var enabled: bool = true:
	set(value):
		enabled = value
		_refresh_visibility()

@export var prompt_offset: Vector2 = Vector2(0, UITokens.PROMPT_OFFSET_Y)

## false — підказки немає зовсім: NPC відкриває своє меню сам, щойно герой поруч (D454).
@export var show_prompt: bool = true:
	set(value):
		show_prompt = value
		_refresh_visibility()

var player_nearby := false
var _prompt: InteractionPrompt = null
var _area: Area2D = null


func _ready() -> void:
	# Підказка має малюватись над спрайтами об'єкта.
	z_index = 20
	set_process(false)
	_area = get_parent() as Area2D
	if _area == null:
		push_error("InteractableComponent: parent must be an Area2D (%s)" % get_path())
		return
	_prompt = PROMPT_SCENE.instantiate()
	_prompt.action_text = action_text
	_prompt.visible = false
	add_child(_prompt)
	_place_prompt()
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	# Гравець міг уже стояти в зоні при завантаженні.
	_check_existing_bodies.call_deferred()


func get_prompt() -> InteractionPrompt:
	return _prompt


func _check_existing_bodies() -> void:
	if not is_inside_tree() or _area == null:
		return
	for body in _area.get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group(GameGroups.PLAYER) or player_nearby:
		return
	player_nearby = true
	_refresh_visibility()
	player_entered.emit()


func _on_body_exited(body: Node) -> void:
	if body == null or not body.is_in_group(GameGroups.PLAYER):
		return
	player_nearby = false
	_refresh_visibility()
	player_exited.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not (enabled and player_nearby) or not event.is_action_pressed(ACTION):
		return
	if not _gameplay_input_allowed():
		return
	get_viewport().set_input_as_handled()
	interacted.emit()


## Поки герой у зоні — щокадру: розмова, меню чи модалка могли початись або скінчитись. Під час них E нічого не робить,
## тож і підказки не видно (B160: «Enter» дверей погреба світився за відповідями перепису).
func _process(_delta: float) -> void:
	_refresh_visibility()


func _refresh_visibility() -> void:
	set_process(player_nearby)
	if _prompt == null:
		return
	var shown: bool = show_prompt and enabled and player_nearby and _gameplay_input_allowed()
	if shown and not _prompt.visible:
		_place_prompt()
	_prompt.visible = shown


## Підказка по центру над точкою компонента; ширина за вмістом (D84).
func _place_prompt() -> void:
	if _prompt == null:
		return
	_prompt.reset_size()
	_prompt.scale = WORLD_UI.screen_scale(self)  # екранний розмір під збільшеною камерою (D170)
	_prompt.position = prompt_offset - Vector2(_prompt.size.x * 0.5, _prompt.size.y) * _prompt.scale


## Не взаємодіємо, поки відкрите меню чи модалка — і поки йде розмова сюжету (D737): героя вона тримає, а E під час
## читання відчиняла двері в іншу кімнату посеред репліки. Репліки мимохідь (барки) не заважають.
func _gameplay_input_allowed() -> bool:
	var locator: Node = ServiceLocatorHelper.get_service_locator()
	return locator.get_ui_manager().is_gameplay_input_allowed() and not locator.get_dialogue_manager().is_story_busy()
