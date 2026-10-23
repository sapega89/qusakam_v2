extends SceneTree

## Іконки вмінь на панелі (D604) у справжньому вікні: активне, ще одне активне, ультимейт, порожній слот.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_skill_icons.gd
## Пише design/shots/skill_icons_hotbar.png.


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	var sl: Node = root.get_node("ServiceLocator")
	var gm: Node = sl.get_game_manager()
	var sm: Node = sl.get_skill_manager()
	gm.player_state["unlocked_skills"] = ["healing_palm", "fire_strike", "judgement_of_the_sky"]
	gm.player_state["equipped_skills"] = ["", "", "", ""]
	sm.set_max_sp(100)
	sm.restore_sp(100)
	sm.equip_skill("healing_palm", 0)
	sm.equip_skill("fire_strike", 1)
	sm.equip_skill("judgement_of_the_sky", 2)
	var bg := ColorRect.new()
	bg.color = Color("2a2433")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var hotbar: Control = load("res://SampleProject/UI/Components/skill_hotbar.tscn").instantiate()
	root.add_child(hotbar)
	hotbar.set_process(false)  # слот асисту читає прапорці Game, а тут хотбар без гри
	hotbar.position = Vector2(760, 480)
	hotbar.refresh()
	for i in 10:
		await process_frame
	var rect := Rect2i(Vector2i(hotbar.position) - Vector2i(20, 20), Vector2i(hotbar.size) + Vector2i(40, 40))
	root.get_texture().get_image().get_region(rect).save_png("res://design/shots/skill_icons_hotbar.png")
	quit()
