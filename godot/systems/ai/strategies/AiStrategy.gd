class_name AiStrategy
extends Resource

## Base class for AI strategies — field-mode-aware geometry helpers used by all subclasses.
## All positions are expressed in arm-local (along, side) coordinates, then converted to world
## space. This makes strategy code identical for 2-team and 3-team field modes.
##
## 2-team:  along = (140−X) for team 0, X for team 1  (increases toward own scoring zone).
##           side = Y − 20 (centre Y).
## 3-team:  along = dot(pos − centre, arm_normal).  side = dot(pos − centre, arm_perp).

# ── Field-mode-aware geometry ──────────────────────────────────────────────────

## Unit vector pointing toward own scoring endzone for team tid.
static func team_advance_dir(tid: int) -> Vector2:
	if not MatchState.is_three_team:
		# Team 0 scores left (low x) → advance = −X.  Team 1 scores right → advance = +X.
		return Vector2(-1.0, 0.0) if tid == 0 else Vector2(1.0, 0.0)
	return MatchState.TEAM3_NORMALS[tid]

## Convert arm-local (along, side) to world position for team tid.
## along  = metres toward own endzone from field start.
## side   = perpendicular offset (positive = one lateral direction).
static func arm_to_world(along: float, side: float, tid: int) -> Vector2:
	if not MatchState.is_three_team:
		# 2-team: "along" increases toward own scoring zone.
		# Team 0 (left) scores at low x  → x = 140 - along
		# Team 1 (right) scores at high x → x = along
		var x := (140.0 - along) if tid == 0 else along
		return Vector2(clampf(x, 5.0, 135.0), clampf(side + 20.0, 2.0, 38.0))
	var centre := Vector2(MatchState.FIELD3_CX, MatchState.FIELD3_CY)
	var norm: Vector2 = MatchState.TEAM3_NORMALS[tid]
	var perp := Vector2(-norm.y, norm.x)
	return centre + norm * along + perp * side

## Decompose a world position into arm-local (along=x, side=y) for team tid.
static func world_to_arm_local(pos: Vector2, tid: int) -> Vector2:
	if not MatchState.is_three_team:
		var along := (140.0 - pos.x) if tid == 0 else pos.x
		return Vector2(along, pos.y - 20.0)
	var centre := Vector2(MatchState.FIELD3_CX, MatchState.FIELD3_CY)
	var norm: Vector2 = MatchState.TEAM3_NORMALS[tid]
	var perp := Vector2(-norm.y, norm.x)
	var rel := pos - centre
	return Vector2(rel.dot(norm), rel.dot(perp))

## Signed distance toward team tid's endzone (higher = closer to scoring).
static func advance_score(pos: Vector2, tid: int) -> float:
	return world_to_arm_local(pos, tid).x

## True if pos_a is further along the scoring direction than pos_b for team tid.
static func is_ahead(pos_a: Vector2, pos_b: Vector2, tid: int) -> bool:
	return advance_score(pos_a, tid) > advance_score(pos_b, tid)

## Arm-local "along" value at the scoring threshold (cap for receiver spread).
static func endzone_along() -> float:
	if not MatchState.is_three_team:
		return 120.0
	return MatchState.FIELD3_CHAN_OUTER

## World-space goal at team tid's endzone — where the carrier aims.
## Overshoots the scoring threshold by a few metres so the carrier crosses it.
static func endzone_goal(tid: int) -> Vector2:
	var overshoot := 8.0 if not MatchState.is_three_team else 5.0
	return arm_to_world(endzone_along() + overshoot, 0.0, tid)

## Stable midfield staging position for agents with no immediate task.
static func midfield_goal(roster_slot: int, tid: int) -> Vector2:
	var along := (60.0 + float(roster_slot % 5) * 5.0) if not MatchState.is_three_team \
	          else (25.0 + float(roster_slot % 4) * 5.0)
	return arm_to_world(along, side_for_slot(roster_slot), tid)

## Perpendicular (side) lane offset for a roster slot.
## Spread is ±16 m, cycling through 11 distinct positions before wrapping.
static func side_for_slot(slot: int) -> float:
	const SIDES: Array = [-12.0, 12.0, 0.0, -6.0, 6.0, -16.0, 16.0, -9.0, 9.0, -3.0, 3.0]
	return SIDES[slot % SIDES.size()]

# ── Shared queries ─────────────────────────────────────────────────────────────

## Closest alive on-field player in the array to a world position.
static func closest_to(players: Array, pos: Vector2) -> AiView.PlayerView:
	var best: AiView.PlayerView = null
	var best_d := INF
	for p in players:
		var pv := p as AiView.PlayerView
		if pv == null or not pv.is_alive or not pv.is_on_field: continue
		var d := pv.position.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = pv
	return best

# ── Override in subclass ───────────────────────────────────────────────────────

func evaluate_goal(
	agent: AiView.PlayerView,
	view: AiView,
	policy: Dictionary
) -> Vector2:
	push_error("AiStrategy.evaluate_goal() not implemented: " + resource_path)
	return agent.position
