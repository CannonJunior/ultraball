extends Node
## Autoload — serialises a complete match report to disk on every game_over.
## Reports are stored as JSON in user://match_reports/ (newest-first, max 20 kept).

const SAVE_DIR  := "user://match_reports/"
const MAX_SAVED := 20

func _ready() -> void:
	EventBus.game_over.connect(_on_game_over)

func _on_game_over(winner_id: int, fh: int, fa: int, _ft: int) -> void:
	var report := _capture(winner_id, fh, fa)
	_write(report)

# ── Capture ────────────────────────────────────────────────────────────────────

func _capture(winner_id: int, fh: int, fa: int) -> Dictionary:
	var cfg := MatchState.config
	var report: Dictionary = {
		"timestamp":       Time.get_unix_time_from_system(),
		"winner_id":       winner_id,
		"home_team_name":  cfg.home_team_name  if cfg else "HOME",
		"away_team_name":  cfg.away_team_name  if cfg else "AWAY",
		"final_home_score": fh,
		"final_away_score": fa,
		"match_mode":      cfg.match_mode if cfg else 0,
		"players":         [],
		"act_summaries":   [],
		"score_points":    [],
		"ball_path":       [],
		"phase_crossings": [],
		"act_snapshots":   [],
	}

	for pid in MatchState.players:
		var rec: MatchState.PlayerRecord = MatchState.players[pid]
		if not rec.is_on_field:
			continue
		var st: MatchState.PlayerStatRecord = MatchState.stat(pid)
		report["players"].append({
			"player_id":    pid,
			"display_name": rec.display_name,
			"team_id":      rec.team_id,
			"class_id":     rec.class_id,
			"stats": {
				"kills":        st.kills,
				"deaths":       st.deaths,
				"dmg":          st.dmg,
				"heal":         st.heal,
				"taken":        st.taken,
				"ub":           st.ub,
				"ca":           st.ca,
				"ff":           st.ff,
				"points":       st.points,
				"ball_carries": st.ball_carries,
				"ball_time":    st.ball_time,
				"passes_thrown": st.passes_thrown,
			},
		})

	for s in MatchTimeline.act_summaries:
		report["act_summaries"].append({
			"act": s.act, "duration": s.duration,
			"home_score": s.home_score, "away_score": s.away_score,
			"kills_by_team": s.kills_by_team.duplicate(),
		})

	for sp in MatchTimeline.score_points:
		report["score_points"].append({
			"tick": sp.tick, "act": sp.act,
			"type": sp.type, "team_id": sp.team_id, "scorer_id": sp.scorer_id,
		})

	for bs in MatchTimeline.ball_path:
		report["ball_path"].append({
			"tick": bs.tick,
			"x": bs.position.x, "y": bs.position.y,
			"holder_team": bs.holder_team,
			"charge_norm": bs.charge_norm,
		})

	for cx in MatchTimeline.phase_crossings:
		report["phase_crossings"].append({
			"tick": cx["tick"], "team_id": cx["team_id"],
			"line_index": cx["line_index"],
			"x": cx["position"].x, "y": cx["position"].y,
		})

	for snap in MatchTimeline.act_snapshots:
		var sd: Dictionary = {"act": snap.act, "alive_by_team": {}}
		for tid in snap.alive_by_team:
			sd["alive_by_team"][str(tid)] = snap.alive_by_team[tid]
		report["act_snapshots"].append(sd)

	return report

# ── Persistence ────────────────────────────────────────────────────────────────

func _write(report: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var fname := "match_%d.json" % int(report["timestamp"])
	var f := FileAccess.open(SAVE_DIR + fname, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
	_prune()

func _prune() -> void:
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return
	var files: Array[String] = []
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".json"):
			files.append(name)
		name = dir.get_next()
	files.sort()
	while files.size() > MAX_SAVED:
		DirAccess.remove_absolute(SAVE_DIR + files[0])
		files.remove_at(0)

static func load_all() -> Array:
	var reports: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return reports
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".json"):
			var f := FileAccess.open(SAVE_DIR + name, FileAccess.READ)
			if f:
				var parsed: Variant = JSON.parse_string(f.get_as_text())
				f.close()
				if parsed is Dictionary:
					reports.append(parsed)
		name = dir.get_next()
	reports.sort_custom(func(a, b): return a["timestamp"] > b["timestamp"])
	return reports
