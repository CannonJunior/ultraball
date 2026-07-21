extends Control

const MANA_COLORS := [
	Color(0.92, 0.22, 0.22),  # Red
	Color(0.25, 0.45, 1.00),  # Blue
	Color(0.90, 0.80, 0.10),  # Yellow
	Color(0.75, 0.25, 0.90),  # Ultra
]
const MANA_NAMES  := ["RED", "BLU", "YEL", "ULT"]
const MANA_MAXES  := [100.0, 100.0, 100.0, 10.0]

var _health_bar: ProgressBar
var _mana_bars: Array[ProgressBar] = []

func _ready() -> void:
	# 190×140 panel at bottom-left with 8px margin
	anchor_left = 0.0;  anchor_top = 1.0
	anchor_right = 0.0; anchor_bottom = 1.0
	offset_left = 8.0;  offset_top = -148.0
	offset_right = 198.0; offset_bottom = -8.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.04, 0.04, 0.10, 0.84)
	sbox.corner_radius_top_left = 4; sbox.corner_radius_top_right = 4
	sbox.corner_radius_bottom_left = 4; sbox.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", sbox)
	add_child(panel)

	var margin := MarginContainer.new()
	for s in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + s, 6)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	_health_bar = _add_row(vbox, "HP", Color(0.2, 0.85, 0.2))
	for i in 4:
		_mana_bars.append(_add_row(vbox, MANA_NAMES[i], MANA_COLORS[i]))

func _add_row(parent: VBoxContainer, label_text: String, color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 28
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size.y = 14
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 2; fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2; fill.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.08, 0.9)
	bar.add_theme_stylebox_override("background", bg)
	row.add_child(bar)
	return bar

func _process(_delta: float) -> void:
	var player := _local_player()
	if player == null: return
	var buffs: Node = player.get_node_or_null("PlayerBuffs")
	if buffs and buffs.max_health > 0:
		_health_bar.value = buffs.health / buffs.max_health
	var mana: Node = player.get_node_or_null("PlayerMana")
	if mana:
		_mana_bars[0].value = mana.red / 100.0
		_mana_bars[1].value = mana.blue / 100.0
		_mana_bars[2].value = mana.yellow / 100.0
		_mana_bars[3].value = mana.ultra / 10.0

func _local_player() -> Node:
	var pid := NetworkManager.local_player_id
	if pid.is_empty(): return null
	for n in get_tree().get_nodes_in_group("players"):
		if n.player_id == pid: return n
	return null
