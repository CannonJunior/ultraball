class_name SnapPullEffect
extends AbilityEffect

## Pulls a single enemy target toward the caster until they are exactly
## min_final_distance away.  Targets already within that distance are unaffected.
@export var min_final_distance: float = 1.0

func apply(ctx: AbilityContext) -> bool:
	var tid := ctx.target_id
	if tid.is_empty():
		return false
	var tpos: Vector2 = ctx._positions.get(tid, ctx.caster_position)
	var diff: Vector2 = tpos - ctx.caster_position
	var dist: float = diff.length()
	if dist <= min_final_distance or dist < 0.001:
		return false
	EventBus.debuff_applied.emit(tid, "knockback", 0.0, {
		"direction": -diff.normalized(),
		"distance": dist - min_final_distance,
		"launches_airborne": false,
		"launch_height": 0.0,
	})
	ctx.hit_ids.append(tid)
	return true
