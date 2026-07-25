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

func _ready() -> void:
	anchor_left   = 0.0; anchor_top    = 0.0
	anchor_right  = 1.0; anchor_bottom = 0.0
	offset_left   = 0.0; offset_top    = 0.0
	offset_right  = 0.0; offset_bottom = BAR_H + 3.0
	mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_build()
	EventBus.act_started.connect(_on_act_started)
	EventBus.game_over.connect(_on_game_over)
	EventBus.score_display_updated.connect(_on_scores_updated)
	EventBus.act_timer_changed.connect(_on_timer_changed)

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

	# Right section: score + team name
	var right_vbox := VBoxContainer.new()
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_theme_constant_override("separation", 2)
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_away_score_lbl = _lbl("0", Color.WHITE, 42)
	_away_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(_away_score_lbl)

	_away_name_lbl = _lbl(away_name, C_AWAY, 20)
	_away_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(_away_name_lbl)

	# Root HBox
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 0)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_bottom = BAR_H
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
