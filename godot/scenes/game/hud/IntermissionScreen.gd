extends Control

const _TeamPortrait := preload("res://scenes/game/hud/TeamPortrait.gd")

const C_GOLD  := Color(1.000, 0.796, 0.239)
const C_CYAN  := Color(0.098, 0.890, 0.890)
const C_BG    := Color(0.039, 0.047, 0.078)
const C_ROW   := Color(0.024, 0.027, 0.051)
const C_HEAL  := Color(0.431, 0.906, 0.718)
const C_DIM   := Color(1.0, 1.0, 1.0, 0.40)
const C_HSEP  := Color(1.0, 1.0, 1.0, 0.08)

const CARD_W  := 892.0

var _act: int = 1
var _next_act: int = 2
var _home_score: int = 0
var _away_score: int = 0
var _current_tab: int = 0
var _show_all: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	visible = false
	EventBus.act_ended.connect(_on_act_ended)

func _on_act_ended(act: int, home: int, away: int, _third: int) -> void:
	if act >= 5:
		return  # game_over fires next; FinalReport handles end-of-match
	_act = act
	_next_act = act + 1
	_home_score = home
	_away_score = away
	_current_tab = 0
	_show_all = false
	_rebuild()
	show()
	get_tree().paused = true

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	if _current_tab == 0:
		_rebuild_stats()
	else:
		_rebuild_portraits()

# ── Stats tab ──────────────────────────────────────────────────────────────────

func _rebuild_stats() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var cfg := MatchState.config
	var home_name: String = cfg.home_team_name if cfg else "HOME"
	var away_name: String = cfg.away_team_name if cfg else "AWAY"

	# Fixed-height sections: tab(34) + header(60) + colhdr(34) + toggle(34) + legend(36) + continue(68)
	var fixed_h := 34 + 60 + 34 + 34 + 36 + 68
	var vp_h := get_viewport_rect().size.y
	var scroll_h := maxf(200.0, vp_h - 80.0 - float(fixed_h))

	var card := _make_panel(C_BG)
	card.custom_minimum_size = Vector2(CARD_W, 0)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	card.add_child(vbox)

	vbox.add_child(_make_tab_strip())

	vbox.add_child(_make_header_row(
		"ACT %d — INTERMISSION" % _act,
		"LIVE STANDINGS",
		home_name, _home_score, away_name, _away_score
	))

	vbox.add_child(_make_col_header())
	vbox.add_child(_make_toggle_row())

	var rows := _collect_rows()
	if not _show_all:
		var active: Array = []
		for r in rows:
			if r.get("participated", false):
				active.append(r)
		rows = active
	rows.sort_custom(func(a, b): return a["points"] > b["points"])
	var max_dmg := 1.0
	var max_heal := 1.0
	for r in rows:
		if r.dmg > max_dmg: max_dmg = r.dmg
		if r.heal > max_heal: max_heal = r.heal

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, scroll_h)
	vbox.add_child(scroll)

	var rows_vbox := VBoxContainer.new()
	rows_vbox.add_theme_constant_override("separation", 0)
	rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows_vbox)

	for i in rows.size():
		var r: Dictionary = rows[i]
		rows_vbox.add_child(_make_stat_row(i + 1, r, max_dmg, max_heal, i == 0))

	vbox.add_child(_make_legend())
	vbox.add_child(_make_continue_btn())

# ── Portraits tab ──────────────────────────────────────────────────────────────

func _rebuild_portraits() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	const PH := 646.0
	var card := _make_panel(C_BG)
	card.custom_minimum_size = Vector2(CARD_W, PH)
	center.add_child(card)

	var cfg := MatchState.config
	var home_name: String = cfg.home_team_name if cfg else "HOME"
	var away_name: String = cfg.away_team_name if cfg else "AWAY"

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 0)
	card.add_child(outer_vbox)

	outer_vbox.add_child(_make_tab_strip())

	# Banner
	var banner := ColorRect.new()
	banner.color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.08)
	banner.custom_minimum_size.y = 60

	var banner_margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		banner_margin.add_theme_constant_override("margin_" + s, 12)
	banner_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.add_child(banner_margin)

	var banner_hbox := HBoxContainer.new()
	banner_hbox.add_theme_constant_override("separation", 12)
	banner_margin.add_child(banner_hbox)

	var title_lbl := _lbl("AFTER ACT %d" % _act, Color.WHITE, 18)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_hbox.add_child(title_lbl)

	var score_hbox := HBoxContainer.new()
	score_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	score_hbox.add_theme_constant_override("separation", 8)
	banner_hbox.add_child(score_hbox)
	score_hbox.add_child(_lbl(home_name, MatchState.team_color(0), 14))
	score_hbox.add_child(_lbl("%d  –  %d" % [_home_score, _away_score], Color.WHITE, 28))
	score_hbox.add_child(_lbl(away_name, MatchState.team_color(1), 14))

	outer_vbox.add_child(banner)

	# Portrait row
	var port_margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		port_margin.add_theme_constant_override("margin_" + s, 12)
	port_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(port_margin)

	var port_hbox := HBoxContainer.new()
	port_hbox.add_theme_constant_override("separation", 12)
	port_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	port_margin.add_child(port_hbox)

	var raw: Array = _collect_team_hex_raw()
	var keys := ["kills", "dmg", "heal", "ball_time", "ball_carries", "points"]
	for tid in [0, 1]:
		var h_vals := PackedFloat32Array()
		for key in keys:
			var mx: float = max(float(raw[0].get(key, 0.0)), float(raw[1].get(key, 0.0)))
			h_vals.append(float(raw[tid].get(key, 0.0)) / max(1.0, mx))
		var tname: String = home_name if tid == 0 else away_name
		var tscore: int = _home_score if tid == 0 else _away_score
		var opp: int = _away_score if tid == 0 else _home_score
		var portrait := _TeamPortrait.new()
		portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
		port_hbox.add_child(portrait)
		portrait.setup(tid, tname, tscore, opp, h_vals)

	outer_vbox.add_child(_make_continue_btn())

# ── Shared helpers ─────────────────────────────────────────────────────────────

func _make_tab_strip() -> Control:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 0)
	strip.custom_minimum_size.y = 34

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.3)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	strip.add_child(bg)

	var labels := ["MATCH STATS", "TEAM PORTRAITS"]
	for idx in labels.size():
		var is_active := idx == _current_tab
		var btn := Button.new()
		btn.text = labels[idx]
		btn.custom_minimum_size = Vector2(160, 34)
		btn.process_mode = Node.PROCESS_MODE_ALWAYS
		var bstyle := StyleBoxFlat.new()
		bstyle.bg_color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.12) if is_active else Color(0, 0, 0, 0)
		bstyle.border_width_bottom = 2 if is_active else 0
		bstyle.border_color = C_GOLD
		btn.add_theme_stylebox_override("normal", bstyle)
		btn.add_theme_stylebox_override("hover", bstyle)
		btn.add_theme_stylebox_override("pressed", bstyle)
		var i := idx
		btn.pressed.connect(func(): _current_tab = i; _rebuild())
		strip.add_child(btn)

	return strip

func _make_toggle_row() -> Control:
	var row := ColorRect.new()
	row.color = Color(0, 0, 0, 0.15)
	row.custom_minimum_size.y = 34

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_theme_constant_override("separation", 0)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_child(hbox)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var btn := Button.new()
	btn.text = "SHOW ALL UNITS" if not _show_all else "ACTIVE PLAYERS ONLY"
	btn.custom_minimum_size = Vector2(180, 26)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.pressed.connect(func(): _show_all = not _show_all; _rebuild())

	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 4)
	m.add_child(btn)
	hbox.add_child(m)

	return row

func _collect_team_hex_raw() -> Array:
	var raw: Array = [{}, {}]
	for pid in MatchState.players:
		var rec: MatchState.PlayerRecord = MatchState.players[pid]
		if rec.team_id < 0 or rec.team_id > 1:
			continue
		var st: MatchState.PlayerStatRecord = MatchState.stat(pid)
		var d: Dictionary = raw[rec.team_id]
		d["kills"]        = d.get("kills", 0)        + st.kills
		d["dmg"]          = d.get("dmg", 0.0)        + st.dmg
		d["heal"]         = d.get("heal", 0.0)        + st.heal
		d["ball_time"]    = d.get("ball_time", 0.0)   + st.ball_time
		d["ball_carries"] = d.get("ball_carries", 0)  + st.ball_carries
		d["points"]       = d.get("points", 0)        + st.points
	return raw

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

	title_vbox.add_child(_lbl(title, Color.WHITE, 18))
	title_vbox.add_child(_lbl(sub, C_GOLD, 9))

	var score_hbox := HBoxContainer.new()
	score_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	score_hbox.add_theme_constant_override("separation", 8)
	inner.add_child(score_hbox)

	score_hbox.add_child(_lbl(home, MatchState.team_color(0), 14))
	score_hbox.add_child(_lbl("%d  –  %d" % [h_score, a_score], Color.WHITE, 28))
	score_hbox.add_child(_lbl(away, MatchState.team_color(1), 14))

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

	var local_pid := NetworkManager.local_player_id
	var is_local: bool = not local_pid.is_empty() and r.get("pid", "") == local_pid

	var team_col: Color = MatchState.team_color(r.team)
	var row_bg: Color
	if is_leader and is_local:
		row_bg = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.12)
	elif is_leader or is_local:
		row_bg = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.07)
	else:
		var rc := MatchState.team_color(r.team)
		row_bg = Color(rc.r, rc.g, rc.b, 0.05)

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

	var rank_col: Color = C_GOLD if is_leader else Color(1, 1, 1, 0.38)
	hbox.add_child(_col_cell("%02d" % rank, 30, rank_col, HORIZONTAL_ALIGNMENT_LEFT, 12))

	var name_cell := Control.new()
	name_cell.custom_minimum_size = Vector2(200, 0)
	name_cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_cell)

	var name_hbox := HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", 8)
	name_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_cell.add_child(name_hbox)

	var badge_panel := PanelContainer.new()
	badge_panel.custom_minimum_size = Vector2(28, 28)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = team_col
	badge_style.corner_radius_top_left = 6; badge_style.corner_radius_top_right = 6
	badge_style.corner_radius_bottom_left = 6; badge_style.corner_radius_bottom_right = 6
	if is_local:
		badge_style.border_width_left   = 2
		badge_style.border_width_right  = 2
		badge_style.border_width_top    = 2
		badge_style.border_width_bottom = 2
		badge_style.border_color = C_GOLD
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

	hbox.add_child(_stat_bar_cell(r.dmg_fmt, r.dmg / max_dmg, team_col, 150))
	hbox.add_child(_stat_bar_cell(
		r.heal_fmt,
		r.heal / max_heal if r.heal > 0 else 0.0,
		C_HEAL, 150
	))

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

	hbox.add_child(_col_cell(str(r.ff), 96, C_CYAN, HORIZONTAL_ALIGNMENT_CENTER, 18))

	return row

func _fmt_num(n: float) -> String:
	if n < 1000: return "%d" % int(n)
	return "%.1fK" % (n / 1000.0)

func _collect_rows() -> Array:
	var rows: Array = []
	for pid in MatchState.players:
		var rec: MatchState.PlayerRecord = MatchState.players[pid]
		var st: MatchState.PlayerStatRecord = MatchState.stat(pid)
		rows.append({
			"pid": pid, "name": rec.display_name, "cls": rec.class_id,
			"team": rec.team_id,
			"participated": rec.is_on_field,
			"dmg": st.dmg, "heal": st.heal, "kills": st.kills,
			"deaths": st.deaths, "taken": st.taken, "ub": st.ub, "ca": st.ca, "ff": st.ff,
			"points": st.points,
			"dmg_fmt": _fmt_num(st.dmg),
			"heal_fmt": _fmt_num(st.heal) if st.heal > 0 else "-",
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

	vbox.add_child(_lbl(val_text, Color.WHITE, 12))

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

func _make_continue_btn() -> Control:
	var wrapper := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		wrapper.add_theme_constant_override("margin_" + s, 12)
	var btn := Button.new()
	btn.text = "CONTINUE TO ACT %d" % _next_act
	btn.custom_minimum_size = Vector2(260, 44)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.pressed.connect(_on_continue_pressed)
	wrapper.add_child(btn)
	return wrapper

func _on_continue_pressed() -> void:
	hide()
	get_tree().paused = MatchState.is_paused
	EventBus.act_transition_complete.emit(_next_act)
	EventBus.act_started.emit(_next_act)
