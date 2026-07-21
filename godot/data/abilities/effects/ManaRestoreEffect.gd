class_name ManaRestoreEffect
extends AbilityEffect

@export var amount: float = 20.0
## 0=Red 1=Blue 2=Yellow 3=All
@export_enum("Red", "Blue", "Yellow", "All") var mana_type: int = 0
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
	EventBus.buff_applied.emit(tid, "mana_restore", 0.0)
	EventBus.debuff_applied.emit(tid, "mana_restore_set", 0.0, {
		"amount": amount,
		"mana_type": mana_type,
	})
	return true
