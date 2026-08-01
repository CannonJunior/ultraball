class_name SafePassTactics
extends "res://systems/ai/tactics/BalancedTactics.gd"

## Pass-first tactics: throw to the first open receiver 3+ m ahead.
## When covered with no outlet, step laterally to an open lane along the arm
## rather than running into defensive traffic.

func _pass_threshold() -> float:
	return 3.0

func _holder_input(
	agent: AiView.PlayerView,
	goal: Vector2,
	view: AiView,
	input: InputState
) -> void:
	var receiver := find_best_receiver(agent, view, _pass_threshold())
	if receiver != null:
		input.release_throw = true
		input.is_aiming = true
		input.aim_world_position = receiver.position
		try_queue_ability(agent, view, input)
		return

	if enemy_pressure(agent, view) >= 2:
		# Sidestep to a less-covered lane (perpendicular to scoring direction)
		var tid  := view.requesting_team_id
		var norm := AiStrategy.team_advance_dir(tid)
		var perp := Vector2(-norm.y, norm.x)
		# Alternate left/right by roster slot to avoid all holders drifting the same way
		var side_sign := 1.0 if agent.roster_slot % 2 == 0 else -1.0
		input.move_direction = navigate_toward(agent, agent.position + perp * side_sign * 8.0, view)
	else:
		input.move_direction = navigate_toward(agent, goal, view)
	try_queue_ability(agent, view, input)
