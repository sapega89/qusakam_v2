extends Node2D

## Зала мера (BACKLOG 16, D255, D300, design/lab_story_plan.md, бітів 1–3).
##   QUEUE — Астрит, Уризен і Алісия стоять у черзі до мера; герой доходить до її кінця (QueueTrigger) —
##           одна кат-сцена (D308, пропуск — до бою): він стає в кінець черги, розмова City_MayorHall,
##   BURST — задня стіна вибухає, з проламу вилазить велетенський скорпіон, за ним — сокирник Скорпікори (D468);
##           скорпіон відступає в пролам, троє тікають на захід, шлях назад перекрито.
##   FIGHT — бій із сокирником сам на сам (D557: скорпіон лише в кат-сцені, не б'ється). Програш — без Game Over:
##           темрява, MayorHall_Defeat (люди клану тягнуть його, D556); перемога — досвід (EnemyStats.xp_reward) і речі
##           із зали, скорпіон вертається й забирає переможеного, MayorHall_Victory, темрява.
##           Так чи так — Кусакам опиняється в лабораторії, дороги назад немає (D130).
## Сейв-точки в залі немає; сейв посеред зали (автосейв переходу) починає залу з черги — тригер покриває
## підлогу від кінця черги до східної стіни: герой або вже в ньому, або дійде до нього, ідучи вглиб зали.

const Cutscene = preload("res://SampleProject/Scripts/Systems/Cutscenes/Cutscene.gd")
const Charms = preload("res://SampleProject/Scripts/Systems/Charms.gd")
const BossEnemy = preload("res://SampleProject/Scripts/Gameplay/Characters/Bosses/BossEnemy.gd")
const WALL_BURST := preload("res://SampleProject/Scenes/FX/Bosses/wall_burst.tscn")

enum State { QUEUE, BURST, FIGHT, TRANSPORT }

## Куди зала переносить героя: його камера в LabCells (D303).
const LAB_ROOM := "res://SampleProject/Maps/LabCells.tscn"
const LAB_MARKER := ^"Arrival"
## Нагорода за перемогу над сокирником — речі із зали (D300, D301); зілля прибрані (4b, D261) — срібло для кузні замість них.
const VICTORY_LOOT := {"silver_ingot": 2, "silver_sword": 1, "coin": 60}
const QUEUE_ORDER: Array[String] = ["astrit", "urizen", "alisia"]

const WALK_TIME := 1.6
const PAN_TIME := 0.6
const BURST_SHAKE := 0.9
const EMERGE_TIME := 1.4
const FLEE_TIME := 1.2
const KNOCKOUT_HOLD := 1.6
## Скорпіон (D557): виходить із проламу, ставши дибки, — і назад; після перемоги забирає сокирника.
const SCORPION_TIME := 1.2
const STING_TIME := 0.9
const SCORPION_FADE := 0.4
## Скорпіон стає над тілом сокирника — трохи ближче до проламу.
const SCORPION_OVER_BODY := 40.0

var current_state: State = State.QUEUE
@onready var warrior: BossEnemy = $ScorpicoreWarrior
@onready var scorpion: Node2D = $GiantScorpion
@onready var scorpion_anim: AnimationPlayer = $GiantScorpion/AnimationPlayer
@onready var scorpion_sprite: Sprite2D = $GiantScorpion/Sprite2D


func _ready() -> void:
	$QueueTrigger.body_entered.connect(_on_queue_trigger)
	warrior.entity_died.connect(_on_warrior_died)
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
	# Першим із проламу лізе велетенський скорпіон і стає дибки
	await _scorpion_walk(cs, ($Marks/ScorpionStand as Node2D).global_position, true)
	scorpion_anim.play(&"sting")
	cs.voice(&"brass_collector_roar")
	await cs.wait(STING_TIME)
	scorpion_anim.play(&"idle")
	# За ним — сокирник: вилазить і стає на підлогу
	warrior.global_position = ($Marks/HoleMouth as Node2D).global_position
	warrior.modulate.a = 0.0
	warrior.show()
	warrior.enemy_view.update_direction(-1)  # обличчям до героя
	warrior.anim_player.process_mode = Node.PROCESS_MODE_ALWAYS  # ШІ боса ще вимкнене, а кроки видно
	warrior.anim_player.play(&"walk")
	create_tween().tween_property(warrior, ^"modulate:a", 1.0, EMERGE_TIME * 0.4)
	await cs.move(warrior, ($Marks/WarriorStand as Node2D).global_position, EMERGE_TIME)
	warrior.anim_player.play(&"idle")
	cs.voice(&"boss_shout")
	_set_barrier(true)
	# Скорпіон відступає в пролам — б'ється сокирник сам (D557)
	await _scorpion_walk(cs, ($Marks/ScorpionOut as Node2D).global_position, false)
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
	game.set_objective("Survive the Scorpicore Axe-Warrior")
	game.player.defeat_handler = _on_hero_defeated
	game.preload_room(LAB_ROOM)  # бій закінчиться телепортом у лабораторію за будь-якого результату (performance_plan, slice 3)
	warrior.anim_player.process_mode = Node.PROCESS_MODE_INHERIT
	warrior.process_mode = Node.PROCESS_MODE_INHERIT
	EventBus.boss_fight_changed.emit(self, true)


## Програш (D300, D556): Game Over немає — люди клану тягнуть Кусакама в лабораторію.
func _on_hero_defeated() -> void:
	_end_fight()
	warrior.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED)
	var cs := Cutscene.new()
	cs.set_pose(&"Hurt")
	await ScreenFade.to_black(self)
	await cs.say("MayorHall_Defeat")
	_transport(cs)


## Перемога (D300, D556): досвід дав сам бос; речі — із зали; скорпіон вертається й забирає сокирника,
## а Кусакама, як і після програшу, тягнуть люди клану (темрява).
func _on_warrior_died() -> void:
	_end_fight()
	var inventory := ServiceLocator.get_inventory_manager()
	for item_id: String in VICTORY_LOOT:
		inventory.add_item(item_id, VICTORY_LOOT[item_id])
	ServiceLocator.get_ui_manager().show_obtained(VICTORY_LOOT)  # BACKLOG 33: покажеться в лабораторії, коли кат-сцена відпустить
	Game.get_singleton().set_quest_flag("mayor_boss_defeated", true)
	Charms.unlock_slot()  # D592: третій слот оберегів — після першого боса
	var cs := Cutscene.new()
	await cs.wait(KNOCKOUT_HOLD)
	var over_body := Vector2(warrior.global_position.x + SCORPION_OVER_BODY, ($Marks/ScorpionStand as Node2D).global_position.y)
	await _scorpion_walk(cs, over_body, true)
	create_tween().tween_property(warrior, ^"modulate:a", 0.0, SCORPION_FADE)  # переможеного забрали
	await cs.wait(SCORPION_FADE)
	await _scorpion_walk(cs, ($Marks/ScorpionOut as Node2D).global_position, false)
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


## Скорпіон іде до [param to] (D557: лише кат-сцена, тіла й хітбоксу в нього немає). [param coming_in] — з'являється з
## проламу (обличчям до героя); інакше — повертається спиною й зникає в проламі.
func _scorpion_walk(cs: Cutscene, to: Vector2, coming_in: bool) -> void:
	if coming_in:
		scorpion.global_position = ($Marks/ScorpionOut as Node2D).global_position
		scorpion.modulate.a = 0.0
		scorpion.show()
	scorpion_sprite.flip_h = to.x < scorpion.global_position.x
	scorpion_anim.play(&"walk")
	if coming_in:
		create_tween().tween_property(scorpion, ^"modulate:a", 1.0, SCORPION_FADE)
	else:
		create_tween().tween_property(scorpion, ^"modulate:a", 0.0, SCORPION_FADE).set_delay(SCORPION_TIME - SCORPION_FADE)
	await cs.move(scorpion, to, SCORPION_TIME)
	scorpion_anim.play(&"idle")
	if not coming_in:
		scorpion.hide()


func _set_barrier(on: bool) -> void:
	$BarrierWest/Collision.set_deferred(&"disabled", not on)
