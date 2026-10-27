extends RefCounted

## Камера карти-полотна (World Map, рівні 1 і 2; D-ID у звіті map-pan): масштаб і зсув вмісту у вікні, як в
## Octopath Traveler. Вміст розміру [member content] (у масштабі 1) показується в [member view] за правилом
## екран = offset + точка × zoom. Вміст ніколи не відкриває край: більший за вікно — притиснутий до країв,
## менший — по центру. Після відпускання миші карта ще ковзає й гальмує; об край ковзання зупиняється.

var view := Rect2()
var content := Vector2.ZERO
var zoom := 1.0
var zoom_min := 1.0
var zoom_max := 1.0
var offset := Vector2.ZERO
## Ковзання після відпускання, px/с екрана.
var velocity := Vector2.ZERO
## Точка вмісту, до якої камера плавно під'їжджає (вибрана клавішами шпилька); [code]null[/code] — нікуди.
var goal: Variant = null


func setup(view_rect: Rect2, content_size: Vector2, min_zoom: float, max_zoom: float) -> void:
	view = view_rect
	content = content_size
	zoom_min = min_zoom
	zoom_max = maxf(min_zoom, max_zoom)
	zoom = clampf(zoom, zoom_min, zoom_max)
	velocity = Vector2.ZERO
	goal = null
	_clamp()


func to_view(p: Vector2) -> Vector2:
	return offset + p * zoom


func to_content(s: Vector2) -> Vector2:
	return (s - offset) / zoom


## Тягнути мишею: вміст іде за курсором 1:1.
func pan(delta: Vector2) -> void:
	goal = null
	offset += delta
	_clamp()


## Масштаб навколо точки вікна [param at]: точка вмісту під нею лишається на місці (поки край не втрутиться).
func zoom_at(at: Vector2, factor: float) -> void:
	var anchor := to_content(at)
	zoom = clampf(zoom * factor, zoom_min, zoom_max)
	offset = at - anchor * zoom
	_clamp()


## Точку вмісту — в центр вікна (наскільки дозволяють краї).
func center_on(p: Vector2) -> void:
	velocity = Vector2.ZERO
	goal = null
	offset = view.get_center() - p * zoom
	_clamp()


## Під'їхати до точки, якщо вона поза вікном зі запасом [param margin].
func reveal(p: Vector2, margin: float) -> void:
	if not view.grow(-margin).has_point(to_view(p)):
		velocity = Vector2.ZERO
		goal = p


## Крок ковзання й під'їзду; true — камера зрушила.
func step(delta: float) -> bool:
	var before := offset
	if goal != null:
		var target: Vector2 = view.get_center() - (goal as Vector2) * zoom
		offset = offset.lerp(target, 1.0 - exp(-UITokens.MAP_FOLLOW_RATE * delta))
		_clamp()
		if offset.distance_to(before) < 0.5:
			goal = null
	elif velocity != Vector2.ZERO:
		offset += velocity * delta
		_clamp()
		velocity *= exp(-UITokens.MAP_GLIDE_FRICTION * delta)
		if velocity.length() < UITokens.MAP_GLIDE_MIN:
			velocity = Vector2.ZERO
	return offset != before


func _clamp() -> void:
	var size := content * zoom
	for axis in 2:
		var lo: float
		var hi: float
		if size[axis] <= view.size[axis]:
			lo = view.position[axis] + (view.size[axis] - size[axis]) / 2.0
			hi = lo
		else:
			lo = view.end[axis] - size[axis]
			hi = view.position[axis]
		var clamped := clampf(offset[axis], lo, hi)
		if clamped != offset[axis]:
			velocity[axis] = 0.0  # м'яка зупинка: об край ковзання гасне, без відскоку
		offset[axis] = clamped
