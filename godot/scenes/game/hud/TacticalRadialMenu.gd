extends Control

## Tactical Radial Menu — assigns per-unit tactical roles to AI teammates.
## Open:  G key   → opens, targeting the closest live teammate
## Cycle: G key (while open) → cycles through alive teammates
## Assign: C / V / F / R hotkeys or mouse-click on role button
## Close:  Escape, or any movement key (W/A/S/D)
##
## Positions on the right side of the screen, just above the CharacterPanel.

const C_BG        := Color(0.035, 0.040, 0.100, 0.93)
const C_BORDER    := Color(0.15,  0.15,  0.28,  0.85)
const C_SEP       := Color(0.12,  0.12,  0.24,  0.60)
const C_DIM       := Color(1, 1, 1, 0.35)
const C_RAIL      := Color(0.15, 0.15, 0.25)
const C_LABEL_DIM := Color(0.55, 0.55, 0.65)

const PANEL_W     := 200.0
const PANEL_H     := 168.0

# Role data
const ROLES := [
	TacticalRoleSystem.ROLE_CARRIER,
	TacticalRoleSystem.ROLE_SHOT_CALLER,
	TacticalRoleSystem.ROLE_FOCUS_FIRE,
	TacticalRoleSystem.ROLE_SHADOW,
]
const ROLE_KEYS   := ["C", "V", "F", "R"]
const BTN_SIZE    := 36.0
const BTN_RADIUS  := 18.0

var _is_open: bool = false
var _target_pid: String = ""
var _team_color: Color = Color(0.4, 0.8, 1.0)

# Built nodes
var _header_lbl:   Label
var _avatar_bg:    ColorRect
var _init_lbl:     Label
var _name_lbl:     Label
var _class_lbl:    Label
var _hp_bar:       ProgressBar
var _role_badge:   Label
var _dial_area:    Control        # custom-draw area for rail
var _btn_panels:   Array[PanelContainer] = []
var _btn_sboxes:   Array[StyleBoxFlat]   = []
var _btn_key_lbls: Array[Label]          = []
var _btn_name_lbls:Array[Label]          = []
var _player_cache: Dictionary = {}

func _ready() -> void:
	# Position: left side, above the selected player's unit card in CharacterPanel.
	# SRM occupies the same footprint but only one menu is ever visible at once.
	anchor_left   = 0.0;  anchor_right  = 0.0
	anchor_top    = 1.0;  anchor_bottom = 1.0
	offset_left   = 8.0
	offset_right  = 8.0 + PANEL_W
	offset_bottom = -146.0
	offset_top    = offset_bottom - PANEL_H
	mouse_filter  = Control.MOUSE_FILTER_STOP
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

# ── Build ──────────────────────────────────────────────────────────────────────

func _build() -> void:
	var root := PanelContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sbox := StyleBoxFlat.new()
	sbox.bg_color             = C_BG
	sbox.border_color         = C_BORDER
	for s in ["left", "right", "top", "bottom"]:
		sbox.set("border_width_" + s, 1)
	for s in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		sbox.set("corner_radius_" + s, 4)
	root.add_theme_stylebox_override("panel", sbox)
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vbox)

	vbox.add_child(_build_header())
	vbox.add_child(_build_unit_card())
	vbox.add_child(_build_separator())
	vbox.add_child(_build_dial())

func _build_header() -> Control:
	var hdr := PanelContainer.new()
	hdr.custom_minimum_size.y = 22.0
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(0.1, 0.1, 0.2, 0.0)  # tinted in _refresh_team_color
	hs.content_margin_left = 8; hs.content_margin_right = 6
	hs.content_margin_top = 4; hs.content_margin_bottom = 4
	hdr.add_theme_stylebox_override("panel", hs)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(row)

	_header_lbl = Label.new()
	_header_lbl.text = "TACTICAL ROLE"
	_header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_lbl.add_theme_font_size_override("font_size", 10)
	_header_lbl.add_theme_color_override("font_color", _team_color)
	_header_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_header_lbl)

	var hint := Label.new()
	hint.text = "[G]"
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", C_DIM)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hint)

	return hdr

func _build_unit_card() -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",  8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top",   6)
	m.add_theme_constant_override("margin_bottom",4)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(row)

	# Avatar circle
	var av := Control.new()
	av.custom_minimum_size = Vector2(30, 30)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(av)

	_avatar_bg = ColorRect.new()
	_avatar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_avatar_bg.color = Color(0.3, 0.5, 0.8, 0.7)
	_avatar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.add_child(_avatar_bg)

	_init_lbl = Label.new()
	_init_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_init_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_init_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_init_lbl.add_theme_font_size_override("font_size", 13)
	_init_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.add_child(_init_lbl)

	# Info column
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
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
	hp_lbl.add_theme_color_override("font_color", C_LABEL_DIM)
	hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_row.add_child(hp_lbl)

	_hp_bar = ProgressBar.new()
	_hp_bar.min_value = 0.0; _hp_bar.max_value = 1.0; _hp_bar.value = 1.0
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.custom_minimum_size.y = 8
	_hp_bar.show_percentage = false
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = _team_color
	fill_sb.corner_radius_top_left    = 2; fill_sb.corner_radius_top_right    = 2
	fill_sb.corner_radius_bottom_left = 2; fill_sb.corner_radius_bottom_right = 2
	_hp_bar.add_theme_stylebox_override("fill", fill_sb)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.08, 0.08, 0.12)
	_hp_bar.add_theme_stylebox_override("background", bg_sb)
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_row.add_child(_hp_bar)

	# Current role badge
	_role_badge = Label.new()
	_role_badge.text = "AUTO"
	_role_badge.add_theme_font_size_override("font_size", 8)
	_role_badge.add_theme_color_override("font_color", C_DIM)
	_role_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(_role_badge)

	return m

func _build_separator() -> Control:
	var r := ColorRect.new()
	r.custom_minimum_size = Vector2(0, 1)
	r.color = C_SEP
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _build_dial() -> Control:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var section_lbl := Label.new()
	section_lbl.text = "ASSIGN ROLE"
	section_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_lbl.add_theme_font_size_override("font_size", 8)
	section_lbl.add_theme_color_override("font_color", C_LABEL_DIM)
	section_lbl.add_theme_constant_override("margin_top", 6)
	section_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sec_m := MarginContainer.new()
	sec_m.add_theme_constant_override("margin_top", 6)
	sec_m.add_theme_constant_override("margin_bottom", 2)
	sec_m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sec_m.add_child(section_lbl)
	outer.add_child(sec_m)

	# Dial drawing area + buttons
	_dial_area = Control.new()
	_dial_area.custom_minimum_size = Vector2(PANEL_W, 84)
	_dial_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dial_area.draw.connect(_draw_dial)
	outer.add_child(_dial_area)

	# Build 4 role buttons inside dial_area
	_btn_panels.clear(); _btn_sboxes.clear()
	_btn_key_lbls.clear(); _btn_name_lbls.clear()

	# Button centers at equal spacing within PANEL_W
	# 4 buttons x 36px + 3 gaps x gap = PANEL_W
	# gap = (PANEL_W - 4*BTN_SIZE) / 5 ~= 11
	var gap := (PANEL_W - 4.0 * BTN_SIZE) / 5.0
	for i in 4:
		var cx := gap + i * (BTN_SIZE + gap) + BTN_RADIUS  # center x
		var btn_x := cx - BTN_RADIUS

		var panel := PanelContainer.new()
		panel.position = Vector2(btn_x, 8)   # y=8 from dial_area top (above tick marks)
		panel.custom_minimum_size = Vector2(BTN_SIZE, BTN_SIZE)
		panel.size = Vector2(BTN_SIZE, BTN_SIZE)
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.10, 0.10, 0.16)
		sb.border_color = Color(0.20, 0.20, 0.30)
		for s in ["left","right","top","bottom"]: sb.set("border_width_" + s, 1)
		sb.corner_radius_top_left    = int(BTN_RADIUS)
		sb.corner_radius_top_right   = int(BTN_RADIUS)
		sb.corner_radius_bottom_left = int(BTN_RADIUS)
		sb.corner_radius_bottom_right = int(BTN_RADIUS)
		sb.content_margin_left  = 2; sb.content_margin_right  = 2
		sb.content_margin_top   = 4; sb.content_margin_bottom  = 2
		panel.add_theme_stylebox_override("panel", sb)
		_btn_panels.append(panel)
		_btn_sboxes.append(sb)

		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 0)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(vb)

		var key_lbl := Label.new()
		key_lbl.text = ROLE_KEYS[i]
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.add_theme_font_size_override("font_size", 14)
		key_lbl.add_theme_color_override("font_color", C_DIM)
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(key_lbl)
		_btn_key_lbls.append(key_lbl)

		var role: int = ROLES[i]
		var capture_i := i
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton \
					and (event as InputEventMouseButton).pressed \
					and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_select_role(ROLES[capture_i])
		)
		_dial_area.add_child(panel)

		# Label below button
		var name_lbl := Label.new()
		name_lbl.text = TacticalRoleSystem.ROLE_SHORT[role]
		name_lbl.position = Vector2(btn_x - 4, 8 + BTN_SIZE + 4)
		name_lbl.size = Vector2(BTN_SIZE + 8, 14)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 8)
		name_lbl.add_theme_color_override("font_color", C_LABEL_DIM)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dial_area.add_child(name_lbl)
		_btn_name_lbls.append(name_lbl)

	return outer

func _draw_dial() -> void:
	if _dial_area == null: return
	var gap := (PANEL_W - 4.0 * BTN_SIZE) / 5.0
	var rail_y := 8.0 + BTN_RADIUS  # center of buttons
	var first_cx := gap + BTN_RADIUS
	var last_cx  := gap + 3.0 * (BTN_SIZE + gap) + BTN_RADIUS

	# Rail line
	_dial_area.draw_line(
		Vector2(first_cx, rail_y),
		Vector2(last_cx,  rail_y),
		C_RAIL, 4.0, true)

	# Tick marks at each button center
	var cur_role := TacticalRoleSystem.get_role(_target_pid)
	for i in 4:
		var cx := gap + i * (BTN_SIZE + gap) + BTN_RADIUS
		var is_active: bool = ROLES[i] == cur_role and cur_role != TacticalRoleSystem.ROLE_NONE
		var tick_col := _team_color if is_active else C_RAIL.lightened(0.15)
		# Tick mark above rail
		_dial_area.draw_line(
			Vector2(cx, rail_y - BTN_RADIUS - 4),
			Vector2(cx, rail_y - BTN_RADIUS),
			tick_col, 2.0)

func _redraw_dial() -> void:
	if _dial_area != null:
		_dial_area.queue_redraw()

# ── Input handling ─────────────────────────────────────────────────────────────

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey): return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo: return
	if MatchState.is_paused: return

	if ke.is_action("trm_open"):
		if not _is_open:
			_open()
		else:
			_cycle_target()
		get_viewport().set_input_as_handled()
		return

	if not _is_open: return

	match ke.physical_keycode:
		KEY_C:
			_select_role(TacticalRoleSystem.ROLE_CARRIER)
			get_viewport().set_input_as_handled()
		KEY_V:
			_select_role(TacticalRoleSystem.ROLE_SHOT_CALLER)
			get_viewport().set_input_as_handled()
		KEY_F:
			_select_role(TacticalRoleSystem.ROLE_FOCUS_FIRE)
			get_viewport().set_input_as_handled()
		KEY_R:
			_select_role(TacticalRoleSystem.ROLE_SHADOW)
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_close()
			# Don't consume Escape — let InputManager pause if needed
		_:
			pass

# ── TRM logic ──────────────────────────────────────────────────────────────────

func _open() -> void:
	# If no target set yet, default to closest teammate
	if _target_pid.is_empty() or not _is_target_valid(_target_pid):
		var closest := _closest_teammate()
		if closest.is_empty():
			return
		_target_pid = closest
	_is_open = true
	TacticalRoleSystem.trm_is_open = true
	visible = true
	_refresh()
	EventBus.trm_opened.emit(_target_pid)

func _close() -> void:
	_is_open = false
	TacticalRoleSystem.trm_is_open = false
	visible = false
	EventBus.trm_closed.emit()

func _cycle_target() -> void:
	var list := _ordered_teammates()
	if list.is_empty():
		return
	var idx := -1
	for i in list.size():
		if list[i] == _target_pid:
			idx = i
			break
	_target_pid = list[(idx + 1) % list.size()]
	_refresh()
	EventBus.trm_opened.emit(_target_pid)

func _select_role(role: int) -> void:
	if _target_pid.is_empty(): return
	# Toggle off if same role is clicked again
	var current := TacticalRoleSystem.get_role(_target_pid)
	if current == role:
		TacticalRoleSystem.set_role(_target_pid, TacticalRoleSystem.ROLE_NONE)
	else:
		TacticalRoleSystem.set_role(_target_pid, role)
		if role == TacticalRoleSystem.ROLE_SHADOW:
			TacticalRoleSystem.shadow_source_id = _local_player_id()
	_refresh()

# ── Update display ─────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not _is_open: return
	_update_hp()

func _refresh() -> void:
	if _target_pid.is_empty(): return
	var rec: MatchState.PlayerRecord = MatchState.players.get(_target_pid)
	var node := _get_player_node(_target_pid)

	# Team color
	var team_id := rec.team_id if rec != null else 0
	_team_color = MatchState.team_color(team_id)
	_header_lbl.add_theme_color_override("font_color", _team_color)

	# Avatar
	var display_name: String = rec.display_name if rec != null else _target_pid
	_init_lbl.text  = display_name.substr(0, 1).to_upper()
	_avatar_bg.color = Color(_team_color.r, _team_color.g, _team_color.b, 0.65)

	# Name + class
	_name_lbl.text  = display_name.to_upper()
	_class_lbl.text = node.class_definition.display_name \
		if node != null and node.class_definition else ""

	# Role badge
	var cur_role := TacticalRoleSystem.get_role(_target_pid)
	_role_badge.text = TacticalRoleSystem.ROLE_LABEL.get(cur_role, "AUTO")
	if cur_role == TacticalRoleSystem.ROLE_NONE:
		_role_badge.add_theme_color_override("font_color", C_DIM)
	else:
		_role_badge.add_theme_color_override("font_color", _team_color)

	# Update HP bar fill color
	var fill_sb := _hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_sb:
		fill_sb.bg_color = _team_color

	_update_hp()
	_refresh_buttons()
	_redraw_dial()

func _update_hp() -> void:
	if _target_pid.is_empty(): return
	var node := _get_player_node(_target_pid)
	if node == null: return
	var buffs := node.get_node_or_null("PlayerBuffs")
	if buffs and buffs.get("max_health") > 0.0:
		_hp_bar.value = buffs.get("health") / buffs.get("max_health")

func _refresh_buttons() -> void:
	var cur_role := TacticalRoleSystem.get_role(_target_pid)
	for i in 4:
		var sb := _btn_sboxes[i]
		var is_active: bool = ROLES[i] == cur_role
		if is_active:
			sb.bg_color    = Color(_team_color.r, _team_color.g, _team_color.b, 0.55)
			sb.border_color = _team_color
			_btn_key_lbls[i].add_theme_color_override("font_color", Color.WHITE)
			_btn_name_lbls[i].add_theme_color_override("font_color", _team_color)
		else:
			sb.bg_color    = Color(0.10, 0.10, 0.16)
			sb.border_color = Color(0.20, 0.20, 0.30)
			_btn_key_lbls[i].add_theme_color_override("font_color", C_DIM)
			_btn_name_lbls[i].add_theme_color_override("font_color", C_LABEL_DIM)

# ── Helpers ────────────────────────────────────────────────────────────────────

func _closest_teammate() -> String:
	var local_pos := Vector2.ZERO
	var local_id  := _local_player_id()
	var local_node := _get_player_node(local_id)
	if local_node != null:
		local_pos = local_node.global_position

	var best_id   := ""
	var best_dist := INF
	var my_team   := -1
	if local_node != null:
		my_team = local_node.team_id

	for n in get_tree().get_nodes_in_group("players"):
		if n.player_id == local_id: continue
		if n.team_id != my_team: continue
		if not n.is_alive or not n.is_on_field: continue
		var d := local_pos.distance_to(n.global_position)
		if d < best_dist:
			best_dist = d
			best_id   = n.player_id
	return best_id

func _ordered_teammates() -> Array:
	var local_id := _local_player_id()
	var my_team  := -1
	var local_node := _get_player_node(local_id)
	if local_node != null:
		my_team = local_node.team_id

	var list: Array = []
	for n in get_tree().get_nodes_in_group("players"):
		if n.player_id == local_id: continue
		if n.team_id != my_team: continue
		if not n.is_alive or not n.is_on_field: continue
		list.append(n.player_id)

	list.sort_custom(func(a: String, b: String) -> bool:
		var ra: MatchState.PlayerRecord = MatchState.players.get(a)
		var rb: MatchState.PlayerRecord = MatchState.players.get(b)
		return (ra.roster_slot if ra else 0) < (rb.roster_slot if rb else 0)
	)
	return list

func _is_target_valid(pid: String) -> bool:
	var node := _get_player_node(pid)
	return node != null and node.is_alive and node.is_on_field

func _local_player_id() -> String:
	var pid := NetworkManager.local_player_id
	if not pid.is_empty():
		return pid
	for n in get_tree().get_nodes_in_group("players"):
		if n.team_id == 0 and n.is_alive and n.is_on_field:
			return n.player_id
	return ""

func _get_player_node(pid: String) -> Node:
	if pid.is_empty(): return null
	if _player_cache.has(pid) and is_instance_valid(_player_cache[pid]):
		return _player_cache[pid]
	for n in get_tree().get_nodes_in_group("players"):
		if n.player_id == pid:
			_player_cache[pid] = n
			return n
	return null
