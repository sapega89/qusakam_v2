extends Node2D

## Камери лабораторії (BACKLOG 17, D303–D305, design/lab_story_plan.md, біти 4–6).
##   CUTSCENE — одна кат-сцена (D308, пропуск — до пробудження): Кусакам у клітці; алхімік веде Алісию до
##              операційного столу й колє її (кішка лишається в камері, B126); заводять в'язня, схожого на бандита;
##              він вигукує закляття вигаданою мовою (Q64) — з нього виривається вогняний джин і тікає крізь стелю;
##              вибухи, землетрус, Кусакам непритомніє. Алхімік і в'язні в камерах реагують (Cutscene.react, D460):
##              «!» на крик, крапля поту на джина, біль від вибуху поруч. Темрява — і він прокидається: ґрати зникли,
##              речі на місці, всі в своїх клітках.
##   AWAKE    — чекає, доки герой вийде з камери (StepOutTrigger).
##   ACQUAINTANCE — друга кат-сцена (D462): Малік підходить першим і питає, хто вони; кожен називає себе (D461),
##              тоді Малік — себе й кличе за собою (завдання malik_escort, відмовитися не можна), усі три асисти відкриті разом (D209, D230: біжать до героя й зникають), Малік зникає в тінях,
##              двері на схід відчиняються.
##   FREE     — двері відчинені, камери порожні; шлях — на схід, у коридори.
## Стан при вході — за прапорцями (B53): сюди потрапляють телепортом із зали мера або завантаженням.

const Cutscene = preload("res://SampleProject/Scripts/Systems/Cutscenes/Cutscene.gd")
const BossEnemy = preload("res://SampleProject/Scripts/Gameplay/Characters/Bosses/BossEnemy.gd")
const EXPLOSION := preload("res://SampleProject/Scenes/FX/Bosses/explosion.tscn")
## Джин — та сама сцена боса, що й у LabBoss (D302); тут лише лялька: ШІ вимкнене, живі тільки кадри.
const FIRE_DJINN := preload("res://SampleProject/Scenes/Characters/Bosses/fire_djinn.tscn")
const TASKS_PATH := "res://SampleProject/Scripts/Tasks/task_service.gd"

enum State { CUTSCENE, AWAKE, ACQUAINTANCE, FREE }

const MALIK_TASK := "malik_escort"
## Супутники в камерах, зліва направо (порядок реплік знайомства — у Lab_Acquaintance).
const COMPANIONS: Array[String] = ["astrit", "alisia", "urizen"]
## Хто з камер реагує на кат-сцену (D460), окрім алхіміка: супутники й Малік.
const CAGED: Array[NodePath] = [^"CompanionNPC_astrit", ^"CompanionNPC_alisia", ^"CompanionNPC_urizen", ^"Malik"]
const BLASTS: Array[NodePath] = [^"Marks/Blast1", ^"Marks/Blast2", ^"Marks/Blast3", ^"Marks/Blast4"]

## Ступні боса — над підлогою (як BrassCollector у MayorHall).
const DJINN_FEET := Vector2(0, -16)
const PAN_TIME := 1.0
const LEAD_TIME := 1.6
const INJECT_HOLD := 0.6
const PRISONER_WALK := 2.4
const SHOUT_SHAKE := 0.6
const DJINN_RISE := 0.8
const DJINN_FLEE := 1.4
const BLAST_GAP := 0.35
const QUAKE_TIME := 1.6
const BLACK_HOLD := 1.2
const STEP_TIME := 0.6
const MALIK_WALK := 2.2
const JOIN_HOLD := 0.9
const MALIK_FADE := 1.2
const DOOR_RISE := 0.8

var current_state: State = State.CUTSCENE
@onready var scientist: Node2D = $Scientist
@onready var prisoner: Node2D = $Prisoner
@onready var malik: Node2D = $Malik


func _ready() -> void:
	$StepOutTrigger.body_entered.connect(_on_step_out)
	var game := Game.get_singleton()
	if game.get_quest_flag("lab_acquaintance_complete"):
		current_state = State.FREE
		_lay_out_awake()
		_lay_out_free()
		game.set_objective("Fight through the laboratory")
	elif game.get_quest_flag("lab_cells_cutscene_complete"):
		current_state = State.AWAKE
		_lay_out_awake()
		game.set_objective("Step out of the cell")
		_put_hero_in_cell.call_deferred()
	else:
		current_state = State.CUTSCENE
		prisoner.hide()
		prisoner.global_position = ($Marks/PrisonerEnter as Node2D).global_position
		game.set_objective("Find out where you are")
		# Зала мера ще закінчує свою сцену (cs.end() після телепорту) — наша починається після неї.
		_cells_cutscene.call_deferred()


func get_current_state_name() -> String:
	return State.keys()[current_state]


## Герой — у своїй камері (Arrival): і після телепорту із зали, і після завантаження сейва.
func _put_hero_in_cell() -> void:
	Game.get_singleton().place_player(($Arrival as Node2D).global_position)


func _cells_cutscene() -> void:
	var game := Game.get_singleton()
	var cs := Cutscene.new()
	_put_hero_in_cell()
	cs.player.get_node(^"Sprite2D").flip_h = false
	await cs.say("Lab_Cells_Arrival")

	# Алісию виводять із камери до столу й колють; кішка лишається в камері (B126) — іде лише її спрайт
	await cs.pan_to(($Marks/Look as Node2D).global_position, PAN_TIME)
	var alisia: Node2D = $CompanionNPC_alisia
	var alisia_body: AnimatedSprite2D = $CompanionNPC_alisia/Sprite
	var cell_x := alisia_body.global_position.x
	$Bars/Bars3.hide()
	_walk(scientist, ($Marks/ScientistTable as Node2D).global_position, LEAD_TIME, cs)
	await _run(alisia_body, Vector2(($Marks/Table as Node2D).global_position.x, alisia_body.global_position.y), LEAD_TIME, cs)
	_play(scientist, &"inject")
	await cs.react(alisia, &"pain")  # здригається від уколу (D460)
	await cs.wait(INJECT_HOLD)
	_play(scientist, &"idle")
	await cs.say("Lab_Cells_Injection")
	await _run(alisia_body, Vector2(cell_x, alisia_body.global_position.y), LEAD_TIME, cs)
	$Bars/Bars3.show()

	# В'язня заводять зі сходу; закляття (Q64) — і з нього виривається джин
	prisoner.show()
	await _walk(prisoner, ($Marks/PrisonerTable as Node2D).global_position, PRISONER_WALK, cs)
	await cs.say("Lab_Cells_Prisoner")
	_play(prisoner, &"shout")
	cs.voice(&"prisoner_incantation")  # закляття вголос (Q64, D310)
	_react_all(cs, &"surprise")  # крик — усі здригаються (D460)
	cs.shake(4.0, SHOUT_SHAKE)
	await cs.wait(SHOUT_SHAKE)
	_play(prisoner, &"collapse")
	var djinn: BossEnemy = FIRE_DJINN.instantiate()
	djinn.process_mode = Node.PROCESS_MODE_DISABLED
	djinn.modulate.a = 0.0
	add_child(djinn)
	djinn.global_position = prisoner.global_position + DJINN_FEET
	djinn.enemy_view.update_direction(-1)  # обличчям до камер
	djinn.anim_player.process_mode = Node.PROCESS_MODE_ALWAYS  # ШІ вимкнене, а кадри живі
	djinn.anim_player.play(&"idle")
	var rise := create_tween()
	rise.tween_property(djinn, ^"modulate:a", 1.0, DJINN_RISE)
	cs.voice(&"fire_djinn_laugh")
	_react_all(cs, &"fear")  # джин — страх (D460)
	await cs.move(djinn, djinn.global_position + Vector2(0, -40), DJINN_RISE)
	await cs.say("Lab_Cells_Djinn")

	# Джин тікає крізь стелю (DjinnUp — під самою стелею, там він і тане); вибухи, землетрус, алхімік утікає на схід
	cs.move(djinn, ($Marks/DjinnUp as Node2D).global_position, DJINN_FLEE)
	create_tween().tween_property(djinn, ^"modulate:a", 0.0, DJINN_FLEE).set_ease(Tween.EASE_IN)
	_walk(scientist, ($Marks/Exit as Node2D).global_position, DJINN_FLEE + BLAST_GAP * BLASTS.size(), cs)
	for mark in BLASTS:
		var blast: Node2D = EXPLOSION.instantiate()
		add_child(blast)
		blast.global_position = (get_node(mark) as Node2D).global_position
		cs.react(_nearest(blast.global_position), &"pain")  # вибух поруч — боляче (D460)
		cs.shake(8.0, BLAST_GAP * 2.0)
		await cs.wait(BLAST_GAP)
	cs.shake(12.0, QUAKE_TIME)
	await cs.wait(QUAKE_TIME)
	djinn.queue_free()
	scientist.hide()
	await cs.camera_back(PAN_TIME)
	cs.set_pose(&"Hurt")
	await cs.say("Lab_Cells_Faint")  # монолог героя — облачко за часом (D178)

	# Темрява: прокидається — ґрати зникли, решта на місцях
	await ScreenFade.to_black(self)
	game.set_quest_flag("lab_cells_cutscene_complete", true)
	current_state = State.AWAKE
	_lay_out_awake()
	await cs.wait(BLACK_HOLD)
	cs.set_pose(&"Idle")
	await ScreenFade.from_black(self)
	await cs.say("Lab_Cells_Awake")
	cs.end()
	game.set_objective("Step out of the cell")


func _on_step_out(body: Node2D) -> void:
	if current_state == State.AWAKE and body.is_in_group(GameGroups.PLAYER):
		_acquaintance()


func _acquaintance() -> void:
	current_state = State.ACQUAINTANCE  # тригер — один раз
	var game := Game.get_singleton()
	var cs := Cutscene.new()
	await cs.walk_hero(Vector2(($Marks/Meet as Node2D).global_position.x, cs.player.global_position.y), STEP_TIME)
	cs.player.get_node(^"Sprite2D").flip_h = false  # до решти в'язнів
	await cs.pan_to(($Marks/MeetLook as Node2D).global_position, PAN_TIME)
	# D462: Малік підходить першим і питає, хто вони; знайомство і його «ідіть зі мною» — одна розмова
	await _walk(malik, ($Marks/MalikMeet as Node2D).global_position, MALIK_WALK, cs)
	await cs.say("Lab_Acquaintance")

	# Відмовитися не можна: завдання взято без меню; асисти — всі три разом
	var TASKS: GDScript = load(TASKS_PATH)
	TASKS.take(TASKS.tasks().filter(func(t: Dictionary) -> bool: return t.id == MALIK_TASK)[0])
	var companions := ServiceLocator.get_companion_manager()
	for id in COMPANIONS:
		var flag: String = CompanionManager.UNLOCK_FLAGS[id]
		game.set_quest_flag(flag, true)
		companions.join_on_unlock(flag)  # D220: у загін, якщо є місце
		(get_node("CompanionNPC_%s" % id) as Node2D).call(&"join", cs.player)
	game.set_quest_flag("lab_acquaintance_complete", true)
	await cs.wait(JOIN_HOLD)

	# Малік зникає в тінях на сході; двері відчиняються
	_walk(malik, ($Marks/Exit as Node2D).global_position, MALIK_FADE * 2.0, cs)
	var fade := create_tween()
	fade.tween_property(malik, ^"modulate:a", 0.0, MALIK_FADE)
	_open_door(DOOR_RISE)
	await cs.wait(MALIK_FADE)
	malik.hide()
	current_state = State.FREE
	await cs.camera_back(PAN_TIME)
	cs.end()
	game.set_objective("Fight through the laboratory")


## Після кат-сцени: ґрати зникли, камера героя відчинена, алхімік утік, в'язень лежить біля столу.
func _lay_out_awake() -> void:
	$Bars.hide()
	$CellLock/Collision.set_deferred(&"disabled", true)
	scientist.hide()
	prisoner.show()
	prisoner.global_position = ($Marks/PrisonerTable as Node2D).global_position
	var anim: AnimationPlayer = prisoner.get_node(^"AnimationPlayer")
	anim.play(&"collapse")
	anim.seek(anim.current_animation_length, true)


## Після знайомства: Маліка немає, двері відчинені (супутники в загоні — CompanionNPC зникають самі).
func _lay_out_free() -> void:
	malik.hide()
	_open_door(0.0)


func _open_door(seconds: float) -> void:
	$ExitDoor/Collision.set_deferred(&"disabled", true)
	var sprite: Sprite2D = $ExitDoor/Sprite
	if seconds <= 0.0:
		sprite.hide()
		return
	var tween := create_tween()
	tween.tween_property(sprite, ^"position:y", sprite.position.y - sprite.get_rect().size.y * sprite.scale.y, seconds)
	tween.tween_callback(sprite.hide)


## Актор із lab_<id>.tscn іде (walk) до [param to] і стає в idle; дивиться туди, куди йде.
func _walk(actor: Node2D, to: Vector2, seconds: float, cs: Cutscene) -> void:
	(actor.get_node(^"Sprite2D") as Sprite2D).flip_h = to.x < actor.global_position.x
	_play(actor, &"walk")
	await cs.move(actor, Vector2(to.x, actor.global_position.y), seconds)
	_play(actor, &"idle")


## Спрайт компаньйона-NPC (CompanionNPC/Sprite) біжить (run) до [param to] і стає в idle (фас — без дзеркала).
## Сам вузол лишається в камері — з ним і кішка Алісії (B126).
func _run(sprite: AnimatedSprite2D, to: Vector2, seconds: float, cs: Cutscene) -> void:
	sprite.flip_h = to.x < sprite.global_position.x
	sprite.play(&"run")
	await cs.move(sprite, to, seconds)
	sprite.flip_h = false
	sprite.play(&"idle")


## Алхімік і всі в камерах реагують разом (D460).
func _react_all(cs: Cutscene, kind: StringName) -> void:
	cs.react(scientist, kind)
	for path in CAGED:
		cs.react(get_node(path), kind)


## Хто з алхіміка й камер найближчий до [param point] (вибух).
func _nearest(point: Vector2) -> Node2D:
	var actors: Array[Node2D] = [scientist]
	for path in CAGED:
		actors.append(get_node(path))
	actors.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_to(point) < b.global_position.distance_to(point))
	return actors[0]


func _play(actor: Node2D, animation: StringName) -> void:
	(actor.get_node(^"AnimationPlayer") as AnimationPlayer).play(animation)
