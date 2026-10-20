extends Node2D

## Облачко над головою (D178): монологи Кусакама показуються тут, а не в боксі діалогу, і гравець
## при цьому ходить. Вузол — дочірній гравцеві, тож іде за ним; flip_h крутить лише спрайт.
## Початок координат — вістря хвоста. Арт тимчасовий (D160 чекає малюнків Sapega).

const BODY := preload("res://SampleProject/Assets/UI/Dialogue/bubble_body.png")
const TAIL := preload("res://SampleProject/Assets/UI/Dialogue/bubble_tail.png")
const WORLD_UI := preload("res://SampleProject/UI/Components/world_ui.gd")

## Набрано [param count] літер репліки (type_out) — бурмотіння голосом мовця (D277).
signal typed(text: String, count: int)

var _panel := PanelContainer.new()
var _label := Label.new()
var _tail := TextureRect.new()


func _ready() -> void:
	z_index = 30
	var box := StyleBoxTexture.new()
	box.texture = BODY
	box.set_texture_margin_all(UITokens.BUBBLE_MARGIN)
	box.set_content_margin_all(UITokens.BUBBLE_PADDING)
	_panel.add_theme_stylebox_override(&"panel", box)
	# Світ не під GameUITheme (він лише на UI-шарах), тож шрифт і колір — прямо з токенів.
	_label.add_theme_font_override(&"font", load(UITokens.FONT_PATH))
	_label.add_theme_font_size_override(&"font_size", UITokens.font_px(UITokens.SIZE_BODY))
	_label.add_theme_color_override(&"font_color", UITokens.BUBBLE_INK)
	# Набір (type_out) лише ховає літери вже розкладеного тексту — облачко не росте посеред репліки.
	_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_panel.add_child(_label)
	_tail.texture = TAIL
	add_child(_panel)
	add_child(_tail)  # після тіла — хвіст закриває його нижній контур
	visible = false


func show_line(text: String) -> void:
	_label.text = text
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.custom_minimum_size.x = 0.0
	var inner_max: float = UITokens.BUBBLE_MAX_WIDTH - 2.0 * UITokens.BUBBLE_PADDING
	if _label.get_minimum_size().x > inner_max:
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.custom_minimum_size.x = inner_max
		# Висоту перенесеного тексту Label знає лише після кадру розкладки.
		await get_tree().process_frame
		_label.update_minimum_size()
	_panel.size = Vector2.ZERO
	_panel.reset_size()
	scale = WORLD_UI.screen_scale(self)  # екранний розмір під збільшеною камерою (D170)
	# У правій половині екрана облачко росте ліворуч, щоб не вилізти за край.
	var left: bool = get_global_transform_with_canvas().origin.x > get_viewport_rect().size.x * 0.5
	var tail: Vector2 = TAIL.get_size()
	_tail.flip_h = left
	_tail.position = Vector2(-tail.x * (0.8 if left else 0.2), -tail.y)
	var body_x: float = _panel.size.x * (0.75 if left else 0.25)
	_panel.position = Vector2(-body_x, -tail.y + UITokens.BUBBLE_TAIL_OVERLAP - _panel.size.y)
	visible = true


## Репліка, показана show_line(), набирається за [param seconds] (розмова в облачку, D263). Пауза тримає набір.
func type_out(seconds: float) -> void:
	_label.visible_characters = 0
	if seconds > 0.0:
		await create_tween().tween_method(_type_to, 0, _label.text.length(), seconds).finished
	_label.visible_ratio = 1.0


## Остання літера з'являється лише з кінцем type_out: is_typed() не має стати true раніше, ніж набір повернувся.
func _type_to(count: int) -> void:
	if count > _label.visible_characters and count < _label.text.length():
		_label.visible_characters = count
		typed.emit(_label.text, count)


func is_typed() -> bool:
	return _label.visible_ratio >= 1.0


static func seconds_for(text: String) -> float:
	return clampf(UITokens.BUBBLE_SECONDS_MIN + text.length() * UITokens.BUBBLE_SECONDS_PER_CHAR,
			UITokens.BUBBLE_SECONDS_MIN, UITokens.BUBBLE_SECONDS_MAX)
