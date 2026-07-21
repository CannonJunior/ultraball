class_name PullEffect
extends AbilityEffect

@export var distance: float = 5.0
## When true, pulls toward caster. When false, pulls toward aim_position.
@export var toward_caster: bool = true
@export var targets_enemies: bool = true
## 0 = single target, >0 = pull all within radius.
@export var aoe_radius: float = 0.0

func apply(ctx: AbilityContext) -> bool:
	var pull_targets: Array[String] = []
	if aoe_radius > 0.0:
		pull_targets = ctx.enemies_in_radius(aoe_radius) if targets_enemies else ctx.allies_in_radius(aoe_radius)
	elif not ctx.target_id.is_empty():
		pull_targets = [ctx.target_id]

	if pull_targets.is_empty():
		return false

	var anchor := ctx.caster_position if toward_caster else ctx.aim_position
	for tid in pull_targets:
		var tpos: Vector2 = ctx._positions.get(tid, ctx.caster_position)
		var direction := (anchor - tpos).normalized()
		EventBus.debuff_applied.emit(tid, "knockback", 0.0, {
			"direction": direction,
			"distance": distance,
			"launches_airborne": false,
			"launch_height": 0.0,
		})
	return true
