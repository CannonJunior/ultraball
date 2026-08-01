class_name BalancedStrategy
extends AiStrategy

## Balanced role-based strategy.  Works identically in 2-team and 3-team modes
## because all spatial reasoning uses arm-local coordinates via AiStrategy helpers.
##
## Role assignment per tick (evaluated independently per agent):
##   CARRIER   — agent holds ball → run for endzone
##   CHASER    — closest alive ally to a loose ball → retrieve it
##   RECEIVER  — spread ahead of carrier along own arm (non-carrier on offence)
##   RUSHER    — closest N allies to enemy carrier → press / attack
##   COVER     — remaining defenders → block path between carrier and their endzone
##
## In-flight handling:
##   Own throw  — chaser intercepts; non-chasers spread along own arm to receive
##   Enemy throw — all defenders converge on nearest enemy as the likely receiver

func evaluate_goal(agent: AiView.PlayerView, view: AiView, _policy: Dictionary) -> Vector2:
	var tid  := view.requesting_team_id
	var ball := view.ball

	# CARRIER — run for own endzone
	if agent.has_ball:
		return AiStrategy.endzone_goal(tid)

	# Ball in flight — split on possession team to avoid sending receivers
	# to the wrong side of the field when the enemy is making a pass.
	if ball.is_in_flight:
		if ball.possessing_team_id == tid:
			# OWN ball in flight: chaser intercepts, others spread ahead to receive
			var cl := AiStrategy.closest_to(view.allies(), ball.position)
			if cl != null and cl.player_id == agent.player_id:
				return ball.position
			return _support_pos(agent, view, tid)   # spreads carrier-relative (falls back to midfield if no carrier)
		else:
			# ENEMY ball in flight: defend against the likely receiver
			var tgt := AiStrategy.closest_to(view.enemies(), ball.position)
			if tgt != null:
				return _defense_pos(agent, view, tid, tgt)
			return AiStrategy.midfield_goal(agent.roster_slot, tid)

	# Loose ball on the ground
	if ball.holder_id.is_empty():
		var cl := AiStrategy.closest_to(view.allies(), ball.position)
		if cl != null and cl.player_id == agent.player_id:
			return ball.position   # CHASER — sprint to ball
		# Non-chasers: only spread into receive positions when ball is inside
		# our arm (advance > 0); otherwise stage at midfield and let the
		# chaser bring the ball toward us.
		if AiStrategy.advance_score(ball.position, tid) > 5.0:
			return _receive_spread(agent, view, tid)
		return AiStrategy.midfield_goal(agent.roster_slot, tid)

	# Ball held by us — relay chain ahead of carrier
	if ball.possessing_team_id == tid:
		return _support_pos(agent, view, tid)

	# Ball held by enemy — press or cover
	var carrier := view.ball_carrier()
	if carrier != null:
		return _defense_pos(agent, view, tid, carrier)

	return AiStrategy.midfield_goal(agent.roster_slot, tid)

# ── Offensive positioning ──────────────────────────────────────────────────────

## Spread ahead of the ball carrier along the arm at staggered depths.
## Clamps minimum along so players never get pushed into enemy territory.
func _support_pos(agent: AiView.PlayerView, view: AiView, tid: int) -> Vector2:
	var carrier := view.ball_carrier()
	if carrier == null:
		return AiStrategy.midfield_goal(agent.roster_slot, tid)
	var c_along  := AiStrategy.world_to_arm_local(carrier.position, tid).x
	var rank     := _non_carrier_rank(agent, view)
	var depth    := 8.0 + float(rank % 3) * 8.0
	var min_a    := _min_along()
	var target   := clampf(c_along + depth, min_a, AiStrategy.endzone_along())
	return AiStrategy.arm_to_world(target, AiStrategy.side_for_slot(agent.roster_slot), tid)

## Spread into catch zones when the ball is loose and in own territory.
func _receive_spread(agent: AiView.PlayerView, view: AiView, tid: int) -> Vector2:
	var b_along := AiStrategy.world_to_arm_local(view.ball.position, tid).x
	var rank    := _non_carrier_rank(agent, view)
	var depth   := 5.0 + float(rank % 3) * 6.0
	var min_a   := _min_along()
	var target  := clampf(b_along + depth, min_a, AiStrategy.endzone_along())
	return AiStrategy.arm_to_world(target, AiStrategy.side_for_slot(agent.roster_slot), tid)

## Minimum arm-local "along" value for receiver and support positions.
## Keeps players inside their own arm and off the central junction boundary.
func _min_along() -> float:
	return 8.0 if MatchState.is_three_team else 20.0

# ── Defensive positioning ──────────────────────────────────────────────────────

## Rush carriers (rank < rush_count); cover the path to carrier's endzone otherwise.
## Cover positions are placed along the *carrier's* arm to cut off their advance.
func _defense_pos(agent: AiView.PlayerView, view: AiView, _my_tid: int, carrier: AiView.PlayerView) -> Vector2:
	var carrier_tid := carrier.team_id
	var rank        := _rusher_rank(agent, view, carrier)
	if rank < _rush_count():
		return carrier.position   # RUSHER — press directly

	# COVER — block the path ahead of the carrier toward their endzone
	var c_along := AiStrategy.world_to_arm_local(carrier.position, carrier_tid).x
	var offset  := 10.0 + float(rank - _rush_count()) * 6.0
	var target  := minf(c_along + offset, AiStrategy.endzone_along())
	return AiStrategy.arm_to_world(target, AiStrategy.side_for_slot(agent.roster_slot), carrier_tid)

## Number of players sent to rush the ball carrier. Override in aggressive subclasses.
func _rush_count() -> int:
	return 2

# ── Rank helpers ───────────────────────────────────────────────────────────────

## Stable 0-based rank among alive non-carrier allies, ordered by roster_slot.
func _non_carrier_rank(agent: AiView.PlayerView, view: AiView) -> int:
	var rank := 0
	for ally in view.allies():
		var pv := ally as AiView.PlayerView
		if pv.has_ball or pv.player_id == agent.player_id: continue
		if not pv.is_alive or not pv.is_on_field: continue
		if pv.roster_slot < agent.roster_slot: rank += 1
	return rank

## Distance-based rank to the carrier (0 = closest → becomes rusher).
func _rusher_rank(agent: AiView.PlayerView, view: AiView, carrier: AiView.PlayerView) -> int:
	var my_d2 := agent.position.distance_squared_to(carrier.position)
	var rank  := 0
	for ally in view.allies():
		var pv := ally as AiView.PlayerView
		if pv.player_id == agent.player_id or not pv.is_alive: continue
		if pv.position.distance_squared_to(carrier.position) < my_d2: rank += 1
	return rank
