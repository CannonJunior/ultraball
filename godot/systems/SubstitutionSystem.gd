class_name SubstitutionSystem
extends Node

## Single owner of the death → substitution flow.
## Fixes: death logic previously scattered across CombatSystem, TerrainSystem,
## CreatureSystem, and BallSystem.

func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)
	EventBus.act_ended.connect(_on_act_ended)

func _on_player_died(player_id: String, _cause: String, _killer_id: String) -> void:
	var rec: MatchState.PlayerRecord = MatchState.players.get(player_id)
	if rec == null: return
	rec.is_alive = false
	rec.is_on_field = false

	# Drop ball if this player was holding it
	if MatchState.ball.holder_id == player_id:
		EventBus.ball_dropped.emit(
			_get_player_position(player_id), "death"
		)

	# Find next reserve for this team
	var next := _next_reserve(rec.team_id)
	if next == null:
		return  # roster depleted — no sub available

	# Sub in immediately unless act has ended (act-end subs handled separately)
	if not MatchState.act_ended:
		_sub_in(next, player_id)

func _sub_in(reserve: MatchState.PlayerRecord, replaced_id: String) -> void:
	reserve.is_alive = true
	reserve.is_on_field = true
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
	for pid in MatchState.players:
		var rec: MatchState.PlayerRecord = MatchState.players[pid]
		if not rec.is_alive:
			rec.is_alive = true
			rec.is_on_field = true
			EventBus.player_subbed_in.emit(rec.player_id, "", rec.team_id)
			EventBus.healing_applied.emit("", rec.player_id, 9999.0)

func _get_player_position(pid: String) -> Vector2:
	for node in get_tree().get_nodes_in_group("players"):
		if node.player_id == pid:
			return node.global_position
	return Vector2.ZERO
