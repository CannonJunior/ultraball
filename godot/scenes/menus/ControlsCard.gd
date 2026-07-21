class_name ControlsCard
extends PanelContainer

const BINDINGS: Array = [
	["W / S",       "Move forward / backward"],
	["A / D",       "Turn left / right"],
	["Q / E",       "Strafe left / right"],
	["1",           "Tackle (basic attack)"],
	["2",           "Power Slam  (25 Red Mana)"],
	["3",           "Sprint  (20 Blue Mana)"],
	["F",           "Pass ball to teammate"],
	["SPACE",       "Jump  (evades tackles while airborne)"],
	["SPACE x2",    "Double-jump  (costs 15 Blue Mana)"],
	["TAB",         "Cycle enemy target"],
	["SHIFT+TAB",   "Switch controlled player"],
	["M",           "Toggle damage / healing meter"],
	["C",           "Cycle player class  (Test Mode only)"],
	["ESC",         "Clear target / Pause"],
]

const C_PANEL_BG   := Color(0.031, 0.031, 0.059)
const C_BORDER     := Color(0.102, 0.102, 0.180)
const C_KEY_BG     := Color(0.200, 0.200, 0.333)
const C_KEY_BORDER := Color(0.333, 0.400, 0.533)
const C_KEY_TEXT   := Color(0.800, 0.867, 1.000)
const C_DESC_TEXT  := Color(1.000, 1.000, 1.000, 0.600)
const C_LABEL_TEXT := Color(1.000, 1.000, 1.000, 0.450)

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sbox := StyleBoxFlat.new()
	sbox.bg_color            = C_PANEL_BG
	sbox.border_color        = C_BORDER
	sbox.border_width_left   = 1
	sbox.border_width_right  = 1
	sbox.border_width_top    = 1
	sbox.border_width_bottom = 1
	sbox.corner_radius_top_left     = 6
	sbox.corner_radius_top_right    = 6
	sbox.corner_radius_bottom_left  = 6
	sbox.corner_radius_bottom_right = 6
	sbox.content_margin_left   = 16
	sbox.content_margin_right  = 16
	sbox.content_margin_top    = 14
	sbox.content_margin_bottom = 14
	add_theme_stylebox_override("panel", sbox)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	var heading := Label.new()
	heading.text = "CONTROLS"
	heading.add_theme_font_size_override("font_size", 9)
	heading.add_theme_color_override("font_color", C_LABEL_TEXT)
	vbox.add_child(heading)

	for pair in BINDINGS:
		vbox.add_child(_binding_row(pair[0], pair[1]))

func _binding_row(key: String, desc: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var badge_panel := PanelContainer.new()
	var badge_sbox := StyleBoxFlat.new()
	badge_sbox.bg_color            = C_KEY_BG
	badge_sbox.border_color        = C_KEY_BORDER
	badge_sbox.border_width_left   = 1
	badge_sbox.border_width_right  = 1
	badge_sbox.border_width_top    = 1
	badge_sbox.border_width_bottom = 1
	badge_sbox.corner_radius_top_left     = 3
	badge_sbox.corner_radius_top_right    = 3
	badge_sbox.corner_radius_bottom_left  = 3
	badge_sbox.corner_radius_bottom_right = 3
	badge_sbox.content_margin_left   = 6
	badge_sbox.content_margin_right  = 6
	badge_sbox.content_margin_top    = 2
	badge_sbox.content_margin_bottom = 2
	badge_panel.add_theme_stylebox_override("panel", badge_sbox)
	badge_panel.custom_minimum_size.x = 72

	var key_lbl := Label.new()
	key_lbl.text = key
	key_lbl.add_theme_font_size_override("font_size", 11)
	key_lbl.add_theme_color_override("font_color", C_KEY_TEXT)
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_panel.add_child(key_lbl)
	row.add_child(badge_panel)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", C_DESC_TEXT)
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(desc_lbl)

	return row
