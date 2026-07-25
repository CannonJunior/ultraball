class_name Creature
extends CharacterBody2D

## Creature patrol entity. Movement lives here; kill detection is in CreatureSystem.

const PATROL_SPEED    := 6.0   # m/s
const WAYPOINT_REACH  := 2.0   # metres — snap to next waypoint
const BODY_RADIUS     := 4.0   # metres — visual + collision

## Rectangular patrol path along the centre of the 10m-wide creature channel.
## End sections: x∈[20,30] and x∈[110,120], y∈[0,40] (inside field).
## Side sections: y∈[−10,0] and y∈[40,50] (outside field).
## Waypoints sit at channel midpoints: x=25/115 (end), y=−5/45 (side).
const WAYPOINTS_2T: Array = [
	Vector2( 25.0, -5.0),   # top-left
	Vector2(115.0, -5.0),   # top-right
	Vector2(115.0, 45.0),   # bottom-right
	Vector2( 25.0, 45.0),   # bottom-left
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
