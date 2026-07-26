extends Control

const C_HOME  := Color(1.000, 0.231, 0.325)
const C_AWAY  := Color(0.184, 0.514, 1.000)
const C_GOLD  := Color(1.000, 0.796, 0.239)
const C_CYAN  := Color(0.098, 0.890, 0.890)
const C_BG    := Color(0.016, 0.020, 0.039)

const BAR_H := 80.0
const SKEW  := 34.0
const CENTER_W := 260.0
const DOT_COUNT := 5
const DOT_W := 22.0
const DOT_H :=  5.0
const DOT_GAP := 5.0

const CARDS_H   := 55.0
const AVATAR_SZ := 30
const HP_BAR_W  := 26
const HP_BAR_H  :=  4
const CARD_PAD  :=  3

class _HpBar extends Control:
	var pct        : float = 1.0
	var fill_color : Color = Color.WHITE
	func set_pct(v: float) -> void:
		pct = clampf(v, 0.0, 1.0)
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(1, 1, 1, 0.10))
		if pct > 0.0:
			draw_rect(Rect2(0, 0, size.x * pct, size.y), fill_color)

var _home_name_lbl : Label
var _home_score_lbl: Label
var _away_name_lbl : Label
var _away_score_lbl: Label
var _act_lbl       : Label
var _timer_lbl     : Label
var _winner_lbl    : Label
var _dots          : Array[ColorRect] = []
var _charge_fill   : ColorRect

var _blink_timer := 0.0
var _colon_on    := true
var _glow_phase  := 0.0
var _raw_secs    := 180

# player_id → {av_bg, init_lbl, hp_bar, kill_lbl, team_color}
var _card_entries     : Dictionary = {}
var _player_node_cache: Dictionary = {}
var _home_box         : HBoxContainer = null
var _away_box         : HBoxContainer = null

func _ready() -> void:
	anchor_left   = 0.0; anchor_top    = 0.0
	anchor_right  = 1.0; anchor_bottom = 0.0
	offset_left   = 0.0; offset_top    = 0.0
	offset_right  = 0.0; offset_bottom = BAR_H + 3.0 + CARDS_H
	mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_build()
	_build_cards()
	EventBus.act_started.connect(_on_act_started)
	EventBus.game_over.connect(_on_game_over)
	EventBus.score_display_updated.connect(_on_scores_updated)
	EventBus.act_timer_changed.connect(_on_timer_changed)
	EventBus.player_died.connect(_on_card_player_died)
	EventBus.player_subbed_in.connect(_on_card_player_subbed)
	EventBus.killa_scored.connect(_on_card_killa_scored)

func _draw() -> void:
	var w := size.x
	draw_rect(Rect2(0, 0, w, BAR_H), C_BG)

	var side_w := (w - CENTER_W) * 0.5
	var clx := side_w
	var crx := side_w + CENTER_W

	# Left team parallelogram
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 0), Vector2(clx, 0),
		Vector2(clx - SKEW, BAR_H), Vector2(0, BAR_H)
	]), Color(C_HOME.r, C_HOME.g, C_HOME.b, 0.22))

	# Center trapezoid (wider at bottom)
	draw_colored_polygon(PackedVector2Array([
		Vector2(clx + SKEW, 0), Vector2(crx - SKEW, 0),
		Vector2(crx, BAR_H), Vector2(clx, BAR_H)
	]), Color(0.0, 0.0, 0.0, 0.55))

	# Right team parallelogram
	draw_colored_polygon(PackedVector2Array([
		Vector2(crx + SKEW, 0), Vector2(w, 0),
		Vector2(w, BAR_H), Vector2(crx, BAR_H)
	]), Color(C_AWAY.r, C_AWAY.g, C_AWAY.b, 0.22))

	# Border lines
	draw_line(Vector2(0, 0), Vector2(w, 0), Color(1, 1, 1, 0.05), 1.0)
	draw_line(Vector2(0, BAR_H), Vector2(w, BAR_H), Color(1, 1, 1, 0.05), 1.0)

	# Cards section background
	draw_rect(Rect2(0, BAR_H + 3.0, w, CARDS_H), Color(C_BG.r, C_BG.g, C_BG.b, 0.90))
	draw_line(Vector2(0, BAR_H + 3.0 + CARDS_H), Vector2(w, BAR_H + 3.0 + CARDS_H), Color(1, 1, 1, 0.05), 1.0)

func _build() -> void:
	var cfg := MatchState.config
	var home_name := cfg.home_team_name if cfg else "REAPERS"
	var away_name := cfg.away_team_name if cfg else "VIPERS"

	# Left section: team name + score
	var left_vbox := VBoxContainer.new()
	left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	left_vbox.add_theme_constant_override("separation", 2)
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_home_name_lbl = _lbl(home_name, C_HOME, 20)
	_home_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(_home_name_lbl)

	_home_score_lbl = _lbl("0", Color.WHITE, 42)
	_home_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(_home_score_lbl)

	# Center section: act + timer + dots
	var center_vbox := VBoxContainer.new()
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 3)
	center_vbox.custom_minimum_size.x = CENTER_W
	center_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_act_lbl = _lbl("ACT 1", C_GOLD, 10)
	_act_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_vbox.add_child(_act_lbl)

	_timer_lbl = _lbl("3:00", C_CYAN, 34)
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_vbox.add_child(_timer_lbl)

	_winner_lbl = _lbl("", C_GOLD, 22)
	_winner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_winner_lbl.visible = false
	center_vbox.add_child(_winner_lbl)

	var dots_hbox := HBoxContainer.new()
	dots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	dots_hbox.add_theme_constant_override("separation", int(DOT_GAP))
	dots_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_vbox.add_child(dots_hbox)

	_dots.clear()
	for i in DOT_COUNT:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(DOT_W, DOT_H)
		dot.color = Color(1, 1, 1, 0.14)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots_hbox.add_child(dot)
		_dots.append(dot)

	# Right section: team name + score
	var right_vbox := VBoxContainer.new()
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_theme_constant_override("separation", 2)
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_away_name_lbl = _lbl(away_name, C_AWAY, 20)
	_away_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(_away_name_lbl)

	_away_score_lbl = _lbl("0", Color.WHITE, 42)
	_away_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(_away_score_lbl)

	# Root HBox
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 0)
	hbox.anchor_left   = 0.0; hbox.anchor_top    = 0.0
	hbox.anchor_right  = 1.0; hbox.anchor_bottom = 0.0
	hbox.offset_left   = 0.0; hbox.offset_top    = 0.0
	hbox.offset_right  = 0.0; hbox.offset_bottom = BAR_H
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)
	hbox.add_child(left_vbox)
	hbox.add_child(center_vbox)
	hbox.add_child(right_vbox)

	# Charge bar
	var charge_bg := ColorRect.new()
	charge_bg.anchor_left = 0.0; charge_bg.anchor_right = 1.0
	charge_bg.anchor_top = 0.0; charge_bg.anchor_bottom = 0.0
	charge_bg.offset_top = BAR_H; charge_bg.offset_bottom = BAR_H + 3.0
	charge_bg.color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.18)
	charge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(charge_bg)

	_charge_fill = ColorRect.new()
	_charge_fill.position = Vector2(0, BAR_H)
	_charge_fill.size = Vector2(0, 3)
	_charge_fill.color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.9)
	_charge_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_charge_fill)

	_refresh_dots(MatchState.current_act)

func _process(delta: float) -> void:
	# Colon blink
	_blink_timer += delta
	if _blink_timer >= 0.5:
		_blink_timer = 0.0
		_colon_on = not _colon_on
		_redraw_timer()

	# Dot glow pulse for current act
	_glow_phase += delta * 3.0
	var glow := (sin(_glow_phase) * 0.25 + 0.75)
	var cur := MatchState.current_act - 1
	if cur >= 0 and cur < _dots.size():
		_dots[cur].color = Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, glow)

	# Charge bar fill
	var ball := MatchState.ball
	var pct := clampf(ball.charge_timer / ball.max_charge, 0.0, 1.0) if ball.max_charge > 0.0 else 0.0
	_charge_fill.size.x = size.x * pct

	# Health bar updates
	_update_card_health()

func _on_act_started(act: int) -> void:
	_act_lbl.text = "ACT %d" % act
	_timer_lbl.visible = true
	_winner_lbl.visible = false
	_refresh_dots(act)

func _on_scores_updated(home: int, away: int, _third: int) -> void:
	_home_score_lbl.text = str(home)
	_away_score_lbl.text = str(away)

func _on_timer_changed(t: float) -> void:
	_raw_secs = maxi(0, int(t))
	_redraw_timer()

func _on_game_over(winner_id: int, _h: int, _a: int, _t: int) -> void:
	var cfg := MatchState.config
	var names := [
		cfg.home_team_name if cfg else "HOME",
		cfg.away_team_name if cfg else "AWAY",
		cfg.third_team_name if cfg else "THIRD",
	]
	_winner_lbl.text = "%s VICTORY" % names[clampi(winner_id, 0, 2)]
	_winner_lbl.visible = true
	_timer_lbl.visible = false

func _redraw_timer() -> void:
	var mins := _raw_secs / 60
	var secs := _raw_secs % 60
	_timer_lbl.text = "%d%s%02d" % [mins, ":" if _colon_on else " ", secs]

func _refresh_dots(current_act: int) -> void:
	for i in _dots.size():
		if i < current_act - 1:
			_dots[i].color = C_CYAN
		elif i == current_act - 1:
			_dots[i].color = C_CYAN  # animated in _process
		else:
			_dots[i].color = Color(1, 1, 1, 0.14)

func _lbl(text: String, col: Color, sz: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", sz)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# ── Player cards section ──────────────────────────────────────────────────────

func _build_cards() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",     8)
	margin.add_theme_constant_override("margin_bottom",  8)
	margin.anchor_left   = 0.0; margin.anchor_right  = 1.0
	margin.anchor_top    = 0.0; margin.anchor_bottom = 0.0
	margin.offset_top    = BAR_H + 3.0
	margin.offset_bottom = BAR_H + 3.0 + CARDS_H
	margin.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)

	_home_box = HBoxContainer.new()
	_home_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_home_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_home_box.add_theme_constant_override("separation", 0)
	_home_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_home_box)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(CENTER_W, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(spacer)

	_away_box = HBoxContainer.new()
	_away_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_away_box.alignment = BoxContainer.ALIGNMENT_END
	_away_box.add_theme_constant_override("separation", 0)
	_away_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_away_box)

	_rebuild_cards()

func _rebuild_cards() -> void:
	if _home_box == null or _away_box == null: return
	for c in _home_box.get_children(): c.queue_free()
	for c in _away_box.get_children(): c.queue_free()
	_card_entries.clear()
	_player_node_cache.clear()

	var home_pids: Array = []
	var away_pids: Array = []
	for pid: String in MatchState.players:
		var rec: MatchState.PlayerRecord = MatchState.players[pid]
		if not rec.is_on_field: continue
		if rec.team_id == 0: home_pids.append(pid)
		elif rec.team_id == 1: away_pids.append(pid)

	for pid: String in home_pids:
		_home_box.add_child(_make_card(pid))
	for pid: String in away_pids:
		_away_box.add_child(_make_card(pid))

func _make_card(pid: String) -> Control:
	var rec: MatchState.PlayerRecord = MatchState.players.get(pid)
	var team  := rec.team_id if rec else 0
	var alive := rec.is_alive if rec else true
	var name_str := rec.display_name if rec and not rec.display_name.is_empty() else pid
	var initial  := name_str.substr(0, 1).to_upper()
	var tc       := C_HOME if team == 0 else C_AWAY
	var kills    := MatchState.stat(pid).kills

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",  CARD_PAD)
	margin.add_theme_constant_override("margin_right", CARD_PAD)
	margin.add_theme_constant_override("margin_top",   0)
	margin.add_theme_constant_override("margin_bottom",0)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	# Avatar (fixed 30×30)
	var av := Control.new()
	av.custom_minimum_size = Vector2(AVATAR_SZ, AVATAR_SZ)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(av)

	var av_bg := ColorRect.new()
	av_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	av_bg.color = Color(tc.r, tc.g, tc.b, 0.65) if alive else Color(0.20, 0.20, 0.22, 0.9)
	av_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.add_child(av_bg)

	var init_lbl := Label.new()
	init_lbl.text = initial
	init_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	init_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	init_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	init_lbl.add_theme_font_size_override("font_size", 14)
	init_lbl.modulate.a = 1.0 if alive else 0.35
	init_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.add_child(init_lbl)

	var kill_lbl := Label.new()
	kill_lbl.text = str(kills)
	kill_lbl.add_theme_color_override("font_color", C_GOLD)
	kill_lbl.add_theme_font_size_override("font_size", 7)
	kill_lbl.position = Vector2(AVATAR_SZ - 12, AVATAR_SZ - 12)
	kill_lbl.size     = Vector2(12, 12)
	kill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kill_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
	kill_lbl.visible  = kills > 0
	kill_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.add_child(kill_lbl)

	# Health bar
	var hp_bar: _HpBar = _HpBar.new()
	hp_bar.custom_minimum_size = Vector2(HP_BAR_W, HP_BAR_H)
	hp_bar.fill_color = tc if alive else Color(0.45, 0.45, 0.45)
	col.add_child(hp_bar)

	_card_entries[pid] = {
		"av_bg":    av_bg,
		"init_lbl": init_lbl,
		"hp_bar":   hp_bar,
		"kill_lbl": kill_lbl,
		"team_color": tc,
	}
	return margin

func _update_card_health() -> void:
	for pid: String in _card_entries:
		var node := _get_player_node(pid)
		if node == null: continue
		var buffs := node.get_node_or_null("PlayerBuffs")
		if buffs == null: continue
		var mx: float = buffs.get("max_health")
		var hp: float = buffs.get("health")
		if mx > 0.0:
			(_card_entries[pid]["hp_bar"] as _HpBar).set_pct(hp / mx)

func _get_player_node(pid: String) -> Node:
	if _player_node_cache.has(pid) and is_instance_valid(_player_node_cache[pid]):
		return _player_node_cache[pid]
	for n in get_tree().get_nodes_in_group("players"):
		if n.player_id == pid:
			_player_node_cache[pid] = n
			return n
	return null

func _on_card_player_died(pid: String, _cause: String, _killer: String) -> void:
	if not _card_entries.has(pid): return
	var e: Dictionary = _card_entries[pid]
	(e["av_bg"]    as ColorRect).color    = Color(0.20, 0.20, 0.22, 0.9)
	(e["init_lbl"] as Label).modulate.a   = 0.35
	var bar := e["hp_bar"] as _HpBar
	bar.fill_color = Color(0.45, 0.45, 0.45)
	bar.set_pct(0.0)

func _on_card_player_subbed(pid: String, _replaced: String, team: int) -> void:
	if not _card_entries.has(pid):
		_rebuild_cards()
		return
	var e: Dictionary = _card_entries[pid]
	var tc := C_HOME if team == 0 else C_AWAY
	(e["av_bg"]    as ColorRect).color  = Color(tc.r, tc.g, tc.b, 0.65)
	(e["init_lbl"] as Label).modulate.a = 1.0
	var bar := e["hp_bar"] as _HpBar
	bar.fill_color = tc
	bar.set_pct(1.0)

func _on_card_killa_scored(_killer_team: int, killer_id: String, _victim_id: String) -> void:
	if killer_id.is_empty() or not _card_entries.has(killer_id): return
	var kills := MatchState.stat(killer_id).kills
	var kill_lbl := _card_entries[killer_id]["kill_lbl"] as Label
	kill_lbl.text    = str(kills)
	kill_lbl.visible = true
