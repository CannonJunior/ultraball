class_name AggressiveStrategy
extends "res://systems/ai/strategies/BalancedStrategy.gd"

## Aggressive variant: 3 rushers, tighter support spread (6 / 10 / 14 m ahead).

func _rush_count() -> int:
	return 3

func _support_pos(agent: AiView.PlayerView, view: AiView, tid: int) -> Vector2:
	var carrier := view.ball_carrier()
	if carrier == null:
		return AiStrategy.midfield_goal(agent.roster_slot, tid)
	var c_along := AiStrategy.world_to_arm_local(carrier.position, tid).x
	var rank    := _non_carrier_rank(agent, view)
	var depth   := 6.0 + float(rank % 3) * 4.0   # tighter: 6, 10, 14 m
	var target  := clampf(c_along + depth, _min_along(), AiStrategy.endzone_along())
	return AiStrategy.arm_to_world(target, AiStrategy.side_for_slot(agent.roster_slot), tid)
