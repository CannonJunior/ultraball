extends Control

const C_BG   := Color(0.039, 0.047, 0.078)
const C_GOLD := Color(1.000, 0.796, 0.239)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()

func _process(_delta: float) -> void:
	visible = MatchState.is_paused

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var card := _make_panel(C_BG)
	card.anchor_left = 0.5; card.anchor_right = 0.5
	card.anchor_top = 0.5; card.anchor_bottom = 0.5
	card.offset_left = -175; card.offset_right = 175
	card.offset_top = -120; card.offset_bottom = 120
	add_child(card)

	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 28)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", C_GOLD)
	vbox.add_child(title)

	var resume_btn := _make_button("Resume")
	resume_btn.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_btn)

	var exit_btn := _make_button("Exit to Main Menu")
	exit_btn.pressed.connect(_on_exit_pressed)
	vbox.add_child(exit_btn)

func _make_panel(bg_color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = bg_color
	sbox.border_color = Color(1, 1, 1, 0.09)
	sbox.border_width_left = 1; sbox.border_width_right = 1
	sbox.border_width_top = 1; sbox.border_width_bottom = 1
	sbox.corner_radius_top_left = 12; sbox.corner_radius_top_right = 12
	sbox.corner_radius_bottom_left = 12; sbox.corner_radius_bottom_right = 12
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_theme_stylebox_override("panel", sbox)
	return p

func _make_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(240, 44)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	return btn

func _on_resume_pressed() -> void:
	MatchState.is_paused = false
	get_tree().paused = false

func _on_exit_pressed() -> void:
	get_tree().paused = false
	MatchState.is_paused = false
	EventBus.exit_to_lobby_requested.emit()
