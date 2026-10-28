extends HBoxContainer

## Рядок значків стану (D599: «вони видні над ворогами і в панелі героя»): кровотеча, підпал, прокляття, оглушення —
## `Assets/UI/Icons/skills/state_*.png`. Один компонент на обох: над ворогом — у poise_bar.tscn над шкалою стійкості
## (px світу), у панелі героя — player_vitals_panel.tscn (масштаб HUD). Розкладка й розміри — у status_row.tscn;
## що ввімкнено, вирішує власник (poise_bar.gd, player_vitals_panel.gd), тут лише показ.

## Стани в порядку значків у рядку (імена вузлів status_row.tscn).
const STATES: Array[StringName] = [&"Bleeding", &"Burning", &"Cursed", &"Stunned"]


func set_state(state: StringName, on: bool) -> void:
	get_node(NodePath(String(state))).visible = on


func is_on(state: StringName) -> bool:
	return get_node(NodePath(String(state))).visible


func any_on() -> bool:
	return STATES.any(is_on)


func clear() -> void:
	for state in STATES:
		set_state(state, false)
	for buff in _buffs():
		buff.queue_free()


## Стійки й баффи героя (v2 зріз 5, D-sv2s1): значок навички [param skill_id] ([param icon]) після станів, поки бафф діє.
## Значок — копія вузла BuffTemplate з status_row.tscn.
func set_buff(skill_id: String, icon: Texture2D, on: bool) -> void:
	var node := get_node_or_null(NodePath("Buff_" + skill_id))
	if not on:
		if node != null:
			node.queue_free()
		return
	if node == null:
		node = $BuffTemplate.duplicate()
		node.name = "Buff_" + skill_id
		add_child(node)
	node.texture = icon
	node.visible = true


## Значки баффів, що зараз у рядку (без вузлів, що вже зникають).
func buff_ids() -> Array[String]:
	var out: Array[String] = []
	for buff in _buffs():
		out.append(String(buff.name).trim_prefix("Buff_"))
	return out


func _buffs() -> Array[Node]:
	return get_children().filter(func(child: Node) -> bool: return String(child.name).begins_with("Buff_") and not child.is_queued_for_deletion())
