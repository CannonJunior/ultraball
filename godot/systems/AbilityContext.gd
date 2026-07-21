class_name AbilityContext

## Transient context built by AbilitySystem each time an ability fires.
## Effects read from this; they never hold references to game nodes.

var caster_id: String = ""
var caster_position: Vector2 = Vector2.ZERO
var caster_facing: float = 0.0
var caster_team_id: int = 0

var target_id: String = ""
var target_position: Vector2 = Vector2.ZERO

## World-space aim point for aimed abilities (Geomancer terrain, Fissure).
var aim_position: Vector2 = Vector2.ZERO

## Cached lists built from MatchState at ability resolution time.
## Effects call helpers rather than reading MatchState themselves.
var _all_player_ids: Array[String] = []
var _positions: Dictionary = {}      # player_id -> Vector2
var _team_ids: Dictionary = {}       # player_id -> int
var _alive: Dictionary = {}          # player_id -> bool
var _on_field: Dictionary = {}       # player_id -> bool

## IDs of entities hit so far this ability (populated by effects).
var hit_ids: Array[String] = []

static func build(
	caster_id_: String,
	target_id_: String,
	aim_pos: Vector2,
	all_players: Array
) -> AbilityContext:
	var ctx := AbilityContext.new()
	ctx.caster_id = caster_id_
	ctx.target_id = target_id_
	ctx.aim_position = aim_pos

	var caster_record: MatchState.PlayerRecord = MatchState.players.get(caster_id_)
	if caster_record:
		ctx.caster_team_id = caster_record.team_id

	for pid in MatchState.players:
		var rec: MatchState.PlayerRecord = MatchState.players[pid]
		ctx._all_player_ids.append(pid)
		ctx._team_ids[pid] = rec.team_id
		ctx._alive[pid] = rec.is_alive
		ctx._on_field[pid] = rec.is_on_field

	# Positions come from live node positions (set by caller).
	for p in all_players:
		ctx._positions[p.player_id] = p.global_position

	if caster_id_ != "":
		ctx.caster_position = ctx._positions.get(caster_id_, Vector2.ZERO)
	if target_id_ != "":
		ctx.target_position = ctx._positions.get(target_id_, Vector2.ZERO)

	return ctx

# ── Query helpers used by effects ─────────────────────────────────────────────

func allies_in_radius(radius: float) -> Array[String]:
	var result: Array[String] = []
	for pid in _all_player_ids:
		if not _alive.get(pid, false): continue
		if not _on_field.get(pid, false): continue
		if _team_ids.get(pid, -1) != caster_team_id: continue
		var pos: Vector2 = _positions.get(pid, Vector2.ZERO)
		if caster_position.distance_to(pos) <= radius:
			result.append(pid)
	return result

func enemies_in_radius(radius: float) -> Array[String]:
	var result: Array[String] = []
	for pid in _all_player_ids:
		if not _alive.get(pid, false): continue
		if not _on_field.get(pid, false): continue
		if _team_ids.get(pid, -1) == caster_team_id: continue
		var pos: Vector2 = _positions.get(pid, Vector2.ZERO)
		if caster_position.distance_to(pos) <= radius:
			result.append(pid)
	return result

func nearest_ally_in_range(range_m: float) -> String:
	var best := ""
	var best_dist := INF
	for pid in _all_player_ids:
		if pid == caster_id: continue
		if not _alive.get(pid, false): continue
		if not _on_field.get(pid, false): continue
		if _team_ids.get(pid, -1) != caster_team_id: continue
		var d := caster_position.distance_to(_positions.get(pid, Vector2.ZERO))
		if d < best_dist and d <= range_m:
			best_dist = d
			best = pid
	return best

func nearest_enemy_in_range(range_m: float) -> String:
	var best := ""
	var best_dist := INF
	for pid in _all_player_ids:
		if not _alive.get(pid, false): continue
		if not _on_field.get(pid, false): continue
		if _team_ids.get(pid, -1) == caster_team_id: continue
		var d := caster_position.distance_to(_positions.get(pid, Vector2.ZERO))
		if d < best_dist and d <= range_m:
			best_dist = d
			best = pid
	return best
