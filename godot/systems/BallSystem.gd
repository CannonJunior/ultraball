class_name BallSystem
extends Node

## Ball physics: phase line detection, pickup/catch, charge timer, arc flight.

const THROW_SPEED := 20.0         # m/s — charged throw horizontal speed
const PASS_SPEED := 25.0          # m/s — regular pass speed
const PICKUP_RADIUS := 1.0        # metres — walk-up grab
const CATCH_RADIUS := 2.5         # metres — thrown catch window
const MAX_CHARGE := 7.0           # seconds before ball explodes
const THROW_GRAVITY := 20.0       # m/s² — arc gravity for charged throw
const THROW_SELF_CATCH_BLOCK := 0.2  # seconds — block self-catch after charged throw

## Two-team mode: phase lines at these x positions (indexed 0-4).
const PHASE_LINES_2T: Array[float] = [30.0, 50.0, 70.0, 90.0, 110.0]

## Ball deceleration rate when loose on ground (m/s²)
const LOOSE_FRICTION := 8.0

## Per-possession 2-team phase line activation flags.
var _phase_lines_activated: Array[bool] = [true, true, true, true, true]
## Per-possession 3-team phase line flags: 9 flags = 3 teams × 3 lines.
var _phase_lines_3t: Array[bool] = [true, true, true, true, true, true, true, true, true]

var _prev_ball_x: float = 70.0
var _prev_ball_pos: Vector2 = Vector2(70.0, 20.0)

func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)
	EventBus.ball_dropped.connect(_on_ball_dropped)
	EventBus.throw_requested.connect(_on_throw_requested)
	EventBus.ultra_scored.connect(_on_scored)
	EventBus.meta_scored.connect(_on_scored)
	EventBus.act_transition_complete.connect(_on_act_transition)

func _physics_process(delta: float) -> void:
	if not MatchState.match_active or MatchState.act_ended: return
	var ball := MatchState.ball

	if not ball.holder_id.is_empty():
		_update_held(ball, delta)
	elif ball.is_in_flight:
		_update_flight(ball, delta)
	else:
		_update_loose(ball, delta)

# ── Held ball ─────────────────────────────────────────────────────────────────

func _update_held(ball: MatchState.BallStateRecord, delta: float) -> void:
	var holder := _get_player_node(ball.holder_id)
	if holder == null:
		_drop_ball(ball, Vector2.ZERO, "death")
		return

	ball.position = holder.global_position
	ball.charge_timer += delta
	EventBus.throw_charge_changed.emit(ball.charge_timer / MAX_CHARGE)

	if ball.charge_timer >= MAX_CHARGE:
		_explode_ball(ball)
		return

	_check_phase_line_crossing(ball)
	if MatchState.is_three_team:
		_check_endzone_scoring_3t(ball)

# ── In-flight ball ────────────────────────────────────────────────────────────

func _update_flight(ball: MatchState.BallStateRecord, delta: float) -> void:
	ball.flight_age += delta
	ball.position += ball.velocity * delta

	if ball.is_charged_throw:
		ball.z_velocity -= THROW_GRAVITY * delta
		ball.z_height += ball.z_velocity * delta
		if ball.z_height <= 0.0:
			ball.z_height = 0.0
			ball.z_velocity = 0.0
			ball.is_in_flight = false
			ball.is_charged_throw = false
			ball.velocity = Vector2.ZERO
			_handle_failed_throw(ball)
			return

	_bounce_ball_at_boundary(ball)
	_check_phase_line_crossing(ball)

	var can_catch := (ball.flight_age >= THROW_SELF_CATCH_BLOCK) and \
		(not ball.is_charged_throw or ball.z_height <= 1.5)
	if can_catch:
		_check_catches(ball)

# ── Loose ball on ground ───────────────────────────────────────────────────────

func _update_loose(ball: MatchState.BallStateRecord, delta: float) -> void:
	var speed := ball.velocity.length()
	if speed > 0.0:
		var decel := minf(LOOSE_FRICTION * delta, speed)
		ball.velocity = ball.velocity * ((speed - decel) / speed)
	ball.position += ball.velocity * delta
	_bounce_ball_at_boundary(ball)
	_check_pickups(ball)

# ── Phase line detection ──────────────────────────────────────────────────────

func _check_phase_line_crossing(ball: MatchState.BallStateRecord) -> void:
	if MatchState.is_three_team:
		_check_phase_line_crossing_3t(ball)
		return

	var team := ball.possessing_team_id
	if team < 0: return

	for i in PHASE_LINES_2T.size():
		if not _phase_lines_activated[i]: continue
		var lx := PHASE_LINES_2T[i]
		var crossed := (_prev_ball_x < lx and ball.position.x >= lx) or \
					   (_prev_ball_x > lx and ball.position.x <= lx)
		if crossed:
			_phase_lines_activated[i] = false
			EventBus.ball_phase_line_crossed.emit(team, i)
			ball.charge_timer = 0.0
			if not ball.holder_id.is_empty():
				EventBus.buff_applied.emit(ball.holder_id, "phase_line_bonus", 0.0)

	_prev_ball_x = ball.position.x

func _check_phase_line_crossing_3t(ball: MatchState.BallStateRecord) -> void:
	if ball.possessing_team_id < 0: return
	var center := Vector2(MatchState.FIELD3_CX, MatchState.FIELD3_CY)
	for t in 3:
		var norm: Vector2 = MatchState.TEAM3_NORMALS[t]
		var perp := Vector2(-norm.y, norm.x)
		for i in 3:
			var idx := t * 3 + i
			if not _phase_lines_3t[idx]: continue
			var d: float = MatchState.FIELD3_PHASE_DISTS[i]
			var prev_dot := (_prev_ball_pos - center).dot(norm)
			var new_dot  := (ball.position  - center).dot(norm)
			if (prev_dot < d and new_dot >= d) or (prev_dot > d and new_dot <= d):
				if absf((ball.position - center).dot(perp)) <= MatchState.FIELD3_ARM_HALF_W:
					_phase_lines_3t[idx] = false
					EventBus.ball_phase_line_crossed.emit(ball.possessing_team_id, idx)
					ball.charge_timer = 0.0
					if not ball.holder_id.is_empty():
						EventBus.buff_applied.emit(ball.holder_id, "phase_line_bonus", 0.0)
	_prev_ball_pos = ball.position

# ── 3-team endzone scoring ────────────────────────────────────────────────────

func _check_endzone_scoring_3t(ball: MatchState.BallStateRecord) -> void:
	if ball.holder_id.is_empty(): return
	var holder := _get_player_node(ball.holder_id)
	if holder == null: return
	var hpos: Vector2 = holder.global_position
	var center := Vector2(MatchState.FIELD3_CX, MatchState.FIELD3_CY)
	for t in 3:
		var norm: Vector2 = MatchState.TEAM3_NORMALS[t]
		if (hpos - center).dot(norm) < MatchState.FIELD3_CHAN_OUTER: continue
		var perp := Vector2(-norm.y, norm.x)
		if absf((hpos - center).dot(perp)) <= MatchState.FIELD3_ARM_HALF_W:
			EventBus.ball_entered_endzone_3t.emit(ball.holder_id)
			return

# ── Pickup and catch ──────────────────────────────────────────────────────────

func _check_pickups(ball: MatchState.BallStateRecord) -> void:
	for player in get_tree().get_nodes_in_group("players"):
		if not player.is_alive: continue
		if player.global_position.distance_to(ball.position) <= PICKUP_RADIUS:
			_give_ball(ball, player.player_id)
			return

func _check_catches(ball: MatchState.BallStateRecord) -> void:
	var thrower_team := ball.possessing_team_id
	for player in get_tree().get_nodes_in_group("players"):
		if not player.is_alive: continue
		if player.player_id == ball.holder_id: continue
		if player.global_position.distance_to(ball.position) > CATCH_RADIUS: continue

		if player.team_id == thrower_team:
			_give_ball(ball, player.player_id)
			EventBus.ball_caught.emit(player.player_id)
		else:
			_handle_interception(ball, player)
		return

func _handle_interception(ball: MatchState.BallStateRecord, interceptor: Node) -> void:
	var original_team := ball.possessing_team_id
	for p in get_tree().get_nodes_in_group("players"):
		if p.team_id == original_team and p.is_alive:
			EventBus.debuff_applied.emit(p.player_id, "stun", 1.0, {})
	_give_ball(ball, interceptor.player_id)
	EventBus.ball_caught.emit(interceptor.player_id)
	EventBus.event_message_shown.emit("INTERCEPTED!", 2.0)

func _give_ball(ball: MatchState.BallStateRecord, player_id: String) -> void:
	ball.holder_id = player_id
	ball.possessing_team_id = MatchState.team_for_player(player_id)
	ball.is_in_flight = false
	ball.is_charged_throw = false
	ball.velocity = Vector2.ZERO
	ball.charge_timer = 0.0
	ball.flight_age = 0.0
	_phase_lines_activated = [true, true, true, true, true]
	_phase_lines_3t = [true, true, true, true, true, true, true, true, true]
	_prev_ball_x = ball.position.x
	_prev_ball_pos = ball.position
	EventBus.ball_picked_up.emit(player_id)
	EventBus.ball_possession_changed.emit(player_id, ball.possessing_team_id)

# ── Throw ──────────────────────────────────────────────────────────────────────

func _on_throw_requested(thrower_id: String, direction: Vector2, is_charged: bool) -> void:
	var ball := MatchState.ball
	if ball.holder_id != thrower_id: return
	var speed := THROW_SPEED if is_charged else PASS_SPEED
	throw_ball(thrower_id, direction, speed, is_charged)

func throw_ball(thrower_id: String, direction: Vector2, speed: float, is_charged: bool) -> void:
	var ball := MatchState.ball
	if ball.holder_id != thrower_id: return
	ball.charge_at_throw = ball.charge_timer
	ball.holder_id = ""
	ball.is_in_flight = true
	ball.is_charged_throw = is_charged
	ball.flight_age = 0.0
	ball.velocity = direction.normalized() * speed
	if is_charged:
		var dist := speed * 1.5
		var flight_time := dist / speed
		ball.z_velocity = 0.5 * THROW_GRAVITY * flight_time
		ball.z_height = 0.001
	EventBus.ball_thrown.emit(thrower_id, ball.position + direction * 10.0, is_charged)
	EventBus.throw_charge_changed.emit(0.0)

# ── Failed throw handling ─────────────────────────────────────────────────────

func _handle_failed_throw(ball: MatchState.BallStateRecord) -> void:
	var stun_dur := maxf(1.5, ball.charge_at_throw)
	for p in get_tree().get_nodes_in_group("players"):
		if p.team_id == ball.possessing_team_id and p.is_alive:
			EventBus.debuff_applied.emit(p.player_id, "stun", stun_dur, {})
	EventBus.event_message_shown.emit("DROPPED!", 1.5)

# ── Ball explosion ────────────────────────────────────────────────────────────

func _explode_ball(ball: MatchState.BallStateRecord) -> void:
	var holder_id := ball.holder_id
	ball.holder_id = ""
	ball.is_in_flight = false
	ball.velocity = Vector2.ZERO
	ball.charge_timer = 0.0
	EventBus.ball_exploded.emit(holder_id)
	EventBus.player_died.emit(holder_id, "explosion", "")

# ── Score and act reset ───────────────────────────────────────────────────────

func _on_scored(_team_id: int, _scorer_id: String) -> void:
	_reset_ball_to_centre()

func _on_act_transition(_next_act: int) -> void:
	_reset_ball_to_centre()

func _reset_ball_to_centre() -> void:
	var ball := MatchState.ball
	var centre := Vector2(MatchState.FIELD3_CX, MatchState.FIELD3_CY) \
		if MatchState.is_three_team else Vector2(70.0, 20.0)
	ball.position = centre
	ball.velocity = Vector2.ZERO
	ball.holder_id = ""
	ball.possessing_team_id = -1
	ball.is_in_flight = false
	ball.is_charged_throw = false
	ball.charge_timer = 0.0
	ball.z_height = 0.0
	ball.z_velocity = 0.0
	ball.flight_age = 0.0
	_phase_lines_activated = [true, true, true, true, true]
	_phase_lines_3t = [true, true, true, true, true, true, true, true, true]
	_prev_ball_x = centre.x
	_prev_ball_pos = centre
	EventBus.ball_reset.emit(centre)
	EventBus.throw_charge_changed.emit(0.0)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _drop_ball(ball: MatchState.BallStateRecord, pos: Vector2, cause: String) -> void:
	if not ball.holder_id.is_empty():
		ball.holder_id = ""
		ball.possessing_team_id = -1
		ball.is_in_flight = false
		ball.velocity = Vector2.ZERO
		ball.charge_timer = 0.0
	if pos != Vector2.ZERO:
		ball.position = pos
	EventBus.ball_dropped.emit(pos, cause)

func _on_player_died(player_id: String, _cause: String, _killer: String) -> void:
	if MatchState.ball.holder_id == player_id:
		_drop_ball(MatchState.ball, _get_player_position(player_id), "death")

func _on_ball_dropped(position: Vector2, _cause: String) -> void:
	var ball := MatchState.ball
	ball.holder_id = ""
	ball.possessing_team_id = -1
	ball.is_in_flight = false
	if position != Vector2.ZERO:
		ball.position = position
	ball.charge_timer = 0.0

func _bounce_ball_at_boundary(ball: MatchState.BallStateRecord) -> void:
	if MatchState.is_three_team:
		var sz := MatchState.FIELD3_SIZE
		if ball.position.y < 0.0:
			ball.position.y = 0.0
			ball.velocity.y = -ball.velocity.y
		elif ball.position.y > sz:
			ball.position.y = sz
			ball.velocity.y = -ball.velocity.y
		if ball.position.x < 0.0:
			ball.position.x = 0.0
			ball.velocity.x = absf(ball.velocity.x) * 0.5
		elif ball.position.x > sz:
			ball.position.x = sz
			ball.velocity.x = -absf(ball.velocity.x) * 0.5
		return
	if ball.position.y < 0.0:
		ball.position.y = 0.0
		ball.velocity.y = -ball.velocity.y
	elif ball.position.y > 40.0:
		ball.position.y = 40.0
		ball.velocity.y = -ball.velocity.y
	if ball.position.x < 0.0:
		ball.position.x = 0.0
		ball.velocity.x = absf(ball.velocity.x) * 0.5
	elif ball.position.x > 140.0:
		ball.position.x = 140.0
		ball.velocity.x = -absf(ball.velocity.x) * 0.5

func _get_player_node(pid: String) -> Node:
	for n in get_tree().get_nodes_in_group("players"):
		if n.player_id == pid: return n
	return null

func _get_player_position(pid: String) -> Vector2:
	var n := _get_player_node(pid)
	return n.global_position if n else Vector2.ZERO
