class_name CarrierTactics
extends "res://systems/ai/tactics/AiTactics.gd"

## The unit's sole focus is ball possession.
## No ball: chase ball directly; strip opponent carrier if in range.
## Has ball: sprint toward own endzone.

const STRIP_RANGE_SQ := 16.0  # 4 m

func produce_input(
	agent: AiView.PlayerView,
	_goal: Vector2,
	view: AiView,
	_policy: Dictionary
) -> InputState:
	var input := InputState.new()
	var ball := view.ball
	if ball == null:
		return input

	if agent.has_ball:
		var endzone := AiStrategy.endzone_goal(agent.team_id)
		input.move_direction = navigate_toward(agent, endzone, view)
		return input

	if not ball.holder_id.is_empty():
		var holder_team := MatchState.team_for_player(ball.holder_id)
		if holder_team != agent.team_id:
			var holder_pv := view.player_view(ball.holder_id)
			var target_pos := holder_pv.position if holder_pv != null else ball.position
			input.move_direction = navigate_toward(agent, target_pos, view)
			if agent.position.distance_squared_to(target_pos) < STRIP_RANGE_SQ:
				try_queue_ability(agent, view, input)
			return input
		else:
			var lead := AiStrategy.endzone_goal(agent.team_id)
			input.move_direction = navigate_toward(agent, lead, view)
			return input

	input.move_direction = navigate_toward(agent, ball.position, view)
	return input
