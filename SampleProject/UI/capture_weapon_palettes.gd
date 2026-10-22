extends SceneTree

## Палітри металу зброї (BACKLOG 42): рядки — палітри weapon_palettes.json (залізо = ключ, мідь, срібло, кристал),
## стовпці — кадри героя кожного типу зброї через той самий шейдер, що на героєві. Потрібне вікно:
##   godot --path . --resolution 1280x720 --script res://SampleProject/UI/capture_weapon_palettes.gd -- <out_dir>
## Файл: <out_dir>/weapon_palettes.png

const FRAMES := [
	"sword/CombatIdle/1", "sword/Attack1/2", "dagger/Attack3/2", "mace/Attack1/2", "halberd/Attack1/2",
	"dual/Attack1/2", "dual/Attack4/2",
]
const SCALE := 2.0
const CELL := 96.0 * SCALE

func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/weapon_palettes.json"))
	var shader: Shader = load("res://SampleProject/Shaders/weapon_palette.gdshader")
	var bg := ColorRect.new()
	bg.color = Color("#3a2f2a")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var row := 0
	for id in data.palettes:
		var entry: Dictionary = data.palettes[id]
		var label := Label.new()
		label.text = id
		label.position = Vector2(8, 16 + row * (CELL * 0.9) + CELL * 0.4)
		root.add_child(label)
		for col in FRAMES.size():
			var sprite := Sprite2D.new()
			sprite.texture = load("res://SampleProject/Sprites/Player/Weapons/%s.png" % FRAMES[col])
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = Vector2(SCALE, SCALE)
			sprite.centered = false
			sprite.position = Vector2(64 + col * (CELL * 0.88), row * (CELL * 0.9) - 20)
			var material := ShaderMaterial.new()
			material.shader = shader
			material.set_shader_parameter(&"active", true)
			var params := [&"light", &"mid", &"dark"]
			for i in 3:
				material.set_shader_parameter(StringName("key_" + params[i]), Color(data.key[i]))
				material.set_shader_parameter(StringName("to_" + params[i]), Color(entry.colors[i]))
			material.set_shader_parameter(&"shimmer", entry.shimmer)
			material.set_shader_parameter(&"glow", entry.glow)
			if entry.has("glow_color"):
				material.set_shader_parameter(&"glow_color", Color(entry.glow_color))
			sprite.material = material
			root.add_child(sprite)
		row += 1
	for i in 30: await process_frame
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png(out_dir.path_join("weapon_palettes.png"))
	print("saved ", out_dir.path_join("weapon_palettes.png"))
	quit()
