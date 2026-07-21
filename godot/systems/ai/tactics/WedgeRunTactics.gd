class_name WedgeRunTactics
extends "res://systems/ai/tactics/BalancedTactics.gd"

## Support players form a tight triangle around the holder.
## The goal position from the strategy is replaced by a wedge offset.

const WEDGE_OFFSETS: Array = [
	Vector2( 5.0,  0.0),   # tip (furthest ahead)
	Vector2(-3.0, -4.0),   # back-left
	Vector2(-3.0,  4.0),   # back-right
]

func _mover_input(
	agent: AiView.PlayerView,
	_goal: Vector2,
	view: AiView,
	input: InputState
) -> void:
	var holder := view.ball_carrier()
	if holder == null:
		input.move_direction = navigate_toward(agent, _goal, view)
	else:
		var tid := view.requesting_team_id
		var off: Vector2 = WEDGE_OFFSETS[agent.roster_slot % 3]
		# Flip x offset so formation faces the correct scoring direction
		var tx := holder.position.x + (off.x if tid == 0 else -off.x)
		var ty := holder.position.y + off.y
		input.move_direction = navigate_toward(agent, Vector2(tx, ty), view)
	try_queue_ability(agent, view, input)
