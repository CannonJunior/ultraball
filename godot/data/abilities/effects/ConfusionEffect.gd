class_name ConfusionEffect
extends AbilityEffect

@export var duration: float = 2.0

func apply(ctx: AbilityContext) -> bool:
	if ctx.target_id.is_empty():
		return false
	EventBus.debuff_applied.emit(ctx.target_id, "confused", duration, {})
	return true
