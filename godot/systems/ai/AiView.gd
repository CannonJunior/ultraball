class_name AiView

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

static func build(requesting_team: int) -> AiView:
	var view := AiView.new()
	view.requesting_team_id = requesting_team

	# Populate player views
	for pid in MatchState.players:
		var rec: MatchState.PlayerRecord = MatchState.players[pid]
		var node := _find_player(pid)
		if node == null: continue

		var pv := PlayerView.new()
		pv.player_id = pid
		pv.team_id = rec.team_id
		pv.class_id = rec.class_id
		pv.roster_slot = rec.roster_slot
		pv.position = node.global_position
		pv.facing = node.rotation
		pv.health_pct = node.buffs.health / node.buffs.max_health
		pv.is_alive = rec.is_alive
		pv.is_on_field = rec.is_on_field
		pv.is_stunned = node.buffs.stun_timer > 0.0
		pv.has_ball = MatchState.ball.holder_id == pid
		## Visible buffs: only report names so AI can't infer exact durations
		if node.buffs.speed_mult_remaining > 0.0: pv.visible_buff_names.append("speed_boost")
		if node.buffs.damage_boost_remaining > 0.0: pv.visible_buff_names.append("damage_boost")
		if node.buffs.dodge_remaining > 0.0: pv.visible_buff_names.append("dodge")
		view.all_players.append(pv)

	# Ball view
	var ball := MatchState.ball
	view.ball.position = ball.position
	view.ball.holder_id = ball.holder_id
	view.ball.possessing_team_id = ball.possessing_team_id
	view.ball.charge_pct = ball.charge_timer / ball.max_charge
	view.ball.is_in_flight = ball.is_in_flight

	# Terrain view (coarse only)
	view.terrain.surface_types = MatchState.terrain.cell_surface_types.duplicate()
	view.terrain.is_pit = MatchState.terrain.cell_is_pit.duplicate()

	# Creature views
	for creature in _find_creatures():
		var cv := CreatureView.new()
		cv.position = creature.global_position
		cv.patrol_direction = creature.patrol_direction if "patrol_direction" in creature else Vector2.RIGHT
		cv.speed = creature.speed if "speed" in creature else 8.0
		view.creatures.append(cv)

	return view

# ── Query helpers ─────────────────────────────────────────────────────────────

func allies() -> Array[PlayerView]:
	var result: Array[PlayerView] = []
	for p in all_players:
		if p.team_id == requesting_team_id and p.is_alive and p.is_on_field:
			result.append(p)
	return result

func enemies() -> Array[PlayerView]:
	var result: Array[PlayerView] = []
	for p in all_players:
		if p.team_id != requesting_team_id and p.is_alive and p.is_on_field:
			result.append(p)
	return result

func ball_carrier() -> PlayerView:
	if ball.holder_id.is_empty(): return null
	for p in all_players:
		if p.player_id == ball.holder_id: return p
	return null

func nearest_enemy(from_pos: Vector2) -> PlayerView:
	var best: PlayerView = null
	var best_d := INF
	for e in enemies():
		var d := from_pos.distance_to(e.position)
		if d < best_d:
			best_d = d
			best = e
	return best

func player_view(player_id: String) -> PlayerView:
	for p in all_players:
		if p.player_id == player_id: return p
	return null

static func _find_player(pid: String) -> Node:
	for n in Engine.get_main_loop().current_scene.get_tree().get_nodes_in_group("players"):
		if n.player_id == pid: return n
	return null

static func _find_creatures() -> Array:
	return Engine.get_main_loop().current_scene.get_tree().get_nodes_in_group("creatures")
