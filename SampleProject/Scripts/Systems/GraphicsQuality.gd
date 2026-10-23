extends Node

## D554: якість графіки High / Low (Settings → Display → Quality). High — сьогоднішній вигляд. Low знімає дороге для
## слабкої відеокарти (D553: Intel HD Graphics 3000 через ANGLE на Direct3D 11 feature level 10_1):
## - світіння й колірні криві WorldEnvironment (D233);
## - розмиття глибини (depth_blur) і решту повноекранних шейдерів шарів;
## - тіні світла (м'які тіні, якість тіней);
## - найбільші кількості частинок — удвічі.
## Діє на кожен вузол, що входить у дерево (node_added — ще до першого кадру кімнати), і на вже наявні при зміні.
## Перемикання назад відновлює збережені значення вузла, ресурси сцен не змінюються.
## Живе вузлом автолоада DisplayManager; значення приходить із SettingsModule через apply_display_settings().

const QUALITIES: Array[String] = ["high", "low"]
## Повноекранні шейдери шарів, які Low знімає. brightness.gdshader лишається: це налаштування гравця (D428).
const LOW_DROPS_SHADERS: Array[String] = [
	"res://SampleProject/Shaders/depth_blur.gdshader",
	"res://SampleProject/Shaders/background_blur.gdshader",
]
## Від скількох частинок Low ріже кількість навпіл (AmbientDust 36, FireStrike 44, LevelUp 40 …; дрібні іскри лишаються).
const PARTICLES_CUT_FROM := 16

## Збережене значення High на вузлі; матеріал — окремо, бо Light2D і частинки теж CanvasItem.
const _META := &"graphics_quality_high"
const _MAT_META := &"graphics_quality_material"

signal quality_changed(quality: String)

var quality: String = "high"


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


## Low для слабкої вбудованої відеокарти (D553), інакше High. [param adapter] — RenderingServer.get_video_adapter_name():
## "Intel(R) HD Graphics 3000", або рядок ANGLE: "ANGLE (Intel, Intel(R) HD Graphics 3000 Direct3D11 vs_4_1 ps_4_1, …)".
## Low: Intel "HD Graphics" без номера або з чотирицифровим номером до 4000 (Sandy Bridge, Ivy Bridge, Ironlake), і
## будь-який ANGLE на Direct3D 11 рівня 10 (vs_4_0 / vs_4_1) — туди Godot падає, коли OpenGL 3.3 немає.
## Тризначні HD Graphics 510–630 (Skylake і новіші) і все інше — High.
static func default_for_adapter(adapter: String) -> String:
	if adapter.contains("ANGLE") and (adapter.contains("vs_4_0") or adapter.contains("vs_4_1")):
		return "low"
	var at: int = adapter.find("HD Graphics")
	if at < 0 or adapter.contains("Iris") or adapter.contains("UHD"):
		return "high"
	var rest: String = adapter.substr(at + "HD Graphics".length()).strip_edges()
	var digits: String = ""
	for ch: String in rest:
		if not ch.is_valid_int():
			break
		digits += ch
	if digits.is_empty():
		return "low"
	return "low" if digits.length() == 4 and int(digits) <= 4000 else "high"


func apply(value: String) -> void:
	assert(value in QUALITIES, "GraphicsQuality: unknown quality %s" % value)
	if value == quality:
		return
	quality = value
	_walk(get_tree().root)
	quality_changed.emit(quality)


func is_low() -> bool:
	return quality == "low"


func _walk(n: Node) -> void:
	_apply_to(n)
	for c: Node in n.get_children(true):
		_walk(c)


func _on_node_added(n: Node) -> void:
	if quality == "low":
		_apply_to(n)


func _apply_to(n: Node) -> void:
	if n is WorldEnvironment:
		_environment(n as WorldEnvironment)
	elif n is CPUParticles2D or n is GPUParticles2D:
		_particles(n)
	elif n is Light2D:
		_light(n as Light2D)
	if n is CanvasItem:
		_material(n as CanvasItem)


## Ресурс Environment спільний для всіх екземплярів сцени, тож Low ставить копію, а High повертає оригінал.
func _environment(we: WorldEnvironment) -> void:
	if is_low():
		if we.has_meta(_META) or we.environment == null:
			return
		we.set_meta(_META, we.environment)
		var env: Environment = we.environment.duplicate()
		env.glow_enabled = false
		env.adjustment_enabled = false
		we.environment = env
	elif we.has_meta(_META):
		we.environment = we.get_meta(_META)
		we.remove_meta(_META)


## CPUParticles2D і GPUParticles2D не мають спільного предка з amount — тому get/set.
func _particles(p: Node) -> void:
	var amount: int = p.get(&"amount")
	if is_low():
		if p.has_meta(_META) or amount < PARTICLES_CUT_FROM:
			return
		p.set_meta(_META, amount)
		p.set(&"amount", ceili(amount / 2.0))
	elif p.has_meta(_META):
		p.set(&"amount", p.get_meta(_META))
		p.remove_meta(_META)


func _light(light: Light2D) -> void:
	if is_low():
		if light.has_meta(_META) or not light.shadow_enabled:
			return
		light.set_meta(_META, light.shadow_enabled)
		light.shadow_enabled = false
	elif light.has_meta(_META):
		light.shadow_enabled = light.get_meta(_META)
		light.remove_meta(_META)


## Матеріал з дорогим шейдером знімається з вузла (вузол малюється звичайним шейдером), High повертає його.
func _material(ci: CanvasItem) -> void:
	if is_low():
		var shader_material := ci.material as ShaderMaterial
		if shader_material == null or shader_material.shader == null:
			return
		if not shader_material.shader.resource_path in LOW_DROPS_SHADERS:
			return
		ci.set_meta(_MAT_META, shader_material)
		ci.material = null
	elif ci.has_meta(_MAT_META):
		ci.material = ci.get_meta(_MAT_META)
		ci.remove_meta(_MAT_META)
