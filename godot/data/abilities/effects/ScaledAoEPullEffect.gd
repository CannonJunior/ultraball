class_name ScaledAoEPullEffect
extends AbilityEffect

## Pulls all on-field enemies toward the caster.
## Enemies closer than near_threshold are pulled by a flat near_pull distance.
## Enemies at or beyond near_threshold are pulled by scale_factor × their distance,
## capped at far_pull_max (0 = no cap).
@export var near_threshold: float = 5.0
@export var near_pull: float = 4.0
@export var scale_factor: float = 0.3
@export var far_pull_max: float = 0.0

func apply(ctx: AbilityContext) -> bool:
	var hit := false
	for tid in ctx._all_player_ids:
		if not ctx._alive.get(tid, false): continue
		if not ctx._on_field.get(tid, false): continue
		if ctx._team_ids.get(tid, -1) == ctx.caster_team_id: continue
		var tpos: Vector2 = ctx._positions.get(tid, ctx.caster_position)
		var diff: Vector2 = tpos - ctx.caster_position
		var dist: float = diff.length()
		if dist < 0.001: continue
		var pull_dist: float
		if dist < near_threshold:
			pull_dist = minf(near_pull, dist)
		else:
			pull_dist = dist * scale_factor
			if far_pull_max > 0.0:
				pull_dist = minf(pull_dist, far_pull_max)
		EventBus.debuff_applied.emit(tid, "knockback", 0.0, {
			"direction": -diff.normalized(),
			"distance": pull_dist,
			"launches_airborne": false,
			"launch_height": 0.0,
		})
		ctx.hit_ids.append(tid)
		hit = true
	return hit
