class_name PossessionBleedStrategy
extends "res://systems/ai/strategies/BalancedStrategy.gd"

## Safe possession: support stays very close to the holder for easy dump-offs.

func _support_pos(agent: AiView.PlayerView, view: AiView, tid: int) -> Vector2:
	var holder := view.ball_carrier()
	if holder == null:
		return AiStrategy.midfield_pos(agent.roster_slot, tid)
	var spread := 5.0 + float(agent.roster_slot % 3) * 3.0
	var raw_x := holder.position.x + spread if tid == 0 else holder.position.x - spread
	# Average with holder position for conservative proximity
	var tx := (raw_x + holder.position.x) / 2.0
	return Vector2(clampf(tx, 0.0, 140.0), clampf(AiStrategy.lane_y(agent.roster_slot), 2.0, 38.0))
