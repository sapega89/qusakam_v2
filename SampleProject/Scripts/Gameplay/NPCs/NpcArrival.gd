extends Area2D

## Перша зустріч з NPC (BACKLOG 14, D292–D294): герой входить у зону — керування забрано, NPC виходить
## із дверей свого будинку (з'являється в темному отворі й іде до свого місця), розмова, видає завдання.
## Один раз: прапорець done_flag. Без нього NPC сховано й вимкнено; з ним — стоїть на місці з .tscn.
## Привітання голосом тут немає: його грає лише NpcBase._on_interacted, коли герой сам заговорив (D277).

const TASKS_PATH := "res://SampleProject/Scripts/Tasks/task_service.gd"

## NPC (NpcBase зі Sprite2D і AnimationPlayer: idle / talk / walk). Його позиція в мапі — місце, куди він іде.
@export var npc_path: NodePath
## Двері будинку: звідси NPC виходить.
@export var door_path: NodePath
## Розмова першої зустрічі (.dqd); після неї — розмова, якою видається завдання (quests.json → give_dialogue).
@export var dialogue: String = ""
## Завдання з quests.json, яке NPC видає наприкінці.
@export var task_id: String = ""
## Прапорець: зустріч відбулася.
@export var done_flag: String = ""
## Зустріч чекає на цей прапорець (порожньо — без умови): торговець виходить лише після бою на дорозі.
@export var require_flag: String = ""

const WALK_SPEED := 70.0
const EMERGE_TIME := 0.5

signal finished

var _npc: NpcBase
var _running := false


func _ready() -> void:
	_npc = get_node(npc_path)
	var game := Game.get_singleton()
	if game.get_quest_flag(done_flag):
		queue_free()
		return
	_npc.hide()
	_npc.process_mode = Node.PROCESS_MODE_DISABLED
	body_entered.connect(func(_body: Node2D) -> void: _try_start())
	game.quest_flag_changed.connect(func(_id: String, _value: Variant) -> void: _try_start())


func _try_start() -> void:
	var game := Game.get_singleton()
	if _running or (require_flag != "" and not game.get_quest_flag(require_flag)):
		return
	if not overlaps_body(game.player):
		return
	_running = true
	_play()


func _play() -> void:
	var game := Game.get_singleton()
	var player: Node2D = game.player
	var dm: Node = ServiceLocatorHelper.get_service_locator().get_dialogue_manager()
	while dm.is_dialogue_active():  # чужа розмова (тригер кімнати) — спершу вона
		await dm.dialogue_finished
	player.set_movement_enabled(false)

	var sprite: Sprite2D = _npc.get_node(^"Sprite2D")
	var anim: AnimationPlayer = _npc.get_node(^"AnimationPlayer")
	var station: float = _npc.global_position.x
	var door: Node2D = get_node(door_path)
	_npc.global_position.x = door.global_position.x
	_npc.modulate.a = 0.0
	_npc.show()
	_npc.process_mode = Node.PROCESS_MODE_INHERIT
	_npc.interactable.enabled = false
	_npc.activity.held = true  # ходу й розмову веде катсцена, не розклад дій (D295)
	sprite.flip_h = station < door.global_position.x  # кадри ходи дивляться праворуч
	anim.play(&"walk")
	var walk := create_tween()
	walk.tween_property(_npc, ^"modulate:a", 1.0, EMERGE_TIME)
	walk.parallel().tween_property(_npc, ^"global_position:x", station, absf(station - door.global_position.x) / WALK_SPEED)
	await walk.finished

	anim.play(&"talk")
	sprite.flip_h = player.global_position.x < station
	await _say(dm, dialogue)
	var TASKS: GDScript = load(TASKS_PATH)
	var task: Dictionary = TASKS.tasks().filter(func(t: Dictionary) -> bool: return t.id == task_id)[0]
	TASKS.take(task)
	await _say(dm, "res://dialogue_quest/%s.dqd" % task.give_dialogue)

	game.set_quest_flag(done_flag, true)
	sprite.flip_h = false
	_npc.activity.resume()
	_npc.refresh_availability()
	player.set_movement_enabled(true)
	finished.emit()
	queue_free()


## Розмова до кінця. DialogueManager після неї повертає керування — забираємо знову до кінця сцени.
func _say(dm: Node, path: String) -> void:
	dm.start_dialogue(path)
	while true:
		var id: String = await dm.dialogue_finished
		if id == path or id == path.get_file().get_basename():
			break
	Game.get_singleton().player.set_movement_enabled(false)
