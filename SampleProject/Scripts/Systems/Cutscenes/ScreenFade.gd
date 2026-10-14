extends RefCounted
class_name ScreenFade

## Затемнення екрана для кат-сцен (design/cutscene_plan.md). Один чорний шар у корені дерева,
## нижче за діалог (шар 100), тож репліки читаються поверх чорного.
##   await ScreenFade.to_black(self)   …   await ScreenFade.from_black(self)

const LAYER := 90
const NODE_NAME := &"ScreenFade"


static func to_black(host: Node) -> void:
	await _fade(host, 1.0)


static func from_black(host: Node) -> void:
	await _fade(host, 0.0)
	_overlay(host).get_parent().queue_free()


static func _fade(host: Node, alpha: float) -> void:
	var rect := _overlay(host)
	var tween := rect.create_tween()
	tween.tween_property(rect, "color:a", alpha, UITokens.FADE_TIME)
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
