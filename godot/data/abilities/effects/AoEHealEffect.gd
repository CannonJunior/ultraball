class_name AoEHealEffect
extends AbilityEffect

@export var amount: float = 20.0
@export var radius: float = 6.0
## When true, includes the caster. When false, excludes self.
@export var include_self: bool = true

func apply(ctx: AbilityContext) -> bool:
	var targets := ctx.allies_in_radius(radius)
	if targets.is_empty():
		return false
	for tid in targets:
		if not include_self and tid == ctx.caster_id:
			continue
		EventBus.healing_applied.emit(ctx.caster_id, tid, amount)
	return true
