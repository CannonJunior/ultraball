class_name SafePassStrategy
extends "res://systems/ai/strategies/BalancedStrategy.gd"

## Safe-pass variant: 5-relay chain 6–22 m ahead; 1 rusher on defence; covers
## receivers by marking the enemies furthest along their scoring arm.

func _rush_count() -> int:
	return 1

func _support_pos(agent: AiView.PlayerView, view: AiView, tid: int) -> Vector2:
	var carrier := view.ball_carrier()
	if carrier == null:
		return AiStrategy.midfield_goal(agent.roster_slot, tid)
	var c_along := AiStrategy.world_to_arm_local(carrier.position, tid).x
	var rank    := _non_carrier_rank(agent, view)
	var depth   := 6.0 + float(rank % 5) * 4.0   # relay chain: 6 / 10 / 14 / 18 / 22 m
	var target  := clampf(c_along + depth, _min_along(), AiStrategy.endzone_along())
	return AiStrategy.arm_to_world(target, AiStrategy.side_for_slot(agent.roster_slot), tid)

func _defense_pos(agent: AiView.PlayerView, view: AiView, _my_tid: int, carrier: AiView.PlayerView) -> Vector2:
	var carrier_tid := carrier.team_id
	var rank        := _rusher_rank(agent, view, carrier)
	if rank < 1:
		return carrier.position

	# Mark the enemy receiver furthest along the carrier's arm (most dangerous pass target)
	var enemies := view.enemies()
	if enemies.is_empty():
		return AiStrategy.midfield_goal(agent.roster_slot, _my_tid)
	var sorted := enemies.duplicate()
	sorted.sort_custom(func(a: AiView.PlayerView, b: AiView.PlayerView) -> bool:
		return AiStrategy.advance_score(a.position, carrier_tid) > \
		       AiStrategy.advance_score(b.position, carrier_tid)
	)
	var idx := (rank - 1) % sorted.size()
	return (sorted[idx] as AiView.PlayerView).position
