class_name CCCleanseEffect
extends AbilityEffect

## Clears all crowd-control debuffs (stun, snare, hex, confusion) from the target.
@export var targets_self: bool = true
## Optionally also clears damage-over-time effects.
@export var clear_dots: bool = false
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
	EventBus.buff_applied.emit(tid, "cleanse", 0.0)
	EventBus.debuff_applied.emit(tid, "cleanse_cc", 0.0, {"clear_dots": clear_dots})
	return true
