extends Node2D

## Поверх кліток лабораторії (BACKLOG 17, D304, D305, design/lab_story_plan.md).
##   CAPTIVE — кат-сцена: Кусакам за ґратами; алхімік веде Алісию до операційного столу й колє її; потім
##             в'язня, схожого на бандита, — той вигукує закляття, з нього виривається вогняний джин і тікає крізь
##             стелю; вибухи, землетрус, Кусакам непритомніє. Прокидається: ґрат немає, речі на місці.
##   AWAKE   — усі ще в клітках; герой виходить зі своєї (StepOutTrigger) → знайомство, Малік і його завдання,
##             усі асисти одразу, двері на схід відчиняються.
##   FREE    — у клітках порожньо, двері відчинені.
## Стан при вході — з прапорців (B53): сюди потрапляють телепортом із Зали мера або завантаженням сейва.

const Cutscene = preload("res://SampleProject/Scripts/Systems/Cutscenes/Cutscene.gd")
const TASKS := preload("res://SampleProject/Scripts/Tasks/task_service.gd")
const EXPLOSION := preload("res://SampleProject/Scenes/FX/Bosses/lab_explosion.tscn")

enum State { CAPTIVE, AWAKE, FREE }

const MALIK_TASK := "malik_escort"
const COMPANIONS := ["alisia", "astrit", "urizen"]
const COMPANIONS_HINT := "companions"

const PAN_TIME := 1.4
const LEAD_TIME := 2.2
const INJECT_HOLD := 0.9
const BURST_TIME := 0.8
const FLY_TIME := 1.2
const QUAKE_TIME := 3.0
const FAINT_HOLD := 1.2
const STEP_OUT_TIME := 1.0
const DOOR_OPEN_TIME := 0.8
const ACTOR_SPEED := 70.0

var current_state: State = State.CAPTIVE
var state_run_id := 0


func _ready() -> void:
	if not ServiceLocator.is_node_ready():
		await ServiceLocator.ready
	$StepOutTrigger.body_entered.connect(_on_step_out)
	_enter(_initial_state())


func _initial_state() -> State:
	var game := Game.get_singleton()
	if game.get_quest_flag("lab_acquaintance_complete"):
		return State.FREE
	if game.get_quest_flag("lab_cells_cutscene_complete"):
		return State.AWAKE
	return State.CAPTIVE


func get_current_state_name() -> String:
	return State.keys()[current_state]


func _enter(state: State) -> void:
	current_state = state
	state_run_id += 1
	var game := Game.get_singleton()
	_show_world(state)
	match state:
		State.CAPTIVE:
			game.set_objective("Escape the cell")
			_captive_cutscene()
		State.AWAKE:
			game.set_objective("Step out of the cell")
		State.FREE:
			game.set_objective("Fight through the laboratory")


## Що видно в кожному стані: ґрати й актори кат-сцени — лише в полоні; двері відчинені — лише на волі.
func _show_world(state: State) -> void:
	$Bars.visible = state == State.CAPTIVE
	for actor in [$Scientist, $Prisoner, $Djinn]:
		actor.hide()
	$Malik.visible = state != State.FREE
	_set_door_open(state == State.FREE)


func _set_door_open(open: bool) -> void:
	$ExitDoor/Collision.set_deferred(&"disabled", open)
	$ExitDoor/Sprite2D.position.y = _door_open_y() if open else 0.0


## Двері відчиняються вгору на свою висоту.
func _door_open_y() -> float:
	var sprite: Sprite2D = $ExitDoor/Sprite2D
	return -sprite.texture.get_height() * sprite.scale.y


func _captive_cutscene() -> void:
	var run_id := state_run_id
	var cs := Cutscene.new()
	var player: Node2D = cs.player
	player.global_position = $Arrival.global_position
	player.get_node(^"Sprite2D").flip_h = false
	await cs.wait(0.4)
	await cs.say("Lab_Cells_Arrival")

	# Алісию ведуть до столу й колють
	await cs.pan_to($Marks/Look.global_position, PAN_TIME)
	$Scientist.global_position = $Marks/ScientistDoor.global_position
	$Scientist.show()
	await _walk_actor($Scientist, $Marks/AlisiaCell.global_position.x + 40.0)
	var alisia: Node2D = $CompanionNPC_alisia
	_run_pose(alisia, true)
	_walk_actor($Scientist, $Marks/TableSide.global_position.x, LEAD_TIME)  # поруч, той самий час
	await cs.move(alisia, $Marks/Table.global_position, LEAD_TIME)
	_run_pose(alisia, false)
	await cs.say("Lab_Cells_Injection")
	$Scientist/AnimationPlayer.play(&"inject")
	_flash(alisia, Color(0.6, 1.0, 0.6))
	await cs.wait(INJECT_HOLD)
	_run_pose(alisia, true)
	await cs.move(alisia, $Marks/AlisiaCell.global_position, LEAD_TIME)
	_run_pose(alisia, false)
	$Scientist/AnimationPlayer.play(&"idle")
	if run_id != state_run_id:
		return

	# В'язень, закляття, джин
	$Prisoner.global_position = $Marks/ScientistDoor.global_position
	$Prisoner.show()
	await _walk_actor($Prisoner, $Marks/Table.global_position.x + 30.0)
	await cs.say("Lab_Cells_Prisoner")
	$Prisoner/AnimationPlayer.play(&"shout")
	await cs.wait(0.5)
	var burst := EXPLOSION.instantiate()
	add_child(burst)
	burst.global_position = $Prisoner.global_position + Vector2(0, -40)
	$Djinn.global_position = $Prisoner.global_position + Vector2(0, -20)
	$Djinn.scale = Vector2.ONE * 0.2
	$Djinn.modulate.a = 0.0
	$Djinn.show()
	$Djinn/AnimationPlayer.play(&"idle")
	cs.shake(6.0, BURST_TIME)
	var grow := create_tween().set_parallel()
	grow.tween_property($Djinn, ^"scale", Vector2.ONE, BURST_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.tween_property($Djinn, ^"modulate:a", 1.0, BURST_TIME * 0.5)
	grow.tween_property($Djinn, ^"global_position", $Marks/DjinnHover.global_position, BURST_TIME)
	$Prisoner/AnimationPlayer.play(&"collapse")
	await grow.finished
	await cs.say("Lab_Cells_Djinn")
	$Djinn/AnimationPlayer.play(&"fly")
	await cs.move($Djinn, $Marks/DjinnExit.global_position, FLY_TIME, Tween.TRANS_QUAD)
	$Djinn.hide()
	if run_id != state_run_id:
		return

	# Вибухи, землетрус, непритомність
	cs.shake(10.0, QUAKE_TIME)
	for mark: Node2D in $Marks/Explosions.get_children():
		var boom := EXPLOSION.instantiate()
		add_child(boom)
		boom.global_position = mark.global_position
		await cs.wait(QUAKE_TIME / ($Marks/Explosions.get_child_count() + 1))
	await cs.camera_back(PAN_TIME * 0.5)
	cs.set_pose(&"Hurt")
	await cs.say("Lab_Cells_Faint", true)
	await ScreenFade.to_black(self)
	Game.get_singleton().set_quest_flag("lab_cells_cutscene_complete", true)
	cs.set_pose(&"Idle")
	_show_world(State.AWAKE)
	await cs.wait(FAINT_HOLD)
	var hero: CombatBody2D = player
	hero.heal_damage(hero.Max_Health)  # проспав — відпочив
	await ScreenFade.from_black(self)
	await cs.say("Lab_Cells_Awake", true)
	cs.end()
	if run_id == state_run_id:
		_enter(State.AWAKE)


func _on_step_out(body: Node2D) -> void:
	if current_state == State.AWAKE and body.is_in_group(GameGroups.PLAYER):
		_acquaintance()


func _acquaintance() -> void:
	current_state = State.FREE  # тригер більше не спрацьовує
	var run_id := state_run_id
	var cs := Cutscene.new()
	var game := Game.get_singleton()
	await cs.pan_to($Marks/Look.global_position, PAN_TIME)
	# Усі виходять зі своїх кліток до Кусакама
	for i in COMPANIONS.size():
		var npc: Node2D = get_node("CompanionNPC_%s" % COMPANIONS[i])
		_run_pose(npc, true, cs.player.global_position.x < npc.global_position.x)
		cs.move(npc, $Marks/Gather.get_child(i).global_position, STEP_OUT_TIME)  # усі разом
	await cs.wait(STEP_OUT_TIME)
	for id: String in COMPANIONS:
		_run_pose(get_node("CompanionNPC_%s" % id), false)
	await cs.say("Lab_Acquaintance")
	await _walk_actor($Malik, $Marks/Gather.get_child(COMPANIONS.size()).global_position.x)
	$Malik/AnimationPlayer.play(&"front")
	await cs.say("Lab_Malik_Quest")
	# Завдання Маліка береться без меню — відмовитися не можна (BACKLOG 17)
	var task: Dictionary = TASKS.tasks().filter(func(t: Dictionary) -> bool: return t.id == MALIK_TASK)[0]
	TASKS.take(task)
	# Усі асисти одразу: троє стають у загін, підбігають до героя й зникають (D230)
	var companions := ServiceLocator.get_companion_manager()
	for id: String in COMPANIONS:
		var flag: String = companions.UNLOCK_FLAGS[id]
		game.set_quest_flag(flag, true)
		companions.join_on_unlock(flag)
		get_node("CompanionNPC_%s" % id).join(cs.player)
	# Малік іде «тінню» — у демо він більше не з'являється (стане NPC згодом)
	var fade := create_tween()
	fade.tween_property($Malik, ^"modulate:a", 0.0, STEP_OUT_TIME)
	await fade.finished
	$Malik.hide()
	game.set_quest_flag("lab_acquaintance_complete", true)
	var door := create_tween()
	door.tween_property($ExitDoor/Sprite2D, ^"position:y", _door_open_y(), DOOR_OPEN_TIME)
	$ExitDoor/Collision.set_deferred(&"disabled", true)
	await door.finished
	await cs.camera_back(PAN_TIME * 0.5)
	cs.end()
	if run_id != state_run_id:
		return
	_enter(State.FREE)
	get_tree().get_first_node_in_group(&"tutorial_hint_display").show_hint(COMPANIONS_HINT, true)


## Актор (Sprite2D + AnimationPlayer: idle / walk) іде до x — кроком ACTOR_SPEED або за [param seconds];
## дивиться туди, куди йде (кадри ходи — праворуч).
func _walk_actor(actor: Node2D, x: float, seconds: float = -1.0) -> void:
	var sprite: Sprite2D = actor.get_node(^"Sprite2D")
	sprite.flip_h = x < actor.global_position.x
	actor.get_node(^"AnimationPlayer").play(&"walk")
	var tween := create_tween()
	var time := seconds if seconds > 0.0 else absf(x - actor.global_position.x) / ACTOR_SPEED
	tween.tween_property(actor, ^"global_position:x", x, time)
	await tween.finished
	actor.get_node(^"AnimationPlayer").play(&"idle")


## Компаньйон (CompanionNPC) біжить або стоїть фасом; [param face_left] — у який бік біжить.
func _run_pose(npc: Node2D, running: bool, face_left: bool = false) -> void:
	for sprite: AnimatedSprite2D in npc.find_children("*", "AnimatedSprite2D", false):
		sprite.flip_h = running and face_left
		sprite.play(&"run" if running else &"idle")


func _flash(node: CanvasItem, color: Color) -> void:
	var tween := create_tween()
	tween.tween_property(node, ^"modulate", color, 0.15)
	tween.tween_property(node, ^"modulate", Color.WHITE, 0.6)
