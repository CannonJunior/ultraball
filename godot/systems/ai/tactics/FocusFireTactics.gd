class_name FocusFireTactics
extends "res://systems/ai/tactics/BalancedTactics.gd"

## Converge on the weakest (lowest health%) enemy for rapid eliminations.

func _mover_input(
	agent: AiView.PlayerView,
	goal: Vector2,
	view: AiView,
	input: InputState
) -> void:
	# Override goal with weakest enemy position when close enough to matter
	var actual_goal := goal
	var weakest: AiView.PlayerView = null
	for e in view.enemies():
		if not e.is_alive or e.is_stunned: continue
		if weakest == null or e.health_pct < weakest.health_pct:
			weakest = e
	if weakest != null and agent.position.distance_squared_to(weakest.position) < 400.0: # 20m
		actual_goal = weakest.position
	input.move_direction = navigate_toward(agent, actual_goal, view)
	try_queue_ability(agent, view, input)
