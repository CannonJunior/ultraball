class_name BalancedStrategy
extends AiStrategy

## Default balanced strategy: advance ball carrier toward endzone,
## spread support players ahead, 2 rushers on defense.

func evaluate_goal(agent: AiView.PlayerView, view: AiView, _policy: Dictionary) -> Vector2:
	var tid  := view.requesting_team_id
	var ball := view.ball
	var allies  := view.allies()
	var enemies := view.enemies()

	# Own in-flight ball: closest ally chases
	if ball.is_in_flight and ball.possessing_team_id == tid:
		var cl := AiStrategy.closest_to(allies, ball.position)
		if cl != null and cl.player_id == agent.player_id:
			return ball.position

	# Loose ball: closest ally retrieves, others stage at mid-field
	if ball.holder_id.is_empty() and not ball.is_in_flight:
		var cl := AiStrategy.closest_to(allies, ball.position)
		if cl != null and cl.player_id == agent.player_id:
			return ball.position
		return AiStrategy.midfield_pos(agent.roster_slot, tid)

	# We possess the ball
	if ball.possessing_team_id == tid:
		if agent.has_ball:
			return Vector2(AiStrategy.endzone_x(tid), AiStrategy.open_lane_y(enemies))
		return _support_pos(agent, view, tid)

	# Enemy possesses: defend
	var carrier := view.ball_carrier()
	if carrier != null:
		return _defense_pos(agent, allies, carrier, tid, view)

	return AiStrategy.midfield_pos(agent.roster_slot, tid)

## Goal position for non-holder offensive support.
func _support_pos(agent: AiView.PlayerView, view: AiView, tid: int) -> Vector2:
	var holder := view.ball_carrier()
	if holder == null:
		return AiStrategy.midfield_pos(agent.roster_slot, tid)
	var spread := 10.0 + float(agent.roster_slot % 3) * 6.0
	var tx := holder.position.x + spread if tid == 0 else holder.position.x - spread
	var ty := AiStrategy.lane_y(agent.roster_slot)
	return Vector2(clampf(tx, 0.0, 140.0), clampf(ty, 2.0, 38.0))

## Goal position on defense.
func _defense_pos(
	agent: AiView.PlayerView,
	allies: Array,
	carrier: AiView.PlayerView,
	tid: int,
	_view: AiView
) -> Vector2:
	var sorted := allies.duplicate()
	sorted.sort_custom(func(a: AiView.PlayerView, b: AiView.PlayerView) -> bool:
		return a.position.distance_squared_to(carrier.position) < \
		       b.position.distance_squared_to(carrier.position)
	)
	var rank := 0
	for i in sorted.size():
		if (sorted[i] as AiView.PlayerView).player_id == agent.player_id:
			rank = i
			break
	if rank < _rush_count():
		return carrier.position
	# Cover midfield between carrier and own endzone
	var guard_x := 0.0 if tid == 0 else 140.0
	return Vector2(
		clampf((carrier.position.x + guard_x) / 2.0, 10.0, 130.0),
		clampf(carrier.position.y + float(rank % 3 - 1) * 6.0, 2.0, 38.0)
	)

## Number of players that rush the carrier; override for more aggressive defense.
func _rush_count() -> int:
	return 2
