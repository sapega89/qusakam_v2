extends PanelContainer
class_name GameTitle

## 🎮 GameTitle - Переиспользуемый компонент заголовка игры
## Используется в title_screen и main_menu

@export var title_text: String = "WAY OF\nQUSAKAM":
	set(value):
		title_text = value
		_update_title_text()

@export var enable_glow_effect: bool = false:
	set(value):
		enable_glow_effect = value
		_update_glow_effect()

@export var glow_intensity: float = 1.8
@export var glow_color: Color = Color(1, 1, 1, 0.396)
@export var glow_strength: float = 0.662

@onready var title_label: Label = $VBoxContainer/TitleLabel

var glow_shader: Shader = null
var glow_material: ShaderMaterial = null

func _ready():
	# Загружаем шейдер для эффекта свечения
	if enable_glow_effect:
		# Шейдер загружается из ресурса, если он существует
		# glow_shader = load("res://SampleProject/Scenes/Menus/Main/main_menu.tres")
		# if glow_shader:
		#     glow_material = ShaderMaterial.new()
		#     glow_material.shader = glow_shader
		pass
	
	_update_title_text()
	_update_glow_effect()

func _update_title_text():
	if title_label:
		title_label.text = title_text

func _update_glow_effect():
	if not title_label:
		return
	
	if enable_glow_effect and glow_material:
		# Настраиваем параметры шейдера
		glow_material.set_shader_parameter("glow_intensity", glow_intensity)
		glow_material.set_shader_parameter("glow_color", glow_color)
		glow_material.set_shader_parameter("glow_strength", glow_strength)
		
		title_label.material = glow_material
		title_label.modulate = Color(1.2, 1.2, 1.2, 1)
		title_label.use_parent_material = true
		title_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	else:
		title_label.material = null
		title_label.modulate = Color.WHITE
		title_label.use_parent_material = false

