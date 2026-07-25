class_name ViewLayer3D
extends Node

## Renders a live 3D mirror of the 2D game world inside a SubViewport.
## Game physics remain entirely 2D; this layer reads positions each frame.
## Coordinate mapping: 2D(x, y) → 3D(x, elevation, -y)
## The 2D game works in world-metres, so 3D positions are 1:1 in metres.

enum CameraMode { BROADCAST = 0, THIRD_PERSON = 1 }

const TEAM_COLORS: Array = [
	Color(1.00, 0.23, 0.32),  # HOME red
	Color(0.18, 0.51, 1.00),  # AWAY blue
	Color(0.20, 0.90, 0.30),  # THIRD green
]
const C_FIELD     := Color(0.13, 0.38, 0.16)
const C_CHANNEL   := Color(0.20, 0.05, 0.28)
const C_ENDZONE_H := Color(0.34, 0.11, 0.11)
const C_ENDZONE_A := Color(0.11, 0.11, 0.36)
const C_LINE      := Color(1.0,  1.0,  1.0,  0.55)
const C_ENDLINE   := Color(1.0,  0.85, 0.15)
const C_BALL      := Color(0.95, 0.90, 0.70)
const C_CREATURE  := Color(0.55, 0.05, 0.60)
const C_SKY       := Color(0.05, 0.08, 0.14)

const CAM_LERP := 8.0

# Throw arc preview constants — match BallSystem values exactly
const ARC_STEPS       := 16
const ARC_FLIGHT_TIME := 1.5     # seconds: dist(30m) / speed(20m/s)
const ARC_H_SPEED     := 20.0    # horizontal m/s (charged throw)
const ARC_INIT_ZV     := 15.0    # 0.5 * gravity(20) * flight_time(1.5)
const ARC_GRAVITY     := 20.0
const PASS_DIST       := 20.0    # metres of pass preview to show (flat)
const CHARGE_SEGS     := 36      # ring segments (one per 10°)
const RING_RADIUS     := 1.3     # metres — just outside 1.62 cube corners
const C_MAX_CHARGE    := 7.0     # seconds — matches BallSystem.MAX_CHARGE

var view_mode: int = MatchConfig.ViewMode.THREE_QUARTER

var _viewport:      SubViewport
var _camera:        Camera3D
var _player_meshes: Dictionary = {}  # player_id -> Node3D (cube + arrow)
var _ball_mesh:     MeshInstance3D = null
var _creature_mesh: MeshInstance3D = null
var _ball_node:     Node = null
var _creature_node: Node = null
var _target_bracket:     Node3D = null
var _target_bracket_mat: StandardMaterial3D = null

var _arc_mat:          StandardMaterial3D = null
var _arc_dots:         Array              = []  # ARC_STEPS MeshInstance3D spheres
var _arc_land:         MeshInstance3D     = null
var _charge_ring_mat:  StandardMaterial3D = null
var _charge_ring_segs: Array              = []  # CHARGE_SEGS MeshInstance3D boxes

# FULL_3D camera state
var _camera_mode: int = CameraMode.BROADCAST
var _ball_cam: bool = false
var _cam_pos:  Vector3 = Vector3(70.0, 52.0, 38.0)
var _cam_look: Vector3 = Vector3(70.0, 0.0, -14.0)

func _ready() -> void:
	add_to_group("view_layer_3d")
	_build_viewport()
	_build_world()
	var game := get_parent()
	_ball_node     = game.get_node_or_null("Entities/Ball")
	_creature_node = game.get_node_or_null("Entities/Creature")
	_ball_mesh     = _make_sphere(0.35, C_BALL)
	_creature_mesh = _make_capsule(4.0, 9.0, C_CREATURE)
	_target_bracket = _make_target_bracket()
	_arc_dots = _make_arc_preview()
	_charge_ring_segs = _make_charge_ring()

func _process(delta: float) -> void:
	_sync_players()
	_sync_ball()
	_sync_creature()
	_sync_target_bracket()
	_sync_throw_arc()
	_sync_charge_ring()
	_update_camera(delta)

func _unhandled_key_input(event: InputEvent) -> void:
	if view_mode != MatchConfig.ViewMode.FULL_3D:
		return
	if event.is_action_pressed("view_cycle"):
		_camera_mode = CameraMode.THIRD_PERSON if _camera_mode == CameraMode.BROADCAST else CameraMode.BROADCAST
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("view_ballcam"):
		_ball_cam = not _ball_cam
		get_viewport().set_input_as_handled()

# ── Viewport ──────────────────────────────────────────────────────────────────

func _build_viewport() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 1
	add_child(canvas)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(container)

	_viewport = SubViewport.new()
	_viewport.size = get_viewport().size
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	container.add_child(_viewport)

# ── World ─────────────────────────────────────────────────────────────────────

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode      = Environment.BG_COLOR
	env.background_color     = C_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.30, 0.38, 0.50)
	env.ambient_light_energy = 0.65
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy     = 1.3
	sun.light_color      = Color(1.0, 0.95, 0.85)
	_viewport.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -125, 0)
	fill.light_energy     = 0.25
	fill.light_color      = Color(0.55, 0.65, 0.90)
	_viewport.add_child(fill)

	# Field surface: 2D x∈[0,140] y∈[0,40] → 3D X∈[0,140] Z∈[0,−40]
	# Side channels extend outside: y∈[−10,0] top (3D Z∈[0,10]) and y∈[40,50] bottom (3D Z∈[−50,−40])
	# Endzones
	_add_box(Vector3( 10.0, 0.010, -20.0), Vector3(20.0, 0.04, 40.0), C_ENDZONE_H)
	_add_box(Vector3(130.0, 0.010, -20.0), Vector3(20.0, 0.04, 40.0), C_ENDZONE_A)

	# End creature channels (inside field): x∈[20,30] and x∈[110,120], full y∈[0,40]
	_add_box(Vector3( 25.0, 0.010, -20.0), Vector3(10.0, 0.04, 40.0), C_CHANNEL)
	_add_box(Vector3(115.0, 0.010, -20.0), Vector3(10.0, 0.04, 40.0), C_CHANNEL)

	# Side creature channels (outside field): y∈[−10,0] and y∈[40,50], x∈[20,120]
	_add_box(Vector3(70.0, 0.010,   5.0), Vector3(100.0, 0.04, 10.0), C_CHANNEL)  # top
	_add_box(Vector3(70.0, 0.010, -45.0), Vector3(100.0, 0.04, 10.0), C_CHANNEL)  # bottom

	# Inner green playing field: x∈[30,110], full y∈[0,40]
	_add_box(Vector3(70.0, 0.020, -20.0), Vector3(80.0, 0.04, 40.0), C_FIELD)

	# Phase lines at x = 50, 70, 90 spanning full inner field height
	for xm: float in [50.0, 70.0, 90.0]:
		_add_box(Vector3(xm, 0.06, -20.0), Vector3(0.18, 0.12, 40.0), C_LINE)

	# Endzone / channel goalline boundary at x=20 and x=120: extended Z=60 to border side channels
	_add_box(Vector3( 20.0, 0.06, -20.0), Vector3(0.25, 0.12, 60.0), C_ENDLINE)
	_add_box(Vector3(120.0, 0.06, -20.0), Vector3(0.25, 0.12, 60.0), C_ENDLINE)

	# End-channel inner walls (inner field / channel boundary) at x=30 and x=110
	_add_box(Vector3( 30.0, 0.06, -20.0), Vector3(0.20, 0.12, 40.0), C_LINE)
	_add_box(Vector3(110.0, 0.06, -20.0), Vector3(0.20, 0.12, 40.0), C_LINE)

	# Side-channel inner edge at y=0 and y=40: span only x∈[30,110] to avoid crossing end channels
	_add_box(Vector3(70.0, 0.06,   0.0), Vector3(80.0, 0.12, 0.20), Color(1, 1, 1, 0.5))
	_add_box(Vector3(70.0, 0.06, -40.0), Vector3(80.0, 0.12, 0.20), Color(1, 1, 1, 0.5))

	# Side-channel outer edge at y=−10 (Z=10) and y=50 (Z=−50), spanning x∈[20,120]
	_add_box(Vector3(70.0, 0.06,  10.0), Vector3(100.0, 0.12, 0.20), Color(1, 1, 1, 0.3))
	_add_box(Vector3(70.0, 0.06, -50.0), Vector3(100.0, 0.12, 0.20), Color(1, 1, 1, 0.3))

	# End walls at x=0 and x=140
	_add_box(Vector3(  0.0, 0.06, -20.0), Vector3(0.20, 0.12, 42.0), Color(1, 1, 1, 0.3))
	_add_box(Vector3(140.0, 0.06, -20.0), Vector3(0.20, 0.12, 42.0), Color(1, 1, 1, 0.3))

	_camera = Camera3D.new()
	_camera.near = 0.5
	_camera.far  = 500.0
	_viewport.add_child(_camera)
	_reset_camera()

func _reset_camera() -> void:
	if view_mode == MatchConfig.ViewMode.THREE_QUARTER:
		_camera.fov = 75.0
		_camera.global_position = Vector3(70.0, 65.0, 90.0)
		_camera.look_at(Vector3(70.0, 0.0, -20.0))
	else:  # FULL_3D
		_camera.fov = 58.0
		_camera.global_position = Vector3(70.0, 52.0, 38.0)
		_camera.look_at(Vector3(70.0, 0.0, -14.0))
		_cam_pos  = _camera.global_position
		_cam_look = Vector3(70.0, 0.0, -14.0)

# ── Camera update ─────────────────────────────────────────────────────────────

func _update_camera(delta: float) -> void:
	if view_mode == MatchConfig.ViewMode.THREE_QUARTER:
		return  # fixed wide-angle view — whole field always visible

	# Compute target position and look-at for FULL_3D
	var ball_x := 70.0
	var ball_z := -20.0
	if is_instance_valid(_ball_node):
		ball_x = _ball_node.global_position.x
		ball_z = -_ball_node.global_position.y

	var target_pos:  Vector3
	var target_look: Vector3
	var target_fov:  float

	match _camera_mode:
		CameraMode.BROADCAST:
			var cx := clampf(ball_x, 28.0, 112.0)
			if _ball_cam:
				# Steep overhead ball-cam: 50° pitch, ~28 units from ball
				target_pos  = Vector3(ball_x, 22.0, ball_z + 16.0)
				target_look = Vector3(ball_x, 0.4, ball_z)
				target_fov  = 55.0
			else:
				# Elevated broadcast, pans with ball along X
				target_pos  = Vector3(cx, 52.0, 38.0)
				target_look = Vector3(cx, 0.0, -14.0)
				target_fov  = 58.0
		CameraMode.THIRD_PERSON:
			var player := _local_player_node()
			if player != null:
				var p: Vector2 = player.global_position
				var rot: float = player.global_rotation
				var forward := Vector3(sin(rot), 0.0, cos(rot))
				var p3 := Vector3(p.x, 0.9, -p.y)
				target_pos  = p3 - forward * 8.0 + Vector3(0.0, 4.0, 0.0)
				target_look = p3 + Vector3(0.0, 1.0, 0.0)
			else:
				var cx := clampf(ball_x, 28.0, 112.0)
				target_pos  = Vector3(cx, 52.0, 38.0)
				target_look = Vector3(cx, 0.0, -14.0)
			target_fov = 90.0
		_:
			target_pos  = _cam_pos
			target_look = _cam_look
			target_fov  = _camera.fov

	var t := clampf(delta * CAM_LERP, 0.0, 1.0)
	_cam_pos  = _cam_pos.lerp(target_pos, t)
	_cam_look = _cam_look.lerp(target_look, t)
	_camera.global_position = _cam_pos
	if _cam_look.distance_squared_to(_cam_pos) > 0.001:
		_camera.look_at(_cam_look)
	_camera.fov = lerpf(_camera.fov, target_fov, t)

func _local_player_node() -> Node:
	var pid := NetworkManager.local_player_id
	if not pid.is_empty():
		for n in get_tree().get_nodes_in_group("players"):
			if n.player_id == pid and n.is_alive and n.is_on_field:
				return n
		return null
	for n in get_tree().get_nodes_in_group("players"):
		if n.get("team_id") == 0 and n.is_alive and n.is_on_field:
			return n
	return null

# ── Entity sync ───────────────────────────────────────────────────────────────

func _sync_players() -> void:
	var seen: Dictionary = {}
	for node in get_tree().get_nodes_in_group("players"):
		var pid: String = node.player_id
		seen[pid] = true
		if not _player_meshes.has(pid):
			var t: int = clampi(int(node.get("team_id")), 0, 2)
			_player_meshes[pid] = _make_player_unit(TEAM_COLORS[t])
		var root: Node3D = _player_meshes[pid]
		var alive: bool = node.get("is_alive") == true and node.get("is_on_field") == true
		root.visible = alive
		if alive:
			var p: Vector2 = node.global_position
			var zh: float = float(node.get("z_height")) * 0.6
			root.global_position = Vector3(p.x, 0.81 + zh, -p.y)
			# W moves in direction (sin θ, -cos θ) in 2D = (sin θ, 0, cos θ) in 3D.
			# Make local -Z point there: root.rotation.y = θ + π.
			root.rotation.y = float(node.get("global_rotation")) + PI
	for pid: String in _player_meshes.keys().duplicate():
		if not seen.has(pid):
			_player_meshes[pid].queue_free()
			_player_meshes.erase(pid)

func _sync_ball() -> void:
	if _ball_mesh == null or not is_instance_valid(_ball_node):
		return
	var p: Vector2 = _ball_node.global_position
	var zh: float = MatchState.ball.z_height * 0.6 if MatchState.ball != null else 0.0
	_ball_mesh.global_position = Vector3(p.x, 0.4 + zh, -p.y)

func _sync_creature() -> void:
	if _creature_mesh == null or not is_instance_valid(_creature_node):
		return
	var p: Vector2 = _creature_node.global_position
	_creature_mesh.global_position = Vector3(p.x, 4.5, -p.y)

# ── Target bracket ────────────────────────────────────────────────────────────

func _make_target_bracket() -> Node3D:
	_target_bracket_mat = StandardMaterial3D.new()
	_target_bracket_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_target_bracket_mat.albedo_color  = Color(1.00, 0.42, 0.42)

	var root := Node3D.new()
	_viewport.add_child(root)

	# Four L-shaped corner brackets framing the unit's 0.75×0.75 footprint.
	# Each corner = two thin boxes: one arm along X, one along Z.
	const H: float = 0.48    # half-span of the bracket square
	const A: float = 0.22    # arm length
	const T: float = 0.05    # arm cross-section (width)
	const Y: float = 0.05    # arm height (flat slab)

	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			# Arm running along X at the Z edge of this corner
			_add_bracket_box(root,
				Vector3(float(sx) * (H - A * 0.5), 0.0, float(sz) * H),
				Vector3(A, Y, T))
			# Arm running along Z at the X edge of this corner
			_add_bracket_box(root,
				Vector3(float(sx) * H, 0.0, float(sz) * (H - A * 0.5)),
				Vector3(T, Y, A))

	root.visible = false
	return root

func _add_bracket_box(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh              = bm
	mi.material_override = _target_bracket_mat
	mi.position          = pos
	parent.add_child(mi)

func _sync_target_bracket() -> void:
	if _target_bracket == null:
		return
	var local_node := _local_player_node()
	if local_node == null:
		_target_bracket.visible = false
		return
	var target_id: String = str(local_node.get("_explicit_target_id"))
	if target_id.is_empty():
		_target_bracket.visible = false
		return
	for n in get_tree().get_nodes_in_group("players"):
		if str(n.get("player_id")) == target_id \
				and n.get("is_alive") == true and n.get("is_on_field") == true:
			var p: Vector2 = n.global_position
			var zh: float = float(n.get("z_height")) * 0.6
			# Raise bracket above field geometry (line boxes top out at y=0.12)
			_target_bracket.global_position = Vector3(p.x, zh + 0.20, -p.y)
			var is_enemy := int(n.get("team_id")) != int(local_node.get("team_id"))
			_target_bracket_mat.albedo_color = \
				Color(1.00, 0.42, 0.42) if is_enemy else Color(0.20, 0.93, 0.40)
			_target_bracket.visible = true
			return
	_target_bracket.visible = false

# ── Throw arc preview ────────────────────────────────────────────────────────

func _make_arc_preview() -> Array:
	_arc_mat = StandardMaterial3D.new()
	_arc_mat.albedo_color  = Color(1.0, 0.87, 0.0, 0.88)
	_arc_mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arc_mat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA

	var dots: Array = []
	for _i in ARC_STEPS:
		var sm := SphereMesh.new()
		sm.radius = 0.10
		sm.height = 0.20
		var mi := MeshInstance3D.new()
		mi.mesh              = sm
		mi.material_override = _arc_mat
		mi.visible           = false
		_viewport.add_child(mi)
		dots.append(mi)

	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(1.0, 0.87, 0.0, 1.0)
	lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var cm := CylinderMesh.new()
	cm.top_radius    = 0.32
	cm.bottom_radius = 0.32
	cm.height        = 0.06
	_arc_land = MeshInstance3D.new()
	_arc_land.mesh              = cm
	_arc_land.material_override = lmat
	_arc_land.visible           = false
	_viewport.add_child(_arc_land)

	return dots

func _sync_throw_arc() -> void:
	if _arc_dots.is_empty():
		return
	var local_node := _local_player_node()
	var ball := MatchState.ball
	var holding := local_node != null and ball != null \
		and str(local_node.get("player_id")) == ball.holder_id \
		and Input.is_action_pressed("throw_ball")
	if not holding:
		for dot in _arc_dots: dot.visible = false
		if _arc_land: _arc_land.visible = false
		return

	var p:   Vector2 = local_node.global_position
	var rot: float   = local_node.global_rotation
	var dir := Vector2(0.0, -1.0).rotated(rot)
	var is_charged := ball.charge_timer > 1.0

	if is_charged:
		for i in ARC_STEPS:
			var t    := float(i + 1) / float(ARC_STEPS) * ARC_FLIGHT_TIME
			var pos2 := p + dir * ARC_H_SPEED * t
			var z    := maxf(0.0, ARC_INIT_ZV * t - 0.5 * ARC_GRAVITY * t * t)
			(_arc_dots[i] as MeshInstance3D).global_position = Vector3(pos2.x, 0.4 + z * 0.6, -pos2.y)
			(_arc_dots[i] as MeshInstance3D).visible = true
		var land2 := p + dir * ARC_H_SPEED * ARC_FLIGHT_TIME
		_arc_land.global_position = Vector3(land2.x, 0.04, -land2.y)
		_arc_land.visible = true
	else:
		# Regular pass: flat dotted line over PASS_DIST metres
		for i in ARC_STEPS:
			var t    := float(i + 1) / float(ARC_STEPS)
			var pos2 := p + dir * PASS_DIST * t
			(_arc_dots[i] as MeshInstance3D).global_position = Vector3(pos2.x, 0.4, -pos2.y)
			(_arc_dots[i] as MeshInstance3D).visible = true
		var land2 := p + dir * PASS_DIST
		_arc_land.global_position = Vector3(land2.x, 0.04, -land2.y)
		_arc_land.visible = true

# ── Charge ring ───────────────────────────────────────────────────────────────

func _make_charge_ring() -> Array:
	_charge_ring_mat = StandardMaterial3D.new()
	_charge_ring_mat.albedo_color = Color(1.0, 0.87, 0.0)
	_charge_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var segs: Array = []
	for i in CHARGE_SEGS:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 0.06, 0.24)
		var mi := MeshInstance3D.new()
		mi.mesh              = bm
		mi.material_override = _charge_ring_mat
		mi.visible           = false
		_viewport.add_child(mi)
		segs.append(mi)
	return segs

func _sync_charge_ring() -> void:
	if _charge_ring_segs.is_empty():
		return
	var local_node := _local_player_node()
	var ball := MatchState.ball
	if local_node == null or ball == null \
			or str(local_node.get("player_id")) != ball.holder_id \
			or ball.charge_timer <= 0.0:
		for seg in _charge_ring_segs: (seg as MeshInstance3D).visible = false
		return

	var p:  Vector2 = local_node.global_position
	var zh: float   = float(local_node.get("z_height")) * 0.6
	var center      := Vector3(p.x, zh, -p.y)
	var pct         := minf(ball.charge_timer / C_MAX_CHARGE, 1.0)
	var fill_count  := int(CHARGE_SEGS * pct)
	_charge_ring_mat.albedo_color = Color(1.0, lerpf(0.87, 0.0, pct), 0.0)

	for i in CHARGE_SEGS:
		var seg := _charge_ring_segs[i] as MeshInstance3D
		if i < fill_count:
			var angle := float(i) / float(CHARGE_SEGS) * TAU
			seg.global_position = center + Vector3(sin(angle) * RING_RADIUS, 0.03, cos(angle) * RING_RADIUS)
			seg.rotation.y = angle
			seg.visible = true
		else:
			seg.visible = false

# ── Screen projection ─────────────────────────────────────────────────────────

## Convert a 2D game-world position to a screen pixel coordinate using the
## 3D camera.  elevation=2.2 sits just above a standing player's head.
func world_to_screen(world_pos_2d: Vector2, elevation: float = 2.2) -> Vector2:
	if _camera == null or not is_instance_valid(_camera):
		return world_pos_2d
	var pos3d := Vector3(world_pos_2d.x, elevation, -world_pos_2d.y)
	return _camera.unproject_position(pos3d)

# ── Mesh helpers ──────────────────────────────────────────────────────────────

func _make_player_unit(color: Color) -> Node3D:
	var root := Node3D.new()
	_viewport.add_child(root)

	# Cube body
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var bm := BoxMesh.new()
	bm.size = Vector3(1.62, 1.62, 1.62)
	var cube := MeshInstance3D.new()
	cube.mesh = bm
	cube.material_override = mat
	root.add_child(cube)

	# Flat directional arrow in XZ plane; tip points toward local -Z (forward after Y rotation)
	var arr := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3( 0.00, 0.0, -0.38),   # tip
		Vector3(-0.27, 0.0,  0.22),   # left base
		Vector3( 0.27, 0.0,  0.22),   # right base
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([
		Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 1, 0),
	])
	arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(1.0, 1.0, 1.0, 0.92)
	amat.cull_mode    = BaseMaterial3D.CULL_DISABLED
	var arrow := MeshInstance3D.new()
	arrow.mesh              = arr
	arrow.material_override = amat
	arrow.position          = Vector3(0.0, 0.81, 0.0)   # sits on cube top
	root.add_child(arrow)

	return root

func _add_box(center: Vector3, sz: Vector3, color: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var bm := BoxMesh.new()
	bm.size = sz
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = center
	_viewport.add_child(mi)
	return mi

func _make_capsule(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	_viewport.add_child(mi)
	return mi

func _make_sphere(radius: float, color: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = mat
	_viewport.add_child(mi)
	return mi
