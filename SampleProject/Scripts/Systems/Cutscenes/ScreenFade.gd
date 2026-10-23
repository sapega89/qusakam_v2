extends RefCounted
class_name ScreenFade

## Затемнення екрана для кат-сцен (design/cutscene_plan.md). Один чорний шар у корені дерева,
## нижче за діалог (шар 100), тож репліки читаються поверх чорного.
##   await ScreenFade.to_black(self)   …   await ScreenFade.from_black(self)
## Зміна кімнати й старт гри з меню (D434) гасять і запалюють той самий шар, коротше — UITokens.ROOM_FADE_TIME.

const LAYER := 90
const NODE_NAME := &"ScreenFade"


static func to_black(host: Node, time: float = UITokens.FADE_TIME) -> void:
	await _fade(host, 1.0, time)


static func from_black(host: Node, time: float = UITokens.FADE_TIME) -> void:
	await _fade(host, 0.0, time)
	_overlay(host).get_parent().queue_free()


## Чорний шар є (екран темний або темніє чи світлішає).
static func is_on(host: Node) -> bool:
	return host.get_tree().root.has_node(NodePath(NODE_NAME))


## Екран уже повністю чорний — гасити нема чого.
static func is_black(host: Node) -> bool:
	return is_on(host) and is_equal_approx(_overlay(host).color.a, 1.0)


static func _fade(host: Node, alpha: float, time: float) -> void:
	var rect := _overlay(host)
	var tween := rect.create_tween()
	tween.tween_property(rect, "color:a", alpha, time)
	await tween.finished


static func _overlay(host: Node) -> ColorRect:
	var root := host.get_tree().root
	if root.has_node(NodePath(NODE_NAME)):
		return root.get_node(NodePath(NODE_NAME)).get_child(0)
	var layer := CanvasLayer.new()
	layer.name = NODE_NAME
	layer.layer = LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	root.add_child(layer)
	return rect
