extends ProgressBar

## Смуга досвіду на всю ширину екрана, по нижньому краю (D552). Figma: UI/HUD/XP Bar (515:6662).
## Без підпису й чисел («без підпису, що це XP, всі і так знають»): лише частка XP до наступного рівня.
## На найвищому рівні (D541) — повна. Вигляд — тип теми HudXpBar (UITokens), без текстур. Значення — XPManager.


func _ready() -> void:
	add_to_group(&"hud_xp_bar")
	var xp: Node = ServiceLocator.get_xp_manager()
	xp.xp_gained.connect(func(_amount: int, _total: int) -> void: refresh())
	xp.level_up.connect(func(_new: int, _old: int) -> void: refresh())
	refresh()


func refresh() -> void:
	var xp: Node = ServiceLocator.get_xp_manager()
	max_value = 1.0
	value = xp.get_xp_percentage()  # на капі — 1.0 (XPManager)
