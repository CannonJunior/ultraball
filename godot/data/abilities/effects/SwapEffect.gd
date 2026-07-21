class_name SwapEffect
extends AbilityEffect

## Teleports caster to target's position and target to caster's position.
func apply(ctx: AbilityContext) -> bool:
	if ctx.target_id.is_empty():
		return false
	EventBus.debuff_applied.emit(ctx.caster_id, "swap", 0.0, {
		"swap_partner_id": ctx.target_id,
		"caster_pos": ctx.caster_position,
		"target_pos": ctx.target_position,
	})
	return true
