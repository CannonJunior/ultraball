class_name HeroBallTactics
extends "res://systems/ai/tactics/BalancedTactics.gd"

## Support rallies closely around the holder and swarms nearby threats.

func _mover_input(
	agent: AiView.PlayerView,
	_goal: Vector2,
	view: AiView,
	input: InputState
) -> void:
	var holder := view.ball_carrier()
	if holder == null:
		input.move_direction = navigate_toward(agent, _goal, view)
		try_queue_ability(agent, view, input)
		return

	# Escort offsets: stay close around the ball carrier
	const ESCORT: Array = [
		Vector2( 3.0, -4.0),
		Vector2( 3.0,  4.0),
		Vector2(-4.0, -3.0),
		Vector2(-4.0,  3.0),
		Vector2( 0.0, -5.0),
		Vector2( 0.0,  5.0),
	]
	var off: Vector2 = ESCORT[agent.roster_slot % ESCORT.size()]
	var target := holder.position + off
	input.move_direction = navigate_toward(agent, target, view)

	# Swarm nearest threat to the holder
	var nearest := view.nearest_enemy(holder.position)
	if nearest != null and holder.position.distance_squared_to(nearest.position) < 100.0:
		input.move_direction = navigate_toward(agent, nearest.position, view)
	try_queue_ability(agent, view, input)
