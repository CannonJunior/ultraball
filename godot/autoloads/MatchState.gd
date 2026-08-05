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

const TEAM_COLOR_PALETTE: Array[Color] = [
	Color(0.94, 0.16, 0.22),  # 0 REAPERS   — blood red
	Color(0.14, 0.88, 0.28),  # 1 VIPERS    — venom green
	Color(0.35, 0.62, 1.00),  # 2 TITANS    — steel blue
	Color(0.70, 0.75, 1.00),  # 3 GHOSTS    — pale violet
	Color(1.00, 0.50, 0.05),  # 4 INFERNO   — blaze orange
	Color(0.94, 0.90, 0.10),  # 5 STORM     — lightning yellow
	Color(0.08, 0.88, 0.84),  # 6 RAPTORS   — afterburner teal
	Color(0.55, 0.20, 1.00),  # 7 COBRAS    — royal purple
	Color(0.96, 0.18, 0.82),  # 8 WARLOCKS  — magenta
	Color(0.55, 0.76, 0.96),  # 9 PHANTOMS  — phantom silver
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
var is_paused: bool = false

# Scores
var scores: Array[int] = [0, 0, 0]     # indexed by Team enum
var kills: Array[int] = [0, 0, 0]
## Unique player_ids eliminated by each team (each roster member counted once regardless of re-kills).
var kills_unique: Array = [[], [], []]

# Player roster data (populated by NetworkManager / GameScene on match start)
# key: player_id (String), value: PlayerRecord
var players: Dictionary = {}

# Ball state (authoritative copy; Player nodes replicate their own position)
var ball: BallStateRecord = BallStateRecord.new()

# Terrain state
var terrain: TerrainStateRecord = TerrainStateRecord.new()

# Per-player cumulative match stats
var player_stats: Dictionary = {}

# Creature positions (set by CreatureSystem each tick)
var creature_positions: Array[Vector2] = []

# ── Helpers ────────────────────────────────────────────────────────────────────

func team_color(team_id: int) -> Color:
	var idx: int
	if config != null:
		match team_id:
			0: idx = config.home_team_idx
			1: idx = config.away_team_idx
			2: idx = config.third_team_idx
			_: idx = team_id
	else:
		idx = clampi(team_id, 0, TEAM_COLOR_PALETTE.size() - 1)
	return TEAM_COLOR_PALETTE[clampi(idx, 0, TEAM_COLOR_PALETTE.size() - 1)]

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

func reset_for_new_match() -> void:
	current_act = 1
	act_timer = 180.0
	match_active = false
	act_ended = false
	game_over = false
	is_paused = false
	scores = [0, 0, 0]
	kills = [0, 0, 0]
	kills_unique = [[], [], []]
	players = {}
	ball = BallStateRecord.new()
	terrain = TerrainStateRecord.new()
	player_stats = {}
	creature_positions = []

func reset_for_new_act() -> void:
	act_ended = false
	act_timer = act_duration()

func stat(player_id: String) -> PlayerStatRecord:
	if not player_stats.has(player_id):
		player_stats[player_id] = PlayerStatRecord.new()
	return player_stats[player_id]


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

class PlayerStatRecord:
	var dmg: float = 0.0
	var heal: float = 0.0
	var kills: int = 0
	var deaths: int = 0
	var taken: float = 0.0
	var ub: int = 0
	var ca: int = 0
	var ff: int = 0

	# Ball-handling
	var ball_carries: int = 0
	var ball_time: float = 0.0
	var passes_thrown: int = 0
	var charged_throws: int = 0
	var max_charge_reached: float = 0.0

	# Per-category breakdowns (slot/cause/act → count)
	var ability_uses: Dictionary = {}   # slot (int) → count
	var death_causes: Dictionary = {}   # "combat"|"creature"|"explosion"|"pit" → count
	var kills_per_act: Dictionary = {}  # act (int) → count

	var points: int:
		get: return kills * 3 + ub * 5 + ca * 2

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
