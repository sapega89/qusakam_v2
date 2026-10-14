extends SceneTree

## Візуальні знімки slice 2 для порівняння з Figma 153:1289 / 153:1760 / 164:1302 (вікно обов'язкове):
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_shop.gd
## Золото для знімка додається лише в пам'ять — нічого не зберігається.


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	var sl: Node = root.get_node("ServiceLocator")
	var inv: Node = sl.get_inventory_manager()
	inv.add_item("coin", 14820)
	inv.add_item("potion", 3)

	var j := JSON.new()
	j.parse(FileAccess.open("res://SampleProject/Resources/Data/merchants.json", FileAccess.READ).get_as_text())
	var shop: Control = load("res://SampleProject/Scenes/Shop/shop_menu.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	shop.setup_shop(j.data.merchants.default.items)
	await _save("res://design/shots/shop_buy_1920.png")
	shop._switch_mode("sell")
	await _save("res://design/shots/shop_sell_1920.png")
	shop._switch_mode("buy")
	await process_frame
	shop.get_rows()[2].pressed.emit()
	await _save("res://design/shots/shop_buy_confirm_1920.png")
	shop.queue_free()
	var layer = sl.get_ui_manager().get_modal_layer()
	if layer and layer.active_modal:
		layer._clear_modal()

	var bg := ColorRect.new()
	bg.color = UITokens.SHOP_PANEL_BG
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var merchant: Node2D = load("res://SampleProject/Scenes/Gameplay/Objects/NPCs/merchant.tscn").instantiate()
	merchant.position = Vector2(900, 600)
	merchant.talk_dialogue = "preview"  # лише для знімка: показати повний склад меню
	world.add_child(merchant)
	await process_frame
	merchant.interactable.interacted.emit()
	await _save("res://design/shots/npc_menu_merchant_1920.png")
	quit(0)


func _save(path: String) -> void:
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("capture saved: %s" % path)
