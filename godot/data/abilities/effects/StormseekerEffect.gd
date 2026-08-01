class_name StormseekerEffect
extends AbilityEffect

## Grants the Stormseeker buff for `duration` seconds.
## Effects: −33% GCD, −33% cast times, freeze ultraball charge, +33% ultra mana regen.

@export var duration: float = 12.0

func apply(ctx: AbilityContext) -> bool:
	EventBus.buff_applied.emit(ctx.caster_id, "stormseeker", duration)
	return true
