class_name AiView

const PlayerLookup = preload("res://systems/PlayerLookup.gd")

## Filtered read-only snapshot of world state for AI consumption.
## AI cannot access MatchState directly — it only sees this view.
## Designed to prevent AI cheating (hidden cooldowns, exact mana values, etc.).

class PlayerView:
	var player_id: String
	var team_id: int
	var class_id: String
	var roster_slot: int          # stable index for formation assignments
	var position: Vector2
	var facing: float
	var health_pct: float         # 0.0–1.0; NOT raw health
	var is_alive: bool
	var is_on_field: bool
	var is_stunned: bool
	var has_ball: bool
	var visible_buff_names: Array[String]   # names only, not durations
	## Cooldowns are NOT exposed — AI must track observed ability uses

class BallView:
	var position: Vector2
	var holder_id: String          # "" = loose or in-flight
	var possessing_team_id: int
	var charge_pct: float          # visible indicator
	var is_in_flight: bool

class CreatureView:
	var position: Vector2
	var patrol_direction: Vector2
	var speed: float

class TerrainView:
	## Coarse grid only — AI sees terrain types and pits but not fine elevation
	var surface_types: PackedByteArray   # 28×8 = 224
	var is_pit: PackedByteArray

var requesting_team_id: int = 0
var all_players: Array[PlayerView] = []
var ball: BallView = BallView.new()
var creatures: Array[CreatureView] = []
var terrain: TerrainView = TerrainView.new()

## Internal caches — updated each build/update call; never allocated mid-tick.
var _pv_cache: Dictionary = {}             # player_id → PlayerView (O(1) lookup)
var _allies_cache: Array[PlayerView] = []
var _enemies_cache: Array[PlayerView] = []

# ── Construction ──────────────────────────────────────────────────────────────

static func build(requesting_team: int) -> AiView:
	var view := AiView.new()
	view.requesting_team_id = requesting_team

	for pid in MatchState.players:
		var rec: MatchState.PlayerRecord = MatchState.players[pid]
		var node: Node = PlayerLookup.get_node(pid)
		if node == null: continue
		var pv := PlayerView.new()
		pv.player_id = pid
		_fill_player_view(pv, rec, node)
		view.all_players.append(pv)
		view._pv_cache[pid] = pv

	var b := MatchState.ball
	view.ball.position = b.position
	view.ball.holder_id = b.holder_id
	view.ball.possessing_team_id = b.possessing_team_id
	view.ball.charge_pct = b.charge_timer / b.max_charge
	view.ball.is_in_flight = b.is_in_flight

	# Terrain: live reference — AI only reads these (no duplicate needed).
	view.terrain.surface_types = MatchState.terrain.cell_surface_types
	view.terrain.is_pit = MatchState.terrain.cell_is_pit

	for creature in _find_creatures():
		var cv := CreatureView.new()
		cv.position = creature.global_position
		cv.patrol_direction = creature.patrol_direction if "patrol_direction" in creature else Vector2.RIGHT
		cv.speed = creature.speed if "speed" in creature else 8.0
		view.creatures.append(cv)

	view._rebuild_ally_enemy_caches()
	return view

## Update the view in-place for the next tick, reusing all existing objects.
## AiDirector should call build() on the first tick then update() thereafter.
func update(requesting_team: int) -> void:
	requesting_team_id = requesting_team

	var seen: Dictionary = {}
	for pid in MatchState.players:
		var rec: MatchState.PlayerRecord = MatchState.players[pid]
		var node: Node = PlayerLookup.get_node(pid)
		if node == null: continue
		seen[pid] = true
		var pv: PlayerView = _pv_cache.get(pid)
		if pv == null:
			pv = PlayerView.new()
			pv.player_id = pid
			all_players.append(pv)
			_pv_cache[pid] = pv
		_fill_player_view(pv, rec, node)

	# Remove stale player views (deaths that removed nodes, act resets, etc.).
	var stale: Array[String] = []
	for pid in _pv_cache:
		if not seen.has(pid):
			stale.append(pid)
	for pid in stale:
		all_players.erase(_pv_cache[pid])
		_pv_cache.erase(pid)

	var b := MatchState.ball
	ball.position = b.position
	ball.holder_id = b.holder_id
	ball.possessing_team_id = b.possessing_team_id
	ball.charge_pct = b.charge_timer / b.max_charge
	ball.is_in_flight = b.is_in_flight

	terrain.surface_types = MatchState.terrain.cell_surface_types
	terrain.is_pit = MatchState.terrain.cell_is_pit

	var creature_nodes := _find_creatures()
	var i := 0
	for creature in creature_nodes:
		if i >= creatures.size():
			creatures.append(CreatureView.new())
		var cv: CreatureView = creatures[i]
		cv.position = creature.global_position
		cv.patrol_direction = creature.patrol_direction if "patrol_direction" in creature else Vector2.RIGHT
		cv.speed = creature.speed if "speed" in creature else 8.0
		i += 1
	while creatures.size() > i:
		creatures.remove_at(creatures.size() - 1)

	_rebuild_ally_enemy_caches()

## Partition all_players into cached ally/enemy arrays once per tick.
func _rebuild_ally_enemy_caches() -> void:
	_allies_cache.clear()
	_enemies_cache.clear()
	for p in all_players:
		if not p.is_alive or not p.is_on_field: continue
		if p.team_id == requesting_team_id:
			_allies_cache.append(p)
		else:
			_enemies_cache.append(p)

## Populate a PlayerView from current MatchState + node data.
static func _fill_player_view(pv: PlayerView, rec: MatchState.PlayerRecord, node: Node) -> void:
	pv.team_id = rec.team_id
	pv.class_id = rec.class_id
	pv.roster_slot = rec.roster_slot
	pv.position = node.global_position
	pv.facing = node.rotation
	pv.health_pct = node.buffs.health / node.buffs.max_health
	pv.is_alive = rec.is_alive
	pv.is_on_field = rec.is_on_field
	pv.is_stunned = node.buffs.stun_timer > 0.0
	pv.has_ball = MatchState.ball.holder_id == pv.player_id
	pv.visible_buff_names.clear()
	if node.buffs.speed_mult_remaining > 0.0: pv.visible_buff_names.append("speed_boost")
	if node.buffs.damage_boost_remaining > 0.0: pv.visible_buff_names.append("damage_boost")
	if node.buffs.dodge_remaining > 0.0: pv.visible_buff_names.append("dodge")

# ── Query helpers ─────────────────────────────────────────────────────────────

## Pre-computed after each build/update — no per-call allocation.
func allies() -> Array[PlayerView]:
	return _allies_cache

func enemies() -> Array[PlayerView]:
	return _enemies_cache

func ball_carrier() -> PlayerView:
	if ball.holder_id.is_empty(): return null
	return _pv_cache.get(ball.holder_id)

func nearest_enemy(from_pos: Vector2) -> PlayerView:
	var best: PlayerView = null
	var best_d_sq := INF
	for e in _enemies_cache:
		var d_sq := from_pos.distance_squared_to(e.position)
		if d_sq < best_d_sq:
			best_d_sq = d_sq
			best = e
	return best

func player_view(player_id: String) -> PlayerView:
	return _pv_cache.get(player_id)

static func _find_creatures() -> Array:
	return Engine.get_main_loop().current_scene.get_tree().get_nodes_in_group("creatures")
