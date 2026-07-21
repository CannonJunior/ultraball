class_name Creature
extends CharacterBody2D

## Creature patrol entity. Movement lives here; kill detection is in CreatureSystem.

const PATROL_SPEED    := 6.0   # m/s
const WAYPOINT_REACH  := 1.0   # metres — snap to next waypoint
const BODY_RADIUS     := 0.55  # metres — visual + collision

## Oval patrol path around the 2-team field interior.
const WAYPOINTS_2T: Array = [
	Vector2( 70.0,  4.0),
	Vector2(110.0,  8.0),
	Vector2(132.0, 20.0),
	Vector2(110.0, 32.0),
	Vector2( 70.0, 36.0),
	Vector2( 30.0, 32.0),
	Vector2(  8.0, 20.0),
	Vector2( 30.0,  8.0),
]

## 9-waypoint star-perimeter patrol for 3-team mode (CW: arm0, arm2, arm1).
## Computed from field geometry: centre(110,110), inradius≈11.5, chanPathMid≈56.5, halfW=25.
const WAYPOINTS_3T: Array = [
	Vector2(135.0, 121.5),   # arm0 inner-left
	Vector2(135.0, 166.5),   # arm0 outer-left
	Vector2( 85.0, 166.5),   # arm0 outer-right
	Vector2( 87.5, 125.9),   # arm2 inner-left
	Vector2( 48.5, 103.4),   # arm2 outer-left
	Vector2( 73.5,  60.1),   # arm2 outer-right
	Vector2(107.5,  82.6),   # arm1 inner-left
	Vector2(146.5,  60.1),   # arm1 outer-left
	Vector2(171.5, 103.4),   # arm1 outer-right
]

var _waypoints: Array = WAYPOINTS_2T
var _wp_index: int = 0
var _dir: int = 1          # 1=forward  −1=reverse

var _goaded: bool = false
var _goad_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("creatures")
	if MatchState.is_three_team:
		_waypoints = WAYPOINTS_3T
	global_position = _waypoints[0]

func _physics_process(_delta: float) -> void:
	var target: Vector2 = _goad_pos if _goaded else _waypoints[_wp_index]
	var to_target: Vector2 = target - global_position
	velocity = to_target.normalized() * PATROL_SPEED
	move_and_slide()

	if not _goaded and to_target.length() < WAYPOINT_REACH:
		_wp_index = (_wp_index + _dir + _waypoints.size()) % _waypoints.size()

# ── Called by CreatureSystem ───────────────────────────────────────────────────

func set_goad_target(pos: Vector2) -> void:
	_goad_pos = pos
	_goaded = true

func clear_goad_target() -> void:
	_goaded = false

func reverse_patrol() -> void:
	_dir *= -1
