class_name GameSnapshot

## Full authoritative state snapshot broadcast from server to clients each tick.
## Clients use this to reconcile predicted state.

var tick: int = 0
var act_number: int = 1
var act_timer: float = 180.0
var scores: Array[int] = [0, 0, 0]

## Player snapshots: Array[{player_id, position, rotation, health, mana_r, mana_b, mana_y, mana_u, is_alive, flags}]
var players: Array = []

## Ball snapshot
var ball_pos: Vector2 = Vector2.ZERO
var ball_vel: Vector2 = Vector2.ZERO
var ball_holder: String = ""
var ball_charge_pct: float = 0.0
var ball_in_flight: bool = false

static func capture(match_state: Node, current_tick: int) -> GameSnapshot:
	var snap := GameSnapshot.new()
	snap.tick = current_tick
	snap.act_number = MatchState.current_act
	snap.act_timer = MatchState.act_timer
	snap.scores = MatchState.scores.duplicate()

	for pid in MatchState.players:
		var rec: MatchState.PlayerRecord = MatchState.players[pid]
		var node := _find_player(pid)
		if node == null: continue
		snap.players.append({
			"player_id": pid,
			"position": node.global_position,
			"rotation": node.rotation,
			"health": node.buffs.health,
			"mana_r": node.mana.red,
			"mana_b": node.mana.blue,
			"mana_y": node.mana.yellow,
			"mana_u": node.mana.ultra,
			"is_alive": rec.is_alive,
			"stun": node.buffs.stun_timer,
		})

	var ball := MatchState.ball
	snap.ball_pos = ball.position
	snap.ball_vel = ball.velocity
	snap.ball_holder = ball.holder_id
	snap.ball_charge_pct = ball.charge_timer / ball.max_charge
	snap.ball_in_flight = ball.is_in_flight
	return snap

func get_player_snapshot(player_id: String) -> Dictionary:
	for p in players:
		if p["player_id"] == player_id:
			return p
	return {}

func serialize() -> PackedByteArray:
	# Use Godot's built-in var_to_bytes for simplicity in early development.
	# Replace with custom binary encoding for production performance.
	return var_to_bytes({
		"tick": tick, "act": act_number, "timer": act_timer,
		"scores": scores, "players": players,
		"bpos": ball_pos, "bvel": ball_vel, "bholder": ball_holder,
		"bcharge": ball_charge_pct, "bflight": ball_in_flight,
	})

static func deserialize(bytes: PackedByteArray) -> GameSnapshot:
	var d: Dictionary = bytes_to_var(bytes)
	var s := GameSnapshot.new()
	s.tick = d.get("tick", 0)
	s.act_number = d.get("act", 1)
	s.act_timer = d.get("timer", 180.0)
	s.scores = d.get("scores", [0, 0, 0])
	s.players = d.get("players", [])
	s.ball_pos = d.get("bpos", Vector2.ZERO)
	s.ball_vel = d.get("bvel", Vector2.ZERO)
	s.ball_holder = d.get("bholder", "")
	s.ball_charge_pct = d.get("bcharge", 0.0)
	s.ball_in_flight = d.get("bflight", false)
	return s

static func _find_player(pid: String) -> Node:
	if not Engine.is_editor_hint():
		for n in Engine.get_main_loop().current_scene.get_tree().get_nodes_in_group("players"):
			if n.player_id == pid: return n
	return null
