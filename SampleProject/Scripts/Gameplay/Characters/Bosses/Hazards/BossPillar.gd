extends Node2D

## Стовп вогню боса (D302): спершу мітка на підлозі (MARK_TIME — встигнути відійти), потім вогонь FIRE_TIME;
## герой, що стоїть на мітці (по x у межах width, на тій самій підлозі), дістає шкоду один раз. Джерело шкоди — сам
## стовп (B133): його не заблокувати й не парирувати. Таймери стоять на паузі (B135).

signal finished

const MARK_TIME := 0.6
const FIRE_TIME := 0.5
## Герой на тій самій підлозі: його центр не вище за низ стовпа більш ніж на стільки px.
const HEIGHT := 150.0

## Ширина, у якій стовп б'є (картинка в сцені намальована під 72 px, D302).
var width := 72.0
var damage := 10


func _ready() -> void:
	$AnimationPlayer.play(&"mark")
	await get_tree().create_timer(MARK_TIME, false).timeout
	$AnimationPlayer.play(&"fire")
	var hero: Node2D = GameGroups.get_player()
	var dy := global_position.y - hero.global_position.y
	if absf(hero.global_position.x - global_position.x) <= width / 2.0 and dy >= -HEIGHT * 0.25 and dy <= HEIGHT:
		hero.take_damage(damage, self)
	await get_tree().create_timer(FIRE_TIME, false).timeout
	finished.emit()
	queue_free()
