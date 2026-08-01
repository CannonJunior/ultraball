class_name PossessionBleedStrategy
extends "res://systems/ai/strategies/BalancedStrategy.gd"

## Keep the ball safe: receivers cluster very close to the holder for easy dump-offs.
## Stagger depths at 7 / 11 / 15 / 19 m — always within pass threshold.

func _support_pos(agent: AiView.PlayerView, view: AiView, tid: int) -> Vector2:
	var carrier := view.ball_carrier()
	if carrier == null:
		return AiStrategy.midfield_goal(agent.roster_slot, tid)
	var c_along := AiStrategy.world_to_arm_local(carrier.position, tid).x
	var rank    := _non_carrier_rank(agent, view)
	var depth   := 7.0 + float(rank % 4) * 4.0   # 7 / 11 / 15 / 19 m ahead
	var target  := clampf(c_along + depth, _min_along(), AiStrategy.endzone_along())
	return AiStrategy.arm_to_world(target, AiStrategy.side_for_slot(agent.roster_slot), tid)
