class_name AoEDamageEffect
extends AbilityEffect

@export var damage: float = 15.0
@export var radius: float = 4.0
@export var knockback_distance: float = 0.0
## When true, uses aim_position as center. When false, uses caster position.
@export var use_aim_position: bool = false

func apply(ctx: AbilityContext) -> bool:
	var center := ctx.aim_position if use_aim_position else ctx.caster_position
	for enemy_id in ctx.enemies_in_radius(radius):
		EventBus.damage_requested.emit({
			"attacker_id": ctx.caster_id,
			"target_id": enemy_id,
			"amount": damage,
			"knockback_distance": knockback_distance,
			"facing": (ctx._positions.get(enemy_id, center) - center).angle(),
		})
		if not ctx.hit_ids.has(enemy_id):
			ctx.hit_ids.append(enemy_id)
	return true
