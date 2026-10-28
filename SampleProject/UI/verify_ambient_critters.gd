extends SceneTree

## Жива дрібнота на передньому плані (D774, ambient_critters_plan slice 1):
##   godot --headless --path . --script res://SampleProject/UI/verify_ambient_critters.gd
##   1. У печері ящурів дві кажани під FrontDark, висять під корінням, ні з чим не стикаються; герой біля дверей їх
##      не лякає.
##   2. Герой іде до кажана (справжнє move_right) → вона злітає й зникає за краєм кадру.
##   3. Поки її місце в кадрі, вона не вертається, хоч затримка й минула; поза кадром — не раніше затримки;
##      після затримки з місцем поза кадром — знову висить.
##   4. Вихід з кімнати й повернення не скидає часу: кажан і далі відсутня, поки затримка не мине.
##   5. R2, кожна кімната: хто де живе (план rooms-dressing), розмір сидячої — точно за таблицею world_scale_plan
##      (× множник шару), жодна не сидить біля дверей, NPC, скрині чи підбирання і не посеред бою; злітаючи, птахи й
##      кажани грають critter_flap, метелики й міль — ні.
##   6. Атмосфера: у кожній кімнаті одне-два тихі ефекти; Low (D554) удвічі ріже ті, де частинок ≥ 16, High вертає.
##   7. Трава (A4): кущики стоять на підлозі, позаду героя, не біля скрині чи підбирання.
##   8. Миша (D803, ambient_critters_plan): сидить на підлозі; злякана — біжить підлогою (run) у свою нору й зникає.
## Затримка вкорочується через експортовану змінну — тест не чекає 30 с. Пише лише в user://verify_ambient_critters/.

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const Critter = preload("res://SampleProject/Scripts/Gameplay/AmbientCritter.gd")
const CAVE := "res://SampleProject/Maps/LizardCave.tscn"
const CANYON := "res://SampleProject/Maps/Canyon.tscn"
const TEST_DIR := "user://verify_ambient_critters/"
const DECOR := "res://SampleProject/Scenes/Backgrounds/Decor/"
const MAPS := "res://SampleProject/Maps/%s.tscn"
## Висота в пікселях арту (world_scale_plan: «bat, lark» 24, «butterfly, moth, mouse» 12); світ = арт × 1.5.
## Голуб 16 (BACKLOG «Critter tweaks», Sapega 28.10: «менший голуб», рядок `critter_small` у world_scale.json).
const ART_HEIGHT := {"critter_bat": 24, "critter_bird": 24, "critter_pigeon": 16, "critter_butterfly": 12,
		"critter_butterfly_blue": 12, "critter_moth": 12, "critter_mouse": 12}
const GRASS_ART := 16
## Хто де живе (R2, Sapega 2026-10-27): кімната → {сцена: скільки}.
const LIVES := {
	"Canyon": {"critter_bird": 2, "critter_butterfly": 1},
	# Village: село згоріло (D796) — ні жайворонків, ні метеликів, у повітрі жар.
	"Village": {},
	"DesertRoad": {"critter_bird": 3, "critter_butterfly": 2},
	"CityGates": {"critter_bird": 2},
	"City": {"critter_pigeon": 3},
	"LaboratoryOutside": {"critter_bird": 1, "critter_butterfly_blue": 2},
	"BanditCamp": {"critter_bird": 1, "critter_butterfly": 1},
	"MesaClimb": {"critter_butterfly": 1},
	"LizardCave": {"critter_bat": 2},
	"GatehouseCellar": {"critter_bat": 2, "critter_mouse": 1},
	"ElderHouse": {"critter_moth": 1, "critter_mouse": 1},
}
## Атмосфера кожної кімнати (m6_backdrops «Every room has atmosphere»); Canyon — еталонні вихори пилу Decor/Dust*.
const AIR := {
	"Canyon": ["dust"], "Village": ["atmo_embers"], "DesertRoad": ["atmo_pollen", "dust"], "CityGates": ["atmo_pollen"],
	"City": ["atmo_pollen"], "LaboratoryOutside": ["atmo_pollen"], "BanditCamp": ["atmo_pollen"], "MesaClimb": ["atmo_pollen"],
	"LizardCave": ["atmo_fireflies"], "DragonMural": ["atmo_spores"], "GatehouseCellar": ["atmo_spores"],
	"ElderHouse": ["atmo_light_shaft"], "MayorHall": ["atmo_light_shaft"], "LabCells": ["atmo_steam"],
	"Laboratory": ["atmo_steam", "atmo_sparks"], "LabBoss": ["atmo_embers", "atmo_steam"],
}
const GRASS_ROOMS := ["Canyon", "Village", "DesertRoad", "CityGates", "City", "LaboratoryOutside", "BanditCamp", "MesaClimb"]

var fails: Array[String] = []
var game: Node


func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _initialize() -> void:
	await process_frame
	await process_frame
	var save_system: Node = root.get_node("SaveSystem")
	save_system.settings_module.settings.tutorial_windows = false
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(1)
	game = await Kit.boot(self)
	Critter.left_at.clear()

	print("[1] Two bats hang in the Lizard Cave's foreground")
	await _visit(CAVE, ^"ExitDoor")
	var bats := _bats()
	ck(bats.size() == 2, "two bats under FrontDark (%d)" % bats.size())
	for bat: Node2D in bats:
		ck(bat.get_parent().name == &"FrontDark", "%s lives on the dark foreground layer" % bat.name)
		ck(bat.find_children("*", "CollisionObject2D", true, false).is_empty(), "%s has no body or area: it touches nothing" % bat.name)
		ck(not bat.is_away() and bat.sprite.visible and bat.sprite.flip_v, "%s hangs perched (upside down) at the start" % bat.name)
		ck(bat.scare_distance == 160.0 and bat.return_delay == 30.0, "%s: the plan's defaults, 160 px and 30 s" % bat.name)
	await _frames(30)
	ck(bats.all(func(b: Node2D) -> bool: return not b.is_away() and not b.is_flying()), "the hero at the door scares nobody")

	print("[2] The hero walks up: the bat leaves the view")
	var bat: Node2D = bats[0]
	bat.return_delay = 2.0
	game.place_player(Vector2(bat.global_position.x - 320.0, game.player.global_position.y))
	await _frames(40)
	ck(not bat.is_flying() and not bat.is_away(), "still perched with the hero 320 px away")
	Input.action_press(&"move_right")
	var took_off := false
	for i in 300:
		await physics_frame
		if bat.is_flying():
			took_off = true
			break
	Input.action_release(&"move_right")
	var gap: float = absf(bat.global_position.x - game.player.global_position.x)
	ck(took_off, "the bat takes off as the hero comes near (%.0f px)" % gap)
	ck(gap <= bat.scare_distance + 8.0, "…within the scare distance, not before")
	ck(bat.sprite.is_playing() and bat.sprite.animation == &"fly", "it flaps (the fly row plays)")
	var away_dir: float = signf(bat.global_position.x - game.player.global_position.x)
	for i in 200:
		await physics_frame
		if bat.is_away():
			break
	ck(bat.is_away() and not bat.sprite.visible, "it is gone, hidden")
	ck(signf(bat.sprite.position.x) == away_dir and bat.sprite.position.y < 0.0, "it flew up and away from the hero")
	var drawn: Rect2 = bat.sprite.get_global_transform_with_canvas() * Rect2(-32, -32, 64, 64)
	ck(not root.get_visible_rect().intersects(drawn), "where it ended is out of the camera's view (%s)" % drawn)
	ck(Critter.left_at.size() == 1, "its leaving time is remembered")

	print("[3] It comes back only after the delay and with its perch out of view")
	ck(bat._perch_on_screen(), "the hero stays: the perch is on screen")
	await _seconds(2.6)
	ck(bat.is_away(), "the delay (2 s) is over, but the perch is on screen: still away")
	bat.return_delay = 8.0
	await _hero_far_from(bat)
	ck(not bat._perch_on_screen(), "the hero walked off: the perch is out of view")
	ck(bat.is_away(), "…and before the delay (8 s) it is still away")
	var since: float = (Time.get_ticks_msec() - Critter.left_at[bat._key]) / 1000.0
	await _seconds(8.2 - since)
	await _frames(2)
	ck(not bat.is_away() and bat.sprite.visible and bat.sprite.position == Vector2.ZERO and bat.sprite.flip_v,
			"after the delay with the perch out of view it hangs there again (no fly-in)")
	ck(not bat.sprite.is_playing(), "…holding one frame")
	ck(Critter.left_at.is_empty(), "its leaving time is cleared")

	print("[4] Leaving the room and coming back keeps it away until the delay")
	game.place_player(Vector2(bat.global_position.x - 40.0, game.player.global_position.y))
	for i in 200:
		await physics_frame
		if bat.is_away():
			break
	ck(bat.is_away(), "scared off again")
	var path: NodePath = game.map.get_path_to(bat)
	await _visit(CANYON, ^"LizardCaveDoor")
	await _visit(CAVE, ^"ExitDoor")
	var again: Node2D = game.map.get_node(path)
	ck(again != bat and again.is_away() and not again.sprite.visible, "a fresh room, the same bat: still away")
	await _hero_far_from(again)
	ck(not again._perch_on_screen() and again.is_away(), "perch out of view, but the 30 s are not over: still away")
	var other: Node2D = game.map.get_node(game.map.get_path_to(_bats()[1]))
	ck(not other.is_away() and other.sprite.visible, "the other bat, never scared, hangs as before")
	again.return_delay = 0.5
	await _frames(4)
	ck(not again.is_away() and again.sprite.visible, "with the delay over it is back")

	await _rooms()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()


func _rooms() -> void:
	var audio: Node = root.get_node("AudioManager")
	var heard: Array[StringName] = []
	audio.sound_played.connect(func(event: StringName, _s: AudioStream, _b: StringName, _p: float) -> void: heard.append(event))
	var quality: Node = root.get_node("DisplayManager").graphics_quality
	for room: String in AIR:
		await game.teleport_to_room(MAPS % room, _first_door(room))
		await _frames(10)
		await Kit.drain(self)
		print("[5] %s: who lives here" % room)
		var critters := _bats()
		var counts := {}
		for c: Node2D in critters:
			var kind: String = c.scene_file_path.get_file().get_basename()
			counts[kind] = counts.get(kind, 0) + 1
		ck(counts == LIVES.get(room, {}), "%s: %s" % [room, counts])
		for c: Node2D in critters:
			_check_size(room, c)
			_check_clear(room, c)
		Critter.left_at.clear()
		for c: Node2D in critters:
			heard.clear()
			c._fly_off(1.0)
			var kind: String = c.scene_file_path.get_file().get_basename()
			var flaps: bool = kind in ["critter_bat", "critter_bird", "critter_pigeon"]
			ck(heard.has(&"critter_flap") == flaps, "%s: %s %s on take-off" % [room, c.name, "flaps (critter_flap)" if flaps else "is silent"])
			if kind == "critter_mouse":
				await _check_mouse(room, c)
		print("[6] %s: the air" % room)
		var effects := _effects(room)
		ck(effects.size() >= 1 and effects.size() <= 2, "%s: one or two quiet effects %s" % [room, effects.keys()])
		ck(effects.keys().all(func(k: String) -> bool: return k in AIR[room]), "%s: fitted to the place (%s)" % [room, AIR[room]])
		var emitters: Array[Node] = game.map.find_children("*", "CPUParticles2D", true, false)
		var high := {}
		for e: Node in emitters:
			high[e] = e.amount
		quality.apply("low")
		ck(emitters.all(func(e: Node) -> bool: return e.amount == (ceili(high[e] / 2.0) if high[e] >= 16 else high[e])),
				"%s: Low halves every emitter of 16+ particles, keeps the small ones" % room)
		quality.apply("high")
		ck(emitters.all(func(e: Node) -> bool: return e.amount == high[e]), "%s: High brings them back" % room)
		if room in GRASS_ROOMS:
			print("[7] %s: grass" % room)
			_check_grass(room)


## Перші двері кімнати (у частини кімнат немає Arrival).
func _first_door(room: String) -> NodePath:
	var scene: Node = (load(MAPS % room) as PackedScene).instantiate()
	var path := ^"Arrival"
	for n: Node in scene.get_children():
		if _kind(n) == "door":
			path = NodePath(n.name)
			break
	scene.free()
	return path


## Сидяча — точно за таблицею: непрозора висота кадру сидіння × масштаб = арт × 1.5 × множник шару (±1 піксель арту).
func _check_size(room: String, c: Node2D) -> void:
	var kind: String = c.scene_file_path.get_file().get_basename()
	var sprite: AnimatedSprite2D = c.sprite
	var anim: StringName = &"fly" if c.perch_animation == &"" else c.perch_animation
	var image: Image = sprite.sprite_frames.get_frame_texture(anim, 0).get_image()
	var factor: float = (c.get_parent() as Parallax2D).scroll_scale.x if c.get_parent() is Parallax2D else 1.0
	var want: float = roundf(ART_HEIGHT[kind] * factor) * 1.5
	var drawn: float = image.get_used_rect().size.y * sprite.scale.y
	ck(absf(drawn - want) <= 1.5, "%s: %s perched is %.1f world px, the chart says %.1f" % [room, c.name, drawn, want])
	if kind == "critter_moth":
		# Міль — не метелик: та сама висота, крила розтягнуті вшир ×1.4 (Critter tweaks).
		ck(is_equal_approx(snappedf(sprite.scale.x / sprite.scale.y, 0.01), 1.4), "%s: %s is stretched ×1.4 wide (%.2f)" % [room, c.name, sprite.scale.x / sprite.scale.y])


## Не біля дверей, NPC, скрині чи підбирання (96 px), не посеред бою (200 px від тригера), на кімнатному плані.
func _check_clear(room: String, c: Node2D) -> void:
	var at := c.global_position
	for n: Node in game.map.get_children():
		if not (n is Node2D):
			continue
		var kind := _kind(n)
		var p: Vector2 = (n as Node2D).global_position
		if kind != "" and absf(p.y - at.y) < 240.0:
			ck(absf(p.x - at.x) >= 96.0, "%s: %s keeps off the %s %s (%.0f px)" % [room, c.name, kind, n.name, absf(p.x - at.x)])
		if String(n.name).begins_with("Fight_"):
			for t: Node in n.get_children():
				if t is Area2D and absf((t as Area2D).global_position.y - at.y) < 480.0:
					ck(absf((t as Area2D).global_position.x - at.x) >= 200.0, "%s: %s is not in the middle of %s" % [room, c.name, n.name])


func _kind(n: Node) -> String:
	var script: Script = n.get_script()
	if script != null and script.resource_path.ends_with("/RoomDoor.gd"):
		return "door"
	if n.scene_file_path.ends_with("Chest.tscn"):
		return "chest"
	if n.scene_file_path.ends_with("ItemPickup.tscn"):
		return "pickup"
	if n.scene_file_path.contains("/NPCs/") or n.scene_file_path.ends_with("grandfather.tscn"):
		return "NPC"
	return ""


func _effects(room: String) -> Dictionary:
	var out := {}
	var holders: Array[Node] = []
	for name: NodePath in [^"Ambience", ^"Decor"]:
		var holder: Node = game.map.get_node_or_null(name)
		if holder != null:
			holders.append(holder)
	for holder: Node in holders:
		for e: Node in holder.get_children():
			var kind: String = e.scene_file_path.get_file().get_basename()
			if kind.begins_with("atmo_") or kind == "dust":
				out[kind] = true
	return out


func _check_grass(room: String) -> void:
	var holder: Node2D = game.map.get_node(^"Grass")
	var tufts: Array[Node] = holder.get_children()
	ck(tufts.size() >= 4, "%s: tufts along the walk line (%d)" % [room, tufts.size()])
	ck(holder.z_index < game.player.z_index, "%s: grass behind the hero" % room)
	var space: PhysicsDirectSpaceState2D = game.map.get_world_2d().direct_space_state
	var off_floor := 0
	var near := 0
	for t: AnimatedSprite2D in tufts:
		var used: float = t.sprite_frames.get_frame_texture(&"idle", 0).get_image().get_used_rect().end.y * t.scale.y
		if absf(used - GRASS_ART * 1.5) > 1.5:
			ck(false, "%s: %s is %.1f world px tall, the chart says %d" % [room, t.name, used, GRASS_ART * 1.5])
		var q := PhysicsRayQueryParameters2D.create(t.global_position + Vector2(0, -6), t.global_position + Vector2(0, 24))
		q.exclude = [game.player.get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty() or absf(hit.position.y - t.global_position.y) > 1.0:
			off_floor += 1
		for n: Node in game.map.get_children():
			if _kind(n) in ["chest", "pickup", "door"] and (n as Node2D).global_position.distance_to(t.global_position) < 64.0:
				near += 1
	ck(off_floor == 0, "%s: every tuft stands on the floor (%d off)" % [room, off_floor])
	ck(near == 0, "%s: no tuft at a chest, pickup or door (%d)" % [room, near])


## [8] Миша не летить: біжить по підлозі (y не змінюється) до нори й там зникає.
func _check_mouse(room: String, mouse: Node2D) -> void:
	print("[8] %s: the mouse runs into its hole" % room)
	var sprite: AnimatedSprite2D = mouse.sprite
	await _frames(3)
	ck(sprite.animation == &"run" and is_zero_approx(sprite.position.y) and sprite.position.x > 0.0,
			"%s: it runs along the floor toward the hole (%s at %s)" % [room, sprite.animation, sprite.position])
	await _seconds(absf(mouse.hole.position.x) / mouse.run_speed + 0.3)
	ck(mouse.is_away() and not sprite.visible, "%s: and is gone in the hole" % room)


func _bats() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for n: Node in game.map.find_children("*", "Node2D", true, false):
		if n.get_script() == Critter:
			out.append(n)
	return out


func _visit(room: String, arrival: NodePath) -> void:
	await game.teleport_to_room(room, arrival)
	await _frames(20)
	await Kit.drain(self)
	# Бій ящурів тримає камеру й героя — тут перевіряється кажан, не бій.
	for n: Node in game.map.get_children():
		if String(n.name).begins_with("Fight_"):
			n.free()


## Герой далеко від кажана, камера доїхала — її місце поза кадром.
func _hero_far_from(bat: Node2D) -> void:
	var far: float = bat.global_position.x + 900.0
	game.place_player(Vector2(far, game.player.global_position.y - 40.0))
	await _frames(90)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await physics_frame
