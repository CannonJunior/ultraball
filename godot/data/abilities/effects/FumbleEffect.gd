class_name FumbleEffect
extends AbilityEffect

## Forces the target to drop the ball if they are carrying it.
@export var fumble_velocity_scale: float = 1.0

func apply(ctx: AbilityContext) -> bool:
	if ctx.target_id.is_empty():
		return false
	EventBus.debuff_applied.emit(ctx.target_id, "fumble", 0.0, {
		"velocity_scale": fumble_velocity_scale,
	})
	return true
