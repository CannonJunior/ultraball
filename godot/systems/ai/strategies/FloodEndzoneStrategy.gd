class_name FloodEndzoneStrategy
extends "res://systems/ai/strategies/BalancedStrategy.gd"

## Flood the endzone with receivers so the holder always has an open target.

const _SLOTS_HOME: Array = [
	Vector2(110.0,  5.0),
	Vector2(122.0, 12.0),
	Vector2(130.0, 20.0),
	Vector2(122.0, 28.0),
	Vector2(110.0, 35.0),
	Vector2(100.0, 20.0),
]
const _SLOTS_AWAY: Array = [
	Vector2( 30.0,  5.0),
	Vector2( 18.0, 12.0),
	Vector2( 10.0, 20.0),
	Vector2( 18.0, 28.0),
	Vector2( 30.0, 35.0),
	Vector2( 40.0, 20.0),
]

func _support_pos(agent: AiView.PlayerView, view: AiView, tid: int) -> Vector2:
	var holder := view.ball_carrier()
	if holder == null:
		return AiStrategy.midfield_pos(agent.roster_slot, tid)
	var slots: Array = _SLOTS_HOME if tid == 0 else _SLOTS_AWAY
	var target: Vector2 = slots[agent.roster_slot % slots.size()]
	# Outlet slot (index 0): stay close to holder as a safe dump-off option
	if agent.roster_slot % slots.size() == 0:
		var outlet_x := holder.position.x + 10.0 if tid == 0 else holder.position.x - 10.0
		return Vector2(clampf(outlet_x, 0.0, 140.0), AiStrategy.lane_y(agent.roster_slot))
	return target
