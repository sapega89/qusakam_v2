extends Node

## B199 (D750, D800): заслони переднього плану (×1.3: скелі, пальми, колони — Occluder*, Pillar*) не ховають бою.
## Заслон їде відносно світу (scroll 1.3), а бій рухається кімнатою — жодне місце в .tscn не тримає його поза боєм
## за кожного положення камери. Тому, поки йде бій, кожен заслон, що перекриває його зону (герой, вороги бою, точки
## їхнього спавну, від краю до краю), швидко тьмяніє до FADED_ALPHA, а після бою вертається.
## Бій іде, коли живий ворог кинувся на героя (CHASE / ATTACK / RETREAT) або живий ворог — у кадрі.
## Дитина Game (Game._ready), працює в кожній кімнаті.

const FADED_ALPHA := 0.25
## Повне згасання / повернення — за FADE_TIME секунд.
const FADE_TIME := 0.2
## Тіло бійця у світі навколо його позиції (ноги — біля низу): з запасом під зброю й стрибок.
const BODY := Rect2(-40.0, -96.0, 80.0, 112.0)

var _occluders: Array[CanvasItem] = []
var _spawners: Array[RoomEnemySpawner] = []
var _map: Node = null


func _process(delta: float) -> void:
	var game: Game = Game.get_singleton()
	if game.map != _map:
		_map = game.map
		_occluders.clear()
		_spawners.clear()
		if _map != null:
			_occluders = occluders_of(_map)
			_spawners.assign(_map.find_children("*", "RoomEnemySpawner", true, false))
	if _occluders.is_empty():
		return
	var area := fight_area(game, _spawners)
	var step := delta * (1.0 - FADED_ALPHA) / FADE_TIME
	for o: CanvasItem in _occluders:
		var covers: bool = area.has_area() and area.intersects(screen_rect(o))
		o.modulate.a = move_toward(o.modulate.a, FADED_ALPHA if covers else 1.0, step)


## Заслони кімнати — як їх бачить D750: спрайти в Parallax2D зі scroll > 1, імена Occluder* / Pillar*.
static func occluders_of(room: Node) -> Array[CanvasItem]:
	var out: Array[CanvasItem] = []
	for p: Node in room.find_children("*", "Parallax2D", true, false):
		if (p as Parallax2D).scroll_scale.x <= 1.0:
			continue
		for c: Node in p.find_children("*", "", true, false):
			if (c is Sprite2D or c is AnimatedSprite2D) and (String(c.name).begins_with("Occluder") or String(c.name).begins_with("Pillar")):
				out.append(c)
	return out


## Намальований прямокутник заслону на екрані.
static func screen_rect(ci: CanvasItem) -> Rect2:
	var r: Rect2
	if ci is AnimatedSprite2D:
		var s: AnimatedSprite2D = ci
		var tex: Texture2D = s.sprite_frames.get_frame_texture(s.animation, s.frame)
		r = Rect2(s.offset - (tex.get_size() / 2.0 if s.centered else Vector2.ZERO), tex.get_size())
	else:
		r = (ci as Sprite2D).get_rect()
	return ci.get_global_transform_with_canvas() * r


## Зона бою на екрані: від краю до краю героя, бійців і точок спавну живих боїв у кадрі. Немає бою — порожня.
static func fight_area(game: Game, spawners: Array[RoomEnemySpawner]) -> Rect2:
	var view: Rect2 = game.get_viewport().get_visible_rect()
	var canvas: Transform2D = game.get_viewport().get_canvas_transform()
	var points: Array[Vector2] = []
	for enemy: Node in game.get_tree().get_nodes_in_group(GameGroups.ENEMIES):
		if not enemy.is_alive() or not game.map.is_ancestor_of(enemy):
			continue
		var at: Vector2 = (enemy as Node2D).global_position
		if _engaged(enemy) or view.has_point(canvas * at):
			points.append(at)
	if points.is_empty():
		return Rect2()
	for spawner: RoomEnemySpawner in spawners:
		if spawner.get_alive_enemies_count() == 0:
			continue
		for sp: EnemySpawnPoint in spawner.spawn_points:
			if view.has_point(canvas * sp.global_position):
				points.append(sp.global_position)
	points.append(game.player.global_position)
	var area := canvas * Rect2(points[0] + BODY.position, BODY.size)
	for p: Vector2 in points:
		area = area.merge(canvas * Rect2(p + BODY.position, BODY.size))
	return area.intersection(view)


static func _engaged(enemy: Node) -> bool:
	var states: Dictionary = enemy.enemy_logic.AIState
	return enemy.enemy_logic.current_state in [states.CHASE, states.ATTACK, states.RETREAT]
