## Server-authoritative match state. On clients, this is populated from GameSnapshot.
extends Node

enum Team { HOME = 0, AWAY = 1, THIRD = 2 }

# 3-team field geometry (equilateral-triangle star, centre at 110,110, world-size 220)
const FIELD3_SIZE       := 220.0
const FIELD3_CX         := 110.0
const FIELD3_CY         := 110.0
const FIELD3_INRADIUS   := 11.547005383792515
const FIELD3_ARM_HALF_W := 20.0
const FIELD3_CHAN_INNER  := 51.547005383792515   # inradius + 40
const FIELD3_CHAN_OUTER  := 61.547005383792515   # inradius + 50 — scoring threshold
const FIELD3_ARM_END    := 81.547005383792515    # inradius + 70 — far wall
const FIELD3_PHASE_DISTS := [21.547005383792515, 31.547005383792515, 41.547005383792515]
# Outward normals: HOME=south (0,1), AWAY=upper-right, THIRD=upper-left
const TEAM3_NORMALS := [
	Vector2(0.0,                   1.0),
	Vector2(0.8660254037844387,  -0.5),
	Vector2(-0.8660254037844387, -0.5),
]

# Match configuration (set before match starts)
var config: MatchConfig = null
var is_three_team: bool = false

# Act state
var current_act: int = 1
var act_timer: float = 180.0
var match_active: bool = false
var act_ended: bool = false
var game_over: bool = false

# Scores
var scores: Array[int] = [0, 0, 0]     # indexed by Team enum
var kills: Array[int] = [0, 0, 0]

# Act 5 overtime
var act5_leading_team: int = -1
var act5_ultra_target: int = 3

# Player roster data (populated by NetworkManager / GameScene on match start)
# key: player_id (String), value: PlayerRecord
var players: Dictionary = {}

# Ball state (authoritative copy; Player nodes replicate their own position)
var ball: BallStateRecord = BallStateRecord.new()

# Terrain state
var terrain: TerrainStateRecord = TerrainStateRecord.new()

# Creature positions (set by CreatureSystem each tick)
var creature_positions: Array[Vector2] = []

# ── Helpers ────────────────────────────────────────────────────────────────────

func score(team: int) -> int:
	return scores[team]

func add_score(team: int, points: int) -> void:
	scores[team] += points
	EventBus.score_display_updated.emit(scores[0], scores[1], scores[2])

func team_for_player(player_id: String) -> int:
	if players.has(player_id):
		return players[player_id].team_id
	return -1

func living_on_field(team: int) -> Array:
	var result: Array = []
	for pid in players:
		var p: PlayerRecord = players[pid]
		if p.team_id == team and p.is_alive and p.is_on_field:
			result.append(p)
	return result

func all_players_for_team(team: int) -> Array:
	var result: Array = []
	for pid in players:
		var p: PlayerRecord = players[pid]
		if p.team_id == team:
			result.append(p)
	return result

func is_fast_mode() -> bool:
	return config != null and config.fast_mode

func act_duration() -> float:
	return 60.0 if is_fast_mode() else 180.0

func reset_for_new_act() -> void:
	act_ended = false
	act_timer = act_duration()


# ── Inner data records (lightweight, not Resources) ───────────────────────────

class PlayerRecord:
	var player_id: String
	var team_id: int
	var class_id: String
	var roster_slot: int
	var deploy_slot: int
	var is_alive: bool = true
	var is_on_field: bool = false
	var display_name: String

class BallStateRecord:
	var position: Vector2 = Vector2(70.0, 20.0)
	var velocity: Vector2 = Vector2.ZERO
	var holder_id: String = ""
	var possessing_team_id: int = -1
	var is_in_flight: bool = false
	var is_charged_throw: bool = false
	var flight_age: float = 0.0       # seconds since throw (for self-catch block)
	var charge_timer: float = 0.0
	var charge_at_throw: float = 0.0  # charge_timer value captured when ball was thrown
	var max_charge: float = 7.0
	var z_height: float = 0.0
	var z_velocity: float = 0.0

class TerrainStateRecord:
	# 28×8 coarse grid (224 cells)
	var cell_surface_types: PackedByteArray
	var cell_heights: PackedFloat32Array
	var cell_target_heights: PackedFloat32Array
	var cell_speed_mults: PackedFloat32Array
	var cell_hazard_timers: PackedFloat32Array
	var cell_is_pit: PackedByteArray

	# 168×48 fine elevation grid (8064 values)
	var elevation_heights: PackedFloat32Array

	func _init() -> void:
		cell_surface_types = PackedByteArray()
		cell_surface_types.resize(224)
		cell_heights = PackedFloat32Array()
		cell_heights.resize(224)
		cell_target_heights = PackedFloat32Array()
		cell_target_heights.resize(224)
		cell_speed_mults = PackedFloat32Array()
		cell_speed_mults.resize(224)
		cell_speed_mults.fill(1.0)
		cell_hazard_timers = PackedFloat32Array()
		cell_hazard_timers.resize(224)
		cell_is_pit = PackedByteArray()
		cell_is_pit.resize(224)
		elevation_heights = PackedFloat32Array()
		elevation_heights.resize(8064)
