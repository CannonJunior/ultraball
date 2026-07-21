class_name MarkEffect
extends AbilityEffect

@export var duration: float = 4.0
## Incoming damage multiplier while marked (1.25 = +25% damage taken).
@export var damage_taken_multiplier: float = 1.25

func apply(ctx: AbilityContext) -> bool:
	if ctx.target_id.is_empty():
		return false
	EventBus.debuff_applied.emit(ctx.target_id, "marked", duration, {
		"damage_taken_multiplier": damage_taken_multiplier
	})
	return true
