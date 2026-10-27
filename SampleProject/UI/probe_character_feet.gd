extends SceneTree

## Ноги ворогів і NPC (hero-feet, крок 3): нижній непрозорий рядок кадрів спокою й ходи (idle і walk, як HitAreas.body_rect;
## без них — перший кадр «idle» чи кадр сцени) проти низу колізії тіла (CollisionShape2D у корені) і проти початку вузла,
## px вузла: найвищі й найнижчі ноги серед кадрів. Друкує таблицю; нічого не міняє.
##   godot --headless --path . --script res://SampleProject/UI/probe_character_feet.gd

const DIRS: Array[String] = [
	"res://SampleProject/Scenes/Characters/Enemies/",
	"res://SampleProject/Scenes/Characters/Bosses/",
	"res://SampleProject/Scenes/Characters/Companions/",
	"res://SampleProject/Scenes/Gameplay/Objects/NPCs/",
	"res://SampleProject/Scenes/Gameplay/Objects/NPCs/Townsfolk/",
]
const IDLE: Array[StringName] = [&"idle", &"Idle", &"default", &"RESET"]
const HitAreas := preload("res://SampleProject/Scripts/Combat/HitAreas.gd")


## Перший кадр анімації спокою з доріжки [param track_path] («<спрайт>:frame»), або -1.
func _idle_frame(player: AnimationPlayer, track_path: String) -> int:
	for name in IDLE:
		if not player.has_animation(name):
			continue
		var animation := player.get_animation(name)
		var track := animation.find_track(NodePath(track_path), Animation.TYPE_VALUE)
		if track != -1 and animation.track_get_key_count(track) > 0:
			return animation.track_get_key_value(track, 0)
	return -1


## Низ непрозорої частини кадру спрайта в px кореня (Rect2.end.y), NAN — порожньо.
func _sprite_bottom(root: Node, sprite: Node2D) -> float:
	var texture: Texture2D
	var cell: Vector2
	var region_at := Vector2.ZERO
	var offset: Vector2
	var centered: bool
	if sprite is Sprite2D:
		var s := sprite as Sprite2D
		var frame := s.frame
		var player := root.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
		if player:
			var idle := _idle_frame(player, "%s:frame" % root.get_path_to(s))
			if idle != -1:
				frame = idle
		texture = s.texture
		cell = Vector2(texture.get_width() / s.hframes, texture.get_height() / s.vframes)
		region_at = Vector2(frame % s.hframes, frame / s.hframes) * cell
		offset = s.offset
		centered = s.centered
	else:
		var a := sprite as AnimatedSprite2D
		var anim := a.animation
		for name in IDLE:
			if a.sprite_frames.has_animation(name):
				anim = name
				break
		texture = a.sprite_frames.get_frame_texture(anim, 0)
		cell = texture.get_size()
		offset = a.offset
		centered = a.centered
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var used := image.get_region(Rect2i(region_at, cell)).get_used_rect()
	if used.size == Vector2i.ZERO:
		return NAN
	var local := float(used.end.y) - (cell.y / 2.0 if centered else 0.0) + offset.y
	return sprite.position.y + local * sprite.scale.y


func _body(root: Node) -> CollisionShape2D:
	for child in root.get_children():
		if child is CollisionShape2D:
			return child
	return null


func _initialize() -> void:
	print("| scene | root | sprite | drawn feet y (idle+walk, min…max) | collision bottom y | feet − collision | feet − origin |")
	print("|---|---|---|---|---|---|---|")
	for dir in DIRS:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".tscn"):
				continue
			var root: Node = load(dir + file).instantiate()
			var sprite: Node2D = root.get_node_or_null(^"Sprite2D")
			if sprite == null:
				for child in root.get_children():
					if child is Sprite2D or child is AnimatedSprite2D:
						sprite = child
						break
			if sprite == null:
				print("| %s | %s | — | | | | |" % [file, root.get_class()])
				root.free()
				continue
			if (sprite is Sprite2D and (sprite as Sprite2D).texture == null) \
					or (sprite is AnimatedSprite2D and (sprite as AnimatedSprite2D).sprite_frames == null):
				print("| %s | %s | %s | (frames set at runtime) | | | |" % [file, root.get_class(), sprite.name])
				root.free()
				continue
			var feet := _sprite_bottom(root, sprite)
			var low := feet
			var player := root.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
			if sprite is Sprite2D and player and player.has_animation(&"idle") \
					and player.get_animation(&"idle").find_track(^"Sprite2D:frame", Animation.TYPE_VALUE) != -1:
				var frames := HitAreas.anim_frames(player, &"idle", 0.0, INF)
				if player.has_animation(&"walk"):
					frames.append_array(HitAreas.anim_frames(player, &"walk", 0.0, INF))
				feet = INF
				low = -INF
				for frame in frames:
					var rect := HitAreas.frame_rect(sprite, frame)
					if rect.size != Vector2.ZERO:
						feet = minf(feet, rect.end.y)
						low = maxf(low, rect.end.y)
			var body := _body(root)
			var bottom := NAN
			if body and body.shape:
				bottom = body.position.y + body.shape.get_rect().end.y
			var span := "%.1f" % feet if is_equal_approx(feet, low) else "%.1f…%.1f" % [feet, low]
			print("| %s | %s | %s | %s | %s | %s | %+.1f |" % [file, root.get_class(), sprite.name, span,
					"—" if is_nan(bottom) else "%.1f" % bottom, "—" if is_nan(bottom) else "%+.1f" % (low - bottom), low])
			root.free()
	quit()
