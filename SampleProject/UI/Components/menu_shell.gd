extends Control
class_name UIMenuShell

## Спільний каркас екранів ігрового меню.
## Figma: спільна структура всіх кадрів menu-* у секції Game Menu (144:1801).
##
##   Background (арт) → DimOverlay → MainLayout(LeftColumn + ContentRoot) → BottomBar
##
## Каркас НЕ знає про конкретні екрани. Екран монтує свій вміст у [member content_root]
## і додає пункти навігації через [method add_nav_item].
##
## Phase 4: каркас створено, але ще нікуди не підключено — існуючі меню працюють
## як раніше. Підключення відбудеться у Phase 5, по одному екрану за раз.

## Емітується при виборі пункту бічної навігації.
signal nav_selected(id: StringName)

@onready var background: TextureRect = %Background
@onready var dim_overlay: ColorRect = %DimOverlay
@onready var title_label: Label = %TitleLabel
@onready var sidebar: VBoxContainer = %Sidebar
@onready var content_root: PanelContainer = %ContentRoot
@onready var bottom_bar: UIBottomBar = %BottomBar

var _nav_buttons: Dictionary = {}  # StringName -> Button
var _nav_group := ButtonGroup.new()


func set_title(text: String) -> void:
	title_label.text = text


## Додає пункт бічної навігації. Повертає створену кнопку.
## [code]id[/code] — стабільний ідентифікатор, що приходить у [signal nav_selected].
func add_nav_item(id: StringName, text: String, enabled: bool = true) -> Button:
	var button := Button.new()
	button.name = String(id)
	button.text = text
	button.theme_type_variation = &"SidebarTab"
	button.toggle_mode = true
	button.button_group = _nav_group
	button.disabled = not enabled
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_on_nav_pressed.bind(id))

	sidebar.add_child(button)
	_nav_buttons[id] = button
	return button


## Позначає пункт активним без емісії сигналу.
func select_nav(id: StringName) -> void:
	var button: Button = _nav_buttons.get(id)
	if button and not button.disabled:
		button.set_pressed_no_signal(true)


func get_nav_item(id: StringName) -> Button:
	return _nav_buttons.get(id)


## Фонове зображення (у Figma — ілюстрована мапа під затемненням).
func set_background_texture(texture: Texture2D) -> void:
	background.texture = texture
	background.visible = texture != null


func _on_nav_pressed(id: StringName) -> void:
	nav_selected.emit(id)
