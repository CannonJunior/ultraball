class_name AiStrategy
extends Resource

## Base class for AI strategies — shared static helpers for all subclasses.

# ── Static helpers (call as AiStrategy.xxx() from subclasses) ─────────────────

static func endzone_x(tid: int) -> float:
	return 132.0 if tid == 0 else 8.0

## True if pos_a is closer to the scoring end than pos_b for this team.
static func is_ahead(pos_a: Vector2, pos_b: Vector2, tid: int) -> bool:
	return pos_a.x > pos_b.x if tid == 0 else pos_a.x < pos_b.x

## Closest alive on-field player to a world position.
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

## Y lane with the fewest nearby alive enemies.
static func open_lane_y(enemies: Array) -> float:
	const LANES: Array[float] = [5.0, 12.0, 20.0, 28.0, 35.0]
	var best := 20.0
	var fewest := 999
	for ly in LANES:
		var count := 0
		for e in enemies:
			var ev := e as AiView.PlayerView
			if ev == null or not ev.is_alive: continue
			if absf(ev.position.y - ly) < 8.0: count += 1
		if count < fewest:
			fewest = count
			best = ly
	return best

## Stable Y lane from roster slot (0-indexed, 5 lanes across 40 m field).
static func lane_y(roster_slot: int) -> float:
	return 5.0 + float(roster_slot % 5) * 7.0

## Mid-field staging position for a given agent.
static func midfield_pos(roster_slot: int, tid: int) -> Vector2:
	var base_x := 60.0 + float(roster_slot % 4) * 10.0
	if tid == 1:
		base_x = 80.0 - float(roster_slot % 4) * 10.0
	return Vector2(clampf(base_x, 30.0, 110.0), lane_y(roster_slot))

# ── Override in subclass ───────────────────────────────────────────────────────

func evaluate_goal(
	agent: AiView.PlayerView,
	view: AiView,
	policy: Dictionary
) -> Vector2:
	push_error("AiStrategy.evaluate_goal() not implemented: " + resource_path)
	return agent.position
