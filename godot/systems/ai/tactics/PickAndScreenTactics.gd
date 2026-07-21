class_name PickAndScreenTactics
extends "res://systems/ai/tactics/BalancedTactics.gd"

## Some players screen between the holder and nearest defender;
## others run ahead as passing options.

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
			target = (holder.position + nearest.position) / 2.0
		else:
			var tid := view.requesting_team_id
			target = holder.position + (Vector2(5.0, 0.0) if tid == 0 else Vector2(-5.0, 0.0))
	else:
		# Run: use strategy goal as the pass-option route
		target = goal

	input.move_direction = navigate_toward(agent, target, view)
	try_queue_ability(agent, view, input)
