class_name AggressiveStrategy
extends "res://systems/ai/strategies/BalancedStrategy.gd"

## Aggressive strategy: 3 rushers on defense, tighter support spread.

func _rush_count() -> int:
	return 3

func _support_pos(agent: AiView.PlayerView, view: AiView, tid: int) -> Vector2:
	var holder := view.ball_carrier()
	if holder == null:
		return AiStrategy.midfield_pos(agent.roster_slot, tid)
	# Tighter spread so players can apply pressure quickly
	var spread := 6.0 + float(agent.roster_slot % 3) * 4.0
	var tx := holder.position.x + spread if tid == 0 else holder.position.x - spread
	return Vector2(clampf(tx, 0.0, 140.0), clampf(AiStrategy.lane_y(agent.roster_slot), 2.0, 38.0))
