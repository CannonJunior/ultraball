class_name FloodEndzoneStrategy
extends "res://systems/ai/strategies/BalancedStrategy.gd"

## Fan all non-carrier allies into the scoring zone so the holder always has a target.
## Positions are arm-local so the strategy works in both 2-team and 3-team modes.

## Side offsets for the 6 endzone receiver slots (arm-local perpendicular metres).
const _ENDZONE_SIDES: Array[float] = [-14.0, -7.0, 0.0, 7.0, 14.0, -10.0]

func _support_pos(agent: AiView.PlayerView, view: AiView, tid: int) -> Vector2:
	var carrier := view.ball_carrier()
	if carrier == null:
		return AiStrategy.midfield_goal(agent.roster_slot, tid)
	var slot_idx := agent.roster_slot % _ENDZONE_SIDES.size()
	var side     := _ENDZONE_SIDES[slot_idx]
	# Outlet slot (0): stay 8 m ahead of holder as a short dump-off option
	if slot_idx == 0:
		var c_along := AiStrategy.world_to_arm_local(carrier.position, tid).x
		var outlet  := clampf(c_along + 8.0, _min_along(), AiStrategy.endzone_along())
		return AiStrategy.arm_to_world(outlet, side, tid)
	# Other slots: flood the scoring zone at slightly staggered depths
	var along := AiStrategy.endzone_along() - 8.0 + float(slot_idx % 3) * 4.0
	return AiStrategy.arm_to_world(along, side, tid)
