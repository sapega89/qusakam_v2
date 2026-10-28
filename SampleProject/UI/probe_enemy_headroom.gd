extends SceneTree

## Зонд B187: місце над ворогом. У кожній кімнаті з точками спавну на кожній точці стає її вид (як у probe_world_scale),
## падає на підлогу, і від верху намальованого тіла (HitAreas.body_rect, кадри idle і walk) три промені вгору (лівий
## край, середина, правий край) шукають стелю — найменший зазор. Ще прохід: на ±WALK px від точки через кожні 20 px
## промінь від лінії ніг угору на намальовану висоту; стеля, двері чи навис, що нижче за малюнок, але вище за тіло (під
## ним тіло пройде, а малюнок вріжеться), — «low», з найнижчою висотою. Друкує рядок на точку і найтісніший:
##   godot --headless --path . --script res://SampleProject/UI/probe_enemy_headroom.gd
## Лише зонд: сцени гри не змінює.

const HitAreas = preload("res://SampleProject/Scripts/Combat/HitAreas.gd")
const MAPS_DIR := "res://SampleProject/Maps/"
const ROOMS: Array[String] = ["BanditCamp", "CityGates", "DesertRoad", "GatehouseCellar", "Laboratory", "LizardCave", "MesaClimb", "Village"]
## Промінь угору: далі за це — відкрите небо.
const REACH := 600.0
## Прохід ліворуч і праворуч від точки, px.
const WALK := 400.0
var spawn_script: Script


func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	spawn_script = load("res://SampleProject/Scripts/Gameplay/EnemySpawnPoint.gd")
	var tightest := {"gap": INF}
	for room: String in ROOMS:
		var path: String = MAPS_DIR + room + ".tscn"
		await game.load_room(path)
		for i in 10: await physics_frame
		var map: Node = game.map
		for node: Node in map.find_children("*", "CharacterBody2D", true, false):
			if node.is_in_group(&"enemies"):
				node.queue_free()
		await process_frame
		for point: Node in map.find_children("*", "", true, false):
			if point.get_script() != spawn_script:
				continue
			var kind: String = point.kind()
			var enemy: Node2D = (load(point.scene_path(kind)) as PackedScene).instantiate()
			enemy.enemy_stats = point.enemy_stats()
			enemy.position = point.position
			point.get_parent().add_child(enemy)
			for i in 30: await physics_frame
			enemy.set_physics_process(false)
			enemy.enemy_logic.set_physics_process(false)
			var body: Rect2 = HitAreas.body_rect(enemy.sprite, enemy.anim_player)
			var top: Vector2 = enemy.global_position + body.position
			var space := (enemy as CharacterBody2D).get_world_2d().direct_space_state
			var gap := REACH
			for x: float in [top.x, top.x + body.size.x * 0.5, body.end.x + enemy.global_position.x]:
				var ray := PhysicsRayQueryParameters2D.create(Vector2(x, top.y), Vector2(x, top.y - REACH), (enemy as CharacterBody2D).collision_mask, [(enemy as CharacterBody2D).get_rid()])
				var hit: Dictionary = space.intersect_ray(ray)
				if not hit.is_empty():
					gap = minf(gap, top.y - (hit.position as Vector2).y)
			var feet: float = enemy.global_position.y + body.end.y - 2.0
			var shape_h: float = (enemy as CharacterBody2D).get_node(^"CollisionShape2D").shape.get_rect().size.y
			var low := INF
			for i in int(WALK * 2.0 / 20.0) + 1:
				var x: float = enemy.global_position.x - WALK + i * 20.0
				var up := PhysicsRayQueryParameters2D.create(Vector2(x, feet), Vector2(x, feet - body.size.y), (enemy as CharacterBody2D).collision_mask, [(enemy as CharacterBody2D).get_rid()])
				var over: Dictionary = space.intersect_ray(up)
				if not over.is_empty() and feet - (over.position as Vector2).y > shape_h:
					low = minf(low, feet - (over.position as Vector2).y)
			var row := "%s %s %s: drawn %.0fx%.0f, ceiling gap %s, walk %s" % [room, point.name, kind, body.size.x, body.size.y,
					"open" if gap >= REACH else "%.0f" % gap, "clear" if low == INF else "low %.0f" % low]
			print("headroom ", row)
			if gap < tightest.gap:
				tightest = {"gap": gap, "row": row}
			enemy.queue_free()
			await process_frame
	print("tightest ", tightest.get("row", "none"))
	quit()
