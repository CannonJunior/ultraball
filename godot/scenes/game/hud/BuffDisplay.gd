extends Control

## Shows active buffs and debuffs for the local player as colored pills.

const BUFFS := [
	["speed_mult_remaining",      "SPEED",   Color(0.3, 0.9, 0.3)],
	["damage_boost_remaining",    "ATK+",    Color(0.9, 0.5, 0.2)],
	["damage_reduction_remaining","DEF+",    Color(0.2, 0.6, 0.9)],
	["stun_immune_remaining",     "IMMUNE",  Color(0.7, 0.7, 0.3)],
	["dodge_remaining",           "DODGE",   Color(0.4, 0.9, 0.7)],
	["hot_remaining",             "REGEN",   Color(0.3, 1.0, 0.3)],
]
const DEBUFFS := [
	["stun_timer",      "STUN",  Color(0.9, 0.9, 0.1)],
	["snare_remaining", "SNARE", Color(0.8, 0.3, 0.1)],
	["confused_timer",  "CONF",  Color(0.8, 0.2, 0.8)],
	["hex_timer",       "HEX",   Color(0.6, 0.1, 0.6)],
	["marked_timer",    "MARK",  Color(0.9, 0.2, 0.2)],
]

var _pill_pool: Array[Label] = []
var _flow: HBoxContainer

func _ready() -> void:
	# Thin bar above ManaBars, bottom-left
	anchor_left = 0.0;  anchor_top = 1.0
	anchor_right = 0.0; anchor_bottom = 1.0
	offset_left = 8.0;  offset_top = -182.0
	offset_right = 350.0; offset_bottom = -152.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func _build() -> void:
	_flow = HBoxContainer.new()
	_flow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flow.alignment = BoxContainer.ALIGNMENT_BEGIN
	_flow.add_theme_constant_override("separation", 4)
	add_child(_flow)

	# Pre-create pill labels for all possible buffs/debuffs (max 11)
	for _i in 11:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.visible = false
		var sbox := StyleBoxFlat.new()
		sbox.bg_color = Color(0.2, 0.2, 0.2, 0.8)
		sbox.corner_radius_top_left = 3; sbox.corner_radius_top_right = 3
		sbox.corner_radius_bottom_left = 3; sbox.corner_radius_bottom_right = 3
		sbox.content_margin_left = 4; sbox.content_margin_right = 4
		sbox.content_margin_top = 1; sbox.content_margin_bottom = 1
		lbl.add_theme_stylebox_override("normal", sbox)
		_flow.add_child(lbl)
		_pill_pool.append(lbl)

func _process(_delta: float) -> void:
	var player := _local_player()
	var buffs: Node = player.get_node_or_null("PlayerBuffs") if player else null

	var pill_idx := 0

	if buffs:
		for entry in BUFFS:
			var val: float = buffs.get(entry[0])
			if val > 0.05 and pill_idx < _pill_pool.size():
				_show_pill(pill_idx, entry[1], entry[2])
				pill_idx += 1
		for entry in DEBUFFS:
			var val: float = buffs.get(entry[0])
			if val > 0.05 and pill_idx < _pill_pool.size():
				_show_pill(pill_idx, entry[1], entry[2])
				pill_idx += 1

	for i in range(pill_idx, _pill_pool.size()):
		_pill_pool[i].visible = false

func _show_pill(idx: int, label_text: String, col: Color) -> void:
	var lbl: Label = _pill_pool[idx]
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", col)
	lbl.visible = true

func _local_player() -> Node:
	var pid := NetworkManager.local_player_id
	if pid.is_empty(): return null
	for n in get_tree().get_nodes_in_group("players"):
		if n.player_id == pid: return n
	return null
