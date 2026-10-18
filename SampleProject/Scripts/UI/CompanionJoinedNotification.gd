extends Control

## «X приєднався до загону» (D230): коли компаньйона відкрито в лабораторії (EventBus.companion_joined).
## Вигляд — як сповіщення про рівень (спільна панель Resources/UI/notification_panel.tres).

const SHOW_TIME := 2.5

@onready var _name: Label = %NameLabel
## Попереднє сповіщення ще гасне — його анімацію зупиняємо, інакше вона сховає нове.
var _tween: Tween


func _ready() -> void:
	visible = false
	EventBus.companion_joined.connect(_on_companion_joined)


func _on_companion_joined(companion_id: String) -> void:
	_name.text = "%s joined the party" % CompanionManager.NAMES[companion_id]
	visible = true
	modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, ^"modulate:a", 1.0, 0.3)
	_tween.tween_interval(SHOW_TIME)
	_tween.tween_property(self, ^"modulate:a", 0.0, 0.4)
	_tween.tween_callback(hide)
