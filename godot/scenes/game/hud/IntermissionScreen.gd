extends Control

const C_HOME  := Color(1.000, 0.231, 0.325)
const C_AWAY  := Color(0.184, 0.514, 1.000)
const C_GOLD  := Color(1.000, 0.796, 0.239)
const C_CYAN  := Color(0.098, 0.890, 0.890)
const C_BG    := Color(0.039, 0.047, 0.078)
const C_ROW   := Color(0.024, 0.027, 0.051)
const C_HEAL  := Color(0.431, 0.906, 0.718)
const C_DIM   := Color(1.0, 1.0, 1.0, 0.40)
const C_HSEP  := Color(1.0, 1.0, 1.0, 0.08)

const CARD_W  := 892.0

func _ready() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	EventBus.act_ended.connect(_on_act_ended)
	EventBus.act_started.connect(func(_n): hide())

func _on_act_ended(act: int, home: int, away: int, _third: int) -> void:
	_rebuild(act, home, away)
	show()

func _rebuild(act: int, home: int, away: int) -> void:
	for c in get_children():
		c.queue_free()

	# Dim overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# Centered card
	var card := _make_panel(C_BG)
	card.custom_minimum_size = Vector2(CARD_W, 0)
	card.anchor_left = 0.5; card.anchor_right = 0.5
	card.anchor_top = 0.5; card.anchor_bottom = 0.5
	card.offset_left = -CARD_W * 0.5
	card.offset_right = CARD_W * 0.5
	card.offset_top = -420
	card.offset_bottom = 420
	add_child(card)

	var cfg := MatchState.config
	var home_name := cfg.home_team_name if cfg else "HOME"
	var away_name := cfg.away_team_name if cfg else "AWAY"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(vbox)

	# Header
	var hdr := _make_header_row(
		"ACT %d — INTERMISSION" % act,
		"LIVE STANDINGS",
		home_name, home, away_name, away
	)
	vbox.add_child(hdr)

	# Column headers
	vbox.add_child(_make_col_header())

	# Build sorted rows
	var rows := _collect_rows()
	rows.sort_custom(func(a, b): return a.points > b.points)
	var max_dmg := 1.0
	var max_heal := 1.0
	for r in rows:
		if r.dmg > max_dmg: max_dmg = r.dmg
		if r.heal > max_heal: max_heal = r.heal

	for i in rows.size():
		var r: Dictionary = rows[i]
		vbox.add_child(_make_stat_row(i + 1, r, max_dmg, max_heal, i == 0))

	# Legend
	vbox.add_child(_make_legend())

func _make_header_row(title: String, sub: String, home: String, h_score: int, away: String, a_score: int) -> Control:
	var c := ColorRect.new()
	c.color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.08)
	c.custom_minimum_size.y = 60

	var inner := HBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("separation", 12)
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 12)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_child(inner)
	c.add_child(m)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 2)
	inner.add_child(title_vbox)

	var title_lbl := _lbl(title, Color.WHITE, 18)
	title_vbox.add_child(title_lbl)
	var sub_lbl := _lbl(sub, C_GOLD, 9)
	title_vbox.add_child(sub_lbl)

	# Score
	var score_hbox := HBoxContainer.new()
	score_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	score_hbox.add_theme_constant_override("separation", 8)
	inner.add_child(score_hbox)

	score_hbox.add_child(_lbl(home, C_HOME, 14))
	score_hbox.add_child(_lbl("%d  –  %d" % [h_score, a_score], Color.WHITE, 28))
	score_hbox.add_child(_lbl(away, C_AWAY, 14))

	return c

func _make_col_header() -> Control:
	var row := _col_row()
	row.custom_minimum_size.y = 34
	var bg := ColorRect.new()
	bg.color = C_ROW
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_child(bg)

	var m := MarginContainer.new()
	for s in ["left", "right"]: m.add_theme_constant_override("margin_" + s, 20)
	for s in ["top", "bottom"]: m.add_theme_constant_override("margin_" + s, 8)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_child(m)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	m.add_child(hbox)

	hbox.add_child(_col_cell("#", 30, C_DIM, HORIZONTAL_ALIGNMENT_LEFT, 9))
	hbox.add_child(_col_cell("PLAYER", 200, C_DIM, HORIZONTAL_ALIGNMENT_LEFT, 9))
	hbox.add_child(_col_cell("DAMAGE DONE", 150, C_DIM, HORIZONTAL_ALIGNMENT_LEFT, 9))
	hbox.add_child(_col_cell("HEALING DONE", 150, C_DIM, HORIZONTAL_ALIGNMENT_LEFT, 9))
	hbox.add_child(_col_cell("POINTS SCORED", 180, C_DIM, HORIZONTAL_ALIGNMENT_CENTER, 9))
	hbox.add_child(_col_cell("FORCED FUMBLES", 96, C_DIM, HORIZONTAL_ALIGNMENT_CENTER, 9))

	return row

func _make_stat_row(rank: int, r: Dictionary, max_dmg: float, max_heal: float, is_leader: bool) -> Control:
	var row := _col_row()
	row.custom_minimum_size.y = 48

	var team_col: Color = C_HOME if r.team == 0 else (C_AWAY if r.team == 1 else Color(0.2, 0.9, 0.3))
	var row_bg: Color
	if is_leader:
		row_bg = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.07)
	elif r.team == 0:
		row_bg = Color(C_HOME.r, C_HOME.g, C_HOME.b, 0.05)
	else:
		row_bg = Color(C_AWAY.r, C_AWAY.g, C_AWAY.b, 0.05)

	var bg := ColorRect.new()
	bg.color = row_bg
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_child(bg)

	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.03)
	sep.anchor_left = 0; sep.anchor_right = 1
	sep.anchor_top = 1; sep.anchor_bottom = 1
	sep.offset_top = -1; sep.offset_bottom = 0
	row.add_child(sep)

	var m := MarginContainer.new()
	for s in ["left", "right"]: m.add_theme_constant_override("margin_" + s, 20)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_child(m)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_theme_constant_override("separation", 0)
	m.add_child(hbox)

	# Rank
	var rank_col := C_GOLD if is_leader else Color(1, 1, 1, 0.38)
	hbox.add_child(_col_cell("%02d" % rank, 30, rank_col, HORIZONTAL_ALIGNMENT_LEFT, 12))

	# Badge + Name + Class
	var name_cell := Control.new()
	name_cell.custom_minimum_size = Vector2(200, 0)
	name_cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_cell)

	var name_hbox := HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", 8)
	name_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_cell.add_child(name_hbox)

	# Badge square
	var badge_panel := PanelContainer.new()
	badge_panel.custom_minimum_size = Vector2(28, 28)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = team_col
	badge_style.corner_radius_top_left = 6; badge_style.corner_radius_top_right = 6
	badge_style.corner_radius_bottom_left = 6; badge_style.corner_radius_bottom_right = 6
	badge_panel.add_theme_stylebox_override("panel", badge_style)
	var badge_lbl := _lbl(r.name[0], Color.WHITE, 13)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_panel.add_child(badge_lbl)
	name_hbox.add_child(badge_panel)

	var name_vbox := VBoxContainer.new()
	name_vbox.add_theme_constant_override("separation", 1)
	name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_hbox.add_child(name_vbox)
	name_vbox.add_child(_lbl(r.name, Color.WHITE, 12))
	name_vbox.add_child(_lbl(r.cls, C_DIM, 9))

	# Damage
	var dmg_cell := _stat_bar_cell(r.dmg_fmt, r.dmg / max_dmg, team_col, 150)
	hbox.add_child(dmg_cell)

	# Healing
	var heal_cell := _stat_bar_cell(r.heal_fmt, r.heal / max_heal if r.heal > 0 else 0.0, C_HEAL, 150)
	if r.heal <= 0:
		(heal_cell.get_child(0).get_child(0) as Label).add_theme_color_override("font_color", C_DIM)
	hbox.add_child(heal_cell)

	# Points
	var pts_cell := Control.new()
	pts_cell.custom_minimum_size = Vector2(180, 0)
	pts_cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(pts_cell)

	var pts_vbox := VBoxContainer.new()
	pts_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pts_vbox.add_theme_constant_override("separation", 3)
	pts_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	pts_cell.add_child(pts_vbox)

	var pts_lbl := _lbl(str(r.points), C_GOLD, 20)
	pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pts_vbox.add_child(pts_lbl)

	var icons_hbox := HBoxContainer.new()
	icons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	icons_hbox.add_theme_constant_override("separation", 10)
	pts_vbox.add_child(icons_hbox)

	icons_hbox.add_child(_icon_label("● %d" % r.ub, C_GOLD, 9))
	icons_hbox.add_child(_icon_label("○ %d" % r.ca, C_CYAN, 9))
	icons_hbox.add_child(_icon_label("◆ %d" % r.kills, Color(1, 0.4, 0.4), 9))

	# Forced fumbles
	hbox.add_child(_col_cell(str(r.ff), 96, C_CYAN, HORIZONTAL_ALIGNMENT_CENTER, 18))

	return row

func _collect_rows() -> Array:
	var rows: Array = []
	for pid in MatchState.players:
		var rec: MatchState.PlayerRecord = MatchState.players[pid]
		var st: MatchState.PlayerStatRecord = MatchState.stat(pid)
		var fmt_n := func(n: float) -> String:
			return "%d" % int(n) if n < 1000 else "%.1fK" % (n / 1000.0)
		rows.append({
			"pid": pid, "name": rec.display_name, "cls": rec.class_id,
			"team": rec.team_id,
			"dmg": st.dmg, "heal": st.heal, "kills": st.kills,
			"deaths": st.deaths, "taken": st.taken, "ub": st.ub, "ca": st.ca, "ff": st.ff,
			"points": st.points,
			"dmg_fmt": fmt_n.call(st.dmg),
			"heal_fmt": fmt_n.call(st.heal) if st.heal > 0 else "—",
		})
	return rows

func _col_row() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _col_cell(text: String, min_w: int, col: Color, align: HorizontalAlignment, sz: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(min_w, 0)
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _lbl(text, col, sz)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(l)
	return c

func _stat_bar_cell(val_text: String, pct: float, bar_color: Color, min_w: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(min_w, 0)
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(vbox)

	var val_lbl := _lbl(val_text, Color.WHITE, 12)
	vbox.add_child(val_lbl)

	var bar_bg := Control.new()
	bar_bg.custom_minimum_size = Vector2(0, 4)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := pct
	var bc := bar_color
	bar_bg.draw.connect(func():
		bar_bg.draw_rect(Rect2(0, 0, bar_bg.size.x, 4), Color(1, 1, 1, 0.07))
		if p > 0.0:
			bar_bg.draw_rect(Rect2(0, 0, bar_bg.size.x * p, 4), bc)
	)
	vbox.add_child(bar_bg)

	return c

func _icon_label(text: String, col: Color, sz: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", sz)
	return l

func _make_legend() -> Control:
	var c := ColorRect.new()
	c.color = C_ROW
	c.custom_minimum_size.y = 36

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 18)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(hbox)

	hbox.add_child(_icon_label("● ULTRABALL", C_GOLD, 9))
	hbox.add_child(_icon_label("○ CATCH", C_CYAN, 9))
	hbox.add_child(_icon_label("◆ KILLING BLOW", Color(1, 0.4, 0.4), 9))

	return c

func _make_panel(bg_color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = bg_color
	sbox.border_color = Color(1, 1, 1, 0.09)
	sbox.border_width_left = 1; sbox.border_width_right = 1
	sbox.border_width_top = 1; sbox.border_width_bottom = 1
	sbox.corner_radius_top_left = 12; sbox.corner_radius_top_right = 12
	sbox.corner_radius_bottom_left = 12; sbox.corner_radius_bottom_right = 12
	p.add_theme_stylebox_override("panel", sbox)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

func _lbl(text: String, col: Color, sz: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", sz)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
