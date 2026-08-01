class_name Ball
extends Node2D

## Visual ball node. BallSystem owns state in MatchState.ball; this node renders it.

const BALL_RADIUS  := 0.25
const CHARGE_MAX   := 7.0   # mirrors BallSystem.MAX_CHARGE

var _prev_pos: Vector2      = Vector2.INF
var _prev_flight: bool      = false
var _prev_holder: String    = ""
var _prev_charge: float     = -1.0

func _ready() -> void:
	add_to_group("ball")

func _process(_delta: float) -> void:
	var ball := MatchState.ball
	global_position = ball.position
	if ball.position     != _prev_pos    or \
	   ball.is_in_flight != _prev_flight or \
	   ball.holder_id    != _prev_holder or \
	   ball.charge_timer != _prev_charge:
		_prev_pos    = ball.position
		_prev_flight = ball.is_in_flight
		_prev_holder = ball.holder_id
		_prev_charge = ball.charge_timer
		queue_redraw()

func _draw() -> void:
	var ball := MatchState.ball
	var col: Color
	if ball.is_in_flight:
		col = Color(1.0, 1.0, 0.55)
	elif not ball.holder_id.is_empty():
		col = Color(1.0, 0.5, 0.0)
	else:
		col = Color(1.0, 0.82, 0.25)
	draw_circle(Vector2.ZERO, BALL_RADIUS, col)

	# Charge arc ring
	if not ball.holder_id.is_empty() and ball.charge_timer > 0.0:
		var t := minf(ball.charge_timer / CHARGE_MAX, 1.0)
		draw_arc(Vector2.ZERO, BALL_RADIUS + 0.18, -PI * 0.5, -PI * 0.5 + TAU * t,
				24, Color(1.0, 0.25, 0.0, 0.85), 0.08)
