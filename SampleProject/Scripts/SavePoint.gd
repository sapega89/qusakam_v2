# Точка збереження. Поруч — підказка "[A] Save" (UI/Interaction/Prompt, D74);
# interact садить героя медитувати (D447, кадри Meditate, як у каньйоні) і тоді відкриває Save Slot Selection
# у режимі SAVE (D75); вихід з екрана його підводить. Медитація повертає звичайних ворогів (D492, Game.meditate()).
# Автозбереження при дотику прибрано (Q5): зберігаємо лише свідомо через підказку.
# Місце медитації (D764) — частина фону кімнати (`Spot`), герой застрибує на нього (`Seat`), сідає, а встаючи — зістрибує.
extends Area2D

## Offset для позиции спавна (относительно SavePoint)
@export var spawn_offset: Vector2 = Vector2(0, 0)

## Позиционировать игрока при сохранении (true = игрок встанет на SavePoint)
@export var position_player_on_touch: bool = true

## D447: скільки герой сидить, перш ніж відкриється екран збереження (с).
const MEDITATE_SIT_TIME := 0.8
## D764: стрибок на місце медитації й назад — час (с) і висота дуги над прямою (px).
const HOP_TIME := 0.3
const HOP_ARC := 14.0

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
	await _meditate(player, game)


## D447: герой сідає й медитує, тоді — екран збереження; закрили екран — він встає й знову ходить.
func _meditate(player: Node2D, game: Game) -> void:
	meditating = true
	player.set_movement_enabled(false)
	var seat_offset: Vector2 = $Seat.global_position - player.global_position
	player.play_body(&"Jump")
	await _hop(player, Vector2.ZERO, seat_offset)
	player.play_body(&"Meditate")
	game.meditate()
	meditation_started.emit()
	await get_tree().create_timer(MEDITATE_SIT_TIME).timeout
	var ui_manager: Node = ServiceLocator.get_ui_manager()
	ui_manager.open_save_game()
	await (ui_manager.current_state as Node).tree_exiting
	player.play_body(&"Fall")
	await _hop(player, seat_offset, Vector2.ZERO)
	player.play_body(&"Idle")
	player.set_movement_enabled(true)
	meditating = false
	meditation_finished.emit()


## Тіло героя стоїть на підлозі (звідси й сейв), а видно його — дугою від [param from] до [param to]: так він сідає
## на місце медитації у фоні й сходить із нього.
func _hop(player: Node2D, from: Vector2, to: Vector2) -> void:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(func(t: float) -> void:
		player.set_visual_offset(from.lerp(to, t) + Vector2(0.0, -HOP_ARC * sin(PI * t))), 0.0, 1.0, HOP_TIME)
	await tween.finished
