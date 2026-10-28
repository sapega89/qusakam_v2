extends "res://SampleProject/Scripts/FX/OathSkillFX.gd"

## Ефект навичок контролю й добивання (v2 зріз 6б, D878): поки арт-лінія (зріз 7) не намалювала їхні кадри, кожна
## позичає charge / release наявної навички клятви — та сама розкладка й маркери, що в OathSkill.tscn. Що бракує — у
## design/cloud_reports/skills-v2-control-b.md («For the art lane»).

## id → [чиї кадри (Assets/FX/Skills/<id>/), маркер вивільнення, край текстури на маркері] (як OathSkillFX.RELEASE_PIN).
const BORROW := {
	"chain_of_night": ["withering_grasp", &"Hand", &"left"],  # темна рука — замість ланцюга
	"sand_veil": ["second_wind", &"Hand", &"left"],  # вихор — замість жмені піску
	"dread_howl": ["searing_hex", &"Centre", &"center"],  # темний спалах — замість хвилі виття
	"radiant_flare": ["dervish_whirl", &"Centre", &"center"],  # кільце навколо героя — замість спалаху світла
	"night_reaper": ["eclipse_cleave", &"ArcEdge", &"right"],  # темний серп
	"soul_harvest": ["eclipse_cleave", &"ArcEdge", &"right"],  # темний серп — замість коси жнеця
}


func release() -> void:
	var pin: Array = BORROW[skill.id]
	var size: Vector2 = _sprite.sprite_frames.get_frame_texture(&"release", 0).get_size()
	_sprite.position = (get_node(NodePath(pin[1])) as Marker2D).position
	_sprite.offset = {&"right": Vector2(-size.x / 2.0, 0), &"left": Vector2(size.x / 2.0, 0),
			&"bottom": Vector2(0, -size.y / 2.0), &"center": Vector2.ZERO}[pin[2]]
	_sprite.play(&"release")


func _add(frames: SpriteFrames, animation: StringName, count: int, fps: float) -> void:
	frames.add_animation(animation)
	frames.set_animation_loop(animation, false)
	frames.set_animation_speed(animation, fps)
	for i in count:
		frames.add_frame(animation, load(FRAMES_DIR % [BORROW[skill.id][0], animation, i + 1]))
