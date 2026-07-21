class_name StunImmuneEffect
extends AbilityEffect

@export var duration: float = 5.0
@export var targets_self: bool = true

func apply(ctx: AbilityContext) -> bool:
	var tid := ctx.caster_id if targets_self else ctx.target_id
	if tid.is_empty():
		return false
	EventBus.buff_applied.emit(tid, "stun_immune", duration)
	return true
