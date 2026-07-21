class_name CreatureGoalEffect
extends AbilityEffect

## Redirects the nearest creature to pursue the target player for a duration.
@export var duration: float = 4.0
## When true, goads creature toward caster's targeted enemy.
## When false, goads creature toward nearest enemy of caster's team.
@export var use_current_target: bool = true

func apply(ctx: AbilityContext) -> bool:
	var target_id := ctx.target_id if use_current_target else ""
	EventBus.creature_goaded.emit(target_id, duration)
	return true
