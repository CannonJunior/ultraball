class_name TricksterTrap
extends Area2D

## Persistent trap spawned by Trickster's Phantom Step.
## Set properties before add_child — _ready() reads them to build the node.

var owner_team_id: int = -1
var trap_radius: float = 2.5
var snare_duration: float = 2.0
var slow_factor: float = 0.5
var trap_timer: float = 8.0

var _triggered: bool = false

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = trap_radius
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)
	var t := Timer.new()
	t.wait_time = trap_timer
	t.one_shot = true
	t.autostart = true
	t.timeout.connect(queue_free)
	add_child(t)

func _on_body_entered(body: Node) -> void:
	if _triggered: return
	if not body.is_in_group("players"): return
	if body.get("team_id") == owner_team_id: return
	_triggered = true
	EventBus.debuff_applied.emit(
		body.get("player_id"), "snare", snare_duration,
		{"slow_factor": slow_factor}
	)
	queue_free()
