class_name ShadowTactics
extends "res://systems/ai/tactics/AiTactics.gd"

## Shadows the local player: maintains close proximity with a lateral offset.
## Uses abilities defensively when enemies threaten the shadow source.

const OFFSET_DIST := 2.5  # metres lateral offset from source

func produce_input(
	agent: AiView.PlayerView,
	_goal: Vector2,
	view: AiView,
	_policy: Dictionary
) -> InputState:
	var input := InputState.new()

	var source_id := TacticalRoleSystem.shadow_source_id
	if source_id.is_empty():
		input.move_direction = navigate_toward(
			agent, AiStrategy.midfield_goal(0, agent.team_id), view)
		return input

	var source_pv := view.player_view(source_id)
	if source_pv == null:
		return input

	var perp := Vector2(-sin(source_pv.facing), cos(source_pv.facing))
	var target_pos := source_pv.position + perp * OFFSET_DIST
	if agent.position.distance_squared_to(target_pos) > 1.0:
		input.move_direction = navigate_toward(agent, target_pos, view)

	if enemy_pressure(agent, view) > 0:
		try_queue_ability(agent, view, input)

	return input
