extends PanelContainer

const OFFSET: Vector2 = Vector2.ONE * 60
var opacity_tween: Tween = null
var item_database: Node = null

func _ready() -> void:
	hide()
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_item_database"):
			item_database = service_locator.get_item_database()

func _input(event: InputEvent):
	# FIX: Проверяем тип события и используем event.position вместо get_global_mouse_position()
	if not visible:
		return
	if event is InputEventMouseMotion:
		global_position = event.position + OFFSET

func toggle(on: bool):
	if on:
		show()
		modulate.a = 0.0
		tween_opacity(1.0)
	else:
		modulate.a = 1.0
		await tween_opacity(0.0).finished
		hide()

func tween_opacity(to: float):
	if opacity_tween: opacity_tween.kill()
	opacity_tween = get_tree().create_tween()
	opacity_tween.tween_property(self, 'modulate:a', to, 0.3)
	return opacity_tween

func update_item_info(item_id: String, show_price: bool = false) -> void:
	if not item_database:
		if Engine.has_singleton("ServiceLocator"):
			var service_locator = Engine.get_singleton("ServiceLocator")
			if service_locator and service_locator.has_method("get_item_database"):
				item_database = service_locator.get_item_database()
	
	if not item_database:
		return
	
	var item = item_database.get_item(item_id)
	if item.is_empty():
		return

	var item_name = item_database.get_item_name(item_id, "en")
	var item_desc = item_database.get_item_description(item_id, "en")
	
	var text = "[b]%s[/b]\n%s" % [item_name, item_desc]
	
	if show_price:
		var price = item.get("buy_price", 0)
		text += "\n\nPrice: %d" % int(price)
		
	var label = get_node_or_null("RichTextLabel")
	if label:
		label.text = text
	else:
		print("📋 Tooltip: RichTextLabel node missing!") # DEBUG PRINT
	
	toggle(true)

