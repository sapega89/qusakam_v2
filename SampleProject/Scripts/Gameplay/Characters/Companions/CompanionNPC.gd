extends Node2D

## Компаньйон чекає в лабораторії біля свого тригера (D230): видно, з ким розмовляєш. Після розмови
## (Laboratory → join) підбігає до героя й зникає — тепер він у загоні й приходить на кнопку асисту.
## Якщо вже в загоні (сейв посеред лабораторії) — його тут немає. Вузли й кадри ставить
## Scripts/Tools/build_laboratory.gd; кадри спокою — idle, бігу — run (і в кішки Алісії теж).

const JOIN_RUN_TIME := 0.45
const JOIN_FADE_TIME := 0.3

@export var companion_id := ""


func _ready() -> void:
	if ServiceLocator.get_companion_manager().is_unlocked(companion_id):
		queue_free()
		return
	for sprite in _sprites():
		sprite.play(&"idle")


## Підбігає до [param hero] і зникає.
func join(hero: Node2D) -> void:
	var dir := signf(hero.global_position.x - global_position.x)
	for sprite in _sprites():
		sprite.flip_h = dir < 0.0
		sprite.play(&"run")
	var tween := create_tween()
	tween.tween_property(self, ^"global_position:x", hero.global_position.x - dir * 30.0, JOIN_RUN_TIME)
	tween.tween_property(self, ^"modulate:a", 0.0, JOIN_FADE_TIME)
	tween.tween_callback(queue_free)


func _sprites() -> Array[Node]:
	return find_children("*", "AnimatedSprite2D", false)
