extends Control

## Смужка боса вгорі екрана (D301, D302): назва, HP і під ним шкала стійкості (D777, poise_bar.tscn). Figma не має кадру смужки боса (figma_coverage §1) —
## вигляд з теми (HpBar, UILabel), розкладка в boss_health_bar.tscn. Сховано, поки бос не вступив у бій.

@onready var _name: Label = %BossName
@onready var _bar: ProgressBar = %BossHp
@onready var _poise: Control = %BossPoise


func track(boss: Node) -> void:
	_name.text = boss.display_name
	_bar.max_value = boss.Max_Health
	_bar.value = boss.current_health
	boss.health_changed.connect(func(health: int, max_health: int, _animate: bool) -> void:
		_bar.max_value = max_health
		_bar.value = health)
	boss.entity_died.connect(hide)
	_poise.track(boss)
