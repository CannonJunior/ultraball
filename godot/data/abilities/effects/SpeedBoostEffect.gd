class_name SpeedBoostEffect
extends AbilityEffect

@export var speed_multiplier: float = 1.5
@export var duration: float = 3.0
@export var targets_self: bool = true

func apply(ctx: AbilityContext) -> bool:
	var tid := ctx.caster_id if targets_self else ctx.target_id
	if tid.is_empty():
		return false
	EventBus.buff_applied.emit(tid, "speed_boost", duration)
	EventBus.debuff_applied.emit(tid, "speed_mult_set", duration, {"multiplier": speed_multiplier})
	return true
