class_name StunEffect
extends AbilityEffect

@export var duration: float = 1.0

func apply(ctx: AbilityContext) -> bool:
	if ctx.target_id.is_empty():
		return false
	EventBus.debuff_applied.emit(ctx.target_id, "stun", duration, {})
	return true
