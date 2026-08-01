class_name TeamPortrait
extends Control

## Draws one team's match portrait for the end-of-match display.
## All rendering is done via _draw(); no child nodes.

const C_GOLD   := Color(1.000, 0.796, 0.239)
const C_DIM    := Color(1.0, 1.0, 1.0, 0.32)
const C_SUBTLE := Color(1.0, 1.0, 1.0, 0.06)

# World-space field bounds for 2-team layout
const FIELD_X0 := 0.0
const FIELD_X1 := 140.0
const FIELD_Y0 := 0.0
const FIELD_Y1 := 40.0
const PAD      := 14.0

# ── Public data ────────────────────────────────────────────────────────────────

var team_id:     int    = 0
var team_color:  Color  = Color(0.94, 0.16, 0.22)
var team_name:   String = ""
var final_score: int    = 0
var opp_score:   int    = 0

## [kills, damage, healing, ball_time, carries, goals] — all normalised 0..1
var hex_vals: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0, 0])

# ── Internal data ──────────────────────────────────────────────────────────────

var _ball_samples:    Array = []   # MatchTimeline.BallSample
var _roster:          Array = []   # {name, died_in_act}  (-1 = survived)
var _score_events:    Array = []   # {tick, type, own}
var _act_end_ticks:   Array = []   # cumulative act-end times (seconds)
var _match_duration:  float = 300.0
var _phase_crossings: Array = []   # {tick, team_id, line_index, position}

# ── Setup ──────────────────────────────────────────────────────────────────────

func setup(tid: int, tname: String, score: int, opp: int,
		   h_vals: PackedFloat32Array) -> void:
	team_id     = tid
	team_name   = tname
	final_score = score
	opp_score   = opp
	team_color  = MatchState.team_color(tid)
	hex_vals    = h_vals
	_collect_data()
	queue_redraw()

func setup_from_saved(report: Dictionary, tid: int, tname: String,
		score: int, opp: int, h_vals: PackedFloat32Array) -> void:
	team_id     = tid
	team_name   = tname
	final_score = score
	opp_score   = opp
	team_color  = MatchState.team_color(tid)
	hex_vals    = h_vals
	_load_from_report(report)
	queue_redraw()

func _load_from_report(report: Dictionary) -> void:
	_ball_samples.clear()
	for b in report.get("ball_path", []):
		_ball_samples.append({
			"position": Vector2(b["x"], b["y"]),
			"holder_team": b["holder_team"],
			"charge_norm": b["charge_norm"],
		})

	_phase_crossings.clear()
	for cx in report.get("phase_crossings", []):
		_phase_crossings.append({
			"tick": cx["tick"], "team_id": cx["team_id"],
			"line_index": cx["line_index"],
			"position": Vector2(cx["x"], cx["y"]),
		})

	# Roster: build from players + act_snapshots
	_roster.clear()
	var snaps: Array = report.get("act_snapshots", [])
	for p in report.get("players", []):
		if p["team_id"] != team_id:
			continue
		var pid: String = str(p["player_id"])
		var died_in_act := -1
		for si in range(snaps.size() - 1):
			var alive_now_arr = snaps[si].get("alive_by_team", {}).get(str(team_id), [])
			var alive_next_arr = snaps[si + 1].get("alive_by_team", {}).get(str(team_id), [])
			if alive_now_arr.has(pid) and not alive_next_arr.has(pid):
				died_in_act = snaps[si]["act"]
				break
		_roster.append({"name": p["display_name"], "died_in_act": died_in_act})
	_roster.sort_custom(func(a, b): return a["died_in_act"] < b["died_in_act"])

	_act_end_ticks.clear()
	var total_t := 0.0
	for s in report.get("act_summaries", []):
		total_t += s["duration"]
		_act_end_ticks.append(total_t)
	_match_duration = max(60.0, total_t)

	_score_events.clear()
	for sp in report.get("score_points", []):
		_score_events.append({"tick": sp["tick"], "type": sp["type"],
							  "own": sp["team_id"] == team_id})

func _collect_data() -> void:
	_phase_crossings = MatchTimeline.phase_crossings.duplicate()
	_ball_samples = MatchTimeline.ball_path.duplicate()

	# Roster: on-field players for this team, when they died
	_roster.clear()
	var snaps: Array = MatchTimeline.act_snapshots
	for pid in MatchState.players:
		var rec: MatchState.PlayerRecord = MatchState.players[pid]
		if rec.team_id != team_id or not rec.is_on_field:
			continue
		var died_in_act := -1
		for si in range(snaps.size() - 1):
			var alive_now: bool  = snaps[si].alive_by_team.get(team_id, []).has(pid)
			var alive_next: bool = snaps[si + 1].alive_by_team.get(team_id, []).has(pid)
			if alive_now and not alive_next:
				died_in_act = snaps[si].act
				break
		_roster.append({"name": rec.display_name, "died_in_act": died_in_act})
	# Survivors first, then by act of death ascending
	_roster.sort_custom(func(a, b): return a["died_in_act"] < b["died_in_act"])

	# Score events and cumulative act durations
	_score_events.clear()
	_act_end_ticks.clear()
	var total_t := 0.0
	for summary in MatchTimeline.act_summaries:
		total_t += summary.duration
		_act_end_ticks.append(total_t)
	_match_duration = max(60.0, total_t)
	for sp in MatchTimeline.score_points:
		_score_events.append({"tick": sp.tick, "type": sp.type,
							  "own": sp.team_id == team_id})

# ── Drawing entry point ────────────────────────────────────────────────────────

func _draw() -> void:
	if size.x < 10 or size.y < 10:
		return
	var w := size.x
	var y := 0.0
	y = _draw_header(w, y)
	y = _draw_ball_river(w, y)
	y = _draw_roster_attrition(w, y)
	y = _draw_scoring_timeline(w, y)
	_draw_combat_hexagon(w, y)

# ── Section: team header ───────────────────────────────────────────────────────

func _draw_header(w: float, y: float) -> float:
	const H := 52.0
	draw_rect(Rect2(0, y, w, H), Color(team_color.r, team_color.g, team_color.b, 0.15))
	draw_rect(Rect2(0, y, 4, H), team_color)
	_draw_str(team_name.to_upper(), Vector2(PAD + 8, y + 9), 18, Color.WHITE)
	_draw_str("%d – %d" % [final_score, opp_score], Vector2(PAD + 8, y + 31), 12, C_DIM)
	draw_rect(Rect2(0, y + H - 1, w, 1), Color(1, 1, 1, 0.08))
	return y + H

# ── Section: ball river ────────────────────────────────────────────────────────

func _draw_ball_river(w: float, y: float) -> float:
	const CHART_H := 84.0
	_draw_section_label("BALL RIVER", Vector2(PAD, y + 5))
	y += 20.0

	var r := Rect2(PAD, y, w - PAD * 2, CHART_H)
	draw_rect(r, Color(0, 0, 0, 0.28))

	# Phase-line guides at field thirds
	for i in range(1, 3):
		var px := r.position.x + r.size.x * (i / 3.0)
		draw_rect(Rect2(px, r.position.y, 1, r.size.y), Color(1, 1, 1, 0.06))

	# Ball trajectory
	for i in range(1, _ball_samples.size()):
		var s0 = _ball_samples[i - 1]
		var s1 = _ball_samples[i]
		var p0 := _world_to_river(s0.position, r)
		var p1 := _world_to_river(s1.position, r)
		var col: Color
		if s1.holder_team == team_id:
			col = team_color
		elif s1.holder_team >= 0:
			col = Color(0.45, 0.45, 0.45, 0.55)
		else:
			col = Color(0.55, 0.55, 0.55, 0.38)
		# Warm toward gold as charge rises
		col = col.lerp(C_GOLD, s1.charge_norm * 0.55)
		draw_line(p0, p1, col, 1.5)

	# Latest ball position
	if not _ball_samples.is_empty():
		draw_circle(_world_to_river(_ball_samples[-1].position, r), 3.0, Color.WHITE)

	# Phase-line crossing markers
	for cx in _phase_crossings:
		var p := _world_to_river(cx["position"], r)
		var own: bool = cx["team_id"] == team_id
		var dot_col: Color = team_color if own else Color(0.6, 0.6, 0.6, 0.55)
		draw_circle(p, 3.5, dot_col)
		draw_arc(p, 5.5, 0.0, TAU, 10, Color(dot_col.r, dot_col.g, dot_col.b, 0.4), 1.0)

	return y + CHART_H + 10.0

# ── Section: roster attrition ──────────────────────────────────────────────────

func _draw_roster_attrition(w: float, y: float) -> float:
	const PILL_H   := 22.0
	const PILL_GAP := 4.0
	const COLS     := 5
	_draw_section_label("ROSTER ATTRITION", Vector2(PAD, y + 5))
	y += 20.0

	var pill_w := (w - PAD * 2 - PILL_GAP * (COLS - 1)) / COLS
	var rows_used := 0
	for i in _roster.size():
		var col_i := i % COLS
		var row_i := i / COLS
		rows_used = row_i + 1
		var px := PAD + col_i * (pill_w + PILL_GAP)
		var py := y + row_i * (PILL_H + PILL_GAP)

		var died: int = _roster[i]["died_in_act"]
		var pill_col: Color
		if died == -1:
			pill_col = Color(team_color.r, team_color.g, team_color.b, 0.55)
		else:
			# Earlier death = darker pill
			pill_col = Color(team_color.r, team_color.g, team_color.b,
							 lerpf(0.35, 0.10, float(died - 1) / 4.0))
		draw_rect(Rect2(px, py, pill_w, PILL_H), pill_col)

		var name: String = _roster[i]["name"]
		if name.length() > 7:
			name = name.left(6) + "…"
		var text_col := Color.WHITE if died == -1 else C_DIM
		_draw_str(name, Vector2(px + 3, py + 3), 8, text_col)
		if died != -1:
			_draw_str("A%d" % died, Vector2(px + pill_w - 14, py + 4), 7,
					  Color(1.0, 0.5, 0.4, 0.9))

	var grid_h := float(rows_used) * (PILL_H + PILL_GAP) - PILL_GAP

	# Legend
	var ly := y + grid_h + 5.0
	draw_circle(Vector2(PAD + 4, ly + 5), 4,
				Color(team_color.r, team_color.g, team_color.b, 0.5))
	_draw_str("survived", Vector2(PAD + 12, ly), 7, C_DIM)
	_draw_str("Ax = died in act x", Vector2(PAD + 72, ly), 7, C_DIM)

	return y + grid_h + 18.0 + 8.0

# ── Section: scoring spine ─────────────────────────────────────────────────────

func _draw_scoring_timeline(w: float, y: float) -> float:
	const TL_H := 46.0
	_draw_section_label("SCORING SPINE", Vector2(PAD, y + 5))
	y += 20.0

	var rx := PAD
	var rw := w - PAD * 2
	var mid_y := y + TL_H * 0.5

	draw_rect(Rect2(rx, y, rw, TL_H), Color(0, 0, 0, 0.2))
	draw_rect(Rect2(rx, mid_y - 0.5, rw, 1), Color(1, 1, 1, 0.10))

	# Act dividers
	for t in _act_end_ticks:
		var px: float = rx + (float(t) / _match_duration) * rw
		draw_rect(Rect2(px - 0.5, y, 1, TL_H), Color(1, 1, 1, 0.08))

	# Score events — own team above midline, opponent below
	for ev in _score_events:
		var px := rx + clampf(float(ev["tick"]) / _match_duration, 0.0, 1.0) * rw
		var is_ultra: bool = ev["type"] == "ultra"
		var is_own:   bool = ev["own"]
		var dot_r := 5.0 if is_ultra else 3.5
		var col   := team_color if is_own else Color(1, 1, 1, 0.22)
		var oy    := -(dot_r + 5.0) if is_own else (dot_r + 5.0)
		draw_circle(Vector2(px, mid_y + oy), dot_r, col)
		if is_ultra and is_own:
			draw_arc(Vector2(px, mid_y + oy), dot_r + 2.5, 0.0, TAU, 12,
					 Color(1, 1, 1, 0.4), 1.0)

	return y + TL_H + 8.0

# ── Section: combat hexagon ────────────────────────────────────────────────────

func _draw_combat_hexagon(w: float, y: float) -> void:
	const RADIUS := 68.0
	const N      := 6
	_draw_section_label("COMBAT SIGNATURE", Vector2(PAD, y + 5))
	y += 22.0

	var center := Vector2(w * 0.5, y + RADIUS + 20.0)
	var axes   := ["KILLS", "DAMAGE", "HEALING", "BALL TIME", "CARRIES", "GOALS"]

	# Guide rings at 33 % / 67 % / 100 %
	for pct in [0.33, 0.67, 1.0]:
		var ring := PackedVector2Array()
		for i in N:
			var a := -PI * 0.5 + i * TAU / N
			ring.append(center + Vector2(cos(a), sin(a)) * RADIUS * pct)
		ring.append(ring[0])
		draw_polyline(ring, Color(1, 1, 1, 0.08 if pct < 1.0 else 0.14), 1.0)

	# Axis spokes and labels
	var font := _get_font()
	for i in N:
		var a   := -PI * 0.5 + i * TAU / N
		var tip := center + Vector2(cos(a), sin(a)) * RADIUS
		draw_line(center, tip, Color(1, 1, 1, 0.09), 1.0)
		var lbl: String = axes[i]
		var lbl_w    := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		var lbl_base := font.get_ascent(7)
		var lbl_pos  := center + Vector2(cos(a), sin(a)) * (RADIUS + 14.0)
		draw_string(font, lbl_pos + Vector2(-lbl_w * 0.5, lbl_base * 0.5),
					lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, C_DIM)

	# Filled polygon
	var pts := PackedVector2Array()
	for i in N:
		var a := -PI * 0.5 + i * TAU / N
		var v := hex_vals[i] if i < hex_vals.size() else 0.0
		pts.append(center + Vector2(cos(a), sin(a)) * RADIUS * v)

	if pts.size() >= 3:
		var fill_col := Color(team_color.r, team_color.g, team_color.b, 0.30)
		draw_colored_polygon(pts, fill_col)
		var outline := pts.duplicate()
		outline.append(outline[0])
		draw_polyline(outline, team_color, 1.5)

	# Value dots at each axis tip
	for i in N:
		var a := -PI * 0.5 + i * TAU / N
		var v := hex_vals[i] if i < hex_vals.size() else 0.0
		draw_circle(center + Vector2(cos(a), sin(a)) * RADIUS * v, 2.5, team_color)

# ── Helpers ────────────────────────────────────────────────────────────────────

func _world_to_river(world_pos: Vector2, r: Rect2) -> Vector2:
	var nx := (world_pos.x - FIELD_X0) / (FIELD_X1 - FIELD_X0)
	var ny := (world_pos.y - FIELD_Y0) / (FIELD_Y1 - FIELD_Y0)
	return Vector2(
		r.position.x + clampf(nx, 0.0, 1.0) * r.size.x,
		r.position.y + clampf(ny, 0.0, 1.0) * r.size.y
	)

func _draw_section_label(text: String, pos: Vector2) -> void:
	_draw_str(text, pos, 7, C_DIM)

func _draw_str(text: String, pos: Vector2, sz: int, col: Color) -> void:
	var font := _get_font()
	draw_string(font, pos + Vector2(0, font.get_ascent(sz)),
				text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func _get_font() -> Font:
	var f := FontCache.body()
	return f if f != null else get_theme_font(&"font")
