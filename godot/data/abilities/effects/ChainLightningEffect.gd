class_name ChainLightningEffect
extends AbilityEffect

## Deals damage to the primary target, then bounces to up to 2 nearby enemies
## within chain_radius of the primary target's position.

@export var damage: float = 35.0
@export var chain_damage: float = 22.0
@export var chain_radius: float = 6.0

func apply(ctx: AbilityContext) -> bool:
	if ctx.target_id.is_empty():
		return false

	EventBus.damage_requested.emit({
		"attacker_id": ctx.caster_id,
		"target_id":   ctx.target_id,
		"amount":      damage,
		"knockback_distance": 0.0,
		"facing":      ctx.caster_facing,
	})
	ctx.hit_ids.append(ctx.target_id)

	# Collect enemies within chain_radius of the primary target, sorted nearest-first.
	var target_pos: Vector2 = ctx._positions.get(ctx.target_id, ctx.target_position)
	var candidates: Array = []
	for pid in ctx._all_player_ids:
		if pid == ctx.caster_id or pid == ctx.target_id: continue
		if not ctx._alive.get(pid, false) or not ctx._on_field.get(pid, false): continue
		if ctx._team_ids.get(pid, -1) == ctx.caster_team_id: continue
		var d := target_pos.distance_to(ctx._positions.get(pid, Vector2.ZERO))
		if d <= chain_radius:
			candidates.append({"id": pid, "dist": d})
	candidates.sort_custom(func(a, b): return a["dist"] < b["dist"])

	for i in mini(candidates.size(), 2):
		var pid: String = candidates[i]["id"]
		EventBus.damage_requested.emit({
			"attacker_id": ctx.caster_id,
			"target_id":   pid,
			"amount":      chain_damage,
			"knockback_distance": 0.0,
			"facing":      ctx.caster_facing,
		})
		ctx.hit_ids.append(pid)

	return true
