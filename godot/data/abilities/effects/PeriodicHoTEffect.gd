class_name PeriodicHoTEffect
extends AbilityEffect

## Applies HoT to all allies (including self) within aoe_radius.
## Used by Vitalist's VERDURE ultra.
@export var ticks: int = 5
@export var heal_per_tick: float = 20.0
@export var interval: float = 2.0
@export var aoe_radius: float = 8.0

func apply(ctx: AbilityContext) -> bool:
	for ally in ctx.allies_in_radius(aoe_radius):
		EventBus.periodic_hot_applied.emit({
			"target_id": ally,
			"caster_id": ctx.caster_id,
			"ticks": ticks,
			"heal_per_tick": heal_per_tick,
			"interval": interval,
		})
	return true
