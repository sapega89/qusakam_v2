extends VBoxContainer
class_name UILootFeed

## Стрічка здобичі на HUD (BACKLOG 33): що герой підібрав із переможеного моба (EventBus.loot_picked_up) —
## тост «<предмет> × <N>» з іконкою. Нові — згори, під рядком валюти; той самий предмет, поки його тост живий,
## додається до нього (монети з одного моба падають по одній) і подовжує його. Тост тримається LOOT_TOAST_HOLD с і
## гасне; більше LOOT_FEED_MAX — найстаріший іде одразу. Вигляд — шаблон Toast у сцені (PanelContainer теми HUD).
## Дарунки й нагороди сюди не йдуть — їм модалка «You obtained:» (UIManager.show_obtained).

@onready var _template: PanelContainer = %Toast


func _ready() -> void:
	add_to_group(&"loot_feed")
	_template.visible = false
	EventBus.loot_picked_up.connect(add_loot)


func add_loot(item_id: String, amount: int) -> void:
	var toast: PanelContainer = _live_toast(item_id)
	if toast == null:
		toast = _template.duplicate() as PanelContainer
		toast.set_meta(&"item_id", item_id)
		toast.set_meta(&"amount", 0)
		add_child(toast)
		move_child(toast, 1)  # 0 — шаблон
		toast.visible = true
		toast.modulate.a = 0.0
		var icon: TextureRect = toast.get_node(^"Row/Icon")
		icon.texture = _items().get_item_icon(item_id)
		_trim()
	var total: int = int(toast.get_meta(&"amount")) + amount
	toast.set_meta(&"amount", total)
	(toast.get_node(^"Row/Text") as Label).text = "%s × %d" % [_items().get_item_name(item_id), total]
	_play(toast)


## Живі тости, найновіший першим.
func toasts() -> Array[PanelContainer]:
	var out: Array[PanelContainer] = []
	for child: Node in get_children():
		if child != _template and not child.is_queued_for_deletion():
			out.append(child as PanelContainer)
	return out


func _live_toast(item_id: String) -> PanelContainer:
	for toast: PanelContainer in toasts():
		if toast.get_meta(&"item_id") == item_id:
			return toast
	return null


func _trim() -> void:
	var live: Array[PanelContainer] = toasts()
	for i: int in range(UITokens.LOOT_FEED_MAX, live.size()):
		live[i].queue_free()


func _play(toast: PanelContainer) -> void:
	if toast.has_meta(&"tween"):
		(toast.get_meta(&"tween") as Tween).kill()
	var tween: Tween = toast.create_tween()
	tween.tween_property(toast, ^"modulate:a", 1.0, UITokens.LOOT_TOAST_FADE)
	tween.tween_interval(UITokens.LOOT_TOAST_HOLD)
	tween.tween_property(toast, ^"modulate:a", 0.0, UITokens.LOOT_TOAST_FADE)
	tween.tween_callback(toast.queue_free)
	toast.set_meta(&"tween", tween)


func _items() -> Node:
	return ServiceLocator.get_item_database()
