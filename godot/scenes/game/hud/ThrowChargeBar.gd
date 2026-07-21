extends Control

## Centered charge bar — only visible when the local player is charging a throw.

const MAX_CHARGE := 7.0  # matches BallState.max_charge

var _bar: ProgressBar
var _label: Label

func _ready() -> void:
	# Centered horizontally, just above the hotbar
	anchor_left = 0.5;  anchor_top = 1.0
	anchor_right = 0.5; anchor_bottom = 1.0
	offset_left = -120.0; offset_top = -100.0
	offset_right =  120.0; offset_bottom = -78.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()

func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.04, 0.04, 0.12, 0.88)
	sbox.corner_radius_top_left = 4; sbox.corner_radius_top_right = 4
	sbox.corner_radius_bottom_left = 4; sbox.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", sbox)
	add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	panel.add_child(hbox)

	_label = Label.new()
	_label.text = "CHARGE"
	_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_label.add_theme_font_size_override("font_size", 12)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_label)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.custom_minimum_size.y = 14
	_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.85, 0.2)
	_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.08, 0.02, 0.9)
	_bar.add_theme_stylebox_override("background", bg)
	hbox.add_child(_bar)

func _process(_delta: float) -> void:
	var pid := NetworkManager.local_player_id
	var ball := MatchState.ball
	if ball.holder_id != pid or pid.is_empty():
		visible = false
		return
	var charge := ball.charge_timer
	if charge <= 0.01:
		visible = false
		return
	visible = true
	_bar.value = minf(charge / MAX_CHARGE, 1.0)
	# Turn red when fully charged
	var fill: StyleBoxFlat = _bar.get_theme_stylebox("fill")
	if charge >= MAX_CHARGE:
		fill.bg_color = Color(1.0, 0.25, 0.25)
	else:
		fill.bg_color = Color(1.0, 0.85, 0.2)
