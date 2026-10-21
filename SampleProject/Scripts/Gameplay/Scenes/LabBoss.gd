extends Node2D

## Зала вогняного джина — кінець лабораторії (BACKLOG 17 + 6, D302, D307, design/lab_story_plan.md).
##   WAIT  — джин висить у глибині зали; герой заходить у TalkTrigger.
##   TALK  — розмова про плащ (Lab_Boss_Talk); зала замикається (ArenaWall на заході).
##   FIGHT — бій. Джин переміг → забирає плащ (Lab_Boss_TakesCloak) → Game Over. Джин переможений → OPEN.
##   OPEN  — репліка Кусакама (Laboratory_AfterBoss), ворота на сході піднімаються — вихід із лабораторії.
## Поки джин живий, з лабораторії не вийти: ворота опущені з самого початку. Стан при вході — з прапорців (B53);
## після програшу (сейв перед залою) розмова вдруге не грає — бій починається одразу.

const Cutscene = preload("res://SampleProject/Scripts/Systems/Cutscenes/Cutscene.gd")

enum State { WAIT, TALK, FIGHT, OPEN }

const PAN_TIME := 1.2
const GATE_TIME := 1.5
const TAKE_CLOAK_TIME := 0.8

var current_state: State = State.WAIT
var state_run_id := 0
@onready var djinn: Node2D = $FireDjinn


func _ready() -> void:
	if not ServiceLocator.is_node_ready():
		await ServiceLocator.ready
	$TalkTrigger.body_entered.connect(_on_talk_trigger)
	djinn.entity_died.connect(_on_djinn_died)
	var state := _initial_state()
	if state == State.OPEN:
		djinn.queue_free()  # переможений раніше (сейв після бою)
	_enter(state)


func _initial_state() -> State:
	var game := Game.get_singleton()
	if game.get_quest_flag("lab_boss_fight_complete"):
		return State.OPEN
	return State.WAIT


func get_current_state_name() -> String:
	return State.keys()[current_state]


func _enter(state: State) -> void:
	current_state = state
	state_run_id += 1
	var game := Game.get_singleton()
	match state:
		State.WAIT:
			game.set_objective("Defeat the fire djinn")
			_set_djinn_awake(false)
			_set_arena_locked(false)
			_set_gates_open(false)
		State.TALK:
			_talk()
		State.FIGHT:
			_fight()
		State.OPEN:
			_set_arena_locked(false)
			if game.get_quest_flag("lab_after_boss_complete"):
				_set_gates_open(true)
				game.set_objective("Leave the laboratory")
			else:
				_set_gates_open(false)
				_after_boss()


func _on_talk_trigger(body: Node2D) -> void:
	if current_state == State.WAIT and body.is_in_group(GameGroups.PLAYER):
		var talked: bool = Game.get_singleton().get_quest_flag("lab_boss_talk_complete")
		_enter(State.FIGHT if talked else State.TALK)


func _talk() -> void:
	var run_id := state_run_id
	_set_arena_locked(true)
	var cs := Cutscene.new()
	await cs.pan_to(($Marks/Look as Node2D).global_position, PAN_TIME)
	await cs.say("Lab_Boss_Talk")
	Game.get_singleton().set_quest_flag("lab_boss_talk_complete", true)
	await cs.camera_back(PAN_TIME * 0.5)
	cs.end()
	if run_id == state_run_id:
		_enter(State.FIGHT)


func _fight() -> void:
	_set_arena_locked(true)
	Game.get_singleton().player.defeat_handler = _on_hero_defeated
	_set_djinn_awake(true)


## Джин переміг: забирає плащ — і Game Over (BACKLOG 17).
func _on_hero_defeated() -> void:
	var player: Node2D = Game.get_singleton().player
	player.defeat_handler = Callable()
	_set_djinn_awake(false)
	var cs := Cutscene.new()
	cs.set_pose(&"Hurt")
	var hover := create_tween()
	hover.tween_property(djinn, ^"global_position:x", player.global_position.x + 60.0, TAKE_CLOAK_TIME)
	await hover.finished
	await cs.say("Lab_Boss_TakesCloak")
	cs.end()
	GameOverScreen.present(player)


func _on_djinn_died() -> void:
	Game.get_singleton().player.defeat_handler = Callable()
	Game.get_singleton().set_quest_flag("lab_boss_fight_complete", true)
	_enter(State.OPEN)


func _after_boss() -> void:
	var run_id := state_run_id
	var cs := Cutscene.new()
	await cs.say("Laboratory_AfterBoss")
	await cs.pan_to(($Gates as Node2D).global_position + Vector2(0, -120), PAN_TIME)
	await _gates_up()
	Game.get_singleton().set_quest_flag("lab_after_boss_complete", true)
	await cs.camera_back(PAN_TIME)
	cs.end()
	if run_id == state_run_id:
		Game.get_singleton().set_objective("Leave the laboratory")


## Джин спить, доки не почався бій: не бачить героя й не б'є.
func _set_djinn_awake(awake: bool) -> void:
	djinn.process_mode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED
	djinn.get_node(^"AnimationPlayer").process_mode = Node.PROCESS_MODE_ALWAYS  # парить і уві сні
	djinn.bar.visible = awake


func _set_arena_locked(locked: bool) -> void:
	$ArenaWall/Collision.set_deferred(&"disabled", not locked)
	$ArenaWall.visible = locked


func _set_gates_open(open: bool) -> void:
	$Gates/Collision.set_deferred(&"disabled", open)
	$Gates/Sprite2D.position.y = _gates_open_y() if open else 0.0


func _gates_up() -> void:
	var tween := create_tween()
	tween.tween_property($Gates/Sprite2D, ^"position:y", _gates_open_y(), GATE_TIME).set_trans(Tween.TRANS_SINE)
	await tween.finished
	_set_gates_open(true)


func _gates_open_y() -> float:
	var sprite: Sprite2D = $Gates/Sprite2D
	return -sprite.texture.get_height() * sprite.scale.y
