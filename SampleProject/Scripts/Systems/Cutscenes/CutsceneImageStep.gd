## Крок катсцени зі статичним зображенням та текстом
## Відображає зображення з текстом (як комікс)
extends CutsceneStep
class_name CutsceneImageStep

## Шлях до зображення
@export var image_path: String = ""

## Текст для відображення
@export var text: String = ""

## Тривалість відображення (якщо 0, чекає на натискання)
@export var display_duration: float = 0.0

## Посилання на UI елементи
var image_display: TextureRect = null
var text_label: Label = null
var cutscene_ui: Control = null

func _ready() -> void:
	super._ready()
	step_name = "ImageStep"

## Кастомна логіка виконання
func _on_execute() -> void:
	# Знаходимо UI для катсцен
	_find_cutscene_ui()
	
	if not cutscene_ui:
		push_error("CutsceneImageStep: CutsceneUI not found")
		complete()
		return
	
	# Завантажуємо зображення
	var texture: Texture2D = null
	if image_path != "" and ResourceLoader.exists(image_path):
		texture = load(image_path) as Texture2D
	
	# Відображаємо зображення та текст
	_display_image_and_text(texture, text)
	
	# Чекаємо на завершення
	if display_duration > 0.0:
		await get_tree().create_timer(display_duration).timeout
		complete()
	else:
		# Чекаємо на натискання кнопки
		await _wait_for_input()
		complete()

## Знаходить UI для катсцен
func _find_cutscene_ui() -> void:
	var scene_root = get_tree().current_scene
	if scene_root:
		cutscene_ui = scene_root.get_node_or_null("CutsceneUI") as Control
		if not cutscene_ui:
			# Шукаємо в UICanvas
			var ui_canvas = scene_root.get_node_or_null("UICanvas")
			if ui_canvas:
				cutscene_ui = ui_canvas.get_node_or_null("CutsceneUI") as Control

## Відображає зображення та текст
func _display_image_and_text(texture: Texture2D, text_string: String) -> void:
	if not cutscene_ui:
		return
	
	# Знаходимо або створюємо елементи
	image_display = cutscene_ui.get_node_or_null("ImageDisplay") as TextureRect
	text_label = cutscene_ui.get_node_or_null("TextLabel") as Label
	
	if not image_display:
		image_display = TextureRect.new()
		image_display.name = "ImageDisplay"
		image_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cutscene_ui.add_child(image_display)
	
	if not text_label:
		text_label = Label.new()
		text_label.name = "TextLabel"
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cutscene_ui.add_child(text_label)
	
	# Встановлюємо зображення
	if texture:
		image_display.texture = texture
		image_display.visible = true
	else:
		image_display.visible = false
	
	# Встановлюємо текст (локалізований)
	if text_string != "":
		text_label.text = tr(text_string) if text_string.begins_with("msgid:") else text_string
		text_label.visible = true
	else:
		text_label.visible = false
	
	# Показуємо UI
	cutscene_ui.visible = true

## Чекає на введення (натискання кнопки)
func _wait_for_input() -> void:
	# Чекаємо на натискання будь-якої кнопки
	await get_tree().create_timer(0.1).timeout  # Невелика затримка
	
	# Підключаємося до сигналу натискання
	var button = cutscene_ui.get_node_or_null("ContinueButton") as Button
	if button:
		await button.pressed
	else:
		# Якщо немає кнопки, чекаємо на будь-яке натискання
		var input_event = await get_tree().input_event
		if input_event is InputEventKey or input_event is InputEventMouseButton:
			pass

## Скидає крок
func reset() -> void:
	super.reset()
	if cutscene_ui:
		cutscene_ui.visible = false
	if image_display:
		image_display.visible = false
	if text_label:
		text_label.visible = false

