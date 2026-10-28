extends "res://SampleProject/UI/verify_camera_transitions.gd"

## TIMEOUT: 900
## SERIAL
## Камера згладжується в кадрах процесу (реальний delta), а герой рухається кроками фізики: рух камери за кадр
## міряється лише без сусідніх тестів (B186; під J=4 AlchemistStore давав 41.7 px).

## B153: камера всередині кімнат — з кожної клітинки кожної кімнати біг праворуч і ліворуч зі стрибком, падіння з
## уступів; кадр, де камера рушила більш ніж на 12 px більше за героя або змінились межі, — провал.
## Розділ [3] verify_camera_transitions.gd, окремим файлом: разом вони довші за 180 с run_verify.sh.
##   godot --headless --path . --script res://SampleProject/UI/verify_camera_rooms.gd


func _sections() -> String:
	return "3"
