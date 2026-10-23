extends Node2D

## Разовий ефект асисту компаньйона (D465): частинки-діти стартують разом, спрайти «Flash…» (адитивне світіння,
## кільце, дуга) ростуть у flash_grow разів і гаснуть за flash_time; увесь ефект зсувається на drift і зникає через life.
## Сцени — Scenes/FX/Companions/*.tscn, ставить CompanionAssist (scale.x = ±1 — у бік удару).

@export var life := 0.6
@export var flash_grow := 2.0
@export var flash_time := 0.18
## Зсув усього ефекту за life, px (вітрова дуга охоронця летить уперед).
@export var drift := Vector2.ZERO


func _ready() -> void:
	add_to_group(&"assist_fx")
	for child in get_children():
		if child is CPUParticles2D:
			child.restart()
		elif child.name.begins_with("Flash"):
			var flash := create_tween().set_parallel()
			flash.tween_property(child, ^"scale", child.scale * flash_grow, flash_time).set_ease(Tween.EASE_OUT)
			flash.tween_property(child, ^"modulate:a", 0.0, flash_time).set_ease(Tween.EASE_IN)
	if drift != Vector2.ZERO:
		create_tween().tween_property(self, ^"position", drift * Vector2(signf(scale.x), 1.0), life).as_relative() \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await get_tree().create_timer(life, false).timeout
	queue_free()
