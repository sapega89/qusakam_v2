extends RefCounted

## Спільні кроки кат-сцен (D177, D308, design/cutscene_plan.md): керування забрано на весь час сцени, HUD сховано,
## камера відчеплена від героя й пливе між мітками, герой і актори ходять твінами, репліки — по черзі.
## Утримання cutscene_skip (Tab / геймпад Y) секунду — пропуск: сцена домотується ×SKIP_SPEED, репліки гортаються
## самі, тож прапорці, телепорти й стани ті самі, що й без пропуску.
##   const Cutscene = preload("res://SampleProject/Scripts/Systems/Cutscenes/Cutscene.gd")
##   var cs := Cutscene.new()
##   await cs.walk_hero(seat, 1.2)
##   await cs.say("Canyon_Exploration")
##   await cs.pan_to($Look.global_position, 1.6)
##   await cs.camera_back(1.0)
##   cs.end()
## Твіни й таймери — на дереві, а не на кімнаті: сцена переживає телепорт (спуск з каньйону).

const SKIP_PROMPT := preload("res://SampleProject/Scenes/UI/cutscene_skip_prompt.tscn")
const SKIP_SPEED := 8.0

var player: Node2D
var camera: Camera2D
var anim: AnimationPlayer
## Поза героя, яку повертає кожне блокування (діалог ставить Idle).
var pose: StringName = &"Idle"
var _tree: SceneTree
var _dm: Node
var _prompt: Node
var _hud: Array[CanvasLayer] = []
var _hold_later: Callable
var _shake: Tween
## Утримали пропуск: сцена домотується, голоси (voice) вже не звучать.
var skipping := false
## Гра пішла посеред сцени (вихід у меню, завантаження): сцена скінчилася разом із героєм (B92).
var _abandoned := false


func _init() -> void:
	_tree = Engine.get_main_loop()
	var game := Game.get_singleton()
	player = game.player
	camera = player.get_node(^"Camera2D")
	anim = player.get_node(^"AnimationPlayer")
	_dm = ServiceLocator.get_dialogue_manager()
	_hold_later = func(_id: String) -> void: hold.call_deferred()
	_dm.dialogue_started.connect(_hold_later)
	player.tree_exiting.connect(_abandon)
	for layer_name in [^"UI", ^"UICanvas"]:
		var layer: CanvasLayer = game.get_node(layer_name)
		if layer.visible:
			layer.visible = false
			_hud.append(layer)
	_prompt = SKIP_PROMPT.instantiate()
	_prompt.skip_requested.connect(_skip)
	_tree.root.add_child(_prompt)
	hold()


## Героя тримає сцена: стоїть у своїй позі, ввід не діє. Кінець кожного діалогу повертає керування — тому знову.
func hold() -> void:
	player.set_movement_enabled(false)
	anim.play(pose)


func set_pose(new_pose: StringName) -> void:
	pose = new_pose
	hold()


## Розмова до кінця. [param in_cloud] — облачко над героєм (D263).
func say(dialogue_id: String, in_cloud: bool = false) -> void:
	var path := "res://dialogue_quest/%s.dqd" % dialogue_id
	_dm.start_dialogue(path, in_cloud)
	while true:
		var finished: String = await _dm.dialogue_finished
		if _abandoned:
			return  # та сама розмова в наступній грі — героя цієї сцени вже немає
		if finished == path or finished == dialogue_id:
			break
	hold()


## Голос, що належить сцені (рев, сміх, закляття — D310); під пропуском — тиша, а не вісім голосів за секунду.
func voice(event: StringName) -> void:
	if not skipping:
		AudioManager.play(event)


func wait(seconds: float) -> void:
	await _tree.create_timer(seconds).timeout


## Герой іде (Walk) до [param to] за [param seconds] і стає в Idle; дивиться туди, куди йде.
func walk_hero(to: Vector2, seconds: float) -> void:
	player.get_node(^"Sprite2D").flip_h = to.x < player.global_position.x
	pose = &"Walk"
	anim.play(pose)
	await move(player, to, seconds)
	set_pose(&"Idle")


## Будь-який вузол — до [param to] за [param seconds] (анімацію ходи вмикає той, хто кличе).
func move(node: Node2D, to: Vector2, seconds: float, trans: Tween.TransitionType = Tween.TRANS_LINEAR) -> void:
	var tween := _tree.create_tween()
	tween.tween_property(node, ^"global_position", to, seconds).set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


## Камера більше не йде за героєм: лишається там, де зараз центр екрана.
func detach_camera() -> void:
	if camera.top_level:
		return
	var center := camera.get_screen_center_position()
	camera.top_level = true
	camera.global_position = center
	camera.reset_smoothing()


func pan_to(point: Vector2, seconds: float) -> void:
	detach_camera()
	await move(camera, point, seconds, Tween.TRANS_SINE)


## Камера пливе назад до героя й знову за ним іде.
func camera_back(seconds: float) -> void:
	if camera.top_level:
		await move(camera, player.global_position, seconds, Tween.TRANS_SINE)
	attach_camera()


func attach_camera() -> void:
	camera.top_level = false
	camera.position = Vector2.ZERO
	camera.reset_smoothing()


## Трусить камеру [param seconds] с з силою [param strength] px (вибух, землетрус).
func shake(strength: float, seconds: float) -> void:
	if _shake and _shake.is_valid():
		_shake.kill()
	_shake = _tree.create_tween()
	var steps := maxi(1, int(seconds / 0.05))
	for i in steps:
		var fade := 1.0 - float(i) / steps
		_shake.tween_property(camera, ^"offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * fade, 0.05)
	_shake.tween_property(camera, ^"offset", Vector2.ZERO, 0.05)


## Кінець сцени: камера за героєм, HUD і керування назад, звичайна швидкість.
func end() -> void:
	player.tree_exiting.disconnect(_abandon)
	camera.offset = Vector2.ZERO
	if camera.top_level:
		attach_camera()
	_prompt.free()  # не queue_free: до кінця кадру підказка гортала б уже наступну розмову (CityGates_Fight)
	_release()
	player.set_movement_enabled(true)


## Герой іде з дерева разом із грою, а end() так і не настав: сцена відпускає все, що тримає поза грою —
## підписку на автозавантаження DialogueManager (наступна гра інакше кликала б hold() на звільненому герої),
## підказку в root, швидкість пропуску (B92).
func _abandon() -> void:
	_abandoned = true
	_prompt.queue_free()  # root саме знімає гру — free() тут не можна
	_release()


func _release() -> void:
	if _shake and _shake.is_valid():
		_shake.kill()
	_dm.dialogue_started.disconnect(_hold_later)
	for layer in _hud:
		layer.visible = true
	_hud.clear()
	Engine.time_scale = 1.0


func _skip() -> void:
	skipping = true
	Engine.time_scale = SKIP_SPEED
