extends Button

## Рядок списку (варіація теми ListRow / ListSubRow): вибраний (pressed) рядок під фокусом.
## Стилбокс "focus" не знає, що рядок натиснутий: золоте кільце лягало на золоту заливку й зникало (B90).
## Тут поверх малюється біле кільце теми "focus_selected" — правило D329 для акцентної заливки.

func _draw() -> void:
	if has_focus() and button_pressed:
		get_theme_stylebox(&"focus_selected").draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
