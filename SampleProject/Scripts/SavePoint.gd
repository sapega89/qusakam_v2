# Точка збереження. Поруч — підказка "[A] Save" (UI/Interaction/Prompt, D74);
# interact садить героя медитувати (D447, кадри Meditate, як у каньйоні) і тоді відкриває Save Slot Selection
# у режимі SAVE (D75); вихід з екрана його підводить. Медитація повертає звичайних ворогів (D492, Game.meditate()).
# Автозбереження при дотику прибрано (Q5): зберігаємо лише свідомо через підказку.
# Арт місця медитації (килимок, камінне коло, D447) ще не зроблений — поки що старе синє коло з «S».
extends Area2D

const WORLD_UI := preload("res://SampleProject/UI/Components/world_ui.gd")

## Offset для позиции спавна (относительно SavePoint)
@export var spawn_offset: Vector2 = Vector2(0, 0)

## Позиционировать игрока при сохранении (true = игрок встанет на SavePoint)
@export var position_player_on_touch: bool = true

## D447: скільки герой сидить, перш ніж відкриється екран збереження (с).
const MEDITATE_SIT_TIME := 0.8

var interactable: InteractableComponent = null
## Герой уже сидить тут — повторне натискання нічого не робить.
var meditating := false

## Герой сів медитувати / підвівся (екран збереження закрито).
signal meditation_started
signal meditation_finished

func _ready() -> void:
	# Добавляем в группу для поиска SavePoint'ов при загрузке комнаты
	add_to_group("save_points")

	interactable = InteractableComponent.new()
	interactable.name = "Interactable"
	interactable.action_text = "Save"
	add_child(interactable)
	interactable.interacted.connect(_on_interacted)
	# Коло й «S» тримають екранний розмір під збільшеною камерою (D170), як підказка.
	var label: Label = $Label
	label.pivot_offset = label.size * 0.5
	label.scale = WORLD_UI.screen_scale(self)

func _on_interacted() -> void:
	if meditating:
		return
	var player := GameGroups.get_first_node_in_group(GameGroups.PLAYER) as Node2D

	# Позиционируем игрока на SavePoint перед сохранением — сейв відновить саме цю точку.
	if position_player_on_touch and player:
		# D447: лише по горизонталі — герой сідає на підлозі, де стоїть, а не зависає на висоті кола.
		var spawn_pos := Vector2(global_position.x + spawn_offset.x, player.global_position.y)
		player.global_position = spawn_pos
		DebugLogger.info("SavePoint: Positioned player at %s" % spawn_pos, "SavePoint")
		MetSys.set_player_position(player.global_position)

	var game := Game.get_singleton()
	# Starting coords for the delta vector feature.
	game.reset_map_starting_coords()

	await _meditate(player, game)


## D447: герой сідає й медитує, тоді — екран збереження; закрили екран — він встає й знову ходить.
func _meditate(player: Node2D, game: Game) -> void:
	meditating = true
	player.set_movement_enabled(false)
	player.play_body(&"Meditate")
	game.meditate()
	meditation_started.emit()
	await get_tree().create_timer(MEDITATE_SIT_TIME, false).timeout
	var ui_manager: Node = ServiceLocator.get_ui_manager()
	ui_manager.open_save_game()
	await (ui_manager.current_state as Node).tree_exiting
	player.play_body(&"Idle")
	player.set_movement_enabled(true)
	meditating = false
	meditation_finished.emit()

func _draw() -> void:
	# Draws the circle.
	draw_set_transform(Vector2.ZERO, 0.0, WORLD_UI.screen_scale(self))
	$CollisionShape2D.shape.draw(get_canvas_item(), Color.BLUE)
