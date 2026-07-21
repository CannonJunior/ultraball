class_name DamageReductionEffect
extends AbilityEffect

## Incoming damage is multiplied by this value (0.7 = 30% damage reduction).
@export var reduction_factor: float = 0.7
@export var duration: float = 3.0
@export var targets_self: bool = true
## When > 0 and no explicit target, auto-targets nearest ally within this range.
@export var auto_ally_range: float = 0.0

func apply(ctx: AbilityContext) -> bool:
	var tid: String
	if targets_self:
		tid = ctx.caster_id
	elif not ctx.target_id.is_empty():
		tid = ctx.target_id
	elif auto_ally_range > 0.0:
		tid = ctx.nearest_ally_in_range(auto_ally_range)
	else:
		return false
	if tid.is_empty():
		return false
	EventBus.buff_applied.emit(tid, "damage_reduction", duration)
	EventBus.debuff_applied.emit(tid, "damage_reduction_set", duration, {"factor": reduction_factor})
	return true
