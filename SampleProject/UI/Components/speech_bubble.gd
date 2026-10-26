extends Node2D

## Облачко над головою (D178): монологи Кусакама показуються тут, а не в боксі діалогу; героя тримає, поки
## монолог іде (D737). Вузол — дочірній гравцеві, тож іде за ним; flip_h крутить лише спрайт.
## Початок координат — вістря хвоста. Арт тимчасовий (D160 чекає малюнків Sapega).

const BODY := preload("res://SampleProject/Assets/UI/Dialogue/bubble_body.png")
const TAIL := preload("res://SampleProject/Assets/UI/Dialogue/bubble_tail.png")
const WORLD_UI := preload("res://SampleProject/UI/Components/world_ui.gd")

## Набрано [param count] літер репліки (type_out) — бурмотіння голосом мовця (D277).
signal typed(text: String, count: int)

## Набір type_out(), поки він іде.
var _typing: Tween
## Крок, що домотує будь-який набір до кінця (finish_typing).
const FINISH_STEP := 3600.0

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
	_label.add_theme_font_size_override(&"font_size", UITokens.font_px(UITokens.SIZE_BODY, true))  # D474: ігровий текст ×1.5
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
		_typing = create_tween()
		_typing.tween_method(_type_to, 0, _label.text.length(), seconds)
		await _typing.finished
		_typing = null
	_label.visible_ratio = 1.0


## D738: «далі» під час набору — уся репліка одразу (як у вікні діалогу): твін домотується, type_out повертається.
func is_typing() -> bool:
	return _typing != null


func finish_typing() -> void:
	_typing.custom_step(FINISH_STEP)


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
