class_name ClientPredictor
extends Node

## Client-side prediction for the local player.
## Applies input immediately, buffers predicted states, and reconciles
## against server snapshots to correct mispredictions.
## Also applies remote player states from each snapshot (no interpolation — snap).

const RING_SIZE := 64
const RECONCILE_THRESHOLD := 0.1   # metres

var _ring: Array = []               # circular buffer of {tick, position, rotation}
var _ring_head: int = 0
var _last_confirmed_tick: int = -1

## Input history for replay after rollback: tick -> InputState
var _input_history: Dictionary = {}

func _ready() -> void:
	add_to_group("client_predictors")

func record_prediction(tick: int, player_node: Node, input: InputState) -> void:
	var entry := {
		"tick": tick,
		"position": player_node.global_position,
		"rotation": player_node.rotation,
		"velocity": player_node.velocity,
	}
	if _ring.size() < RING_SIZE:
		_ring.append(entry)
	else:
		_ring[_ring_head % RING_SIZE] = entry
	_ring_head += 1
	_input_history[tick] = input
	# Prune old history
	for k in _input_history.keys():
		if k < tick - RING_SIZE:
			_input_history.erase(k)

func reconcile(snapshot: GameSnapshot) -> void:
	if snapshot.tick <= _last_confirmed_tick: return
	_last_confirmed_tick = snapshot.tick

	# 1. Apply authoritative state to MatchState and remote player nodes
	_apply_snapshot_state(snapshot)

	# 2. Reconcile local player prediction
	var local_pid := NetworkManager.local_player_id
	if local_pid.is_empty(): return
	var server_state := snapshot.get_player_snapshot(local_pid)
	if server_state.is_empty(): return

	var predicted := _find_predicted(snapshot.tick)
	if predicted.is_empty(): return

	var delta_pos: float = (server_state["position"] - predicted["position"]).length()
	if delta_pos > RECONCILE_THRESHOLD:
		_rollback_and_replay(server_state, snapshot.tick)

# ── Snapshot application ───────────────────────────────────────────────────────

func _apply_snapshot_state(snapshot: GameSnapshot) -> void:
	var local_pid := NetworkManager.local_player_id

	# Authoritative scores, act state
	for i in snapshot.scores.size():
		if i < MatchState.scores.size():
			MatchState.scores[i] = snapshot.scores[i]
	MatchState.act_timer = snapshot.act_timer
	MatchState.current_act = snapshot.act_number

	# Authoritative ball state
	var ball := MatchState.ball
	ball.holder_id = snapshot.ball_holder
	ball.is_in_flight = snapshot.ball_in_flight
	ball.position = snapshot.ball_pos
	ball.velocity = snapshot.ball_vel

	# Remote player states — snap to server position
	for p_snap in snapshot.players:
		var pid: String = p_snap["player_id"]
		if pid == local_pid: continue   # local player reconciled separately
		var node := _find_player_node(pid)
		if node == null: continue
		node.global_position = p_snap["position"]
		node.rotation = p_snap.get("rotation", node.rotation)
		# Sync health so buffs/HUD reflect server truth
		if node.has_node("PlayerBuffs"):
			node.get_node("PlayerBuffs").health = p_snap.get("health", node.buffs.health)
		# Sync alive state
		var rec: MatchState.PlayerRecord = MatchState.players.get(pid)
		if rec:
			var was_alive := rec.is_alive
			rec.is_alive = p_snap.get("is_alive", rec.is_alive)
			if was_alive and not rec.is_alive:
				EventBus.player_died.emit(pid, "combat", "")

# ── Prediction ring ────────────────────────────────────────────────────────────

func _find_predicted(tick: int) -> Dictionary:
	for entry in _ring:
		if entry["tick"] == tick:
			return entry
	return {}

func _rollback_and_replay(server_state: Dictionary, server_tick: int) -> void:
	var local_pid := NetworkManager.local_player_id
	var player_node := _find_player_node(local_pid)
	if player_node == null: return

	# Snap to authoritative state
	player_node.global_position = server_state["position"]
	player_node.rotation = server_state.get("rotation", player_node.rotation)

	# Replay buffered inputs from server_tick forward
	var ticks_to_replay := _input_history.keys()
	ticks_to_replay.sort()
	for t in ticks_to_replay:
		if t <= server_tick: continue
		var input: InputState = _input_history[t]
		player_node.apply_input(input)
		player_node._physics_process(get_physics_process_delta_time())

# ── Helpers ───────────────────────────────────────────────────────────────────

func _find_player_node(pid: String) -> Node:
	for n in get_tree().get_nodes_in_group("players"):
		if n.player_id == pid: return n
	return null
