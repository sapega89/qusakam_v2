extends Control

@onready var btn_simple: Button = $CenterContainer/VBoxContainer/ShowModalButton
@onready var btn_stacked: Button = $CenterContainer/VBoxContainer/ShowStackedButton

func _ready() -> void:
	btn_simple.pressed.connect(_on_simple_pressed)
	btn_stacked.pressed.connect(_on_stacked_pressed)
	
	# Attempt to grab focus initially to test restoration
	btn_simple.grab_focus()

func _on_simple_pressed() -> void:
	var content = _create_test_content("This is a simple modal.\nTab key should be trapped inside.")
	ModalManager.show_modal(content)

func _on_stacked_pressed() -> void:
	var content = _create_test_content("This is the First Modal.\nClick 'Next' to open another one on top.")
	
	var next_btn = Button.new()
	next_btn.text = "Open Second Modal"
	next_btn.pressed.connect(func():
		var content2 = _create_test_content("This is the Second Modal.\nIt is stacked on top.")
		ModalManager.show_modal(content2)
	)
	content.add_child(next_btn)
	content.move_child(next_btn, 1) # Put after label
	
	ModalManager.show_modal(content)

func _create_test_content(msg: String) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 0)
	vbox.add_theme_constant_override("separation", 12)
	
	var lbl = Label.new()
	lbl.text = msg
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)
	
	var input = LineEdit.new()
	input.placeholder_text = "Focusable Input..."
	vbox.add_child(input)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_END
	
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): ModalManager.dismiss_top())
	
	hbox.add_child(close_btn)
	vbox.add_child(hbox)
	
	return vbox
