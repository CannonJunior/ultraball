class_name LightningBoltVfx
extends Node2D

## Procedural lightning bolt rendered as a variable-width ribbon mesh.
## Widens at displacement kink points to produce angular faceted look.
## Three render layers:
##   GlowMesh  — wide TRIANGLE_STRIP ribbon, additive lightning shader
##   CoreMesh  — narrow TRIANGLE_STRIP ribbon, additive white
##   _draw()   — perpendicular discharge streaks at sharp kinks (additive)

const _SHADER := preload("res://assets/shaders/lightning_bolt.gdshader")

var from:      Vector2 = Vector2.ZERO
var to:        Vector2 = Vector2.ZERO
var delay:     float   = 0.0
var duration:  float   = 0.22
var color:     Color   = Color(0.55, 0.85, 1.0)
var is_3d_mode: bool   = false

var _elapsed: float = 0.0
var _rng := RandomNumberGenerator.new()
var _pts: PackedVector2Array

var _glow_mesh:  MeshInstance2D
var _core_mesh:  MeshInstance2D
var _glow_imesh: ImmediateMesh
var _core_imesh: ImmediateMesh

const _GLOW_HALF_W := 0.80  # world units — glow halo half-width at base
const _CORE_HALF_W := 0.10  # world units — bright center half-width at base
const _KINK_SCALE  := 2.2   # width multiplier added per unit of bend angle
const _TIP_FACTOR  := 0.20  # ribbon width at tip relative to base
const _STREAK_HALF := 0.55  # perpendicular streak half-length at each kink

func _ready() -> void:
	if is_3d_mode:
		visible = false
		return

	# ── Glow ribbon ── wide, additive lightning shader ────────────────────────
	_glow_imesh = ImmediateMesh.new()
	_glow_mesh  = MeshInstance2D.new()
	_glow_mesh.mesh = _glow_imesh
	var mat := ShaderMaterial.new()
	mat.shader = _SHADER
	mat.set_shader_parameter("glow_color",  color)
	mat.set_shader_parameter("core_color",  Color(1.0, 1.0, 1.0))
	mat.set_shader_parameter("flicker_amp", 0.22)
	_glow_mesh.material = mat
	add_child(_glow_mesh)

	# ── Core ribbon ── narrow, plain additive white ────────────────────────────
	_core_imesh = ImmediateMesh.new()
	_core_mesh  = MeshInstance2D.new()
	_core_mesh.mesh = _core_imesh
	var ci_mat := CanvasItemMaterial.new()
	ci_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_core_mesh.material = ci_mat
	add_child(_core_mesh)

	# Streaks use _draw() on this node — additive so they bloom into the glow.
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

func _process(delta: float) -> void:
	if is_3d_mode:
		return

	_elapsed += delta

	if _elapsed < delay:
		return

	var t := _elapsed - delay

	if t >= duration:
		queue_free()
		return

	var progress := clampf(t / duration, 0.0, 1.0)
	var tip      := from.lerp(to, progress)

	_rng.seed = Time.get_ticks_msec()
	_pts = _displace(from, tip, 3)

	var alpha := lerpf(1.0, 0.65, progress)
	_glow_mesh.modulate.a = alpha
	_core_mesh.modulate.a = alpha

	_rebuild_ribbon(_glow_imesh, _pts, _GLOW_HALF_W, _TIP_FACTOR)
	_rebuild_ribbon(_core_imesh, _pts, _CORE_HALF_W, _TIP_FACTOR * 0.6)
	queue_redraw()

func _draw() -> void:
	if _pts.size() < 3:
		return
	var n := _pts.size()
	for i in range(1, n - 1):
		var v_in  := (_pts[i]     - _pts[i - 1]).normalized()
		var v_out := (_pts[i + 1] - _pts[i]).normalized()
		var kink  := maxf(0.0, 1.0 - v_in.dot(v_out))
		if kink < 0.25:
			continue
		# Bisector perpendicular — stable direction at the kink apex
		var avg_dir := (v_in + v_out).normalized()
		var perp    := Vector2(-avg_dir.y, avg_dir.x)
		var half    := _STREAK_HALF * kink
		draw_line(_pts[i] - perp * half, _pts[i] + perp * half,
				Color(color.r, color.g, color.b, kink * 0.75), 0.09)

## Build a triangle-strip ribbon from displacement points.
## UV.x = bolt progress (0→1), UV.y = cross-section (0 = left, 1 = right).
## Width peaks at sharp kink points and tapers toward the tip.
func _rebuild_ribbon(mesh: ImmediateMesh, pts: PackedVector2Array,
		base_hw: float, tip_factor: float) -> void:
	mesh.clear_surfaces()
	var n := pts.size()
	if n < 2:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n:
		var t := float(i) / float(n - 1)
		var w := base_hw * lerpf(1.0, tip_factor, t)
		if i > 0 and i < n - 1:
			var v_in  := (pts[i]     - pts[i - 1]).normalized()
			var v_out := (pts[i + 1] - pts[i]).normalized()
			var kink  := maxf(0.0, 1.0 - v_in.dot(v_out))
			w *= (1.0 + kink * _KINK_SCALE)
		var perp := _perp_at(pts, i)
		mesh.surface_set_uv(Vector2(t, 0.0))
		mesh.surface_add_vertex_2d(pts[i] + perp * w)
		mesh.surface_set_uv(Vector2(t, 1.0))
		mesh.surface_add_vertex_2d(pts[i] - perp * w)
	mesh.surface_end()

## Perpendicular to the bolt's local direction at point i.
func _perp_at(pts: PackedVector2Array, i: int) -> Vector2:
	var n := pts.size()
	var dir: Vector2
	if i == 0:
		dir = pts[1] - pts[0]
	elif i == n - 1:
		dir = pts[n - 1] - pts[n - 2]
	else:
		dir = pts[i + 1] - pts[i - 1]
	return Vector2(-dir.y, dir.x).normalized()

## Recursive midpoint displacement — 3 levels → 8 segments, natural flicker.
func _displace(a: Vector2, b: Vector2, levels: int) -> PackedVector2Array:
	var pts := PackedVector2Array([a, b])
	var disp := a.distance_to(b) * 0.35

	for _lvl in levels:
		var next := PackedVector2Array()
		next.append(pts[0])
		for i in range(pts.size() - 1):
			var p0: Vector2 = pts[i]
			var p1: Vector2 = pts[i + 1]
			var mid  := (p0 + p1) * 0.5
			var perp := Vector2(-(p1 - p0).y, (p1 - p0).x).normalized()
			var kick := (_rng.randf() - 0.5) * 2.0 * disp
			next.append(mid + perp * kick)
			next.append(p1)
		pts  = next
		disp *= 0.5

	return pts
