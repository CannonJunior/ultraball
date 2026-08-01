class_name CreatureFlankTactics
extends "res://systems/ai/tactics/BalancedTactics.gd"

## Position on the opposite side of the creature from the holder,
## herding it toward enemy players.

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

	var tid      := view.requesting_team_id
	var norm     := AiStrategy.team_advance_dir(tid)
	var perp     := Vector2(-norm.y, norm.x)
	var creature := view.creatures[0]

	# Compute which lateral side of the creature the holder is on
	var holder_side  := (holder.position - creature.position).dot(perp)
	# Place this agent on the opposite side — flanking to herd the creature
	var side_sign    := -1.0 if holder_side > 0.0 else 1.0
	var rank_offset  := float(agent.roster_slot % 3) * 4.0  # stagger multiple flankers

	# Advance ahead of or alongside the carrier along the arm
	var c_local  := AiStrategy.world_to_arm_local(holder.position, tid)
	var spread   := 8.0 + float(agent.roster_slot % 3) * 6.0
	var target_along := c_local.x + spread
	var target   := AiStrategy.arm_to_world(target_along, (10.0 + rank_offset) * side_sign, tid)
	input.move_direction = navigate_toward(agent, target, view)
	try_queue_ability(agent, view, input)
