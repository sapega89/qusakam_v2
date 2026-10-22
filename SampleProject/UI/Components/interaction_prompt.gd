extends PanelContainer
class_name InteractionPrompt

## Підказка взаємодії "[A] Дія" — Figma UI/Interaction/Prompt (461:6479).
## Покращений варіант за D84: ширина за вмістом, текст 16 px (UILabel), той самий стиль.
## Бейдж перемикається між клавіатурою (E) і геймпадом (A) за останнім пристроєм вводу.
##
## Стилі — лише з GameUITheme (варіації InteractionPrompt*/PromptRow/UILabel).

enum State { DEFAULT, FOCUSED, DISABLED }

const THEME_PATH := "res://SampleProject/UI/Themes/GameUITheme.tres"
const BADGE_KEYBOARD := preload("res://SampleProject/Assets/UI/Icons/input_key_e.svg")
const BADGE_GAMEPAD := preload("res://SampleProject/Assets/UI/Icons/input_gamepad_y.svg")  # interact — Y (D156)

const _VARIATIONS := {
	State.DEFAULT: &"InteractionPrompt",
	State.FOCUSED: &"InteractionPromptFocused",
	State.DISABLED: &"InteractionPromptDisabled",
}

const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")

@export var action_text: String = "Interact":
	set(value):
		action_text = value
		if is_node_ready():
			_label.text = value
			reset_size()

@export var state: State = State.DEFAULT:
	set(value):
		state = value
		if is_node_ready():
			_apply_state()

@onready var _badge: TextureRect = %Badge
@onready var _label: Label = %ActionLabel


func _ready() -> void:
	# Підказка живе у світі гри, поза UIRoot/ModalLayer, тож тему треба задати явно.
	if theme == null:
		theme = load(THEME_PATH)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.custom_minimum_size = Vector2(UITokens.PROMPT_BADGE, UITokens.PROMPT_BADGE)
	_label.text = action_text
	_apply_state()
	_apply_badge()
	get_node(^"/root/EventBus").input_device_changed.connect(_apply_badge.unbind(1))


## Пристрій — спільний InputGlyphs (увесь ввід бачить InputDeviceWatcher). Власний прапорець підказки оновлювався
## лише поки якась підказка була в дереві: у новій кімнаті вона показувала E, хоч гравець тримав стік.
func is_using_gamepad() -> bool:
	return InputGlyphs.using_gamepad


func _apply_state() -> void:
	theme_type_variation = _VARIATIONS[state]
	var alpha := UITokens.PROMPT_DISABLED_CONTENT_ALPHA if state == State.DISABLED else 1.0
	_badge.modulate.a = alpha
	_label.modulate.a = alpha


func _apply_badge() -> void:
	var tex: Texture2D = BADGE_GAMEPAD if InputGlyphs.using_gamepad else BADGE_KEYBOARD
	if _badge.texture != tex:
		_badge.texture = tex
