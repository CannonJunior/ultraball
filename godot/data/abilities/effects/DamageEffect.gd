class_name DamageEffect
extends AbilityEffect

@export var damage: float = 10.0
@export var knockback_distance: float = 0.0

func apply(ctx: AbilityContext) -> bool:
	if ctx.target_id.is_empty():
		return false
	if not ctx.hit_ids.has(ctx.target_id):
		ctx.hit_ids.append(ctx.target_id)
	EventBus.damage_requested.emit({
		"attacker_id": ctx.caster_id,
		"target_id": ctx.target_id,
		"amount": damage,
		"knockback_distance": knockback_distance,
		"facing": ctx.caster_facing,
	})
	return true
