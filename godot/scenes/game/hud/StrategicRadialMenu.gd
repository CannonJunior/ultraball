extends Control

## Strategic Radial Menu — team-wide tactical directives.
## Opens on the left side, just above the currently controlled unit card.
## Features will be implemented per recommendation 2 and beyond.
## Currently: basic panel with open/close wiring.

const C_BG     := Color(0.035, 0.040, 0.100, 0.93)
const C_BORDER := Color(0.15,  0.15,  0.28,  0.85)
const C_DIM    := Color(1, 1, 1, 0.35)
const PANEL_W  := 200.0
const PANEL_H  := 168.0

var _is_open: bool = false
var _header_lbl: Label

func _ready() -> void:
	anchor_left   = 0.0; anchor_right  = 0.0
	anchor_top    = 1.0; anchor_bottom = 1.0
	offset_left   = 8.0
	offset_right  = 8.0 + PANEL_W
	offset_bottom = -146.0
	offset_top    = offset_bottom - PANEL_H
	mouse_filter  = Control.MOUSE_FILTER_STOP
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	var root := PanelContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = C_BG
	sbox.border_color = C_BORDER
	for s in ["left","right","top","bottom"]: sbox.set("border_width_" + s, 1)
	for s in ["top_left","top_right","bottom_left","bottom_right"]:
		sbox.set("corner_radius_" + s, 4)
	root.add_theme_stylebox_override("panel", sbox)
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vbox)

	# Header
	var hdr := MarginContainer.new()
	hdr.custom_minimum_size.y = 22.0
	hdr.add_theme_constant_override("margin_left", 8)
	hdr.add_theme_constant_override("margin_right", 6)
	hdr.add_theme_constant_override("margin_top", 4)
	hdr.add_theme_constant_override("margin_bottom", 4)
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hdr)

	var hdr_row := HBoxContainer.new()
	hdr_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(hdr_row)

	_header_lbl = Label.new()
	_header_lbl.text = "STRATEGIC MODE"
	_header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_lbl.add_theme_font_size_override("font_size", 10)
	_header_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
	_header_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_row.add_child(_header_lbl)

	var hint := Label.new()
	hint.text = "[H]"
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", C_DIM)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_row.add_child(hint)

	# Separator
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(0.12, 0.12, 0.24, 0.60)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	# Placeholder body
	var body := MarginContainer.new()
	body.add_theme_constant_override("margin_left", 8)
	body.add_theme_constant_override("margin_right", 8)
	body.add_theme_constant_override("margin_top", 12)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(body)

	var body_vbox := VBoxContainer.new()
	body_vbox.add_theme_constant_override("separation", 6)
	body_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(body_vbox)

	var placeholder := Label.new()
	placeholder.text = "Team-wide commands\ncoming soon."
	placeholder.add_theme_font_size_override("font_size", 10)
	placeholder.add_theme_color_override("font_color", C_DIM)
	placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_vbox.add_child(placeholder)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey): return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo: return
	if MatchState.is_paused: return

	if ke.is_action("srm_open"):
		if not _is_open:
			_open()
		else:
			_close()
		get_viewport().set_input_as_handled()
		return

	if not _is_open: return

	if ke.physical_keycode == KEY_ESCAPE:
		_close()
	elif ke.physical_keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_close()

func _open() -> void:
	_is_open = true
	TacticalRoleSystem.srm_is_open = true
	visible = true
	EventBus.srm_opened.emit()

func _close() -> void:
	_is_open = false
	TacticalRoleSystem.srm_is_open = false
	visible = false
	EventBus.srm_closed.emit()
