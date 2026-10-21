extends CanvasLayer

## Червона віньєтка по краях екрана, коли героя вдарили (4b): спалахує й гасне. Центр екрана прозорий —
## це не повноекранний спалах (Sapega, hack'n'slash). Колір — UITokens.HURT_VIGNETTE; розмітка — HurtVignette.tscn.

@onready var _edge: TextureRect = $Edge
var _fade: Tween


func _ready() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(UITokens.HURT_VIGNETTE.map(func(s: Array) -> float: return s[1]))
	gradient.colors = PackedColorArray(UITokens.HURT_VIGNETTE.map(func(s: Array) -> Color: return s[0]))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	_edge.texture = texture
	_edge.modulate.a = 0.0


## Спалах силою [param strength] (0..1), що гасне за [param time] с (реальних — завмирання його не тримає).
func pulse(strength: float, time: float) -> void:
	if _fade:
		_fade.kill()
	_edge.modulate.a = strength
	_fade = create_tween().set_ignore_time_scale()
	_fade.tween_property(_edge, ^"modulate:a", 0.0, time).set_ease(Tween.EASE_IN)


func strength() -> float:
	return _edge.modulate.a
