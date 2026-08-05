class_name Creature
extends CharacterBody2D

## Creature patrol entity. Movement lives here; kill detection is in CreatureSystem.

const PlayerLookup = preload("res://systems/PlayerLookup.gd")


# Per-type stats applied in _ready()
var patrol_speed: float = 6.0
var body_radius:  float = 4.0   # read by CreatureSystem for kill detection

# Shared timed-behaviour state (used by chaos/thunderbird/demon/hellhound)
var _behaviour_timer: float = 0.0
var _speed_mult:      float = 1.0
var _hunt_pos:        Vector2 = Vector2.ZERO
var _hunting:         bool = false
var _creature_type:   int = 0

const CREATURE_ID  := "creature"
const MAX_HP       := 1000.0
const REGEN_RATE   := 50.0   # HP/s
const SLAM_DAMAGE     := 100.0
const SLAM_CD         := 1.5
const SLAM_RADIUS     := 5.0   # must exceed physics contact distance (~4.35 m)
const _SLAM_RADIUS_SQ := SLAM_RADIUS * SLAM_RADIUS

var hp:              float = MAX_HP
var is_alive:        bool  = true
var _slam_cd:        float = 0.0
var _respawn_timer:  float = 0.0

## Which team owns this creature (set by GameScene at spawn time).
var team_id: int = 0

## Outer-perimeter patrol path (2-team).
## y=−15/55 clears the endzones (field_min.y=−10, field_max.y=50).
## x=−15/155 puts vertical transitions off-screen (viewport ≈ x=−1..141 at 1280 px).
const WAYPOINTS_2T: Array = [
	Vector2(25.0, -5.0),
	Vector2(105.0, -5.0),
	Vector2(105.0,  45.0),
	Vector2(25.0,  45.0),
]


var _waypoints: Array = WAYPOINTS_2T
var _wp_index:  int   = 0
var _dir:       int   = 1   # 1=forward  −1=reverse

var _goaded:   bool    = false
var _goad_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("creatures")
	if MatchState.is_three_team:
		_waypoints = _build_waypoints_3t(team_id)
	else:
		_waypoints = WAYPOINTS_2T
	global_position = _waypoints[0]
	EventBus.damage_requested.connect(_on_damage_requested)
	_apply_creature_type()
	var visual := get_node_or_null("Visual")
	if visual and visual.has_method("setup"):
		visual.setup(body_radius, _creature_type)

func _physics_process(delta: float) -> void:
	if not is_alive:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			hp       = MAX_HP
			is_alive = true
			_speed_mult = 1.0
			_hunting    = false
			_wp_index = 0
			global_position = _waypoints[0]
		return

	hp = minf(MAX_HP, hp + REGEN_RATE * delta)

	_slam_cd = maxf(0.0, _slam_cd - delta)
	if _slam_cd <= 0.0:
		_try_slam()

	# Per-type special behaviour
	match _creature_type:
		4:  _tick_hellhound(delta)
		5:  _tick_thunderbird(delta)
		8:  _tick_demon(delta)
		10: _tick_chaos(delta)

	if _goaded:
		_steer_toward(_goad_pos)
	elif _hunting:
		_steer_toward(_hunt_pos)
	_advance_along_path(patrol_speed * _speed_mult * delta)

# ── Per-type behaviour ticks ──────────────────────────────────────────────────

func _tick_hellhound(delta: float) -> void:
	_behaviour_timer -= delta
	if _hunting:
		# Check if we've reached the hunt target or timed out
		if global_position.distance_squared_to(_hunt_pos) < 9.0 or _behaviour_timer <= 0.0:
			_hunting = false
			_behaviour_timer = randf_range(3.0, 7.0)
	elif _behaviour_timer <= 0.0:
		# Look for the nearest player to chase
		var nearest: Node = null
		var best_d_sq := 400.0   # 20^2
		for p in PlayerLookup.get_all_nodes():
			if not p.is_alive or not p.is_on_field: continue
			var d_sq := global_position.distance_squared_to(p.global_position)
			if d_sq < best_d_sq:
				best_d_sq = d_sq
				nearest = p
		if nearest != null:
			_hunt_pos = nearest.global_position
			_hunting = true
			_behaviour_timer = randf_range(2.5, 4.5)
		else:
			_behaviour_timer = randf_range(1.0, 3.0)

func _tick_thunderbird(delta: float) -> void:
	_behaviour_timer -= delta
	if _behaviour_timer <= 0.0:
		_behaviour_timer = randf_range(3.0, 8.0)
		_speed_mult = randf_range(0.4, 2.8)

func _tick_demon(delta: float) -> void:
	_behaviour_timer -= delta
	if _behaviour_timer <= 0.0:
		_behaviour_timer = randf_range(8.0, 15.0)
		_dir *= -1

func _tick_chaos(delta: float) -> void:
	_behaviour_timer -= delta
	if _behaviour_timer <= 0.0:
		_behaviour_timer = randf_range(2.0, 6.0)
		var roll := randf()
		if roll < 0.15:
			_dir *= -1
		elif roll < 0.40:
			_speed_mult = randf_range(2.2, 3.5)
		elif roll < 0.55:
			_speed_mult = randf_range(0.2, 0.5)
		elif roll < 0.65:
			_dir *= -1
		else:
			_speed_mult = 1.0

# ── Slam ──────────────────────────────────────────────────────────────────────

func _try_slam() -> void:
	for player in PlayerLookup.get_all_nodes():
		if not player.is_alive or not player.is_on_field: continue
		if global_position.distance_squared_to(player.global_position) <= _SLAM_RADIUS_SQ:
			_do_slam()
			return

func _do_slam() -> void:
	_slam_cd = SLAM_CD
	for player in PlayerLookup.get_all_nodes():
		if not player.is_alive or not player.is_on_field: continue
		if global_position.distance_squared_to(player.global_position) <= _SLAM_RADIUS_SQ:
			EventBus.damage_requested.emit({
				"attacker_id": CREATURE_ID,
				"target_id":   player.player_id,
				"amount":      SLAM_DAMAGE,
				"knockback_distance": 0.0,
				"facing":      0.0,
			})

# ── Path following ────────────────────────────────────────────────────────────

func _advance_along_path(distance: float) -> void:
	var remaining := distance
	while remaining > 0.0:
		var target: Vector2 = _waypoints[_wp_index]
		var to_target: Vector2 = target - global_position
		var dist := to_target.length()
		if dist <= remaining:
			global_position = target
			remaining -= dist
			_wp_index = (_wp_index + _dir + _waypoints.size()) % _waypoints.size()
		else:
			global_position += to_target.normalized() * remaining
			remaining = 0.0

## Point the patrol direction toward whichever waypoint is nearest to world-space target.
## The creature never leaves the waypoint loop — it just rushes toward the closest corner.
func _steer_toward(target: Vector2) -> void:
	var n := _waypoints.size()
	var best_idx := _wp_index
	var best_d_sq := INF
	for i in n:
		var d_sq: float = target.distance_squared_to(_waypoints[i])
		if d_sq < best_d_sq:
			best_d_sq = d_sq
			best_idx = i
	var dist_fwd := (best_idx - _wp_index + n) % n
	var dist_rev := (_wp_index - best_idx + n) % n
	_dir = 1 if dist_fwd <= dist_rev else -1

# ── Waypoint builders ────────────────────────────────────────────────────────

## Single 9-point loop shared by all three creatures. Each arm contributes:
##   • one junction point  (where this arm's perp+ midline meets the previous arm's perp- midline)
##   • two outer points    (at the crossbar-depth midpoint, on each side of the arm)
##
## Reference points (hand-picked approximation, all arms):
##   (85,126.5) (85,166.5) (135,166.5) (135,126.5)
##   (171.5,103.5) (145.5,62.5) (110,80) (70,62.5) (43.5,100)
##
## Geometry (exact, derived from MatchState constants):
##   dp   = (hw + hwc) / 2       — side-strip midpoint (25.0)
##   dn_o = (ci + co) / 2        — crossbar-depth midpoint (56.547)
##   dn_i = dp / sqrt(3)         — depth where adjacent dp=±25 midlines coincide (~14.434)
##
## Each creature is staggered by tid*3 waypoints so it starts near its own arm.
func _build_waypoints_3t(tid: int) -> Array:
	var center := Vector2(MatchState.FIELD3_CX, MatchState.FIELD3_CY)
	var ci  := MatchState.FIELD3_CHAN_INNER
	var co  := MatchState.FIELD3_CHAN_OUTER
	var hw  := MatchState.FIELD3_ARM_HALF_W
	var hwc := hw + 10.0
	var dp  := (hw + hwc) * 0.5
	var dn_o := (ci + co) * 0.5
	var dn_i := dp / sqrt(3.0)
	var all: Array = []
	for t in 3:
		var norm: Vector2 = MatchState.TEAM3_NORMALS[t]
		var perp := Vector2(-norm.y, norm.x)
		all.append(center + norm * dn_i + perp * dp)   # junction: prev-arm perp- meets this arm perp+
		all.append(center + norm * dn_o + perp * dp)   # outer, perp+ side
		all.append(center + norm * dn_o - perp * dp)   # outer, perp- side
	var offset := tid * 3
	return all.slice(offset) + all.slice(0, offset)

# ── Type init ────────────────────────────────────────────────────────────────

func _apply_creature_type() -> void:
	if MatchState.config == null: return
	_creature_type = MatchState.config.creature_type
	match _creature_type:
		0:  # Wraith    — REAPERS
			patrol_speed = 16.0; body_radius = 2.0
		1:  # Serpent   — VIPERS
			patrol_speed = 11.0; body_radius = 4.0
		2:  # Golem     — TITANS
			patrol_speed =  5.0; body_radius = 6.0
		3:  # Specter   — GHOSTS
			patrol_speed = 22.0; body_radius = 1.8
		4:  # Hellhound — INFERNO
			patrol_speed = 15.0; body_radius = 3.0
			_behaviour_timer = randf_range(1.0, 3.0)
		5:  # Thunderbird — STORM
			patrol_speed = 12.0; body_radius = 3.0
			_behaviour_timer = randf_range(1.0, 4.0)
		6:  # Wyvern    — RAPTORS
			patrol_speed = 14.0; body_radius = 3.5
		7:  # Basilisk  — COBRAS
			patrol_speed =  7.0; body_radius = 5.5
		8:  # Demon     — WARLOCKS
			patrol_speed = 12.0; body_radius = 3.5
			_behaviour_timer = randf_range(5.0, 10.0)
		9:  # Banshee   — PHANTOMS
			patrol_speed = 20.0; body_radius = 2.2
		10: # Chaos     — Neutral
			patrol_speed =  9.0; body_radius = 3.5
			_behaviour_timer = randf_range(1.0, 3.0)

# ── Damage reception ──────────────────────────────────────────────────────────

func _on_damage_requested(payload: Dictionary) -> void:
	if payload.get("target_id", "") != CREATURE_ID: return
	if not is_alive: return
	var amount: float = payload.get("amount", 0.0)
	hp = maxf(0.0, hp - amount)
	var attacker_id: String = payload.get("attacker_id", "")
	print("[CREATURE] hit by %s for %.1f | hp=%.1f/%.1f" % [attacker_id, amount, hp, MAX_HP])
	EventBus.damage_applied.emit(attacker_id, CREATURE_ID, amount, hp <= 0.0)
	EventBus.damage_indicator_spawned.emit(global_position, str(int(round(amount))), "damage")
	if hp <= 0.0:
		is_alive = false
		_respawn_timer = 10.0

# ── Called by CreatureSystem ───────────────────────────────────────────────────

func set_goad_target(pos: Vector2) -> void:
	_goad_pos = pos
	_goaded   = true

func clear_goad_target() -> void:
	_goaded = false

func reverse_patrol() -> void:
	_dir *= -1
