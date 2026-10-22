extends Node2D

## Зала вогняного джина — кінець лабораторії (BACKLOG 17 + 6, D302, D307, design/lab_story_plan.md біти 8–9).
##   WAIT  — джин висить у глибині зали й спить; герой заходить у TalkTrigger.
##   TALK  — кат-сцена (D308): розмова про плащ (Lab_Boss_Talk); зала замикається (ArenaWall на заході).
##   FIGHT — бій. Джин переміг → CLOAK: забирає плащ (Lab_Boss_TakesCloak) → звичайний Game Over.
##           Джин переможений → OPEN.
##   OPEN  — кат-сцена: репліка Кусакама (Laboratory_AfterBoss), брама на сході піднімається — шлях у LaboratoryOutside.
## Поки джин живий, з лабораторії не вийти: брама опущена з самого початку, після розмови замкнено й захід.
## Стан при вході — з прапорців (B53): розмова вже була (сейв посеред бою) → бій одразу, без повтору;
## lab_boss_fight_complete → OPEN; lab_after_boss_complete → брама вже піднята.
## Гачок для кінця демо (черга 9.8): прапорець lab_after_boss_complete — шлях на схід відкрито.

const Cutscene = preload("res://SampleProject/Scripts/Systems/Cutscenes/Cutscene.gd")
const BossEnemy = preload("res://SampleProject/Scripts/Gameplay/Characters/Bosses/BossEnemy.gd")

enum State { WAIT, TALK, FIGHT, CLOAK, OPEN }

const PAN_TIME := 1.2
const GATE_TIME := 1.5
const TAKE_CLOAK_TIME := 0.8
## Брама піднімається на висоту проходу між кімнатами (рядки 6–11): низ ґрат — над головою героя.
const GATE_LIFT := 200.0
## Де джин зависає перед героєм, коли забирає плащ.
const TAKE_CLOAK_GAP := 60.0

var current_state: State = State.WAIT
var state_run_id := 0
@onready var djinn: BossEnemy = $FireDjinn
@onready var gate_sprite: Sprite2D = $Gates/Sprite
@onready var gate_closed_y: float = gate_sprite.position.y


func _ready() -> void:
	$TalkTrigger.body_entered.connect(_on_talk_trigger)
	djinn.entity_died.connect(_on_djinn_died)
	djinn.enemy_view.update_direction(-1)  # обличчям до входу
	var state := _initial_state()
	if state == State.OPEN:
		djinn.queue_free()  # переможений раніше
	_enter(state)


func _initial_state() -> State:
	var game := Game.get_singleton()
	if game.get_quest_flag("lab_boss_fight_complete"):
		return State.OPEN
	if game.get_quest_flag("lab_boss_talk_complete"):
		return State.FIGHT
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
		_enter(State.TALK)


## Розмова — одна кат-сцена: пропуск (утримання Tab / Y) домотує її до того самого бою.
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
	var game := Game.get_singleton()
	game.set_objective("Defeat the fire djinn")
	_set_arena_locked(true)
	_set_gates_open(false)
	game.player.defeat_handler = _on_hero_defeated
	# Зала замкнена: джин бачить і переслідує героя в будь-якому її кутку, від краю до краю.
	var room_width: float = $RoomInstance.get_size().x
	djinn.enemy_logic.detection_range = room_width
	djinn.enemy_logic.chase_range = room_width
	djinn.enemy_logic.leash_range = room_width
	_set_djinn_awake(true)
	djinn.enemy_logic.on_player_detected(game.player)  # смужка боса — одразу (BossEnemy)
	EventBus.boss_fight_changed.emit(self, true)


## Джин переміг: підлітає до героя, забирає плащ (BACKLOG 17) — і звичайний Game Over.
func _on_hero_defeated() -> void:
	current_state = State.CLOAK
	state_run_id += 1
	var player: Node2D = Game.get_singleton().player
	player.defeat_handler = Callable()
	EventBus.boss_fight_changed.emit(self, false)
	djinn.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED)
	djinn.bar.hide()
	var cs := Cutscene.new()
	cs.set_pose(&"Hurt")
	var side := signf(djinn.global_position.x - player.global_position.x)
	djinn.enemy_view.update_direction(-int(side) if side != 0.0 else -1)
	cs.voice(&"fire_djinn_laugh")
	await cs.move(djinn, Vector2(player.global_position.x + side * TAKE_CLOAK_GAP, djinn.global_position.y), TAKE_CLOAK_TIME)
	await cs.say("Lab_Boss_TakesCloak")
	cs.end()
	GameOverScreen.present(player)


func _on_djinn_died() -> void:
	Game.get_singleton().player.defeat_handler = Callable()
	EventBus.boss_fight_changed.emit(self, false)
	Game.get_singleton().set_quest_flag("lab_boss_fight_complete", true)
	_enter(State.OPEN)


## Перемога: репліка Кусакама, камера до брами, брама вгору — одна кат-сцена.
func _after_boss() -> void:
	var run_id := state_run_id
	var cs := Cutscene.new()
	await cs.say("Laboratory_AfterBoss")
	await cs.pan_to(($Marks/GatesLook as Node2D).global_position, PAN_TIME)
	await _gates_up()
	Game.get_singleton().set_quest_flag("lab_after_boss_complete", true)
	await cs.camera_back(PAN_TIME)
	cs.end()
	if run_id == state_run_id:
		Game.get_singleton().set_objective("Leave the laboratory")


## Джин спить, доки не почався бій: не бачить героя й не б'є, але парить (анімація йде й так).
func _set_djinn_awake(awake: bool) -> void:
	djinn.process_mode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED
	djinn.anim_player.process_mode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_ALWAYS
	djinn.bar.visible = awake


func _set_arena_locked(locked: bool) -> void:
	$ArenaWall/Collision.set_deferred(&"disabled", not locked)


func _set_gates_open(open: bool) -> void:
	$Gates/Body/Collision.set_deferred(&"disabled", open)
	gate_sprite.position.y = gate_closed_y - GATE_LIFT if open else gate_closed_y


func is_arena_locked() -> bool:
	return not ($ArenaWall/Collision as CollisionShape2D).disabled


func are_gates_open() -> bool:
	return ($Gates/Body/Collision as CollisionShape2D).disabled


func _gates_up() -> void:
	var tween := create_tween()
	tween.tween_property(gate_sprite, ^"position:y", gate_closed_y - GATE_LIFT, GATE_TIME).set_trans(Tween.TRANS_SINE)
	await tween.finished
	_set_gates_open(true)
