class_name DamageBoostEffect
extends AbilityEffect

@export var damage_multiplier: float = 1.3
@export var duration: float = 4.0
@export var targets_self: bool = false
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
	EventBus.buff_applied.emit(tid, "damage_boost", duration)
	EventBus.debuff_applied.emit(tid, "damage_boost_set", duration, {"multiplier": damage_multiplier})
	return true
