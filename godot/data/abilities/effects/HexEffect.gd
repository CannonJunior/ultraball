class_name HexEffect
extends AbilityEffect

@export var duration: float = 3.0
## Damage output reduction while hexed (0.8 = 20% less damage).
@export var damage_factor: float = 0.8

func apply(ctx: AbilityContext) -> bool:
	if ctx.target_id.is_empty():
		return false
	EventBus.debuff_applied.emit(ctx.target_id, "hex", duration, {"damage_factor": damage_factor})
	return true
