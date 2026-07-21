extends Control

var _home_lbl: Label
var _away_lbl: Label
var _third_lbl: Label
var _act_lbl: Label
var _timer_lbl: Label
var _winner_lbl: Label

func _ready() -> void:
	# Full-width bar at the top
	anchor_left = 0.0;  anchor_top = 0.0
	anchor_right = 1.0; anchor_bottom = 0.0
	offset_left = 0.0;  offset_top = 0.0
	offset_right = 0.0; offset_bottom = 44.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	EventBus.act_started.connect(func(n: int): _act_lbl.text = "ACT %d" % n)
	EventBus.game_over.connect(_on_game_over)
	EventBus.score_display_updated.connect(_on_scores_updated)

func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.04, 0.04, 0.12, 0.88)
	panel.add_theme_stylebox_override("panel", sbox)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	_home_lbl = _lbl("HOME: 0", Color(0.4, 0.65, 1.0), 17)
	hbox.add_child(_home_lbl)
	hbox.add_child(_spacer())

	_act_lbl = _lbl("ACT 1", Color(0.85, 0.85, 0.85), 14)
	hbox.add_child(_act_lbl)

	_timer_lbl = _lbl("3:00", Color(0.95, 0.92, 0.6), 18)
	hbox.add_child(_timer_lbl)

	_winner_lbl = _lbl("", Color(1.0, 0.85, 0.1), 20)
	_winner_lbl.visible = false
	hbox.add_child(_winner_lbl)

	hbox.add_child(_spacer())
	_away_lbl = _lbl("AWAY: 0", Color(1.0, 0.4, 0.3), 17)
	hbox.add_child(_away_lbl)

	if MatchState.is_three_team:
		hbox.add_child(_spacer())
		_third_lbl = _lbl("THIRD: 0", Color(0.3, 1.0, 0.45), 17)
		hbox.add_child(_third_lbl)

func _process(_delta: float) -> void:
	var secs := maxi(0, int(MatchState.act_timer))
	_timer_lbl.text = "%d:%02d" % [secs / 60, secs % 60]

func _on_scores_updated(home: int, away: int, third: int) -> void:
	var cfg := MatchState.config
	_home_lbl.text = "%s: %d" % [cfg.home_team_name, home]
	_away_lbl.text = "%s: %d" % [cfg.away_team_name, away]
	if _third_lbl:
		_third_lbl.text = "%s: %d" % [cfg.third_team_name, third]

func _on_game_over(winner_id: int, _h: int, _a: int, _t: int) -> void:
	var names := ["HOME", "AWAY", "THIRD"]
	_winner_lbl.text = "%s WINS!" % names[clampi(winner_id, 0, 2)]
	_winner_lbl.visible = true
	_timer_lbl.visible = false

func _lbl(text: String, col: Color, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c
