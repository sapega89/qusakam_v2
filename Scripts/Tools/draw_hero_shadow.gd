extends SceneTree

## Тінь героя (hero-shadow, «як в MK1»): піксельний овал 26×6 із трьох сходинок прозорості, майже чорний
## (темніший за контур героя: на темній підлозі приміщень контур не видно). У грі ×1.5, nearest; загальну прозорість і розмір дає HeroShadow.gd.
##   godot --headless --path . --script res://Scripts/Tools/draw_hero_shadow.gd

const SIZE := Vector2i(26, 6)
const DARK := Color8(16, 10, 16)
## [межа (x/rx)² + (y/ry)², прозорість]: ядро, середина, край.
const STEPS := [[0.45, 1.0], [0.75, 0.8], [1.0, 0.55]]
const OUT := "res://SampleProject/Sprites/Player/Shadow/shadow.png"

func _initialize() -> void:
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var half := Vector2(SIZE) / 2.0
	for y in SIZE.y:
		for x in SIZE.x:
			var d := Vector2((x + 0.5 - half.x) / half.x, (y + 0.5 - half.y) / half.y).length_squared()
			for step: Array in STEPS:
				if d <= step[0]:
					image.set_pixel(x, y, Color(DARK, step[1]))
					break
	image.save_png(ProjectSettings.globalize_path(OUT))
	print("drawn ", OUT)
	quit()
