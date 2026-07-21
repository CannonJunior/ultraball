class_name TrapSpawnEffect
extends AbilityEffect

## Spawns a TricksterTrap at the caster's pre-teleport position.
## Emits trap_spawn_requested; TerrainMutationSystem handles scene instantiation.

@export var trap_radius: float = 2.5
@export var snare_duration: float = 2.0
@export var slow_factor: float = 0.5
@export var trap_timer: float = 8.0

func apply(ctx: AbilityContext) -> bool:
	EventBus.trap_spawn_requested.emit(
		ctx.caster_position, ctx.caster_team_id,
		trap_radius, snare_duration, slow_factor, trap_timer
	)
	return true
