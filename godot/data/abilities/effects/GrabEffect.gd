class_name GrabEffect
extends AbilityEffect

## Pulls the target toward the caster by up to pull_distance, capped at the
## actual separation so the target can never overshoot the caster.
## Against an ally: applies heal_amount healing.
## Against an enemy: deals damage_amount damage.

@export var pull_distance: float = 7.0
@export var heal_amount: float = 10.0
@export var damage_amount: float = 10.0

func apply(ctx: AbilityContext) -> bool:
	var tid := ctx.target_id
	if tid.is_empty():
		return false

	var tpos: Vector2 = ctx._positions.get(tid, ctx.caster_position)
	var to_caster: Vector2 = ctx.caster_position - tpos
	var dist: float = to_caster.length()
	if dist < 0.001:
		return false

	EventBus.debuff_applied.emit(tid, "knockback", 0.0, {
		"direction": to_caster / dist,
		"distance": minf(pull_distance, dist),
		"launches_airborne": false,
		"launch_height": 0.0,
	})
	ctx.hit_ids.append(tid)

	if ctx._team_ids.get(tid, -1) == ctx.caster_team_id:
		EventBus.healing_applied.emit(ctx.caster_id, tid, heal_amount)
	else:
		EventBus.damage_requested.emit({
			"attacker_id": ctx.caster_id,
			"target_id": tid,
			"amount": damage_amount,
			"knockback_distance": 0.0,
			"facing": ctx.caster_facing,
		})
	return true
