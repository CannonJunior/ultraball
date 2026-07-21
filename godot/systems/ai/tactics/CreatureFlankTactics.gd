class_name CreatureFlankTactics
extends "res://systems/ai/tactics/BalancedTactics.gd"

## Support positions on the opposite side of the creature from the holder,
## herding it toward enemies.

func _mover_input(
	agent: AiView.PlayerView,
	goal: Vector2,
	view: AiView,
	input: InputState
) -> void:
	var holder := view.ball_carrier()
	if holder == null or view.creatures.is_empty():
		input.move_direction = navigate_toward(agent, goal, view)
		try_queue_ability(agent, view, input)
		return

	var creature_y := view.creatures[0].position.y
	var lane_base := AiStrategy.lane_y(agent.roster_slot)
	# Opposite side of creature from holder
	var side_y := clampf(lane_base, 22.0, 38.0) if holder.position.y < creature_y \
		else clampf(lane_base, 2.0, 18.0)
	var tid := view.requesting_team_id
	var spread := 8.0 + float(agent.roster_slot % 3) * 6.0
	var tx := holder.position.x + spread if tid == 0 else holder.position.x - spread
	input.move_direction = navigate_toward(agent, Vector2(clampf(tx, 0.0, 140.0), side_y), view)
	try_queue_ability(agent, view, input)
