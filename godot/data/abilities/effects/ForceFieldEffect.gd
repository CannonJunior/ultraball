class_name ForceFieldEffect
extends AbilityEffect

func apply(ctx: AbilityContext) -> bool:
	EventBus.force_field_spawned.emit(ctx.caster_id, ctx.caster_team_id, ctx.caster_position)
	return true
