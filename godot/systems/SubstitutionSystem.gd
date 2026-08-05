class_name SubstitutionSystem
extends Node

## Single owner of the death → substitution flow.
## Acts 1–4: each team may substitute once per act (first death only).
## Act 5: unlimited substitutions until the roster is empty.

## team_id → true once a sub has been used in the current act.
var _subs_used: Dictionary = {}

func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)
	EventBus.act_ended.connect(_on_act_ended)
	EventBus.act_started.connect(_on_act_started)

func _on_act_started(act: int) -> void:
	_subs_used.clear()
	_print_bench_state(act)

func _on_player_died(player_id: String, cause: String, killer_id: String) -> void:
	var rec: MatchState.PlayerRecord = MatchState.players.get(player_id)
	if rec == null:
		print("[DEATH] player_id=%s not found in MatchState.players (size=%d)" % [player_id, MatchState.players.size()])
		return
	rec.is_alive = false
	rec.is_on_field = false

	print("[DEATH] player=%s cause=%s killer=%s" % [player_id, cause, killer_id])

	# Drop ball if this player was holding it
	if MatchState.ball.holder_id == player_id:
		EventBus.ball_dropped.emit(
			_get_player_position(player_id), "death"
		)

	if MatchState.act_ended:
		print("[DEATH] bailed: act_ended=true (act=%d)" % MatchState.current_act)
		return

	# Acts 1–4: only the first death per team triggers a sub.
	# Act 5: every death triggers a sub until the roster is empty.
	if MatchState.current_act < 5 and _subs_used.get(rec.team_id, false):
		print("[DEATH] team %d already used sub this act" % rec.team_id)
		return

	var next := _next_reserve(rec.team_id)
	if next == null:
		var bench_count := 0
		for pid in MatchState.players:
			var r: MatchState.PlayerRecord = MatchState.players[pid]
			if r.team_id == rec.team_id and r.is_alive and not r.is_on_field:
				bench_count += 1
		print("[DEATH] team %d no reserve — bench_alive_off_field=%d total_players=%d act=%d" % [
			rec.team_id, bench_count, MatchState.players.size(), MatchState.current_act])
		return

	if MatchState.current_act < 5:
		_subs_used[rec.team_id] = true

	_sub_in(next, player_id)

func _sub_in(reserve: MatchState.PlayerRecord, replaced_id: String) -> void:
	reserve.is_alive = true
	reserve.is_on_field = true
	print("[SUB] %s subbed in for %s (team %d)" % [reserve.player_id, replaced_id, reserve.team_id])
	EventBus.event_message_shown.emit("SUB IN — %s" % reserve.display_name, 2.5)
	EventBus.player_subbed_in.emit(reserve.player_id, replaced_id, reserve.team_id)
	EventBus.healing_applied.emit("", reserve.player_id, 9999.0)

func _next_reserve(team_id: int) -> MatchState.PlayerRecord:
	var candidates: Array = []
	for pid in MatchState.players:
		var rec: MatchState.PlayerRecord = MatchState.players[pid]
		if rec.team_id != team_id: continue
		if rec.is_alive and not rec.is_on_field:
			candidates.append(rec)
	if candidates.is_empty(): return null
	# Sort by deploy_slot ascending (lowest deploy_slot = first sub in)
	candidates.sort_custom(func(a, b): return a.deploy_slot < b.deploy_slot)
	return candidates[0]

func _on_act_ended(_act: int, _s0: int, _s1: int, _s2: int) -> void:
	var pps: int = MatchState.config.players_per_side if MatchState.config else 7

	# Count living on-field players per team before touching anything.
	var on_field_count: Dictionary = {}
	var to_revive: Array = []
	for pid in MatchState.players:
		var rec: MatchState.PlayerRecord = MatchState.players[pid]
		if rec.is_alive and rec.is_on_field:
			on_field_count[rec.team_id] = on_field_count.get(rec.team_id, 0) + 1
		elif not rec.is_alive:
			to_revive.append(rec)

	# Process original starters first (lowest deploy_slot) so field slots go to
	# the players who were meant to start, not whichever sub happened to die.
	to_revive.sort_custom(func(a, b): return a.deploy_slot < b.deploy_slot)

	for rec in to_revive:
		rec.is_alive = true
		var count: int = on_field_count.get(rec.team_id, 0)
		if count < pps:
			rec.is_on_field = true
			on_field_count[rec.team_id] = count + 1
			EventBus.player_subbed_in.emit(rec.player_id, "", rec.team_id)
			EventBus.healing_applied.emit("", rec.player_id, 9999.0)
		else:
			# Field is already at capacity — bench this player as a reserve
			# for the next act. _sub_in will spawn/show them when they're needed.
			rec.is_on_field = false

func _print_bench_state(act: int) -> void:
	var bench_per_team: Dictionary = {}
	var field_per_team: Dictionary = {}
	for pid in MatchState.players:
		var r: MatchState.PlayerRecord = MatchState.players[pid]
		if r.is_alive and not r.is_on_field:
			bench_per_team[r.team_id] = bench_per_team.get(r.team_id, 0) + 1
		if r.is_alive and r.is_on_field:
			field_per_team[r.team_id] = field_per_team.get(r.team_id, 0) + 1
	var pps := MatchState.config.players_per_side if MatchState.config else -1
	print("[SUB] act=%d pps=%d bench=%s field=%s total_players=%d" % [act, pps, bench_per_team, field_per_team, MatchState.players.size()])

func _get_player_position(pid: String) -> Vector2:
	for node in get_tree().get_nodes_in_group("players"):
		if node.player_id == pid:
			return node.global_position
	return Vector2.ZERO
