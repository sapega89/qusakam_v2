extends Button

## Світна кнопка нових очок на HUD (D723, як у Diablo II; Sapega: «просто на екрані з'являється підсвічена кнопка,
## куди натискаєш і переміщуєшся в меню»): «+N», підпис і клавіша, що відкриває вкладку. Розкладка — у сцені,
## вигляд — тема (NewPointsButton, NewPoints*), сяйво — спільний points_glow.tscn.

## Ключ підпису («New skills» / «New attributes»), перекладається.
@export var caption_key: String = ""

@onready var _count: Label = %Count
@onready var _caption: Label = %Caption
@onready var _key_badge: PanelContainer = %KeyBadge
@onready var _key: Label = %Key
@onready var _glow: Control = %Glow


## [param count] очок чекає; [param key_text] — кнопка, що відкриває вкладку («K», «D-pad left»), порожньо — без неї.
func show_points(count: int, key_text: String) -> void:
	visible = count > 0
	_count.text = "+%d" % count
	_caption.text = tr(caption_key)
	_key_badge.visible = key_text != ""
	_key.text = key_text
	_glow.set_count(count)


func is_glowing() -> bool:
	return visible and _glow.is_glowing()


func key_text() -> String:
	return _key.text if _key_badge.visible else ""
