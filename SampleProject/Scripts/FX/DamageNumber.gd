extends Node2D

## Одна цифра урону (D66): з'являється над тілом, піднімається на DAMAGE_NUMBER_RISE і гасне за DAMAGE_NUMBER_TIME.
## Крит (D393) спершу більший і стискається. Розмітка — Scenes/FX/DamageNumber.tscn, хто й коли — DamageNumbers.

@onready var label: Label = $Label


## [param text] — число або слово; колір і розмір шрифту — з UITokens (DamageNumbers обирає).
func pop(text: String, color: Color, font_size: int, critical: bool) -> void:
	label.text = text
	label.label_settings.font_color = color
	label.label_settings.font_size = font_size
	label.label_settings.outline_color = UITokens.DAMAGE_NUMBER_OUTLINE
	label.label_settings.outline_size = UITokens.DAMAGE_NUMBER_OUTLINE_SIZE
	var tween := create_tween().set_parallel()
	tween.tween_property(self, ^"position:y", position.y - UITokens.DAMAGE_NUMBER_RISE, UITokens.DAMAGE_NUMBER_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, ^"modulate:a", 0.0, UITokens.DAMAGE_NUMBER_TIME / 2.0).set_delay(UITokens.DAMAGE_NUMBER_TIME / 2.0)
	if critical:
		var base := scale
		scale = base * UITokens.DAMAGE_NUMBER_CRIT_POP
		tween.tween_property(self, ^"scale", base, UITokens.DAMAGE_NUMBER_POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(queue_free)
