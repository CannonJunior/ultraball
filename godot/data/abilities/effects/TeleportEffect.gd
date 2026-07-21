class_name TeleportEffect
extends AbilityEffect

@export var distance: float = 7.0
## When true, teleports in the facing direction. When false, teleports to aimed point.
@export var use_facing: bool = true

func apply(ctx: AbilityContext) -> bool:
	var destination: Vector2
	if use_facing:
		destination = ctx.caster_position + Vector2.from_angle(ctx.caster_facing) * distance
	else:
		destination = ctx.aim_position
	EventBus.debuff_applied.emit(ctx.caster_id, "teleport", 0.0, {"destination": destination})
	return true
