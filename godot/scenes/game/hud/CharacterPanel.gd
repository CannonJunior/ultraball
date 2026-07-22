extends Control

## Unified bottom HUD panel: player card (left) | ability slots (centre) | target card (right).

const C_BG     := Color(0.04, 0.04, 0.10, 0.88)
const C_BORDER := Color(0.12, 0.12, 0.24, 0.80)
const C_SEP    := Color(0.12, 0.12, 0.24, 0.60)
const C_DIM    := Color(1, 1, 1, 0.38)
const C_ENEMY  := Color(1.0, 0.35, 0.35)
const C_NONE   := Color(1, 1, 1, 0.20)

const HP_COLOR    := Color(0.20, 0.85, 0.20)
const MANA_COLORS := [
	Color(0.92, 0.22, 0.22),   # Red
	Color(0.25, 0.45, 1.00),   # Blue
	Color(0.90, 0.80, 0.10),   # Yellow
	Color(0.75, 0.25, 0.90),   # Ultra
]
const MANA_NAMES  := ["RED", "BLU", "YEL", "ULT"]
const MANA_MAXES  := [100.0, 100.0, 100.0, 10.0]
const MANA_TINTS  := [
	Color(0.22, 0.22, 0.22),   # 0 = None
	Color(0.35, 0.08, 0.08),   # 1 = Red
	Color(0.08, 0.12, 0.38),   # 2 = Blue
	Color(0.32, 0.28, 0.04),   # 3 = Yellow
	Color(0.28, 0.08, 0.38),   # 4 = Ultra
]
const READY_TINT := Color(0.14, 0.14, 0.18)

# ── Cached nodes ──────────────────────────────────────────────────────────────
var _class_dot    : ColorRect
var _name_lbl     : Label
var _class_lbl    : Label
var _hp_bar       : ProgressBar
var _mana_bars    : Array[ProgressBar] = []

var _slots        : Array[Dictionary] = []
var _names_loaded : bool = false
var _last_pid     : String = ""

var _target_icon  : Label
var _target_name  : Label
var _target_class : Label
var _target_hp    : ProgressBar

# ── Layout ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	anchor_left   = 0.0;  anchor_top    = 1.0
	anchor_right  = 1.0;  anchor_bottom = 1.0
	offset_left   = 8.0;  offset_top    = -130.0
	offset_right  = -8.0; offset_bottom = -8.0
	mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_build()

func _build() -> void:
	var root := PanelContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color           = C_BG
	bg.border_color       = C_BORDER
	bg.border_width_left  = 1; bg.border_width_right  = 1
	bg.border_width_top   = 1; bg.border_width_bottom = 1
	bg.corner_radius_top_left    = 4; bg.corner_radius_top_right    = 4
	bg.corner_radius_bottom_left = 4; bg.corner_radius_bottom_right = 4
	root.add_theme_stylebox_override("panel", bg)
	add_child(root)

	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 8)
	root.add_child(m)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	m.add_child(row)

	row.add_child(_build_player_pane())
	row.add_child(_vsep())
	row.add_child(_build_slot_pane())
	row.add_child(_vsep())
	row.add_child(_build_target_pane())

# ── Player pane ───────────────────────────────────────────────────────────────
func _build_player_pane() -> Control:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 220
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	vbox.add_child(hdr)

	_class_dot = ColorRect.new()
	_class_dot.custom_minimum_size = Vector2(5, 0)
	_class_dot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_class_dot.color = Color(0.5, 0.5, 0.5)
	hdr.add_child(_class_dot)

	_name_lbl = Label.new()
	_name_lbl.text = "—"
	_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_lbl.add_theme_font_size_override("font_size", 11)
	_name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	hdr.add_child(_name_lbl)

	_class_lbl = Label.new()
	_class_lbl.text = ""
	_class_lbl.add_theme_font_size_override("font_size", 9)
	_class_lbl.add_theme_color_override("font_color", C_DIM)
	hdr.add_child(_class_lbl)

	_hp_bar = _make_bar(HP_COLOR)
	vbox.add_child(_bar_row("HP ", _hp_bar, HP_COLOR))

	_mana_bars.clear()
	for i in 4:
		var bar := _make_bar(MANA_COLORS[i])
		_mana_bars.append(bar)
		vbox.add_child(_bar_row(MANA_NAMES[i], bar, MANA_COLORS[i]))

	return vbox

# ── Ability slot pane ─────────────────────────────────────────────────────────
func _build_slot_pane() -> Control:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 3)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_slots.clear()
	for i in 10:
		var key_text := "U" if i == 9 else str(i + 1)
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sbox := StyleBoxFlat.new()
		sbox.bg_color = READY_TINT
		sbox.corner_radius_top_left     = 3; sbox.corner_radius_top_right    = 3
		sbox.corner_radius_bottom_left  = 3; sbox.corner_radius_bottom_right = 3
		sbox.content_margin_left  = 4; sbox.content_margin_right  = 4
		sbox.content_margin_top   = 4; sbox.content_margin_bottom = 4
		panel.add_theme_stylebox_override("panel", sbox)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(vbox)

		var key_lbl := Label.new()
		key_lbl.text = key_text
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.add_theme_font_size_override("font_size", 9)
		key_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		vbox.add_child(key_lbl)

		var name_lbl := Label.new()
		name_lbl.text = "----"
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 8)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(name_lbl)

		var cd_lbl := Label.new()
		cd_lbl.text = ""
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.add_theme_font_size_override("font_size", 13)
		cd_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		vbox.add_child(cd_lbl)

		hbox.add_child(panel)
		_slots.append({"sbox": sbox, "name_lbl": name_lbl, "cd_lbl": cd_lbl})

	return hbox

# ── Target pane ───────────────────────────────────────────────────────────────
func _build_target_pane() -> Control:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 190
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	vbox.add_child(hdr)

	_target_icon = Label.new()
	_target_icon.text = "⊕"
	_target_icon.add_theme_font_size_override("font_size", 11)
	_target_icon.add_theme_color_override("font_color", C_NONE)
	hdr.add_child(_target_icon)

	_target_name = Label.new()
	_target_name.text = "NO TARGET"
	_target_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_name.add_theme_font_size_override("font_size", 11)
	_target_name.add_theme_color_override("font_color", C_NONE)
	hdr.add_child(_target_name)

	_target_class = Label.new()
	_target_class.text = ""
	_target_class.add_theme_font_size_override("font_size", 9)
	_target_class.add_theme_color_override("font_color", C_DIM)
	hdr.add_child(_target_class)

	_target_hp = _make_bar(C_ENEMY)
	vbox.add_child(_bar_row("HP ", _target_hp, C_ENEMY))

	return vbox

# ── Shared widget builders ────────────────────────────────────────────────────
func _bar_row(lbl_text: String, bar: ProgressBar, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var lbl := Label.new()
	lbl.text = lbl_text
	lbl.custom_minimum_size.x = 30
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", color)
	row.add_child(lbl)
	row.add_child(bar)
	return row

func _make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0; bar.max_value = 1.0; bar.value = 1.0
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size.y = 12
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left    = 2; fill.corner_radius_top_right    = 2
	fill.corner_radius_bottom_left = 2; fill.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.08, 0.08, 0.08, 0.9)
	bar.add_theme_stylebox_override("background", bg_sb)
	return bar

func _vsep() -> Control:
	var r := ColorRect.new()
	r.color = C_SEP
	r.custom_minimum_size.x = 1
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return r

# ── _process ──────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	var player := _local_player()
	if player == null:
		return
	_update_player(player)
	_update_slots(player)
	_update_target(player)

func _update_player(player: Node) -> void:
	var dot_color: Color = player.class_definition.body_color \
		if player.class_definition else Color(0.5, 0.5, 0.5)
	_class_dot.color = dot_color

	var rec = MatchState.players.get(player.player_id, null)
	_name_lbl.text = rec.display_name if rec else player.player_id
	_name_lbl.add_theme_color_override("font_color", dot_color.lightened(0.15))
	_class_lbl.text = player.class_definition.display_name \
		if player.class_definition else ""

	var buffs = player.get_node_or_null("PlayerBuffs")
	if buffs and buffs.max_health > 0:
		_hp_bar.value = buffs.health / buffs.max_health

	var mana = player.get_node_or_null("PlayerMana")
	if mana:
		_mana_bars[0].value = mana.red    / 100.0
		_mana_bars[1].value = mana.blue   / 100.0
		_mana_bars[2].value = mana.yellow / 100.0
		_mana_bars[3].value = mana.ultra  / 10.0

func _update_slots(player: Node) -> void:
	# Reset when controlled player changes
	if _last_pid != player.player_id:
		_last_pid = player.player_id
		_names_loaded = false
		for entry in _slots:
			entry["name_lbl"].text = "----"

	if not _names_loaded:
		_try_load_names(player)

	var abilities = player.get_node_or_null("PlayerAbilities")
	if abilities == null:
		return

	var gcd_active: bool = abilities.gcd_remaining > 0.05
	for i in 10:
		var entry: Dictionary = _slots[i]
		var cd: float = abilities.get_cooldown(i + 1)
		var ready := cd < 0.05
		var sbox: StyleBoxFlat = entry["sbox"]
		if not ready:
			sbox.bg_color = Color(0.08, 0.08, 0.08)
			entry["cd_lbl"].text = "%.1f" % cd
		elif gcd_active:
			sbox.bg_color = Color(0.10, 0.10, 0.20)
			entry["cd_lbl"].text = ""
		else:
			var tint := 0
			if player.class_definition:
				var defs: Array = player.class_definition.abilities
				if i < defs.size() and defs[i] != null:
					tint = (defs[i] as AbilityDefinition).mana_type
			sbox.bg_color = MANA_TINTS[clampi(tint, 0, MANA_TINTS.size() - 1)]
			entry["cd_lbl"].text = ""

func _try_load_names(player: Node) -> void:
	if player.class_definition == null:
		return
	var defs: Array = player.class_definition.abilities
	for i in mini(defs.size(), 10):
		if defs[i] != null:
			_slots[i]["name_lbl"].text = (defs[i] as AbilityDefinition).display_name.left(6)
	_names_loaded = true

func _update_target(player: Node) -> void:
	var tid: String = player.current_target_id
	if tid.is_empty():
		_target_icon.add_theme_color_override("font_color", C_NONE)
		_target_name.text = "NO TARGET"
		_target_name.add_theme_color_override("font_color", C_NONE)
		_target_class.text = ""
		_target_hp.value = 0.0
		return

	var target: Node = null
	for n in get_tree().get_nodes_in_group("players"):
		if n.player_id == tid:
			target = n
			break
	if target == null:
		return

	_target_icon.add_theme_color_override("font_color", C_ENEMY)
	var rec = MatchState.players.get(tid, null)
	_target_name.text = rec.display_name if rec else tid
	_target_name.add_theme_color_override("font_color", C_ENEMY)
	_target_class.text = target.class_definition.display_name \
		if target.class_definition else ""
	var t_buffs = target.get_node_or_null("PlayerBuffs")
	if t_buffs and t_buffs.max_health > 0:
		_target_hp.value = t_buffs.health / t_buffs.max_health

func _local_player() -> Node:
	var pid := NetworkManager.local_player_id
	if pid.is_empty():
		return null
	for n in get_tree().get_nodes_in_group("players"):
		if n.player_id == pid:
			return n
	return null
