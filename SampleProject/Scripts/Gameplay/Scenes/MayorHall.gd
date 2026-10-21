extends Node2D

## Зала мера (BACKLOG 16, D255, D300, design/lab_story_plan.md).
##   QUEUE — Астрит, Уризен і Алісия стоять у черзі до мера; герой заходить (QueueTrigger) — керування забрано,
##           він стає в кінець черги, розмова (City_MayorHall).
##   BURST — задня стіна вибухає, з проламу вилазить Мідний Збирач; троє тікають на захід, шлях назад перекрито.
##   FIGHT — бій із Збирачем. «Непереможний», але його можна здолати:
##           програш — без Game Over: темрява, MayorHall_Defeat; перемога — досвід і речі, сонний дим, MayorHall_Victory.
##           Так чи так — Кусакам опиняється в лабораторії (LabCells), дороги назад немає (D130).
## Сейва в залі немає: перезавантаження — з міста, і зала починається з черги.

const Cutscene = preload("res://SampleProject/Scripts/Systems/Cutscenes/Cutscene.gd")

enum State { QUEUE, BURST, FIGHT, TRANSPORT }

const LAB_CELLS := "res://SampleProject/Maps/LabCells.tscn"
## Нагорода за перемогу над Збирачем (D300); досвід — його EnemyStats.xp_reward.
const VICTORY_LOOT := {"hi_potion": 2, "silver_sword": 1, "coin": 60}
const QUEUE_ORDER := ["astrit", "urizen", "alisia"]

const WALK_TIME := 1.6
const BURST_SHAKE := 0.9
const EMERGE_TIME := 1.4
const FLEE_TIME := 1.2
const KNOCKOUT_HOLD := 1.0

var current_state: State = State.QUEUE
var state_run_id := 0
@onready var collector: Node2D = $BrassCollector


func _ready() -> void:
	if not ServiceLocator.is_node_ready():
		await ServiceLocator.ready
	$QueueTrigger.body_entered.connect(_on_queue_trigger)
	collector.entity_died.connect(_on_collector_died)
	_enter(State.QUEUE)


func get_current_state_name() -> String:
	return State.keys()[current_state]


func _enter(state: State) -> void:
	current_state = state
	state_run_id += 1
	match state:
		State.QUEUE:
			Game.get_singleton().set_objective("Speak with the mayor")
			collector.hide()
			collector.process_mode = Node.PROCESS_MODE_DISABLED
			collector.bar.hide()
			$WallHole.hide()
			_set_barrier(false)
		State.BURST:
			_burst()
		State.FIGHT:
			Game.get_singleton().set_objective("Survive the Brass Collector")
			Game.get_singleton().player.defeat_handler = _on_hero_defeated
			collector.process_mode = Node.PROCESS_MODE_INHERIT
			collector.bar.show()


func _on_queue_trigger(body: Node2D) -> void:
	if current_state == State.QUEUE and body.is_in_group(GameGroups.PLAYER):
		_queue()


func _queue() -> void:
	current_state = State.BURST  # тригер — один раз
	var run_id := state_run_id
	var cs := Cutscene.new()
	await cs.walk_hero(($Queue/Kusakam as Node2D).global_position, WALK_TIME)
	cs.player.get_node(^"Sprite2D").flip_h = false  # у черзі — обличчям до дверей мера
	await cs.say("City_MayorHall")
	cs.end()
	if run_id == state_run_id:
		_enter(State.BURST)


func _burst() -> void:
	var run_id := state_run_id
	var cs := Cutscene.new()
	await cs.pan_to(($Marks/Look as Node2D).global_position, 0.6)
	var burst: Node2D = load("res://SampleProject/Scenes/FX/Bosses/wall_burst.tscn").instantiate()
	add_child(burst)
	burst.global_position = $WallHole.global_position
	cs.shake(9.0, BURST_SHAKE)
	$WallHole.show()
	await cs.wait(BURST_SHAKE * 0.6)
	# Збирач вилазить із проламу й стає на підлогу
	collector.global_position = ($Marks/HoleMouth as Node2D).global_position
	collector.modulate.a = 0.0
	collector.show()
	collector.get_node(^"AnimationPlayer").play(&"walk")
	var emerge := create_tween().set_parallel()
	emerge.tween_property(collector, ^"modulate:a", 1.0, EMERGE_TIME * 0.4)
	emerge.tween_property(collector, ^"global_position", ($Marks/CollectorStand as Node2D).global_position, EMERGE_TIME)
	await emerge.finished
	collector.get_node(^"AnimationPlayer").play(&"idle")
	_set_barrier(true)
	await cs.say("MayorHall_WallBurst")
	# Троє тікають на захід, геть із зали
	for id: String in QUEUE_ORDER:
		var npc: Node2D = get_node("Queue/CompanionNPC_%s" % id)
		for sprite: AnimatedSprite2D in npc.find_children("*", "AnimatedSprite2D", false):
			sprite.flip_h = true
			sprite.play(&"run")
		cs.move(npc, Vector2(($Marks/FleeTo as Node2D).global_position.x, npc.global_position.y), FLEE_TIME)
	await cs.wait(FLEE_TIME)
	for id: String in QUEUE_ORDER:
		get_node("Queue/CompanionNPC_%s" % id).hide()
	await cs.camera_back(0.5)
	cs.end()
	if run_id == state_run_id:
		_enter(State.FIGHT)


## Програш (D300): Game Over немає — Збирач несе Кусакама в лабораторію.
func _on_hero_defeated() -> void:
	_end_fight()
	collector.process_mode = Node.PROCESS_MODE_DISABLED
	var cs := Cutscene.new()
	cs.set_pose(&"Hurt")
	await ScreenFade.to_black(self)
	await cs.say("MayorHall_Defeat")
	_transport(cs)


func _on_collector_died() -> void:
	_end_fight()
	var inventory := ServiceLocator.get_inventory_manager()
	for item_id: String in VICTORY_LOOT:
		inventory.add_item(item_id, VICTORY_LOOT[item_id])
	Game.get_singleton().set_quest_flag("mayor_boss_defeated", true)
	var cs := Cutscene.new()
	await cs.wait(KNOCKOUT_HOLD)
	var gas: Node2D = load("res://SampleProject/Scenes/FX/Bosses/sleep_gas.tscn").instantiate()
	add_child(gas)
	gas.global_position = collector.global_position
	await cs.say("MayorHall_Victory")
	cs.set_pose(&"Hurt")
	await ScreenFade.to_black(self)
	_transport(cs)


func _end_fight() -> void:
	current_state = State.TRANSPORT
	state_run_id += 1
	Game.get_singleton().player.defeat_handler = Callable()


## Темрява вже настала: герой на ногах, у лабораторії. Далі сцену веде LabCells (кат-сцена в клітці).
func _transport(cs: RefCounted) -> void:
	var game := Game.get_singleton()
	var player: CombatBody2D = game.player
	if player.is_dead:
		player.revive()
	game.set_quest_flag("city_mayor_hall_complete", true)
	cs.end()
	game.teleport_to_room(LAB_CELLS, ^"Arrival")
	player.get_node(^"Camera2D").reset_smoothing()
	ScreenFade.from_black(player)


func _set_barrier(on: bool) -> void:
	$BarrierWest/Collision.set_deferred(&"disabled", not on)
