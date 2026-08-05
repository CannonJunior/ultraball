extends Control

## Shows the unit that the player's current target is currently targeting.
## Positioned above the target pane of CharacterPanel (right side).
## Hidden automatically when the chain is broken (no target, or target has no target).

const C_BG       := Color(0.035, 0.040, 0.100, 0.93)
const C_BORDER   := Color(0.15,  0.15,  0.28,  0.85)
const C_SEP      := Color(0.12,  0.12,  0.24,  0.60)
const C_DIM      := Color(1, 1, 1, 0.35)
const C_ENEMY    := Color(1.0, 0.35, 0.35)
const C_FRIENDLY := Color(0.35, 0.85, 0.35)

const PANEL_W := 200.0
const PANEL_H := 80.0

var _header_lbl:      Label
var _avatar_bg:       ColorRect
var _init_lbl:        Label
var _name_lbl:        Label
var _class_lbl:       Label
var _hp_bar:          ProgressBar
var _hp_fill_sb:      StyleBoxFlat
var _current_tot_id:  String = ""
var _player_cache:    Dictionary = {}

func _ready() -> void:
	anchor_left   = 1.0;  anchor_right  = 1.0
	anchor_top    = 1.0;  anchor_bottom = 1.0
	offset_right  = -8.0
	offset_left   = -(PANEL_W + 8.0)
	offset_bottom = -146.0
	offset_top    = offset_bottom - PANEL_H
	mouse_filter  = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()

# ── Build ──────────────────────────────────────────────────────────────────────

func _build() -> void:
	var root := PanelContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	root.gui_input.connect(_on_card_clicked)
	var sbox := StyleBoxFlat.new()
	sbox.bg_color   = C_BG
	sbox.border_color = C_BORDER
	for s in ["left","right","top","bottom"]:
		sbox.set("border_width_" + s, 1)
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
	var hdr_m := MarginContainer.new()
	hdr_m.add_theme_constant_override("margin_left",   8)
	hdr_m.add_theme_constant_override("margin_right",  6)
	hdr_m.add_theme_constant_override("margin_top",    4)
	hdr_m.add_theme_constant_override("margin_bottom", 3)
	hdr_m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hdr_m)

	_header_lbl = Label.new()
	_header_lbl.text = "TARGET'S TARGET"
	_header_lbl.add_theme_font_size_override("font_size", 9)
	_header_lbl.add_theme_color_override("font_color", C_DIM)
	_header_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_m.add_child(_header_lbl)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = C_SEP
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	# Unit card row
	var card_m := MarginContainer.new()
	card_m.add_theme_constant_override("margin_left",   8)
	card_m.add_theme_constant_override("margin_right",  8)
	card_m.add_theme_constant_override("margin_top",    6)
	card_m.add_theme_constant_override("margin_bottom", 6)
	card_m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(card_m)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_m.add_child(row)

	# Avatar
	var av := Control.new()
	av.custom_minimum_size = Vector2(28, 28)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(av)

	_avatar_bg = ColorRect.new()
	_avatar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_avatar_bg.color = Color(C_ENEMY.r, C_ENEMY.g, C_ENEMY.b, 0.55)
	_avatar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.add_child(_avatar_bg)

	_init_lbl = Label.new()
	_init_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_init_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_init_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_init_lbl.add_theme_font_size_override("font_size", 12)
	_init_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.add_child(_init_lbl)

	# Info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_row)

	_name_lbl = Label.new()
	_name_lbl.text = "—"
	_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_lbl.add_theme_font_size_override("font_size", 11)
	_name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(_name_lbl)

	_class_lbl = Label.new()
	_class_lbl.text = ""
	_class_lbl.add_theme_font_size_override("font_size", 9)
	_class_lbl.add_theme_color_override("font_color", C_DIM)
	_class_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(_class_lbl)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 4)
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(hp_row)

	var hp_lbl := Label.new()
	hp_lbl.text = "HP"
	hp_lbl.custom_minimum_size.x = 14
	hp_lbl.add_theme_font_size_override("font_size", 8)
	hp_lbl.add_theme_color_override("font_color", C_DIM)
	hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_row.add_child(hp_lbl)

	_hp_bar = ProgressBar.new()
	_hp_bar.min_value = 0.0; _hp_bar.max_value = 1.0; _hp_bar.value = 0.0
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.custom_minimum_size.y = 8
	_hp_bar.show_percentage = false
	_hp_fill_sb = StyleBoxFlat.new()
	_hp_fill_sb.bg_color = C_ENEMY
	for s in ["top_left","top_right","bottom_left","bottom_right"]:
		_hp_fill_sb.set("corner_radius_" + s, 2)
	_hp_bar.add_theme_stylebox_override("fill", _hp_fill_sb)
	var hp_bg_sb := StyleBoxFlat.new()
	hp_bg_sb.bg_color = Color(0.08, 0.08, 0.12)
	_hp_bar.add_theme_stylebox_override("background", hp_bg_sb)
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_row.add_child(_hp_bar)

# ── Update ─────────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	_update()

func _update() -> void:
	var local_player := _local_player()
	if local_player == null:
		visible = false
		return

	var target_id: String = local_player.current_target_id
	if target_id.is_empty():
		visible = false
		return

	var target_node := _get_player_node(target_id)
	if target_node == null:
		visible = false
		return

	var tot_id: String = target_node.current_target_id
	if tot_id.is_empty():
		visible = false
		return

	var tot_node := _get_player_node(tot_id)
	if tot_node == null:
		visible = false
		_current_tot_id = ""
		return

	visible = true
	_current_tot_id = tot_id

	var rec: MatchState.PlayerRecord = MatchState.players.get(tot_id)
	var display_name: String = rec.display_name if rec != null else tot_id
	var tot_team: int = rec.team_id if rec != null else 0
	var is_friendly: bool = tot_team == local_player.team_id
	var accent: Color = C_FRIENDLY if is_friendly else C_ENEMY

	_init_lbl.text = display_name.substr(0, 1).to_upper()
	_avatar_bg.color = Color(accent.r, accent.g, accent.b, 0.55)
	_name_lbl.text = display_name.to_upper()
	_name_lbl.add_theme_color_override("font_color", accent)
	_class_lbl.text = tot_node.class_definition.display_name \
		if tot_node.class_definition else ""

	var buffs := tot_node.get_node_or_null("PlayerBuffs")
	if buffs != null and (buffs.get("max_health") as float) > 0.0:
		_hp_bar.value = (buffs.get("health") as float) / (buffs.get("max_health") as float)
		_hp_fill_sb.bg_color = accent

# ── Input ──────────────────────────────────────────────────────────────────────

func _on_card_clicked(event: InputEvent) -> void:
	if not (event is InputEventMouseButton): return
	var mb := event as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT): return
	if _current_tot_id.is_empty(): return
	var local := _local_player()
	if local == null: return
	local.set_explicit_target(_current_tot_id)

# ── Helpers ────────────────────────────────────────────────────────────────────

func _local_player() -> Node:
	var pid := NetworkManager.local_player_id
	if not pid.is_empty():
		for n in get_tree().get_nodes_in_group("players"):
			if n.player_id == pid:
				return n
		return null
	for n in get_tree().get_nodes_in_group("players"):
		if n.team_id == 0 and n.is_alive and n.is_on_field:
			return n
	return null

func _get_player_node(pid: String) -> Node:
	if pid.is_empty(): return null
	if _player_cache.has(pid) and is_instance_valid(_player_cache[pid]):
		return _player_cache[pid]
	for n in get_tree().get_nodes_in_group("players"):
		if n.player_id == pid:
			_player_cache[pid] = n
			return n
	return null
