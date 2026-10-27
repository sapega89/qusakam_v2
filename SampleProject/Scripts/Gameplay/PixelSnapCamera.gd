extends Camera2D

## B180 (depth critique №7): Parallax2D при snap_2d_transforms_to_pixel сам округлює свій зсув до цілого пікселя світу,
## а згладжена камера стоїть між пікселями — тож кожен шар (навіть небо ×0) щокадру стрибав на ±1 піксель світу
## відносно підлоги. Тут, після внутрішнього оновлення Camera2D у тому ж кадрі (той самий вузол: спершу
## INTERNAL_PROCESS), лівий верхній кут кадру доводиться до цілого пікселя світу — і для полотна, і для кожного
## шару: його screen_offset — те, що дає шарам сама Camera2D, «центр кадру − розмір вікна / 2», з округленого кута.
## Підлога й шари рухаються однаковими цілими кроками, нерухоме лишається нерухомим.

var _planes: Array[Parallax2D] = []


func _ready() -> void:
	for p: Node in get_tree().root.find_children("*", "Parallax2D", true, false):
		_planes.append(p)
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)


func _on_node_added(n: Node) -> void:
	if n is Parallax2D:
		_planes.append(n)


func _on_node_removed(n: Node) -> void:
	if n is Parallax2D:
		_planes.erase(n)


func _process(_delta: float) -> void:
	if not is_current():
		return
	var viewport := get_viewport()
	var canvas := viewport.canvas_transform
	var top_left: Vector2 = (-canvas.origin / zoom).round()
	canvas.origin = -top_left * zoom
	viewport.canvas_transform = canvas
	var size: Vector2 = viewport.get_visible_rect().size
	var screen_offset: Vector2 = top_left + size / zoom / 2.0 - size / 2.0
	for p: Parallax2D in _planes:
		if not p.ignore_camera_scroll and p.get_viewport() == viewport:
			p.screen_offset = screen_offset
