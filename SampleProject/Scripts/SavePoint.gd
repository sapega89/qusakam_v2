# Точка збереження. Поруч — підказка "[A] Save" (UI/Interaction/Prompt, D74);
# interact відкриває Save Slot Selection у режимі SAVE (D75).
# Автозбереження при дотику прибрано (Q5): зберігаємо лише свідомо через підказку.
extends Area2D

## Offset для позиции спавна (относительно SavePoint)
@export var spawn_offset: Vector2 = Vector2(0, 0)

## Позиционировать игрока при сохранении (true = игрок встанет на SavePoint)
@export var position_player_on_touch: bool = true

var interactable: InteractableComponent = null

func _ready() -> void:
	# Добавляем в группу для поиска SavePoint'ов при загрузке комнаты
	add_to_group("save_points")

	interactable = InteractableComponent.new()
	interactable.name = "Interactable"
	interactable.action_text = "Save"
	add_child(interactable)
	interactable.interacted.connect(_on_interacted)

func _on_interacted() -> void:
	var player := GameGroups.get_first_node_in_group(GameGroups.PLAYER) as Node2D

	# Позиционируем игрока на SavePoint перед сохранением — сейв відновить саме цю точку.
	if position_player_on_touch and player:
		var spawn_pos = global_position + spawn_offset
		player.global_position = spawn_pos
		DebugLogger.info("SavePoint: Positioned player at %s" % spawn_pos, "SavePoint")
		MetSys.set_player_position(player.global_position)

	var game := Game.get_singleton()
	if game:
		# Starting coords for the delta vector feature.
		game.reset_map_starting_coords()

	var ui = ServiceLocatorHelper.get_manager("get_ui_manager")
	if ui and ui.has_method("open_save_game"):
		ui.open_save_game()
	else:
		push_error("SavePoint: UIManager unavailable, cannot open the save screen")

func _draw() -> void:
	# Draws the circle.
	$CollisionShape2D.shape.draw(get_canvas_item(), Color.BLUE)
