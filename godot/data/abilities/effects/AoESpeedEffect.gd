class_name AoESpeedEffect
extends AbilityEffect

## Applies a speed multiplier to all allies within radius of the caster.
@export var radius: float = 6.0
@export var speed_multiplier: float = 1.4
@export var duration: float = 4.0
## When false, excludes the caster from the buff.
@export var include_self: bool = true

func apply(ctx: AbilityContext) -> bool:
	var targets := ctx.allies_in_radius(radius)
	if targets.is_empty():
		return false
	for tid in targets:
		if not include_self and tid == ctx.caster_id:
			continue
		EventBus.buff_applied.emit(tid, "speed_boost", duration)
		EventBus.debuff_applied.emit(tid, "speed_mult_set", duration, {"multiplier": speed_multiplier})
	return true
