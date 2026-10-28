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
