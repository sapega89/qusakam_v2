extends Control
class_name GameOverScreen

## Екран Game Over. Figma: game-over-screen 41:83.
## Показується замість миттєвого респавну, коли гравець гине (Player.die()).
##
##   Resume from last save point → завантажити слот, що востаннє зберігався/завантажувався (Q6).
##                                  Немає сейва — стара поведінка: респавн біля входу в кімнату.
##   Return to title              → титульний екран, як "Return to Title" у меню Misc.

const SCENE_PATH := "res://SampleProject/Scenes/UI/game_over_screen.tscn"
const GAME_SCENE := "res://SampleProject/Game.tscn"
const MAIN_MENU := "res://SampleProject/MainMenu.tscn"

## Гравець, що загинув (для респавну, якщо сейва немає).
var player: Node = null
## Чи міняти сцену (тести вимикають, щоб перевірити лише рішення).
var change_scenes := true
## Що вибрано: "load", "respawn" або "title" — для тестів і логів.
var last_action := ""

@onready var _resume: Button = %ResumeButton
@onready var _title: Button = %TitleButton


## Показує екран у власному CanvasLayer під паузою. false — показати нікуди (немає сцени).
static func present(dead_player: Node) -> bool:
	var tree := dead_player.get_tree() if dead_player else null
	var host := tree.current_scene if tree else null
	if host == null or not ResourceLoader.exists(SCENE_PATH):
		return false
	# Повторний виклик смерті, поки екран уже відкритий, не створює другий.
	if tree.get_first_node_in_group(&"game_over_screen") != null:
		return true
	var layer := CanvasLayer.new()
	layer.name = "GameOverLayer"
	layer.layer = 14
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(layer)
	var screen: GameOverScreen = load(SCENE_PATH).instantiate()
	screen.player = dead_player
	layer.add_child(screen)
	tree.paused = true
	return true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"game_over_screen")
	_build_vignette()
	for frame: Control in [%Inset, %Corners]:
		frame.offset_left = UITokens.GAME_OVER_INSET
		frame.offset_top = UITokens.GAME_OVER_INSET
		frame.offset_right = -UITokens.GAME_OVER_INSET
		frame.offset_bottom = -UITokens.GAME_OVER_INSET
	_place_corners()
	%Rule.custom_minimum_size.x = UITokens.GAME_OVER_RULE
	for line in [%EyebrowLineLeft, %EyebrowLineRight]:
		line.custom_minimum_size.x = UITokens.GAME_OVER_EYEBROW_LINE
	%EyebrowDiamond.modulate = UITokens.GAME_OVER_RED
	var footer: Control = %Footer
	footer.offset_top = -UITokens.GAME_OVER_FOOTER_BOTTOM - footer.get_combined_minimum_size().y
	footer.offset_bottom = -UITokens.GAME_OVER_FOOTER_BOTTOM
	for b in [_resume, _title]:
		b.custom_minimum_size.x = UITokens.MENU_ITEM_WIDTH
		b.focus_entered.connect(func(): b.theme_type_variation = &"NpcMenuItemOn")
		b.focus_exited.connect(func(): b.theme_type_variation = &"NpcMenuItem")
		b.mouse_entered.connect(b.grab_focus)
	_resume.pressed.connect(resume)
	_title.pressed.connect(return_to_title)
	_resume.grab_focus.call_deferred()


## Figma: радіальний градієнт поверх фото підземелля.
func _build_vignette() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(UITokens.GAME_OVER_VIGNETTE.map(func(s): return s[1]))
	gradient.colors = PackedColorArray(UITokens.GAME_OVER_VIGNETTE.map(func(s): return s[0]))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	(%Vignette as TextureRect).texture = tex


## Кути лежать на шарі розміру рамки: кожен прив'язаний до свого кута
## і віддзеркалений через scale (малюється від точки прив'язки всередину).
func _place_corners() -> void:
	var specs := [[%CornerTL, Vector2(0, 0)], [%CornerTR, Vector2(1, 0)],
		[%CornerBL, Vector2(0, 1)], [%CornerBR, Vector2(1, 1)]]
	for spec in specs:
		var corner: Control = spec[0]
		var anchor: Vector2 = spec[1]
		corner.anchor_left = anchor.x
		corner.anchor_right = anchor.x
		corner.anchor_top = anchor.y
		corner.anchor_bottom = anchor.y
		corner.offset_left = 0
		corner.offset_top = 0
		corner.offset_right = 0
		corner.offset_bottom = 0
		corner.scale = Vector2(-1 if anchor.x > 0 else 1, -1 if anchor.y > 0 else 1)


## Resume from last save point.
func resume() -> void:
	var ss = ServiceLocatorHelper.get_manager("get_save_system")
	var slot := int(ss.current_slot) if ss else 0
	if ss and ss.has_method("slot_has_save") and ss.slot_has_save(slot):
		last_action = "load"
		get_tree().set_meta("save_file_path", ss.get_slot_path(slot))
		get_tree().set_meta("start_new_game", false)
		_leave(GAME_SCENE)
		return
	# Сейва ще немає — зберігаємо стару поведінку: респавн біля входу в кімнату.
	last_action = "respawn"
	_close()
	if player and is_instance_valid(player) and player.has_method("kill"):
		player.kill()


## Return to title — як "Return to Title" у меню Misc (game_menu.gd).
func return_to_title() -> void:
	last_action = "title"
	get_tree().set_meta("show_title_screen", true)
	_leave(MAIN_MENU)


func _leave(scene: String) -> void:
	get_tree().paused = false
	if change_scenes:
		get_tree().change_scene_to_file(scene)


func _close() -> void:
	get_tree().paused = false
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.queue_free()
	else:
		queue_free()
