class_name TerrainTimeEffect
extends AbilityEffect

## Extends (positive) or collapses (negative) active terrain event timers in an area.
@export var radius: float = 5.0
@export var delta_seconds: float = 10.0
## When true, centers on the caster. When false, centers on aim_position.
@export var use_caster_position: bool = false

func apply(ctx: AbilityContext) -> bool:
	var center := ctx.caster_position if use_caster_position else ctx.aim_position
	EventBus.terrain_timers_shifted.emit(center, radius, delta_seconds)
	return true
