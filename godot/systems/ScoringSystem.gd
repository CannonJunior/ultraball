class_name ScoringSystem
extends Node

## Single owner of all scoring logic and act timer.
## Fixes the current BallSystem↔ActSystem bidirectional coupling.

const ULTRA_POINTS := 7
const META_POINTS := 3
const KILLA_POINTS := 1
const ULTRA_MANA_PER_KILLA := 1.0

func _ready() -> void:
	EventBus.ball_phase_line_crossed.connect(_on_phase_line_crossed)
	EventBus.ball_caught.connect(_on_ball_caught)
	EventBus.ball_entered_endzone_3t.connect(_on_ball_entered_endzone_3t)
	EventBus.player_died.connect(_on_player_died)
	EventBus.ball_exploded.connect(_on_ball_exploded)
	EventBus.act_started.connect(_on_act_started)
	EventBus.act_transition_complete.connect(_on_act_transition_complete)

func _physics_process(delta: float) -> void:
	if not MatchState.match_active or MatchState.act_ended or MatchState.game_over:
		return
	MatchState.act_timer -= delta
	EventBus.act_timer_changed.emit(MatchState.act_timer)

	if MatchState.act_timer <= 0.0:
		_end_current_act()
	elif MatchState.current_act == 5 and _act5_overtime_trigger():
		_end_current_act()

# ── Phase line crossing → Ultra scoring ───────────────────────────────────────

func _on_phase_line_crossed(team_id: int, line_index: int) -> void:
	var ball := MatchState.ball
	if ball.holder_id.is_empty(): return
	if MatchState.team_for_player(ball.holder_id) != team_id: return

	if _is_ultra_scoring_line(line_index, team_id):
		EventBus.ultra_scored.emit(team_id, ball.holder_id)
		MatchState.add_score(team_id, ULTRA_POINTS)
		EventBus.event_message_shown.emit("ULTRA!", 2.0)

## Phase lines at x=30,50,70,90,110 (5 lines). Team HOME scores crossing line 4 (x=110).
## Team AWAY scores crossing line 0 (x=30, travelling left).
func _is_ultra_scoring_line(line_index: int, team_id: int) -> bool:
	if not MatchState.is_three_team:
		match team_id:
			0: return line_index == 4   # HOME: cross rightmost line
			1: return line_index == 0   # AWAY: cross leftmost line
	return false  # 3-team scoring handled separately

# ── 3-team endzone entry → Ultra scoring ──────────────────────────────────────

func _on_ball_entered_endzone_3t(holder_id: String) -> void:
	var team := MatchState.team_for_player(holder_id)
	if team < 0: return
	EventBus.ultra_scored.emit(team, holder_id)
	MatchState.add_score(team, ULTRA_POINTS)
	EventBus.event_message_shown.emit("ULTRA!", 2.0)

# ── Catch in endzone → Meta scoring ───────────────────────────────────────────

func _on_ball_caught(catcher_id: String) -> void:
	if not _is_in_endzone(catcher_id): return
	var team := MatchState.team_for_player(catcher_id)
	if team < 0: return
	if MatchState.ball.possessing_team_id == team:
		EventBus.meta_scored.emit(team, catcher_id)
		MatchState.add_score(team, META_POINTS)
		EventBus.event_message_shown.emit("META!", 2.0)

func _is_in_endzone(player_id: String) -> bool:
	var pos := _get_player_position(player_id)
	var team := MatchState.team_for_player(player_id)
	if MatchState.is_three_team:
		return _is_in_endzone_3t(pos, team)
	if team == 0: return pos.x >= 130.0   # HOME endzone: right side
	if team == 1: return pos.x <= 10.0    # AWAY endzone: left side
	return false

func _is_in_endzone_3t(pos: Vector2, team: int) -> bool:
	if team < 0 or team >= MatchState.TEAM3_NORMALS.size(): return false
	var center := Vector2(MatchState.FIELD3_CX, MatchState.FIELD3_CY)
	var norm: Vector2 = MatchState.TEAM3_NORMALS[team]
	if (pos - center).dot(norm) < MatchState.FIELD3_CHAN_OUTER: return false
	var perp := Vector2(-norm.y, norm.x)
	return absf((pos - center).dot(perp)) <= MatchState.FIELD3_ARM_HALF_W

# ── Player death → Killa scoring ──────────────────────────────────────────────

func _on_player_died(player_id: String, _cause: String, killer_id: String) -> void:
	if killer_id.is_empty(): return
	var killer_team := MatchState.team_for_player(killer_id)
	if killer_team < 0: return
	EventBus.killa_scored.emit(killer_team, killer_id, player_id)
	MatchState.add_score(killer_team, KILLA_POINTS)
	MatchState.kills[killer_team] += 1
	# Award ultra mana to killer (handled by PlayerMana component via buff signal)
	EventBus.buff_applied.emit(killer_id, "ultra_mana_gain", ULTRA_MANA_PER_KILLA)

func _on_ball_exploded(holder_id: String) -> void:
	if holder_id.is_empty(): return
	var victim_team := MatchState.team_for_player(holder_id)
	# 3-team: cycle killa to next team (0→1→2→0); 2-team: simple inversion
	var opposing := (victim_team + 1) % 3 if MatchState.is_three_team else 1 - victim_team
	EventBus.killa_scored.emit(opposing, "", holder_id)
	MatchState.add_score(opposing, KILLA_POINTS)
	MatchState.kills[opposing] += 1

# ── Act timer management ───────────────────────────────────────────────────────

func _on_act_started(act_number: int) -> void:
	MatchState.current_act = act_number
	MatchState.reset_for_new_act()

func _end_current_act() -> void:
	MatchState.act_ended = true
	if MatchState.current_act == 4:
		var leading := _determine_winner()
		MatchState.act5_leading_team = leading
		MatchState.act5_ultra_target = MatchState.scores[leading] + 3 * ULTRA_POINTS
	EventBus.act_ended.emit(
		MatchState.current_act,
		MatchState.scores[0], MatchState.scores[1], MatchState.scores[2]
	)
	if MatchState.current_act >= 5:
		_end_game()
	else:
		var next := MatchState.current_act + 1
		await get_tree().create_timer(2.0).timeout
		EventBus.act_transition_complete.emit(next)
		EventBus.act_started.emit(next)

func _end_game() -> void:
	MatchState.game_over = true
	var winner := _determine_winner()
	EventBus.game_over.emit(winner, MatchState.scores[0], MatchState.scores[1], MatchState.scores[2])

func _determine_winner() -> int:
	var best := 0
	for i in MatchState.scores.size():
		if MatchState.scores[i] > MatchState.scores[best]:
			best = i
	return best

func _act5_overtime_trigger() -> bool:
	var leading := MatchState.act5_leading_team
	if leading < 0: return false
	return MatchState.scores[leading] >= MatchState.act5_ultra_target

func _on_act_transition_complete(_next_act: int) -> void:
	EventBus.positions_reset.emit()

# ── Helper ─────────────────────────────────────────────────────────────────────

func _get_player_position(pid: String) -> Vector2:
	for node in get_tree().get_nodes_in_group("players"):
		if node.player_id == pid:
			return node.global_position
	return Vector2.ZERO
