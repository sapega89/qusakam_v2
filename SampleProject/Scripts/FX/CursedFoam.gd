extends Node2D

## Проклята піна (D653): сяйні сині краплі (біле ядро, що синіє й гасне) капають з пащі — ефект, а не частина арту, тож пасує будь-якому проклятому
## виду (enemy_variety.json kinds.<id>.foam, DefaultEnemy._add_foam). Дитина Sprite2D ворога: росте з розміром і
## дзеркалиться за flip_h; краплі живуть у світі (local_coords off), тож відстають, коли звір біжить. Шар — як у
## ефектів влучання (z 250, HitImpact).

## Паща в пікселях кадру від його центру, обличчям праворуч.
var mouth := Vector2.ZERO

@onready var _sprite: Sprite2D = get_parent()


func _process(_delta: float) -> void:
	# Центр намальованого кадру — з offset спрайта (і його нахилом, EnemyView) та дзеркалом
	position = _sprite.get_rect().get_center() + Vector2(-mouth.x if _sprite.flip_h else mouth.x, mouth.y)
