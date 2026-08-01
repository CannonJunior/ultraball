class_name HeroBallTactics
extends "res://systems/ai/tactics/BalancedTactics.gd"

## Carrier runs hard; support rallies close around the holder and swarms threats.

## Escort slots in arm-local coordinates: x = along (ahead/behind), y = side (lateral).
const ESCORT: Array = [
	Vector2( 3.0, -4.0),
	Vector2( 3.0,  4.0),
	Vector2(-4.0, -3.0),
	Vector2(-4.0,  3.0),
	Vector2( 0.0, -5.0),
	Vector2( 0.0,  5.0),
]

func _holder_input(
	agent: AiView.PlayerView,
	goal: Vector2,
	view: AiView,
	input: InputState
) -> void:
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
		try_queue_ability(agent, view, input)
		return

	# Convert arm-local escort offset to world space
	var tid  := view.requesting_team_id
	var norm := AiStrategy.team_advance_dir(tid)
	var perp := Vector2(-norm.y, norm.x)
	var off  : Vector2 = ESCORT[agent.roster_slot % ESCORT.size()]
	var target := holder.position + norm * off.x + perp * off.y
	input.move_direction = navigate_toward(agent, target, view)

	# Swarm nearest threat within 10 m of holder
	var nearest := view.nearest_enemy(holder.position)
	if nearest != null and holder.position.distance_squared_to(nearest.position) < 100.0:
		input.move_direction = navigate_toward(agent, nearest.position, view)
	try_queue_ability(agent, view, input)
