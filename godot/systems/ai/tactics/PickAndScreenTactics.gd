class_name PickAndScreenTactics
extends "res://systems/ai/tactics/BalancedTactics.gd"

## Two-thirds of players screen between holder and nearest defender;
## the rest run as pass options using the strategy goal.

func _mover_input(
	agent: AiView.PlayerView,
	goal: Vector2,
	view: AiView,
	input: InputState
) -> void:
	var holder := view.ball_carrier()
	if holder == null:
		input.move_direction = navigate_toward(agent, goal, view)
		try_queue_ability(agent, view, input)
		return

	var target: Vector2
	if agent.roster_slot % 3 < 2:
		# Screen: position between holder and nearest threat
		var nearest := view.nearest_enemy(holder.position)
		if nearest != null:
			target = (holder.position + nearest.position) * 0.5
		else:
			# No visible threat — drift 5 m ahead of holder along scoring direction
			var norm := AiStrategy.team_advance_dir(view.requesting_team_id)
			target = holder.position + norm * 5.0
	else:
		# Run the strategy route as a pass option
		target = goal

	input.move_direction = navigate_toward(agent, target, view)
	try_queue_ability(agent, view, input)
