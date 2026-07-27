extends Node

## Periodic time-series recorder used by the end-of-match portrait display.
## Samples ball position every 2 s; captures events, act snapshots, and score arcs.

# ── Inner types ────────────────────────────────────────────────────────────────

class BallSample:
	var tick: float           # seconds since match start
	var position: Vector2
	var holder_team: int      # -1 = loose / in-flight
	var charge_norm: float    # charge_timer / max_charge, 0–1

class MatchEvent:
	var tick: float
	var type: String          # "ultra"|"meta"|"killa"|"death"|"terrain_<type>"
	var team_id: int          # -1 = neutral
	var player_id: String
	var position: Vector2

class ActRosterSnapshot:
	var act: int
	var alive_by_team: Dictionary   # team_id (int) → Array[String] player_ids

class ActSummary:
	var act: int
	var duration: float
	var home_score: int
	var away_score: int
	var third_score: int
	var kills_by_team: Dictionary   # team_id (int) → int

class ScorePoint:
	var tick: float
	var act: int
	var type: String          # "ultra" | "meta"
	var team_id: int
	var scorer_id: String

# ── Public data arrays (read by portrait display after game_over) ──────────────

var ball_path: Array = []        # Array[BallSample]
var events: Array = []           # Array[MatchEvent]
var act_snapshots: Array = []    # Array[ActRosterSnapshot]
var act_summaries: Array = []    # Array[ActSummary]
var score_points: Array = []     # Array[ScorePoint]
var phase_crossings: Array = []  # Array[{tick, team_id, line_index, position}]

# ── Internal state ─────────────────────────────────────────────────────────────

var _active: bool = false
var _match_start_usec: int = 0
var _act_start_usec: int = 0
var _ball_timer: float = 0.0
var _current_act: int = 1
var _act_kills: Dictionary = {}  # team_id → int for the current act

const BALL_SAMPLE_INTERVAL := 2.0

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	EventBus.act_started.connect(_on_act_started)
	EventBus.act_ended.connect(_on_act_ended)
	EventBus.game_over.connect(_on_game_over)
	EventBus.ball_phase_line_crossed.connect(_on_phase_line_crossed)
	EventBus.ultra_scored.connect(_on_ultra_scored)
	EventBus.meta_scored.connect(_on_meta_scored)
	EventBus.killa_scored.connect(_on_killa_scored)
	EventBus.player_died.connect(_on_player_died)
	EventBus.terrain_modified.connect(_on_terrain_modified)

func _process(delta: float) -> void:
	if not _active: return
	_ball_timer += delta
	if _ball_timer >= BALL_SAMPLE_INTERVAL:
		_ball_timer = 0.0
		_sample_ball()

# ── Helpers ────────────────────────────────────────────────────────────────────

func _now() -> float:
	return (Time.get_ticks_usec() - _match_start_usec) / 1_000_000.0

func _sample_ball() -> void:
	var s := BallSample.new()
	s.tick = _now()
	s.position = MatchState.ball.position
	s.holder_team = MatchState.ball.possessing_team_id
	s.charge_norm = MatchState.ball.charge_timer / max(1.0, MatchState.ball.max_charge)
	ball_path.append(s)

func _snapshot_roster(act: int) -> void:
	var snap := ActRosterSnapshot.new()
	snap.act = act
	snap.alive_by_team = {}
	for pid in MatchState.players:
		var rec: MatchState.PlayerRecord = MatchState.players[pid]
		if rec.is_alive and rec.is_on_field:
			if not snap.alive_by_team.has(rec.team_id):
				snap.alive_by_team[rec.team_id] = []
			snap.alive_by_team[rec.team_id].append(pid)
	act_snapshots.append(snap)

# ── Signal handlers ────────────────────────────────────────────────────────────

func _on_act_started(act_number: int) -> void:
	if act_number == 1:
		_active = true
		_match_start_usec = Time.get_ticks_usec()
		ball_path.clear()
		events.clear()
		act_snapshots.clear()
		act_summaries.clear()
		score_points.clear()
		phase_crossings.clear()
	_current_act = act_number
	_act_start_usec = Time.get_ticks_usec()
	_act_kills = {}
	_ball_timer = 0.0
	_snapshot_roster(act_number)

func _on_act_ended(act_number: int, home_score: int, away_score: int, third_score: int) -> void:
	var summary := ActSummary.new()
	summary.act = act_number
	summary.duration = (Time.get_ticks_usec() - _act_start_usec) / 1_000_000.0
	summary.home_score = home_score
	summary.away_score = away_score
	summary.third_score = third_score
	summary.kills_by_team = _act_kills.duplicate()
	act_summaries.append(summary)

func _on_game_over(_winner_id: int, _fh: int, _fa: int, _ft: int) -> void:
	_active = false

func _on_ultra_scored(team_id: int, scorer_id: String) -> void:
	if not _active: return
	var e := MatchEvent.new()
	e.tick = _now()
	e.type = "ultra"
	e.team_id = team_id
	e.player_id = scorer_id
	e.position = MatchState.ball.position
	events.append(e)
	var sp := ScorePoint.new()
	sp.tick = e.tick
	sp.act = _current_act
	sp.type = "ultra"
	sp.team_id = team_id
	sp.scorer_id = scorer_id
	score_points.append(sp)

func _on_meta_scored(team_id: int, scorer_id: String) -> void:
	if not _active: return
	var e := MatchEvent.new()
	e.tick = _now()
	e.type = "meta"
	e.team_id = team_id
	e.player_id = scorer_id
	e.position = MatchState.ball.position
	events.append(e)
	var sp := ScorePoint.new()
	sp.tick = e.tick
	sp.act = _current_act
	sp.type = "meta"
	sp.team_id = team_id
	sp.scorer_id = scorer_id
	score_points.append(sp)

func _on_killa_scored(team_id: int, killer_id: String, victim_id: String) -> void:
	if not _active: return
	_act_kills[team_id] = _act_kills.get(team_id, 0) + 1
	var e := MatchEvent.new()
	e.tick = _now()
	e.type = "killa"
	e.team_id = team_id
	e.player_id = killer_id
	e.position = MatchState.ball.position
	events.append(e)

func _on_player_died(player_id: String, cause: String, _killer_id: String) -> void:
	if not _active: return
	var rec: MatchState.PlayerRecord = MatchState.players.get(player_id)
	var e := MatchEvent.new()
	e.tick = _now()
	e.type = "death"
	e.team_id = rec.team_id if rec else -1
	e.player_id = player_id
	e.position = MatchState.ball.position  # proxy; player nodes not accessible here
	events.append(e)

func _on_phase_line_crossed(team_id: int, line_index: int) -> void:
	if not _active: return
	phase_crossings.append({
		"tick": _now(),
		"team_id": team_id,
		"line_index": line_index,
		"position": MatchState.ball.position,
	})

func _on_terrain_modified(event_type: String, world_pos: Vector2, _radius: float, _duration: float, _intensity: float) -> void:
	if not _active: return
	var e := MatchEvent.new()
	e.tick = _now()
	e.type = "terrain_" + event_type
	e.team_id = -1
	e.player_id = ""
	e.position = world_pos
	events.append(e)
