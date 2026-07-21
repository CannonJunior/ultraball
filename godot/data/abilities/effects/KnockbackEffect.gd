class_name KnockbackEffect
extends AbilityEffect

@export var distance: float = 5.0
## When true, launches target into the air (airborne state).
@export var launches_airborne: bool = false
@export var launch_height: float = 2.0

func apply(ctx: AbilityContext) -> bool:
	if ctx.target_id.is_empty():
		return false
	var direction := (ctx.target_position - ctx.caster_position).normalized()
	EventBus.debuff_applied.emit(ctx.target_id, "knockback", 0.0, {
		"direction": direction,
		"distance": distance,
		"launches_airborne": launches_airborne,
		"launch_height": launch_height,
	})
	return true
