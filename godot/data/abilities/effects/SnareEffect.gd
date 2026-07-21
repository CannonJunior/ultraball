class_name SnareEffect
extends AbilityEffect

@export var duration: float = 1.5
## Speed multiplier while snared (0.5 = 50% slow).
@export var slow_factor: float = 0.5
## When > 0, snares all enemies within this radius of caster instead of single target.
@export var aoe_radius: float = 0.0

func apply(ctx: AbilityContext) -> bool:
	if aoe_radius > 0.0:
		var targets := ctx.enemies_in_radius(aoe_radius)
		for tid in targets:
			EventBus.debuff_applied.emit(tid, "snare", duration, {"slow_factor": slow_factor})
		return targets.size() > 0
	var tid := ctx.target_id
	if tid.is_empty():
		return false
	EventBus.debuff_applied.emit(tid, "snare", duration, {"slow_factor": slow_factor})
	return true
