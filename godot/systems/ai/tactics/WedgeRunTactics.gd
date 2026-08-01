class_name WedgeRunTactics
extends "res://systems/ai/tactics/BalancedTactics.gd"

## Support players form a tight wedge around the holder: one blocker ahead,
## two flanking behind.  Offsets are in arm-local (along, side) so the formation
## faces the correct scoring direction in both field modes.

## Arm-local offsets: x = along (positive = ahead of holder), y = side (lateral).
const WEDGE_OFFSETS: Array = [
	Vector2( 5.0,  0.0),   # tip  — runs ahead of carrier
	Vector2(-3.0, -4.0),   # back-left
	Vector2(-3.0,  4.0),   # back-right
]

func _holder_input(
	agent: AiView.PlayerView,
	goal: Vector2,
	view: AiView,
	input: InputState
) -> void:
	# Pure run play — carrier drives; no passing.
	input.move_direction = navigate_toward(agent, goal, view)
	try_queue_ability(agent, view, input)

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
		var tid  := view.requesting_team_id
		var norm := AiStrategy.team_advance_dir(tid)
		var perp := Vector2(-norm.y, norm.x)
		var off  : Vector2 = WEDGE_OFFSETS[agent.roster_slot % WEDGE_OFFSETS.size()]
		var target := holder.position + norm * off.x + perp * off.y
		input.move_direction = navigate_toward(agent, target, view)
	try_queue_ability(agent, view, input)
