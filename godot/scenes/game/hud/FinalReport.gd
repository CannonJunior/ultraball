extends Control

const _TeamPortrait := preload("res://scenes/game/hud/TeamPortrait.gd")

const C_GOLD  := Color(1.000, 0.796, 0.239)
const C_CYAN  := Color(0.098, 0.890, 0.890)
const C_BG    := Color(0.039, 0.047, 0.078)
const C_ROW   := Color(0.024, 0.027, 0.051)
const C_HEAL  := Color(0.431, 0.906, 0.718)
const C_TAKEN := Color(1.000, 0.557, 0.196)
const C_DIM   := Color(1.0, 1.0, 1.0, 0.40)

const CARD_W := 960.0

var _winner_id:   int = -1
var _home_score:  int = 0
var _away_score:  int = 0
var _current_tab: int = 0   # 0 = MATCH STATS, 1 = TEAM PORTRAITS

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	visible = false
	EventBus.game_over.connect(_on_game_over)

func _on_game_over(winner_id: int, home: int, away: int, _third: int) -> void:
	_winner_id  = winner_id
	_home_score = home
	_away_score = away
	_current_tab = 0
	_rebuild()
	show()
	get_tree().paused = true

func _rebuild() -> void:
	if _current_tab == 1:
		_rebuild_portraits()
	else:
		_rebuild_stats()

# ── MATCH STATS page ───────────────────────────────────────────────────────────

func _rebuild_stats() -> void:
	for c in get_children():
		c.queue_free()

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.78)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var cfg := MatchState.config
	var team_names := [
		cfg.home_team_name if cfg else "HOME",
		cfg.away_team_name if cfg else "AWAY",
		cfg.third_team_name if cfg else "THIRD",
	]
	var winner_name: String = team_names[clampi(_winner_id, 0, 2)]
	var winner_col := MatchState.team_color(_winner_id)

	# Fixed-height sections: tab(36) + hdr(80) + strip(56) + colhdr(34) + legend(36) + exit(68)
	var fixed_h := 36 + 80 + 56 + 34 + 36 + 68
	var vp_h := get_viewport_rect().size.y
	var scroll_h := maxf(200.0, vp_h - 80.0 - float(fixed_h))

	var card := _make_panel(C_BG)
	card.custom_minimum_size = Vector2(CARD_W, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	card.add_child(vbox)

	vbox.add_child(_make_tab_strip())

	# Victory header
	var wc := MatchState.team_color(_winner_id)
	var hdr := ColorRect.new()
	hdr.color = Color(wc.r, wc.g, wc.b, 0.10)
	hdr.custom_minimum_size.y = 80
	vbox.add_child(hdr)

	var hdr_vbox := VBoxContainer.new()
	hdr_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hdr_vbox.add_theme_constant_override("separation", 3)
	hdr_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hdr.add_child(hdr_vbox)

	var final_lbl := _lbl("FINAL", C_GOLD, 10)
	final_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr_vbox.add_child(final_lbl)

	var victory_hbox := HBoxContainer.new()
	victory_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	victory_hbox.add_theme_constant_override("separation", 8)
	hdr_vbox.add_child(victory_hbox)

	victory_hbox.add_child(_lbl(winner_name, Color.WHITE, 32))
	victory_hbox.add_child(_lbl("VICTORY", winner_col, 32))

	var scores_lbl := _lbl("%d  –  %d" % [_home_score, _away_score], Color(1, 1, 1, 0.7), 22)
	scores_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr_vbox.add_child(scores_lbl)

	# Stats summary strip
	var rows := _collect_rows()
	rows.sort_custom(func(a, b): return a.points > b.points)

	var top_pts_player: Dictionary = rows[0] if rows.size() > 0 else {}
	var top_dmg_player := rows.duplicate()
	top_dmg_player.sort_custom(func(a, b): return a.dmg > b.dmg)
	var top_heal_player := rows.duplicate()
	top_heal_player = top_heal_player.filter(func(r): return r.heal > 0)
	top_heal_player.sort_custom(func(a, b): return a.heal > b.heal)

	var strip := _make_stats_strip(top_pts_player, top_dmg_player, top_heal_player,
			MatchState.kills_unique[0].size(), MatchState.kills_unique[1].size())
	vbox.add_child(strip)

	vbox.add_child(_make_col_header())

	var max_dmg := 1.0
	var max_heal := 1.0
	var max_taken := 1.0
	for r in rows:
		if r.dmg > max_dmg: max_dmg = r.dmg
		if r.heal > max_heal: max_heal = r.heal
		if r.taken > max_taken: max_taken = r.taken

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, scroll_h)
	vbox.add_child(scroll)

	var rows_vbox := VBoxContainer.new()
	rows_vbox.add_theme_constant_override("separation", 0)
	rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows_vbox)

	for i in rows.size():
		rows_vbox.add_child(_make_stat_row(i + 1, rows[i], max_dmg, max_heal, max_taken, i == 0))

	vbox.add_child(_make_legend())
	vbox.add_child(_make_exit_btn())

# ── TEAM PORTRAITS page ────────────────────────────────────────────────────────

func _rebuild_portraits() -> void:
	for c in get_children():
		c.queue_free()

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.78)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	const PH := 646.0
	var card := _make_panel(C_BG)
	card.custom_minimum_size = Vector2(CARD_W, PH)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	card.add_child(vbox)

	vbox.add_child(_make_tab_strip())

	# Winner banner
	var cfg := MatchState.config
	var team_names := [
		cfg.home_team_name if cfg else "HOME",
		cfg.away_team_name if cfg else "AWAY",
	]
	var winner_col := MatchState.team_color(_winner_id)
	var winner_name: String = team_names[clampi(_winner_id, 0, 1)]

	var banner := ColorRect.new()
	banner.color = Color(winner_col.r, winner_col.g, winner_col.b, 0.08)
	banner.custom_minimum_size.y = 30
	vbox.add_child(banner)
	var banner_lbl := _lbl(
		"%s WINS  %d – %d" % [winner_name.to_upper(), _home_score, _away_score],
		C_GOLD, 12)
	banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	banner_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.add_child(banner_lbl)

	# Portrait area
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(hbox)

	# Compute and normalise hex data for both teams
	var raw: Array = _collect_team_hex_raw()
	var axes := ["kills", "dmg", "heal", "ball_time", "carries", "goals"]
	for key in axes:
		var mx: float = max(raw[0].get(key, 0.0), raw[1].get(key, 0.0))
		if mx > 0.0:
			raw[0][key] = float(raw[0].get(key, 0.0)) / mx
			raw[1][key] = float(raw[1].get(key, 0.0)) / mx

	for tid in 2:
		var h_vals := PackedFloat32Array()
		for key in axes:
			h_vals.append(float(raw[tid].get(key, 0.0)))

		var score := _home_score if tid == 0 else _away_score
		var opp   := _away_score if tid == 0 else _home_score

		var portrait := _TeamPortrait.new()
		portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portrait.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		hbox.add_child(portrait)
		portrait.setup(tid, team_names[tid], score, opp, h_vals)

	vbox.add_child(_make_exit_btn())

func _collect_team_hex_raw() -> Array:
	var result: Array = [{}, {}]
	for tid in 2:
		result[tid] = {"kills": 0.0, "dmg": 0.0, "heal": 0.0,
					   "ball_time": 0.0, "carries": 0.0, "goals": 0.0}
	for pid in MatchState.players:
		var rec: MatchState.PlayerRecord = MatchState.players[pid]
		if rec.team_id > 1:
			continue
		var st: MatchState.PlayerStatRecord = MatchState.stat(pid)
		var t: Dictionary = result[rec.team_id]
		t["kills"]     += st.kills
		t["dmg"]       += st.dmg
		t["heal"]      += st.heal
		t["ball_time"] += st.ball_time
		t["carries"]   += st.ball_carries
		t["goals"]     += st.ub + st.ca
	return result

# ── Tab strip ──────────────────────────────────────────────────────────────────

func _make_tab_strip() -> Control:
	var strip := ColorRect.new()
	strip.color = Color(0, 0, 0, 0.28)
	strip.custom_minimum_size.y = 36

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	strip.add_child(hbox)

	var tab_names := ["MATCH STATS", "TEAM PORTRAITS"]
	for i in tab_names.size():
		var btn := Button.new()
		btn.text = tab_names[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		btn.focus_mode            = Control.FOCUS_NONE
		var is_active := i == _current_tab
		var sbox := StyleBoxFlat.new()
		sbox.bg_color      = Color(0, 0, 0, 0)
		sbox.border_color  = C_GOLD if is_active else Color(1, 1, 1, 0.0)
		sbox.border_width_bottom = 2
		for sb_name in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(sb_name, sbox)
		btn.add_theme_color_override("font_color", C_GOLD if is_active else C_DIM)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_font_size_override("font_size", 11)
		btn.process_mode = Node.PROCESS_MODE_ALWAYS
		var idx := i
		btn.pressed.connect(func():
			_current_tab = idx
			_rebuild()
		)
		hbox.add_child(btn)

	return strip

# ── Stats page helpers (unchanged from original) ───────────────────────────────

func _make_stats_strip(mvp: Dictionary, top_dmg: Array, top_heal: Array, home: int, away: int) -> Control:
	var strip := ColorRect.new()
	strip.color = Color(1, 1, 1, 0.03)
	strip.custom_minimum_size.y = 56

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 1)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	strip.add_child(hbox)

	var cells := [
		["%d" % mvp.get("points", 0), "★ MVP · " + mvp.get("name", "—"), C_GOLD],
		[_fmt(top_dmg[0].dmg if top_dmg.size() > 0 else 0), "TOP DAMAGE", Color(1, 0.55, 0.55)],
		[_fmt(top_heal[0].heal if top_heal.size() > 0 else 0), "TOP HEALING · " + (top_heal[0].name if top_heal.size() > 0 else "—"), C_HEAL],
		["%d / %d" % [home, away], "TEAM KILLS", Color.WHITE],
	]

	for cell_data in cells:
		var sep := ColorRect.new()
		sep.color = Color(1, 1, 1, 0.06)
		sep.custom_minimum_size = Vector2(1, 0)
		sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hbox.add_child(sep)

		var cell := Control.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(cell)

		var cvbox := VBoxContainer.new()
		cvbox.alignment = BoxContainer.ALIGNMENT_CENTER
		cvbox.add_theme_constant_override("separation", 2)
		cvbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		cell.add_child(cvbox)

		var val_lbl := _lbl(cell_data[0], cell_data[2], 16)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cvbox.add_child(val_lbl)

		var sub_lbl := _lbl(cell_data[1], C_DIM, 9)
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cvbox.add_child(sub_lbl)

	return strip

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
	hbox.add_child(_col_cell("DAMAGE DONE", 140, C_DIM, HORIZONTAL_ALIGNMENT_LEFT, 9))
	hbox.add_child(_col_cell("HEALING DONE", 140, C_DIM, HORIZONTAL_ALIGNMENT_LEFT, 9))
	hbox.add_child(_col_cell("DAMAGE TAKEN", 140, C_DIM, HORIZONTAL_ALIGNMENT_LEFT, 9))
	hbox.add_child(_col_cell("POINTS SCORED", 180, C_DIM, HORIZONTAL_ALIGNMENT_CENTER, 9))
	hbox.add_child(_col_cell("FORCED FUMBLES", 90, C_DIM, HORIZONTAL_ALIGNMENT_CENTER, 9))

	return row

func _make_stat_row(rank: int, r: Dictionary, max_dmg: float, max_heal: float, max_taken: float, is_leader: bool) -> Control:
	var row := _col_row()
	row.custom_minimum_size.y = 48

	var local_pid := NetworkManager.local_player_id
	var is_local: bool = not local_pid.is_empty() and r.get("pid", "") == local_pid

	var team_col := MatchState.team_color(r.team)
	var row_bg: Color
	if is_leader and is_local:
		row_bg = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.12)
	elif is_leader or is_local:
		row_bg = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.07)
	else:
		row_bg = Color(team_col.r, team_col.g, team_col.b, 0.05)

	var bg := ColorRect.new()
	bg.color = row_bg
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_child(bg)

	var m := MarginContainer.new()
	for s in ["left", "right"]: m.add_theme_constant_override("margin_" + s, 20)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_child(m)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	m.add_child(hbox)

	var rank_col := C_GOLD if is_leader else Color(1, 1, 1, 0.38)
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

	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 1)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_hbox.add_child(nv)
	nv.add_child(_lbl(r.name, Color.WHITE, 12))
	nv.add_child(_lbl(r.cls, C_DIM, 9))

	hbox.add_child(_stat_bar_cell(r.dmg_fmt, r.dmg / max_dmg, team_col, 140))

	var heal_cell := _stat_bar_cell(r.heal_fmt, r.heal / max_heal if r.heal > 0 else 0.0, C_HEAL, 140)
	if r.heal <= 0:
		(heal_cell.get_child(0).get_child(0) as Label).add_theme_color_override("font_color", C_DIM)
	hbox.add_child(heal_cell)

	var taken_cell := _stat_bar_cell(r.taken_fmt, r.taken / max_taken if r.taken > 0 else 0.0, C_TAKEN, 140)
	if r.taken <= 0:
		(taken_cell.get_child(0).get_child(0) as Label).add_theme_color_override("font_color", C_DIM)
	hbox.add_child(taken_cell)

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

	hbox.add_child(_col_cell(str(r.ff), 90, C_CYAN, HORIZONTAL_ALIGNMENT_CENTER, 18))

	return row

func _collect_rows() -> Array:
	var rows: Array = []
	for pid in MatchState.players:
		var rec: MatchState.PlayerRecord = MatchState.players[pid]
		var st: MatchState.PlayerStatRecord = MatchState.stat(pid)
		rows.append({
			"pid": pid, "name": rec.display_name, "cls": rec.class_id,
			"team": rec.team_id,
			"dmg": st.dmg, "heal": st.heal, "kills": st.kills,
			"deaths": st.deaths, "taken": st.taken, "ub": st.ub, "ca": st.ca, "ff": st.ff,
			"points": st.points,
			"dmg_fmt": _fmt(st.dmg),
			"heal_fmt": _fmt(st.heal) if st.heal > 0 else "—",
			"taken_fmt": _fmt(st.taken) if st.taken > 0 else "—",
		})
	return rows

func _fmt(n: float) -> String:
	return "%d" % int(n) if n < 1000 else "%.1fK" % (n / 1000.0)

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

func _make_exit_btn() -> Control:
	var wrapper := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		wrapper.add_theme_constant_override("margin_" + s, 12)
	var btn := Button.new()
	btn.text = "EXIT TO MAIN MENU"
	btn.custom_minimum_size = Vector2(260, 44)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.pressed.connect(_on_exit_pressed)
	wrapper.add_child(btn)
	return wrapper

func _on_exit_pressed() -> void:
	get_tree().paused = false
	MatchState.is_paused = false
	EventBus.exit_to_lobby_requested.emit()
