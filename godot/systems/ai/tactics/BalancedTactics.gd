class_name BalancedTactics
extends AiTactics

## Default balanced tactics: advance toward goal, pass when receiver is open.

## Minimum advance (m) a receiver must have for the holder to pass.
## Override in subclasses for more/less eager passing.
func _pass_threshold() -> float:
	return 5.0

func produce_input(
	agent: AiView.PlayerView,
	goal: Vector2,
	view: AiView,
	_policy: Dictionary
) -> InputState:
	var input := InputState.new()
	if agent.has_ball:
		_holder_input(agent, goal, view, input)
	else:
		_mover_input(agent, goal, view, input)
	return input

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
	else:
		input.move_direction = navigate_toward(agent, goal, view)
	try_queue_ability(agent, view, input)

func _mover_input(
	agent: AiView.PlayerView,
	goal: Vector2,
	view: AiView,
	input: InputState
) -> void:
	input.move_direction = navigate_toward(agent, goal, view)
	try_queue_ability(agent, view, input)
