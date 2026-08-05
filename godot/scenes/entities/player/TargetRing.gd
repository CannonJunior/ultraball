class_name TargetRing
extends Node2D

## World-space targeting reticle drawn around a player when they are the local
## player's explicit target. Visual mirrors the Flutter field_painter design:
## soft glow aura → crisp main ring → thin outer ring → four NESW triangles.
## Also shown in yellow when this unit possesses the ultraball.

const PlayerLookup = preload("res://systems/PlayerLookup.gd")

const BODY_R  := 0.40  # matches PlayerVisual.BODY_RADIUS
const RING1_R := 0.57  # main crisp ring
const RING2_R := 0.67  # outer thin ring
const TRI_R   := 0.74  # triangle tip radius
const TRI_SZ  := 0.085 # triangle arm length

const C_POSSESSION := Color(1.000, 0.800, 0.000)  # #FFCC00 — ball holder yellow
const C_TARGET_GLOW := Color(1.000, 0.000, 0.267) # #FF0044 — target ring deep red glow

func _process(_delta: float) -> void:
	var active := _is_targeted() or _is_ball_holder()
	if active != visible:
		visible = active
	if active:
		queue_redraw()

func _draw() -> void:
	var is_holder := _is_ball_holder()
	var tc := C_POSSESSION if is_holder else _ring_color()
	var gc := tc if is_holder else C_TARGET_GLOW

	# Simulated glow: concentric semi-transparent thick arcs
	draw_arc(Vector2.ZERO, RING1_R + 0.12, 0.0, TAU, 48, Color(gc.r, gc.g, gc.b, 0.07), 0.16)
	draw_arc(Vector2.ZERO, RING1_R + 0.07, 0.0, TAU, 48, Color(gc.r, gc.g, gc.b, 0.12), 0.10)
	draw_arc(Vector2.ZERO, RING1_R + 0.03, 0.0, TAU, 48, Color(gc.r, gc.g, gc.b, 0.18), 0.06)

	# Crisp main ring
	draw_arc(Vector2.ZERO, RING1_R, 0.0, TAU, 64, Color(tc.r, tc.g, tc.b, 0.92), 0.035)
	# Outer thin ring
	draw_arc(Vector2.ZERO, RING2_R, 0.0, TAU, 64, Color(tc.r, tc.g, tc.b, 0.50), 0.018)

	# Four inward-pointing triangles at N / E / S / W
	for i in 4:
		var angle := i * PI * 0.5
		var tip := Vector2(cos(angle) * TRI_R, sin(angle) * TRI_R)
		var pts := PackedVector2Array([
			tip + Vector2(cos(angle + PI),         sin(angle + PI))         * TRI_SZ,
			tip + Vector2(cos(angle + PI * 0.5),   sin(angle + PI * 0.5))   * TRI_SZ * 0.5,
			tip + Vector2(cos(angle - PI * 0.5),   sin(angle - PI * 0.5))   * TRI_SZ * 0.5,
		])
		draw_colored_polygon(pts, Color(tc.r, tc.g, tc.b, 0.88))

func _is_ball_holder() -> bool:
	var parent := get_parent()
	if parent == null: return false
	var pid: String = parent.get("player_id")
	if pid == null or pid.is_empty(): return false
	var ball := MatchState.ball
	return ball != null and ball.holder_id == pid

func _is_targeted() -> bool:
	var pid := NetworkManager.local_player_id
	if pid.is_empty():
		return false
	var node := PlayerLookup.get_node(pid)
	return node != null and node.get("_explicit_target_id") == get_parent().get("player_id")

func _ring_color() -> Color:
	var parent := get_parent()
	var pid := NetworkManager.local_player_id
	var node := PlayerLookup.get_node(pid)
	if node != null:
		if parent.get("team_id") == node.get("team_id"):
			return Color(0.20, 0.93, 0.40)  # ally green (shouldn't normally target allies)
		return Color(1.00, 0.42, 0.42)      # enemy coral red
	return Color(1.00, 0.42, 0.42)
