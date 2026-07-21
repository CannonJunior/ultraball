class_name DurationDoubleNextEffect
extends AbilityEffect

## Sets a flag on the target ally: the next buff applied to them has double duration.
## Used by Vitalist's Prolong (slot 9).
@export var range: float = 10.0

func apply(ctx: AbilityContext) -> bool:
	var tid := ctx.nearest_ally_in_range(range)
	if tid.is_empty():
		tid = ctx.caster_id
	EventBus.buff_applied.emit(tid, "duration_double_next", 0.0)
	return true
