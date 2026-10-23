extends Control
class_name DemoEndScreen

## Фінал демо (D473): керування вимкнено, HUD гасне, камера ~4 с пливе вгору в небо під тихе наростання музики,
## потім титул «KHALAHAS / HEROES» (як у головному меню) і подяка з HexButton «Return to Main Menu».
## Небо — прокляття (D587): тон тихий і зловісний — повільна панорама, приглушене наростання й темніша музика, без фанфар.
## Лише картка без сцени (тести, переклад) — просто екземпляр; повний фінал запускає кімната через play_finale().

signal return_to_menu
## Фінал дограв: титул і кнопка на екрані, кнопка у фокусі.
signal finale_shown

const HUD_FADE := 0.5
const PAN_TIME := 4.0
## Наростання музики за час панорами: +дБ і трохи нижчий тон.
const SWELL_DB := 4.0
const SWELL_PITCH := 0.94
const TITLE_FADE := 2.0
const FAREWELL_FADE := 1.2
const SHADE_FADE := 2.0

@onready var return_button: Button = %ReturnButton
@onready var _shade: ColorRect = $Shade
@onready var _title: Control = $VBoxContainer/GameTitle
@onready var _farewell: Control = $VBoxContainer/Farewell


func _ready() -> void:
	$VBoxContainer/GameTitle/TopRule.custom_minimum_size.x = UITokens.TITLE_RULE_OUTER
	$VBoxContainer/GameTitle/MiddleRule.custom_minimum_size.x = UITokens.TITLE_RULE_MIDDLE
	$VBoxContainer/GameTitle/BottomRule.custom_minimum_size.x = UITokens.TITLE_RULE_OUTER
	_shade.color = UITokens.OVERLAY
	return_button.custom_minimum_size = Vector2(UITokens.MODAL_BUTTON_WIDTH, UITokens.MODAL_BUTTON_HEIGHT)
	return_button.focus_entered.connect(func() -> void: return_button.theme_type_variation = &"ModalButtonOn")
	return_button.focus_exited.connect(func() -> void: return_button.theme_type_variation = &"ModalButton")
	return_button.mouse_entered.connect(return_button.grab_focus)
	return_button.pressed.connect(_on_return_button_pressed)
	_translate_button()
	GameGroups.get_player().set_movement_enabled(false)
	# Фокус на кнопку — геймпад A / Enter (BACKLOG 24)
	return_button.grab_focus.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_translate_button()


## Figma UI/HexButton: підпис великими літерами — авто-переклад не знайшов би "RETURN TO MAIN MENU".
func _translate_button() -> void:
	return_button.text = tr("Return to Main Menu").to_upper()


## Повний фінал (D473) у кімнаті кінця демо: [param music] — її музика, [param sky_top] — верх неба над нею (світові px).
## Екран уже в UICanvas гри.
func play_finale(music: AudioStreamPlayer, sky_top: float) -> void:
	var game := Game.get_singleton()
	_shade.modulate.a = 0.0
	_title.modulate.a = 0.0
	_farewell.modulate.a = 0.0
	return_button.disabled = true
	return_button.release_focus.call_deferred()

	# (1) HUD гасне: усе в шарах HUD, крім самого фіналу.
	var hud := create_tween().set_parallel()
	for layer_name in [^"UI", ^"UICanvas"]:
		for child in game.get_node(layer_name).get_children():
			if child != self and child is CanvasItem:
				hud.tween_property(child, ^"modulate:a", 0.0, HUD_FADE)
	await hud.finished

	# (2) Камера відчеплена від героя й пливе вгору, доки верх неба не стане верхом кадру; музика тихо наростає.
	var camera: Camera2D = game.player.get_node(^"Camera2D")
	var center := camera.get_screen_center_position()
	camera.top_level = true
	camera.global_position = center
	camera.reset_smoothing()
	camera.limit_top = floori(sky_top)
	var view_height := get_viewport_rect().size.y / camera.zoom.y
	var pan := create_tween().set_parallel()
	pan.tween_property(camera, ^"global_position:y", sky_top + view_height / 2.0, PAN_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pan.tween_property(music, ^"volume_db", music.volume_db + SWELL_DB, PAN_TIME).set_trans(Tween.TRANS_SINE)
	pan.tween_property(music, ^"pitch_scale", SWELL_PITCH, PAN_TIME)
	await pan.finished

	# (3) Титул, (4) подяка й кнопка.
	var card := create_tween()
	card.set_parallel()
	card.tween_property(_shade, ^"modulate:a", 1.0, SHADE_FADE)
	card.tween_property(_title, ^"modulate:a", 1.0, TITLE_FADE)
	card.chain().tween_property(_farewell, ^"modulate:a", 1.0, FAREWELL_FADE)
	await card.finished
	return_button.disabled = false
	return_button.grab_focus()
	finale_shown.emit()


func _on_return_button_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(self, ^"modulate:a", 0.0, 0.3)
	await tween.finished
	# Перехід до меню робить той, хто показав екран (LaboratoryOutside). Другий
	# change_scene_to_file тут падав: сцену вже вийнято з дерева, get_tree() == null.
	return_to_menu.emit()
