extends SceneTree

## Іконки вмінь (D604): у кожного вміння є іконка, вона вантажиться; тон за видом (D602); слот панелі її малює.
##   godot --headless --path . --script res://SampleProject/UI/verify_skill_icons.gd

var fails: Array[String] = []


func ck(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		fails.append(label)


func _initialize() -> void:
	await process_frame
	var db: Node = root.get_node("SkillDatabase")
	print("=== [1] every skill has an icon that loads")
	var skills: Array = db.get_all_skills()
	var missing: Array[String] = []
	for def: SkillDefinition in skills:
		var tex: Texture2D = load(def.icon) if def.icon != "" else null
		if tex == null or tex.get_width() < 64:
			missing.append(def.id)
	ck(skills.size() > 0 and missing.is_empty(), "all %d skills have a loadable icon (missing: %s)" % [skills.size(), missing])

	print("=== [2] the tint follows the kind")
	ck(db.get_skill("fire_strike").icon_tint() == UITokens.SKILL_ICON_ACTIVE, "an active is ivory")
	ck(db.get_skill("toughness").icon_tint() == UITokens.SKILL_ICON_PASSIVE, "a passive is steel-blue")
	ck(db.get_skill("judgement_of_the_sky").icon_tint() == UITokens.SKILL_ICON_ULTIMATE, "an ultimate is gold")

	print("=== [3] the hotbar slot draws the equipped skill's icon")
	var sl: Node = root.get_node("ServiceLocator")
	var gm: Node = sl.get_game_manager()
	var sm: Node = sl.get_skill_manager()
	var R = load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd").Result
	gm.player_state["unlocked_skills"] = ["healing_palm"]
	gm.player_state["equipped_skills"] = ["", "", "", ""]
	ck(sm.equip_skill("healing_palm", 0) == R.OK, "healing_palm equips into slot 1")
	var hotbar: Control = load("res://SampleProject/UI/Components/skill_hotbar.tscn").instantiate()
	root.add_child(hotbar)
	hotbar.set_process(false)  # слот асисту читає прапорці Game, а тут хотбар без гри
	hotbar.refresh()
	var art: TextureRect = hotbar._slots[0].get_node("Slot/IconCenter/Icon/Art")
	ck(art.texture != null and art.texture.resource_path.ends_with("healing_palm.png"), "slot 1 shows healing_palm.png")
	ck(art.self_modulate == UITokens.SKILL_ICON_ACTIVE, "slot 1 icon is tinted as an active")
	var empty_art: TextureRect = hotbar._slots[1].get_node("Slot/IconCenter/Icon/Art")
	ck(empty_art.texture == null, "an empty slot draws no icon")
	hotbar.queue_free()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()
