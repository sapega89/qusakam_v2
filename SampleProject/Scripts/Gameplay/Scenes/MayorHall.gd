extends Node2D

## Зала мера (BACKLOG 16, D255, D300, design/lab_story_plan.md, бітів 1–3).
##   QUEUE — Астрит, Уризен і Алісия стоять у черзі до мера; герой доходить до її кінця (QueueTrigger) —
##           одна кат-сцена (D308, пропуск — до бою): він стає в кінець черги, розмова City_MayorHall,
##   BURST — задня стіна вибухає, з проламу вилазить Мідний Збирач; троє тікають на захід, шлях назад перекрито.
##   FIGHT — бій із Збирачем (D301). Програш — без Game Over: темрява, MayorHall_Defeat;
##           перемога — досвід (його EnemyStats.xp_reward) і речі із зали, сонний дим, MayorHall_Victory.
##           Так чи так — Кусакам опиняється в лабораторії, дороги назад немає (D130).
## Сейв-точки в залі немає; сейв посеред зали (автосейв переходу) починає залу з черги — тригер покриває
## підлогу від кінця черги до східної стіни: герой або вже в ньому, або дійде до нього, ідучи вглиб зали.

const Cutscene = preload("res://SampleProject/Scripts/Systems/Cutscenes/Cutscene.gd")
const BossEnemy = preload("res://SampleProject/Scripts/Gameplay/Characters/Bosses/BossEnemy.gd")
const WALL_BURST := preload("res://SampleProject/Scenes/FX/Bosses/wall_burst.tscn")
const SLEEP_GAS := preload("res://SampleProject/Scenes/FX/Bosses/sleep_gas.tscn")

enum State { QUEUE, BURST, FIGHT, TRANSPORT }

## Куди зала переносить героя: його камера в LabCells (D303).
const LAB_ROOM := "res://SampleProject/Maps/LabCells.tscn"
const LAB_MARKER := ^"Arrival"
## Нагорода за перемогу над Збирачем — речі із зали (D300, D301); зілля прибрані (4b, D261) — срібло для кузні замість них.
const VICTORY_LOOT := {"silver_ingot": 2, "silver_sword": 1, "coin": 60}
const QUEUE_ORDER: Array[String] = ["astrit", "urizen", "alisia"]

const WALK_TIME := 1.6
const PAN_TIME := 0.6
const BURST_SHAKE := 0.9
const EMERGE_TIME := 1.4
const FLEE_TIME := 1.2
const KNOCKOUT_HOLD := 1.0
## Дим із клітки на спині голема — над його ногами.
const CAGE_OFFSET := Vector2(0, -60)

var current_state: State = State.QUEUE
@onready var collector: BossEnemy = $BrassCollector


func _ready() -> void:
	$QueueTrigger.body_entered.connect(_on_queue_trigger)
	collector.entity_died.connect(_on_collector_died)
	Game.get_singleton().set_objective("Speak with the mayor")


func get_current_state_name() -> String:
	return State.keys()[current_state]


func _on_queue_trigger(body: Node2D) -> void:
	if current_state == State.QUEUE and body.is_in_group(GameGroups.PLAYER):
		_queue_and_burst()


## Черга й пролам — одна кат-сцена: пропуск доводить її до бою.
func _queue_and_burst() -> void:
	current_state = State.BURST  # тригер — один раз
	var cs := Cutscene.new()
	var spot := Vector2(($Queue/Kusakam as Node2D).global_position.x, cs.player.global_position.y)
	await cs.walk_hero(spot, WALK_TIME)
	cs.player.get_node(^"Sprite2D").flip_h = false  # у черзі — обличчям до дверей мера
	await cs.say("City_MayorHall")

	await cs.pan_to(($Marks/Look as Node2D).global_position, PAN_TIME)
	var burst: Node2D = WALL_BURST.instantiate()
	add_child(burst)
	burst.global_position = ($Marks/HoleMouth as Node2D).global_position
	cs.shake(9.0, BURST_SHAKE)
	$WallHole.show()
	await cs.wait(BURST_SHAKE * 0.6)
	# Збирач вилазить із проламу й стає на підлогу
	collector.global_position = ($Marks/HoleMouth as Node2D).global_position
	collector.modulate.a = 0.0
	collector.show()
	collector.enemy_view.update_direction(-1)  # обличчям до героя
	collector.anim_player.process_mode = Node.PROCESS_MODE_ALWAYS  # ШІ боса ще вимкнене, а кроки видно
	collector.anim_player.play(&"walk")
	create_tween().tween_property(collector, ^"modulate:a", 1.0, EMERGE_TIME * 0.4)
	await cs.move(collector, ($Marks/CollectorStand as Node2D).global_position, EMERGE_TIME)
	collector.anim_player.play(&"idle")
	cs.voice(&"brass_collector_roar")
	_set_barrier(true)
	await cs.say("MayorHall_WallBurst")
	# Троє тікають на захід, геть із зали
	var flee_x: float = ($Marks/FleeTo as Node2D).global_position.x
	for id in QUEUE_ORDER:
		var npc: Node2D = get_node("Queue/CompanionNPC_%s" % id)
		for sprite: AnimatedSprite2D in npc.find_children("*", "AnimatedSprite2D", false):
			sprite.flip_h = true
			sprite.play(&"run")
		cs.move(npc, Vector2(flee_x, npc.global_position.y), FLEE_TIME)
	await cs.wait(FLEE_TIME)
	$Queue.hide()
	await cs.camera_back(PAN_TIME)
	cs.end()
	_fight()


func _fight() -> void:
	current_state = State.FIGHT
	var game := Game.get_singleton()
	game.set_objective("Survive the Brass Collector")
	game.player.defeat_handler = _on_hero_defeated
	game.preload_room(LAB_ROOM)  # бій закінчиться телепортом у лабораторію за будь-якого результату (performance_plan, slice 3)
	collector.anim_player.process_mode = Node.PROCESS_MODE_INHERIT
	collector.process_mode = Node.PROCESS_MODE_INHERIT
	EventBus.boss_fight_changed.emit(self, true)


## Програш (D300): Game Over немає — Збирач несе Кусакама в лабораторію.
func _on_hero_defeated() -> void:
	_end_fight()
	collector.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED)
	var cs := Cutscene.new()
	cs.set_pose(&"Hurt")
	await ScreenFade.to_black(self)
	await cs.say("MayorHall_Defeat")
	_transport(cs)


## Перемога (D300): досвід дав сам бос; речі — із зали; із клітки б'є сонний дим.
func _on_collector_died() -> void:
	_end_fight()
	var inventory := ServiceLocator.get_inventory_manager()
	for item_id: String in VICTORY_LOOT:
		inventory.add_item(item_id, VICTORY_LOOT[item_id])
	ServiceLocator.get_ui_manager().show_obtained(VICTORY_LOOT)  # BACKLOG 33: покажеться в лабораторії, коли кат-сцена відпустить
	Game.get_singleton().set_quest_flag("mayor_boss_defeated", true)
	var cs := Cutscene.new()
	await cs.wait(KNOCKOUT_HOLD)
	var gas: Node2D = SLEEP_GAS.instantiate()
	add_child(gas)
	gas.global_position = collector.global_position + CAGE_OFFSET
	await cs.say("MayorHall_Victory")
	cs.set_pose(&"Hurt")
	await ScreenFade.to_black(self)
	_transport(cs)


func _end_fight() -> void:
	current_state = State.TRANSPORT
	Game.get_singleton().player.defeat_handler = Callable()
	EventBus.boss_fight_changed.emit(self, false)


## Темрява вже настала: герой на ногах, у лабораторії. Після телепорту зали немає — телепорт не чекаємо (жодного
## await на ній); світло після заміни кімнати повертає сам Game.load_room() (D434).
func _transport(cs: Cutscene) -> void:
	var game := Game.get_singleton()
	var player: CombatBody2D = game.player
	player.revive()
	game.set_quest_flag("city_mayor_hall_complete", true)
	game.teleport_to_room(LAB_ROOM, LAB_MARKER)
	cs.end()


func _set_barrier(on: bool) -> void:
	$BarrierWest/Collision.set_deferred(&"disabled", not on)
