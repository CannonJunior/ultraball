class_name ShotCallerTactics
extends "res://systems/ai/tactics/AiTactics.gd"

## Scans for the highest-priority enemy, marks them for the team, and applies CC.
## Priority: low-HP enemies closer to our endzone.

const MARK_INTERVAL := 4.0
const CC_RANGE_SQ   := 100.0  # 10 m

var _mark_timer:      float  = 0.0
var _current_mark_id: String = ""

func produce_input(
	agent: AiView.PlayerView,
	_goal: Vector2,
	view: AiView,
	_policy: Dictionary
) -> InputState:
	var input := InputState.new()
	_mark_timer -= 0.1  # called at 10 Hz

	var best := _pick_target(agent, view)
	if best != null:
		if _mark_timer <= 0.0 or _current_mark_id != best.player_id:
			_current_mark_id = best.player_id
			_mark_timer      = MARK_INTERVAL
			EventBus.enemy_marked.emit(best.player_id, agent.team_id)

		input.move_direction = navigate_toward(agent, best.position, view)
		if agent.position.distance_squared_to(best.position) < CC_RANGE_SQ:
			try_queue_ability(agent, view, input)
	else:
		input.move_direction = navigate_toward(
			agent, AiStrategy.midfield_goal(0, agent.team_id), view)

	return input

func _pick_target(agent: AiView.PlayerView, view: AiView) -> AiView.PlayerView:
	var best:  AiView.PlayerView = null
	var best_score := INF
	for e in view.enemies():
		if not e.is_alive: continue
		var dist  := agent.position.distance_to(e.position)
		var score := e.health_pct * 1.5 + dist * 0.05
		if score < best_score:
			best_score = score
			best = e
	return best
