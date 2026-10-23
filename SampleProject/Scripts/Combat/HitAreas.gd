extends RefCounted

## Зони удару з того, що намальовано (B128): непрозорі межі кадрів спрайта, px у координатах вузла, якому належить
## спрайт (ворог, герой), обличчям праворуч. Тіло (воно ж зона, куди б'ють) — межі кадрів idle і walk; удар — межі
## кадрів анімації attack, що на екрані, поки хітбокс живий (від meta «attack_strike_time» AnimationPlayer на
## attack_active_time). Цим міряють форми в сценах ворогів і перевіряє verify_hit_areas.


const EPSILON := 0.001


## Непрозора частина кадру [param frame] (Rect2() — кадр порожній).
static func frame_rect(sprite: Sprite2D, frame: int) -> Rect2:
	var image: Image = sprite.texture.get_image()
	var cell := Vector2i(image.get_width() / sprite.hframes, image.get_height() / sprite.vframes)
	var at := Vector2i(frame % sprite.hframes * cell.x, frame / sprite.hframes * cell.y)
	var used := image.get_region(Rect2i(at, cell)).get_used_rect()
	if used.size == Vector2i.ZERO:
		return Rect2()
	var local := Rect2(Vector2(used.position) - Vector2(cell) / 2.0 + sprite.offset, Vector2(used.size))
	return Rect2(sprite.position + local.position * sprite.scale, local.size * sprite.scale)


## Спільні межі кадрів [param frames].
static func frames_rect(sprite: Sprite2D, frames: Array[int]) -> Rect2:
	var out := Rect2()
	for frame in frames:
		var rect := frame_rect(sprite, frame)
		if rect.size != Vector2.ZERO:
			out = rect if out.size == Vector2.ZERO else out.merge(rect)
	return out


## Кадри доріжки «Sprite2D:frame» анімації [param anim], що на екрані з [param from] по [param to] с.
static func anim_frames(player: AnimationPlayer, anim: StringName, from: float, to: float) -> Array[int]:
	var animation := player.get_animation(anim)
	var track := animation.find_track(^"Sprite2D:frame", Animation.TYPE_VALUE)
	var frames: Array[int] = []
	for key in animation.track_get_key_count(track):
		var start := animation.track_get_key_time(track, key)
		var end := animation.track_get_key_time(track, key + 1) if key + 1 < animation.track_get_key_count(track) else animation.length
		if start < to - EPSILON and end > from + EPSILON:  # ключі — float32: 0.4 у доріжці трохи більше за 0.4
			frames.append(int(animation.track_get_key_value(track, key)))
	return frames


## Межі тіла ворога: кадри idle і walk.
static func body_rect(sprite: Sprite2D, player: AnimationPlayer) -> Rect2:
	var frames := anim_frames(player, &"idle", 0.0, INF)
	frames.append_array(anim_frames(player, &"walk", 0.0, INF))
	return frames_rect(sprite, frames)


## Межі удару ворога: кадри attack, поки хітбокс живий ([param active_time] с від кадру удару).
static func strike_rect(sprite: Sprite2D, player: AnimationPlayer, active_time: float) -> Rect2:
	var strike: float = player.get_meta(&"attack_strike_time")
	return frames_rect(sprite, anim_frames(player, &"attack", strike, strike + active_time))


## Прямокутник форми [param shape] у координатах її батька-тіла (обличчям праворуч), з урахуванням зсуву зони.
static func shape_rect(shape: CollisionShape2D) -> Rect2:
	var rect: Rect2 = shape.shape.get_rect()
	var at := shape.position
	if shape.get_parent() is Area2D:
		at += (shape.get_parent() as Node2D).position
	return Rect2(rect.position + at, rect.size)
