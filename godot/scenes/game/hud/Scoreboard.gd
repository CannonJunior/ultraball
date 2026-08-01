extends Control

const _ProvisionalBar := preload("res://scenes/game/hud/ProvisionalBar.gd")

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

class _HpBar extends _ProvisionalBar:
	func _init() -> void:
		bg_color = Color(1, 1, 1, 0.10)

class _SelectedOutline extends Control:
	var outline_color: Color = Color.TRANSPARENT
	func set_selected(col: Color) -> void:
		outline_color = col
		queue_redraw()
	func clear_selected() -> void:
		outline_color = Color.TRANSPARENT
		queue_redraw()
	func _draw() -> void:
		if outline_color.a > 0.0:
			draw_rect(Rect2(0, 0, size.x, size.y), outline_color, false, 2.0)

var _home_name_lbl : Label
var _home_score_lbl: Label
var _away_name_lbl : Label
var _away_score_lbl: Label
var _act_lbl       : Label
var _timer_lbl     : Label
var _winner_lbl    : Label
var _dots          : Array[ColorRect] = []
var _charge_fill   : ColorRect

var _blink_timer  := 0.0
var _colon_on     := true
var _glow_phase   := 0.0
var _raw_secs     := 180
var _charge_pct   := 0.0

# player_id → {av_bg, init_lbl, hp_bar, kill_lbl, team_color, outline}
var _card_entries         : Dictionary = {}
var _player_node_cache    : Dictionary = {}
var _last_local_player_id : String     = ""
var _home_box         : HBoxContainer = null
var _away_box         : HBoxContainer = null
var _third_name_lbl   : Label         = null
var _third_score_lbl  : Label         = null
var _third_box        : HBoxContainer = null

const PLAYBACK_FPS_3T := 10.0
var _hl_thumbs        : Array[TextureRect] = []
var _hl_frames        : Array              = [[], [], []]
var _hl_frame_idx     : Array[int]         = [0, 0, 0]
var _hl_frame_timer   : Array[float]       = [0.0, 0.0, 0.0]
var _hl_scorer_lbls   : Array[Label]       = []

func _ready() -> void:
	anchor_left   = 0.0; anchor_top    = 0.0
	anchor_right  = 1.0; anchor_bottom = 0.0
	offset_left   = 0.0; offset_top    = 0.0
	offset_right  = 0.0; offset_bottom = BAR_H + 3.0 + CARDS_H
	mouse_filter  = Control.MOUSE_FILTER_IGNORE
	if MatchState.is_three_team:
		_build_3team()
		_build_cards_3team()
		HighlightRecorder.clip_added.connect(_on_3t_clip_added)
	else:
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
	if MatchState.is_three_team:
		_draw_3team()
		return
	var w      := size.x
	var side_w := (w - CENTER_W) * 0.5
	var clx    := side_w
	var crx    := side_w + CENTER_W

	# Home panel (always full width of home section)
	draw_rect(Rect2(0.0, 0.0, clx, BAR_H), C_BG)
	draw_rect(Rect2(0.0, 0.0, clx, BAR_H), Color(MatchState.team_color(0).r, MatchState.team_color(0).g, MatchState.team_color(0).b, 0.70))

	# Center section
	draw_rect(Rect2(clx, 0.0, CENTER_W, BAR_H), C_BG)
	draw_rect(Rect2(clx, 0.0, CENTER_W, BAR_H), Color(0.0, 0.0, 0.0, 0.55))

	# Away panel (always full width of away section)
	draw_rect(Rect2(crx, 0.0, w - crx, BAR_H), C_BG)
	draw_rect(Rect2(crx, 0.0, w - crx, BAR_H), Color(MatchState.team_color(1).r, MatchState.team_color(1).g, MatchState.team_color(1).b, 0.70))

	# Inner border lines at center section edges
	draw_line(Vector2(clx, 0.0), Vector2(clx, BAR_H), Color.WHITE, 2.0)
	draw_line(Vector2(crx, 0.0), Vector2(crx, BAR_H), Color.WHITE, 2.0)

	# Cards section background
	draw_rect(Rect2(0.0, BAR_H + 3.0, w, CARDS_H), Color(C_BG.r, C_BG.g, C_BG.b, 0.90))
	draw_line(Vector2(0.0, BAR_H), Vector2(w, BAR_H), Color(1, 1, 1, 0.05), 1.0)
	draw_line(Vector2(0.0, BAR_H + 3.0 + CARDS_H), Vector2(w, BAR_H + 3.0 + CARDS_H),
			Color(1, 1, 1, 0.05), 1.0)

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

	_home_name_lbl = _lbl(home_name, MatchState.team_color(0), 20)
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

	_away_name_lbl = _lbl(away_name, MatchState.team_color(1), 20)
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

	# Charge bar fill — expands from center outward
	var ball := MatchState.ball
	var pct := clampf(ball.charge_timer / ball.max_charge, 0.0, 1.0) if ball.max_charge > 0.0 else 0.0
	var fill_w := size.x * pct
	_charge_fill.size.x = fill_w
	_charge_fill.position.x = (size.x - fill_w) * 0.5
	_charge_fill.position.y = BAR_H

	# Health bar updates
	_update_card_health()
	_update_card_status()

	# Selection outline refresh when controlled player changes
	var cur_pid := NetworkManager.local_player_id
	if cur_pid != _last_local_player_id:
		_last_local_player_id = cur_pid
		_refresh_selection_outlines()

	# 3-team inline highlight playback
	if MatchState.is_three_team and not _hl_thumbs.is_empty():
		for t in 3:
			if _hl_frames[t].size() < 2: continue
			_hl_frame_timer[t] += delta
			if _hl_frame_timer[t] >= 1.0 / PLAYBACK_FPS_3T:
				_hl_frame_timer[t] -= 1.0 / PLAYBACK_FPS_3T
				_hl_frame_idx[t] = (_hl_frame_idx[t] + 1) % _hl_frames[t].size()
				_hl_thumbs[t].texture = _hl_frames[t][_hl_frame_idx[t]]

func _on_act_started(act: int) -> void:
	_act_lbl.text = "ACT %d" % act
	_timer_lbl.visible = true
	_winner_lbl.visible = false
	_refresh_dots(act)
	_rebuild_cards()

func _on_scores_updated(home: int, away: int, third: int) -> void:
	_home_score_lbl.text = str(home)
	_away_score_lbl.text = str(away)
	if _third_score_lbl:
		_third_score_lbl.text = str(third)

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
	_home_box.alignment = BoxContainer.ALIGNMENT_END
	_home_box.add_theme_constant_override("separation", 0)
	_home_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_home_box)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(CENTER_W, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(spacer)

	_away_box = HBoxContainer.new()
	_away_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_away_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_away_box.add_theme_constant_override("separation", 0)
	_away_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_away_box)

	_rebuild_cards()

func _rebuild_cards() -> void:
	if _home_box == null or _away_box == null: return
	for c in _home_box.get_children(): c.queue_free()
	for c in _away_box.get_children(): c.queue_free()
	if _third_box != null:
		for c in _third_box.get_children(): c.queue_free()
	_card_entries.clear()
	_player_node_cache.clear()

	var home_pids: Array = []
	var away_pids: Array = []
	var third_pids: Array = []
	for n in get_tree().get_nodes_in_group("players"):
		if not n.is_alive or not n.is_on_field: continue
		if n.team_id == 0: home_pids.append(n.player_id)
		elif n.team_id == 1: away_pids.append(n.player_id)
		elif n.team_id == 2: third_pids.append(n.player_id)

	for pid: String in home_pids:
		_home_box.add_child(_make_card(pid))
	for pid: String in away_pids:
		_away_box.add_child(_make_card(pid))
	if _third_box != null:
		for pid: String in third_pids:
			_third_box.add_child(_make_card(pid))
	_refresh_selection_outlines()

func _make_card(pid: String) -> Control:
	var rec: MatchState.PlayerRecord = MatchState.players.get(pid)
	var team  := rec.team_id if rec else 0
	var alive := rec.is_alive if rec else true
	var name_str := rec.display_name if rec and not rec.display_name.is_empty() else pid
	var initial  := name_str.substr(0, 1).to_upper()
	var tc       := MatchState.team_color(team)
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

	# Target outline on all cards; click sets explicit target on the local player
	var outline := _SelectedOutline.new()
	outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.add_child(outline)
	av.mouse_filter = Control.MOUSE_FILTER_STOP
	av.gui_input.connect(_on_avatar_clicked.bind(pid))

	# Status dots — 6 fixed-purpose tiny colored dots at avatar bottom-left
	# Order: stun / snare / confused / hex / mark / any-buff
	const _DOT_W := 4; const _DOT_H := 4; const _DOT_GAP := 1
	const _DOT_COUNT := 6
	var s_dots: Array[ColorRect] = []
	for k in _DOT_COUNT:
		var sd := ColorRect.new()
		sd.position = Vector2(k * (_DOT_W + _DOT_GAP), AVATAR_SZ - _DOT_H - 1)
		sd.size = Vector2(_DOT_W, _DOT_H)
		sd.color = Color.TRANSPARENT
		sd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		av.add_child(sd)
		s_dots.append(sd)

	# Health bar
	var hp_bar: _HpBar = _HpBar.new()
	hp_bar.custom_minimum_size = Vector2(HP_BAR_W, HP_BAR_H)
	hp_bar.fill_color = tc if alive else Color(0.45, 0.45, 0.45)
	col.add_child(hp_bar)

	_card_entries[pid] = {
		"av_bg":       av_bg,
		"init_lbl":    init_lbl,
		"hp_bar":      hp_bar,
		"kill_lbl":    kill_lbl,
		"team_color":  tc,
		"outline":     outline,
		"status_dots": s_dots,
	}
	return margin

func _on_avatar_clicked(event: InputEvent, pid: String) -> void:
	if not (event is InputEventMouseButton): return
	var mb := event as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT): return
	var local := _get_player_node(NetworkManager.local_player_id)
	if local == null: return
	local.set_explicit_target(pid)
	_refresh_selection_outlines()

func _refresh_selection_outlines() -> void:
	var local := _get_player_node(NetworkManager.local_player_id)
	var target_id: String = local.current_target_id if local != null else ""
	for pid: String in _card_entries:
		var outline = _card_entries[pid].get("outline")
		if outline == null: continue
		if pid == target_id:
			(outline as _SelectedOutline).set_selected(C_GOLD)
		else:
			(outline as _SelectedOutline).clear_selected()

func _update_card_health() -> void:
	for pid: String in _card_entries:
		var node := _get_player_node(pid)
		if node == null: continue
		var buffs := node.get_node_or_null("PlayerBuffs")
		if buffs == null: continue
		var mx: float = buffs.get("max_health")
		var hp: float = buffs.get("health")
		var prov: float = buffs.get("provisional_damage")
		if mx > 0.0:
			(_card_entries[pid]["hp_bar"] as _HpBar).set_health(hp / mx, prov / mx)

func _update_card_status() -> void:
	for pid: String in _card_entries:
		var dots: Array = _card_entries[pid].get("status_dots", [])
		if dots.is_empty():
			continue
		var node := _get_player_node(pid)
		var buffs: Node = node.get_node_or_null("PlayerBuffs") if node != null else null
		# Dot 0=stun, 1=snare, 2=confused, 3=hex, 4=mark, 5=any_buff
		var vals := [
			buffs.get("stun_timer")               if buffs else 0.0,
			buffs.get("snare_remaining")           if buffs else 0.0,
			buffs.get("confused_timer")            if buffs else 0.0,
			buffs.get("hex_timer")                 if buffs else 0.0,
			buffs.get("marked_timer")              if buffs else 0.0,
		]
		var buff_active: bool = buffs != null and (
			buffs.get("speed_mult_remaining") > 0.05 or
			buffs.get("damage_boost_remaining") > 0.05 or
			buffs.get("damage_reduction_remaining") > 0.05 or
			buffs.get("stun_immune_remaining") > 0.05 or
			buffs.get("dodge_remaining") > 0.05 or
			buffs.get("hot_remaining") > 0.05 or
			buffs.get("stormseeker_remaining") > 0.05
		)
		const DEBUFF_COLORS := [
			Color(0.95, 0.95, 0.10),  # stun — yellow
			Color(0.85, 0.30, 0.10),  # snare — orange
			Color(0.80, 0.20, 0.80),  # confused — purple
			Color(0.60, 0.10, 0.60),  # hex — dark purple
			Color(0.95, 0.20, 0.20),  # mark — red
		]
		for i in 5:
			(dots[i] as ColorRect).color = DEBUFF_COLORS[i] if (vals[i] as float) > 0.05 else Color.TRANSPARENT
		(dots[5] as ColorRect).color = Color(0.25, 0.95, 0.35) if buff_active else Color.TRANSPARENT

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
	bar.set_health(0.0, 0.0)

func _on_card_player_subbed(pid: String, _replaced: String, team: int) -> void:
	if not _card_entries.has(pid):
		_rebuild_cards()
		return
	var e: Dictionary = _card_entries[pid]
	var tc := MatchState.team_color(team)
	(e["av_bg"]    as ColorRect).color  = Color(tc.r, tc.g, tc.b, 0.65)
	(e["init_lbl"] as Label).modulate.a = 1.0
	var bar := e["hp_bar"] as _HpBar
	bar.fill_color = tc
	bar.set_health(1.0, 0.0)

func _on_card_killa_scored(_killer_team: int, killer_id: String, _victim_id: String) -> void:
	if killer_id.is_empty() or not _card_entries.has(killer_id): return
	var kills := MatchState.stat(killer_id).kills
	var kill_lbl := _card_entries[killer_id]["kill_lbl"] as Label
	kill_lbl.text    = str(kills)
	kill_lbl.visible = true

# ── 3-team layout ─────────────────────────────────────────────────────────────

func _draw_3team() -> void:
	var w := size.x
	draw_rect(Rect2(0, 0, CENTER_W, BAR_H), C_BG)
	draw_rect(Rect2(0, 0, CENTER_W, BAR_H), Color(0, 0, 0, 0.55))
	var team_w := (w - CENTER_W) / 3.0
	for t in 3:
		var tx := CENTER_W + t * team_w
		var tc := MatchState.team_color(t)
		draw_rect(Rect2(tx, 0, team_w, BAR_H), C_BG)
		draw_rect(Rect2(tx, 0, team_w, BAR_H), Color(tc.r, tc.g, tc.b, 0.60))
		draw_line(Vector2(tx, 0), Vector2(tx, BAR_H), Color.WHITE, 1.0)
	draw_rect(Rect2(0.0, BAR_H + 3.0, w, CARDS_H), Color(C_BG.r, C_BG.g, C_BG.b, 0.90))
	draw_line(Vector2(0.0, BAR_H), Vector2(w, BAR_H), Color(1, 1, 1, 0.05), 1.0)
	draw_line(Vector2(0.0, BAR_H + 3.0 + CARDS_H), Vector2(w, BAR_H + 3.0 + CARDS_H), Color(1, 1, 1, 0.05), 1.0)

func _build_3team() -> void:
	var cfg := MatchState.config
	var team_names := [
		cfg.home_team_name  if cfg else "HOME",
		cfg.away_team_name  if cfg else "AWAY",
		cfg.third_team_name if cfg else "THIRD",
	]

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.anchor_left = 0.0; hbox.anchor_top = 0.0
	hbox.anchor_right = 1.0; hbox.anchor_bottom = 0.0
	hbox.offset_left = 0.0; hbox.offset_top = 0.0
	hbox.offset_right = 0.0; hbox.offset_bottom = BAR_H
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)

	# Far-left: act info panel
	var center_vbox := VBoxContainer.new()
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 3)
	center_vbox.custom_minimum_size.x = CENTER_W
	center_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(center_vbox)

	_act_lbl = _lbl("ACT 1", C_GOLD, 10)
	_act_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_vbox.add_child(_act_lbl)

	_timer_lbl = _lbl("3:00", C_CYAN, 34)
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_vbox.add_child(_timer_lbl)

	_winner_lbl = _lbl("", C_GOLD, 18)
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

	# One section per team: [score vbox] [highlight area]
	_hl_thumbs.resize(3)
	_hl_scorer_lbls.resize(3)

	for t in 3:
		var tc := MatchState.team_color(t)

		var team_section := HBoxContainer.new()
		team_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		team_section.add_theme_constant_override("separation", 0)
		team_section.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(team_section)

		# Score column
		var score_vbox := VBoxContainer.new()
		score_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		score_vbox.add_theme_constant_override("separation", 2)
		score_vbox.custom_minimum_size.x = 150.0
		score_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		team_section.add_child(score_vbox)

		var name_lbl := _lbl(team_names[t], tc, 14)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_vbox.add_child(name_lbl)

		var score_lbl := _lbl("0", Color.WHITE, 36)
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_vbox.add_child(score_lbl)

		match t:
			0: _home_name_lbl = name_lbl; _home_score_lbl = score_lbl
			1: _away_name_lbl = name_lbl; _away_score_lbl = score_lbl
			2: _third_name_lbl = name_lbl; _third_score_lbl = score_lbl

		# Highlight thumbnail area
		var hl_area := Control.new()
		hl_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hl_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		team_section.add_child(hl_area)

		var hl_bg := ColorRect.new()
		hl_bg.color = Color(tc.r, tc.g, tc.b, 0.08)
		hl_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		hl_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hl_area.add_child(hl_bg)

		var thumb := TextureRect.new()
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_SCALE
		thumb.set_anchors_preset(Control.PRESET_FULL_RECT)
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.visible = false
		hl_area.add_child(thumb)
		_hl_thumbs[t] = thumb

		var ovl := ColorRect.new()
		ovl.color = Color(0, 0, 0, 0.35)
		ovl.set_anchors_preset(Control.PRESET_FULL_RECT)
		ovl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hl_area.add_child(ovl)

		var scorer_lbl := _lbl("", Color.WHITE, 9)
		scorer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scorer_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		scorer_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		scorer_lbl.offset_bottom = -4.0
		scorer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hl_area.add_child(scorer_lbl)
		_hl_scorer_lbls[t] = scorer_lbl

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

func _build_cards_3team() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",     8)
	margin.add_theme_constant_override("margin_bottom",  8)
	margin.anchor_left = 0.0; margin.anchor_right = 1.0
	margin.anchor_top = 0.0; margin.anchor_bottom = 0.0
	margin.offset_top = BAR_H + 3.0
	margin.offset_bottom = BAR_H + 3.0 + CARDS_H
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(CENTER_W, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(spacer)

	_home_box = HBoxContainer.new()
	_home_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_home_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_home_box.add_theme_constant_override("separation", 0)
	_home_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_home_box)

	_away_box = HBoxContainer.new()
	_away_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_away_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_away_box.add_theme_constant_override("separation", 0)
	_away_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_away_box)

	_third_box = HBoxContainer.new()
	_third_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_third_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_third_box.add_theme_constant_override("separation", 0)
	_third_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_third_box)

	_rebuild_cards()

func _on_3t_clip_added(clip: Dictionary) -> void:
	var t: int = clip["team_id"]
	if t < 0 or t >= _hl_thumbs.size(): return
	var frames: Array = clip.get("frames", [])
	if not frames.is_empty():
		_hl_frames[t] = frames
		_hl_frame_idx[t] = 0
		_hl_frame_timer[t] = 0.0
		_hl_thumbs[t].texture = frames[0]
		_hl_thumbs[t].visible = true
	elif clip.get("texture") != null:
		_hl_frames[t] = []
		_hl_thumbs[t].texture = clip["texture"]
		_hl_thumbs[t].visible = true
	_hl_scorer_lbls[t].text = (clip["scorer_name"] as String).to_upper()

