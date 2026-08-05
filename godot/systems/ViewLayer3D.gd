class_name ViewLayer3D
extends Node

const PlayerLookup = preload("res://systems/PlayerLookup.gd")

## Renders a live 3D mirror of the 2D game world inside a SubViewport.
## Game physics remain entirely 2D; this layer reads positions each frame.
## Coordinate mapping: 2D(x, y) → 3D(x, elevation, -y)
## The 2D game works in world-metres, so 3D positions are 1:1 in metres.

enum CameraMode { BROADCAST = 0, THIRD_PERSON = 1 }

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

# Terrain height mesh constants — coarse 29×9 vertex grid over the play field
const TERRAIN_NX       := 29        # 28 coarse columns + 1
const TERRAIN_NY       :=  9        # 8 coarse rows + 1
const TERRAIN_DX       :=  5.0      # metres per coarse column
const TERRAIN_DY       :=  5.0      # metres per coarse row
const TERRAIN_ELEV_COLS := 168
const TERRAIN_ELEV_ROWS :=  48
const TERRAIN_ELEV_CW  := 140.0 / 168.0
const TERRAIN_ELEV_CH  :=  40.0 / 48.0
const TERRAIN_Y_BASE   :=  0.01     # at field surface level

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
const ABILITY_BAR_SEGS   := 20
const ABILITY_BAR_W      := 2.0   # metres wide
const TERRAIN_RING_SEGS  := 48    # segments for terrain preview/expiry rings
const TERRAIN_IND_DUR    := 1.5   # seconds — matches PREVIEW_DELAY / EXPIRY_WARN_TIME

var view_mode: int = MatchConfig.ViewMode.THREE_QUARTER

var _viewport:      SubViewport
var _camera:        Camera3D
var _player_meshes:   Dictionary = {}  # player_id -> Node3D (cube + arrow)
var _creature_meshes: Dictionary = {}  # creature node -> MeshInstance3D
var _stale_player_ids: Array[String] = []  # reused buffer; avoids per-frame allocation
var _ball_mesh:       MeshInstance3D = null
var _ball_node: Node = null
var _target_bracket:     Node3D = null
var _target_bracket_mat: StandardMaterial3D = null

var _arc_mat:          StandardMaterial3D = null
var _arc_dots:         Array              = []  # ARC_STEPS MeshInstance3D spheres
var _arc_land:         MeshInstance3D     = null
var _charge_ring_mat:  StandardMaterial3D = null
var _charge_ring_segs: Array              = []  # CHARGE_SEGS MeshInstance3D boxes

var _terrain_mesh_inst: MeshInstance3D    = null
var _terrain_mat:       StandardMaterial3D = null
var _terrain_dirty:     bool               = false

# Ability charge bar (below casting unit)
var _ability_bar_segs:      Array              = []
var _ability_bar_mat:       StandardMaterial3D = null
var _ability_charging:      bool               = false
var _ability_charge_elapsed: float             = 0.0
var _ability_charge_max_val: float             = 0.0
var _ability_charge_pid:    String             = ""

# Terrain preview / expiry rings (ImmediateMesh lines drawn on the ground)
var _terrain_preview_mesh: MeshInstance3D     = null
var _terrain_preview_imm:  ImmediateMesh      = null
var _terrain_preview_mat:  StandardMaterial3D = null
var _preview_pos:    Vector3 = Vector3.ZERO
var _preview_radius: float   = 0.0
var _preview_timer:  float   = 0.0
var _preview_color:  Color   = Color.WHITE

var _terrain_expiry_mesh: MeshInstance3D     = null
var _terrain_expiry_imm:  ImmediateMesh      = null
var _terrain_expiry_mat:  StandardMaterial3D = null
var _expiry_pos:    Vector3 = Vector3.ZERO
var _expiry_radius: float   = 0.0
var _expiry_timer:  float   = 0.0
var _expiry_color:  Color   = Color.WHITE

# Ability VFX overlay — reads AbilityVfxLayer._active and draws in 3D
var _vfx_imm:  ImmediateMesh      = null
var _vfx_mesh: MeshInstance3D     = null

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
	_ball_node = game.get_node_or_null("Entities/Ball")
	_ball_mesh = _make_sphere(0.35, C_BALL)
	_target_bracket = _make_target_bracket()
	_arc_dots = _make_arc_preview()
	_charge_ring_segs = _make_charge_ring()
	_ability_bar_segs = _make_ability_bar()
	_build_terrain_indicators()
	_build_vfx_overlay()
	EventBus.terrain_preview_started.connect(_on_terrain_preview_started)
	EventBus.terrain_expiry_warning.connect(_on_terrain_expiry_warning)
	EventBus.ability_charge_started.connect(_on_ability_charge_started)
	EventBus.ability_charge_released.connect(_on_ability_charge_released)

func _process(delta: float) -> void:
	_sync_players()
	_sync_ball()
	_sync_creatures()
	_sync_target_bracket()
	_sync_throw_arc()
	_sync_charge_ring()
	_sync_terrain()
	_sync_terrain_preview(delta)
	_sync_terrain_expiry(delta)
	_sync_ability_bar(delta)
	_sync_vfx()
	_update_camera(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _try_pick_target(event.position):
			get_viewport().set_input_as_handled()

func _try_pick_target(screen_pos: Vector2) -> bool:
	if MatchState.is_paused:
		return false
	var local_node := _local_player_node()
	if local_node == null:
		return false
	var local_pid: String = local_node.player_id
	const PICK_RADIUS := 50.0
	var best_pid := ""
	var best_dist := PICK_RADIUS
	for pid in _player_meshes:
		var root: Node3D = _player_meshes[pid]
		if not root.visible:
			continue
		var screen2d: Vector2 = _camera.unproject_position(root.global_position)
		var d := screen_pos.distance_to(screen2d)
		if d < best_dist:
			best_dist = d
			best_pid = pid
	for _cnode in _creature_meshes:
		var cmi: MeshInstance3D = _creature_meshes[_cnode]
		if not cmi.visible: continue
		var screen2d: Vector2 = _camera.unproject_position(cmi.global_position)
		var d := screen_pos.distance_to(screen2d)
		if d < best_dist:
			best_dist = d
			best_pid = "creature"
	if best_pid.is_empty():
		return false
	local_node.set_explicit_target(best_pid)
	return true

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

	if MatchState.is_three_team:
		_build_field_3team()
	else:
		_build_field_2team()

	# Terrain height mesh — IS the field surface (replaces flat zone boxes).
	# Rebuilt whenever elevation or pit data changes; also built once on startup.
	_terrain_mat = StandardMaterial3D.new()
	_terrain_mat.vertex_color_use_as_albedo = true
	_terrain_mat.shading_mode  = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_terrain_mat.cull_mode     = BaseMaterial3D.CULL_DISABLED
	_terrain_mesh_inst = MeshInstance3D.new()
	_terrain_mesh_inst.mesh              = ArrayMesh.new()
	_terrain_mesh_inst.material_override = _terrain_mat
	_viewport.add_child(_terrain_mesh_inst)
	EventBus.terrain_elevation_changed.connect(func() -> void: _terrain_dirty = true)
	EventBus.pit_opened.connect(func(_p: Vector2, _r: float, _d: float) -> void: _terrain_dirty = true)
	EventBus.terrain_reset.connect(func(_c: int, _row: int) -> void: _terrain_dirty = true)
	_terrain_dirty = true  # build flat field surface on first _process tick

	_camera = Camera3D.new()
	_camera.near = 0.5
	_camera.far  = 500.0
	_viewport.add_child(_camera)
	_reset_camera()

func _build_field_2team() -> void:
	# Side creature channels (outside terrain mesh, y∈[−10,0] and y∈[40,50], x∈[20,120])
	_add_box(Vector3(70.0, 0.010,   5.0), Vector3(100.0, 0.04, 10.0), C_CHANNEL)  # top
	_add_box(Vector3(70.0, 0.010, -45.0), Vector3(100.0, 0.04, 10.0), C_CHANNEL)  # bottom

	# Phase lines at x = 50, 70, 90 spanning full inner field height
	for xm: float in [50.0, 70.0, 90.0]:
		_add_box(Vector3(xm, 0.06, -20.0), Vector3(0.18, 0.12, 40.0), C_LINE)

	# Goalline at x=20 and x=120
	_add_box(Vector3( 20.0, 0.06, -20.0), Vector3(0.25, 0.12, 40.0), C_ENDLINE)
	_add_box(Vector3(120.0, 0.06, -20.0), Vector3(0.25, 0.12, 40.0), C_ENDLINE)

	# Endzone top/bottom borders
	_add_box(Vector3( 10.0, 0.06,   0.0), Vector3(20.0, 0.12, 0.20), Color(1, 1, 1, 0.5))
	_add_box(Vector3( 10.0, 0.06, -40.0), Vector3(20.0, 0.12, 0.20), Color(1, 1, 1, 0.5))
	_add_box(Vector3(130.0, 0.06,   0.0), Vector3(20.0, 0.12, 0.20), Color(1, 1, 1, 0.5))
	_add_box(Vector3(130.0, 0.06, -40.0), Vector3(20.0, 0.12, 0.20), Color(1, 1, 1, 0.5))

	# End-channel inner walls at x=30 and x=110
	_add_box(Vector3( 30.0, 0.06, -20.0), Vector3(0.20, 0.12, 40.0), C_LINE)
	_add_box(Vector3(110.0, 0.06, -20.0), Vector3(0.20, 0.12, 40.0), C_LINE)

	# Side-channel inner edge at y=0 and y=40
	_add_box(Vector3(70.0, 0.06,   0.0), Vector3(80.0, 0.12, 0.20), Color(1, 1, 1, 0.5))
	_add_box(Vector3(70.0, 0.06, -40.0), Vector3(80.0, 0.12, 0.20), Color(1, 1, 1, 0.5))

	# Side-channel end caps
	_add_box(Vector3( 20.0, 0.06,   5.0), Vector3(0.20, 0.12, 10.0), Color(1, 1, 1, 0.5))
	_add_box(Vector3( 20.0, 0.06, -45.0), Vector3(0.20, 0.12, 10.0), Color(1, 1, 1, 0.5))
	_add_box(Vector3(120.0, 0.06,   5.0), Vector3(0.20, 0.12, 10.0), Color(1, 1, 1, 0.5))
	_add_box(Vector3(120.0, 0.06, -45.0), Vector3(0.20, 0.12, 10.0), Color(1, 1, 1, 0.5))

	# Side-channel outer edges
	_add_box(Vector3(70.0, 0.06,  10.0), Vector3(100.0, 0.12, 0.20), Color(1, 1, 1, 0.3))
	_add_box(Vector3(70.0, 0.06, -50.0), Vector3(100.0, 0.12, 0.20), Color(1, 1, 1, 0.3))

	# End walls at x=0 and x=140
	_add_box(Vector3(  0.0, 0.06, -20.0), Vector3(0.20, 0.12, 42.0), Color(1, 1, 1, 0.3))
	_add_box(Vector3(140.0, 0.06, -20.0), Vector3(0.20, 0.12, 42.0), Color(1, 1, 1, 0.3))

func _build_field_3team() -> void:
	var cx    := MatchState.FIELD3_CX
	var cy    := MatchState.FIELD3_CY
	var inner := MatchState.FIELD3_INRADIUS
	var ch_in := MatchState.FIELD3_CHAN_INNER
	var ch_out:= MatchState.FIELD3_CHAN_OUTER
	var arm_e := MatchState.FIELD3_ARM_END
	var hw2   := MatchState.FIELD3_ARM_HALF_W * 2.0  # full arm width

	# Central hub box covers the junction of all three arms
	_add_box(Vector3(cx, 0.01, -cy), Vector3(hw2, 0.04, hw2), C_FIELD)

	for tid in 3:
		var n2d: Vector2  = MatchState.TEAM3_NORMALS[tid]
		var dir3 := Vector3(n2d.x, 0.0, -n2d.y)
		var rot_y := atan2(dir3.x, dir3.z)
		var ez_color := MatchState.team_color(tid)

		# Playing field zone (inner → ch_in)
		var f_dist := (inner + ch_in) * 0.5
		var f_p    := Vector2(cx, cy) + n2d * f_dist
		_add_oriented_box(Vector3(f_p.x, 0.01, -f_p.y), Vector3(hw2, 0.04, ch_in - inner), rot_y, C_FIELD)

		# Channel zone (ch_in → ch_out)
		var c_dist := (ch_in + ch_out) * 0.5
		var c_p    := Vector2(cx, cy) + n2d * c_dist
		_add_oriented_box(Vector3(c_p.x, 0.01, -c_p.y), Vector3(hw2, 0.04, ch_out - ch_in), rot_y, C_CHANNEL)

		# Endzone (ch_out → arm_e)
		var e_dist := (ch_out + arm_e) * 0.5
		var e_p    := Vector2(cx, cy) + n2d * e_dist
		_add_oriented_box(Vector3(e_p.x, 0.01, -e_p.y), Vector3(hw2, 0.04, arm_e - ch_out), rot_y, ez_color)

		# Phase lines
		for pd: float in MatchState.FIELD3_PHASE_DISTS:
			var pl_p := Vector2(cx, cy) + n2d * pd
			_add_oriented_box(Vector3(pl_p.x, 0.06, -pl_p.y), Vector3(hw2, 0.12, 0.18), rot_y, C_LINE)

		# Goal line at ch_out
		var gl_p := Vector2(cx, cy) + n2d * ch_out
		_add_oriented_box(Vector3(gl_p.x, 0.06, -gl_p.y), Vector3(hw2, 0.12, 0.25), rot_y, C_ENDLINE)

		# Arm end wall
		var ew_p := Vector2(cx, cy) + n2d * arm_e
		_add_oriented_box(Vector3(ew_p.x, 0.06, -ew_p.y), Vector3(hw2, 0.12, 0.20), rot_y, Color(1, 1, 1, 0.3))

		# Arm side walls along full arm length (inner → arm_e)
		var perp2d  := Vector2(-n2d.y, n2d.x)
		var mid_dist := (inner + arm_e) * 0.5
		var mid_p   := Vector2(cx, cy) + n2d * mid_dist
		for side in [-1, 1]:
			var sw_p := mid_p + perp2d * (MatchState.FIELD3_ARM_HALF_W * float(side))
			_add_oriented_box(Vector3(sw_p.x, 0.06, -sw_p.y),
				Vector3(0.20, 0.12, arm_e - inner), rot_y, Color(1, 1, 1, 0.35))

		# Creature channel: two side strips beside the arm ending at ch_out.
		# The cross-bar at ch_in → ch_out is already drawn by the channel-zone box above.
		var strip_len := ch_out - inner
		var strip_mid := (inner + ch_out) * 0.5
		for side in [-1, 1]:
			var ch_p := Vector2(cx, cy) + n2d * strip_mid \
				+ perp2d * ((MatchState.FIELD3_ARM_HALF_W + 5.0) * float(side))
			_add_oriented_box(Vector3(ch_p.x, 0.01, -ch_p.y),
				Vector3(10.0, 0.04, strip_len), rot_y, C_CHANNEL)

func _reset_camera() -> void:
	if MatchState.is_three_team:
		if view_mode == MatchConfig.ViewMode.THREE_QUARTER:
			_camera.fov = 70.0
			_camera.global_position = Vector3(110.0, 160.0, 50.0)
			_camera.look_at(Vector3(110.0, 0.0, -120.0))
		else:  # FULL_3D
			_camera.fov = 65.0
			_camera.global_position = Vector3(110.0, 130.0, 35.0)
			_camera.look_at(Vector3(110.0, 0.0, -110.0))
			_cam_pos  = _camera.global_position
			_cam_look = Vector3(110.0, 0.0, -110.0)
	elif view_mode == MatchConfig.ViewMode.THREE_QUARTER:
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
			if _ball_cam:
				# Steep overhead ball-cam: 50° pitch, ~28 units from ball
				target_pos  = Vector3(ball_x, 22.0, ball_z + 16.0)
				target_look = Vector3(ball_x, 0.4, ball_z)
				target_fov  = 55.0
			elif MatchState.is_three_team:
				# Elevated broadcast panning 25% toward ball from field centre
				var cx3 := MatchState.FIELD3_CX
				var cz3 := -MatchState.FIELD3_CY
				var tx  := lerpf(cx3, ball_x, 0.25)
				var tz  := lerpf(cz3, ball_z, 0.25)
				target_pos  = Vector3(tx, 130.0, tz + 50.0)
				target_look = Vector3(tx, 0.0, tz - 15.0)
				target_fov  = 65.0
			else:
				# Elevated broadcast, pans with ball along X
				var cx := clampf(ball_x, 28.0, 112.0)
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
		var n := PlayerLookup.get_node(pid)
		return n if n != null and n.is_alive and n.is_on_field else null
	for n in PlayerLookup.get_all_nodes():
		if n.get("team_id") == 0 and n.is_alive and n.is_on_field:
			return n
	return null

# ── Entity sync ───────────────────────────────────────────────────────────────

func _sync_players() -> void:
	var seen: Dictionary = {}
	for node in PlayerLookup.get_all_nodes():
		var pid: String = node.player_id
		seen[pid] = true
		if not _player_meshes.has(pid):
			_player_meshes[pid] = _make_player_unit(MatchState.team_color(int(node.get("team_id"))))
		var root: Node3D = _player_meshes[pid]
		var alive: bool = node.get("is_alive") == true and node.get("is_on_field") == true
		root.visible = alive
		if alive:
			var p: Vector2 = node.global_position
			var zh: float = float(node.get("z_height")) * 0.6
			var th: float = _terrain_sample_at(p)
			root.global_position = Vector3(p.x, 0.81 + zh + th, -p.y)
			# W moves in direction (sin θ, -cos θ) in 2D = (sin θ, 0, cos θ) in 3D.
			# Make local -Z point there: root.rotation.y = θ + π.
			root.rotation.y = float(node.get("global_rotation")) + PI
			var cube_mat: StandardMaterial3D = root.get_child(0).material_override
			if pid == NetworkManager.local_player_id:
				var cls = node.get("class_definition")
				cube_mat.albedo_color = cls.body_color if cls != null else MatchState.team_color(int(node.get("team_id")))
			else:
				cube_mat.albedo_color = MatchState.team_color(int(node.get("team_id")))
	_stale_player_ids.clear()
	for pid: String in _player_meshes:
		if not seen.has(pid):
			_stale_player_ids.append(pid)
	for pid: String in _stale_player_ids:
		_player_meshes[pid].queue_free()
		_player_meshes.erase(pid)

func _sync_ball() -> void:
	if _ball_mesh == null or not is_instance_valid(_ball_node):
		return
	var p: Vector2 = _ball_node.global_position
	var zh: float = MatchState.ball.z_height * 0.6 if MatchState.ball != null else 0.0
	var th: float = _terrain_sample_at(p)
	_ball_mesh.global_position = Vector3(p.x, 0.4 + zh + th, -p.y)

func _sync_creatures() -> void:
	var creatures := get_tree().get_nodes_in_group("creatures")
	for node in _creature_meshes.keys():
		if not is_instance_valid(node):
			(_creature_meshes[node] as MeshInstance3D).queue_free()
			_creature_meshes.erase(node)
	for creature in creatures:
		if not _creature_meshes.has(creature):
			var r: float = float(creature.get("body_radius")) if creature.get("body_radius") else 4.0
			_creature_meshes[creature] = _make_creature_box(r)
		var mi: MeshInstance3D = _creature_meshes[creature]
		var alive: bool = creature.get("is_alive") == true
		mi.visible = alive
		if alive:
			var p: Vector2 = creature.global_position
			var r: float = float(creature.get("body_radius")) if creature.get("body_radius") else 4.0
			mi.global_position = Vector3(p.x, r, -p.y)

# ── Target bracket ────────────────────────────────────────────────────────────

func _make_target_bracket() -> Node3D:
	_target_bracket_mat = StandardMaterial3D.new()
	_target_bracket_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_target_bracket_mat.albedo_color  = Color(1.00, 0.10, 0.10)

	var root := Node3D.new()
	_viewport.add_child(root)

	# Four L-shaped corner brackets — tall vertical slabs visible from any camera angle.
	const H: float = 1.20   # half-span (outside the 1.62m cube, half-face = 0.81)
	const A: float = 0.55   # arm length along each edge
	const T: float = 0.14   # arm depth (thin in the radial direction)
	const Y: float = 0.55   # arm HEIGHT

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

	if target_id == "creature":
		for c in get_tree().get_nodes_in_group("creatures"):
			if c.get("is_alive") == true:
				var p: Vector2 = c.global_position
				_target_bracket.global_position = Vector3(p.x, 4.5, -p.y)
				_target_bracket.scale = Vector3(5.0, 1.0, 5.0)
				_target_bracket_mat.albedo_color = Color(1.00, 0.50, 0.05)
				_target_bracket.visible = true
				return
		_target_bracket.visible = false
		return

	_target_bracket.scale = Vector3(1.0, 1.0, 1.0)
	for n in PlayerLookup.get_all_nodes():
		if str(n.get("player_id")) == target_id \
				and n.get("is_alive") == true and n.get("is_on_field") == true:
			var p: Vector2 = n.global_position
			var zh: float = float(n.get("z_height")) * 0.6
			# Centre the tall bracket slabs at mid-cube height
			_target_bracket.global_position = Vector3(p.x, zh + 0.81, -p.y)
			var is_enemy := int(n.get("team_id")) != int(local_node.get("team_id"))
			_target_bracket_mat.albedo_color = \
				Color(1.00, 0.05, 0.05) if is_enemy else Color(0.05, 1.00, 0.20)
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

# ── Terrain height mesh ───────────────────────────────────────────────────────

func _sync_terrain() -> void:
	if MatchState.is_three_team:
		return  # 3-team field uses flat geometry built in _build_field_3team
	if not _terrain_dirty or _terrain_mesh_inst == null:
		return
	if MatchState.terrain == null:
		return
	var elev: PackedFloat32Array = MatchState.terrain.elevation_heights
	if elev.is_empty():
		return
	_terrain_dirty = false
	_rebuild_terrain_mesh(elev)

func _rebuild_terrain_mesh(elev: PackedFloat32Array) -> void:
	var verts  := PackedVector3Array()
	var norms  := PackedVector3Array()
	var cols   := PackedColorArray()
	var inds   := PackedInt32Array()

	# Pass 1: sample fine elevation at coarse vertex positions.
	var heights := PackedFloat32Array()
	heights.resize(TERRAIN_NX * TERRAIN_NY)
	for r in TERRAIN_NY:
		for c in TERRAIN_NX:
			var fc := mini(c * 6, TERRAIN_ELEV_COLS - 1)
			var fr := mini(r * 6, TERRAIN_ELEV_ROWS - 1)
			heights[r * TERRAIN_NX + c] = elev[fr * TERRAIN_ELEV_COLS + fc]

	# Pass 2: override vertices inside pit cells with a deep depression.
	var pits: PackedByteArray = MatchState.terrain.cell_is_pit if MatchState.terrain != null else PackedByteArray()
	if pits.size() == 224:
		for r in TERRAIN_NY:
			for c in TERRAIN_NX:
				var cc := mini(c, 27)
				var cr := mini(r, 7)
				if pits[cr * 28 + cc] != 0:
					heights[r * TERRAIN_NX + c] = -6.0

	# Pass 3: build vertex geometry.
	for r in TERRAIN_NY:
		for c in TERRAIN_NX:
			var h: float  = heights[r * TERRAIN_NX + c]
			var x: float  = float(c) * TERRAIN_DX
			var z: float  = -float(r) * TERRAIN_DY
			verts.append(Vector3(x, TERRAIN_Y_BASE + h, z))

			var hl: float = heights[r * TERRAIN_NX + maxi(c - 1, 0)]
			var hr: float = heights[r * TERRAIN_NX + mini(c + 1, TERRAIN_NX - 1)]
			var hu: float = heights[maxi(r - 1, 0) * TERRAIN_NX + c]
			var hd: float = heights[mini(r + 1, TERRAIN_NY - 1) * TERRAIN_NX + c]
			norms.append(Vector3(hl - hr, 2.0 * TERRAIN_DX, hd - hu).normalized())

			var rgb: Color
			if h <= -5.0:
				rgb = Color(0.08, 0.06, 0.04)  # dark pit floor
			else:
				var t: float    = clampf(h / 4.0, -1.0, 1.0)
				var base: Color = _terrain_zone_color(x)
				if t > 0.0:
					rgb = base.lerp(Color(0.72, 0.58, 0.24), t * 0.70)
				else:
					rgb = base.lerp(Color(0.06, 0.12, 0.38), -t * 0.70)
			cols.append(Color(rgb.r, rgb.g, rgb.b, 1.0))

	for r in TERRAIN_NY - 1:
		for c in TERRAIN_NX - 1:
			var i := r * TERRAIN_NX + c
			inds.append(i);             inds.append(i + TERRAIN_NX); inds.append(i + 1)
			inds.append(i + 1);         inds.append(i + TERRAIN_NX); inds.append(i + TERRAIN_NX + 1)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR]  = cols
	arrays[Mesh.ARRAY_INDEX]  = inds

	var am := _terrain_mesh_inst.mesh as ArrayMesh
	am.clear_surfaces()
	if not verts.is_empty():
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func _terrain_zone_color(x: float) -> Color:
	if x < 20.0:  return C_ENDZONE_H
	if x > 120.0: return C_ENDZONE_A
	if x < 30.0 or x > 110.0: return C_CHANNEL
	return C_FIELD

func _terrain_sample_at(world_pos: Vector2) -> float:
	if MatchState.is_three_team:
		return 0.0
	if MatchState.terrain == null:
		return 0.0
	var elev: PackedFloat32Array = MatchState.terrain.elevation_heights
	if elev.is_empty():
		return 0.0
	var c := clampi(int(world_pos.x / TERRAIN_ELEV_CW), 0, TERRAIN_ELEV_COLS - 1)
	var r := clampi(int(world_pos.y / TERRAIN_ELEV_CH), 0, TERRAIN_ELEV_ROWS - 1)
	return elev[r * TERRAIN_ELEV_COLS + c]

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

func _add_oriented_box(center: Vector3, sz: Vector3, rotation_y: float, color: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var bm := BoxMesh.new()
	bm.size = sz
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = center
	mi.rotation.y = rotation_y
	_viewport.add_child(mi)
	return mi

func _make_creature_box(radius: float) -> MeshInstance3D:
	var ctype: int = MatchState.config.creature_type if MatchState.config != null else 0
	var color := _creature_color(ctype)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var bm := BoxMesh.new()
	var side := radius * 2.0
	bm.size = Vector3(side, side, side)
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	_viewport.add_child(mi)
	return mi

func _creature_color(ctype: int) -> Color:
	match ctype:
		0:  return Color(0.80, 0.88, 1.00)  # Wraith
		1:  return Color(0.10, 0.75, 0.20)  # Serpent
		2:  return Color(0.50, 0.45, 0.40)  # Golem
		3:  return Color(0.92, 1.00, 1.00)  # Specter
		4:  return Color(0.95, 0.30, 0.05)  # Hellhound
		5:  return Color(0.95, 0.85, 0.10)  # Thunderbird
		6:  return Color(0.10, 0.40, 0.65)  # Wyvern
		7:  return Color(0.30, 0.52, 0.10)  # Basilisk
		8:  return Color(0.60, 0.05, 0.55)  # Demon
		9:  return Color(0.70, 1.00, 0.78)  # Banshee
		10: return Color(0.90, 0.10, 0.90)  # Chaos
	return C_CREATURE

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

# ── Ability charge bar ────────────────────────────────────────────────────────

func _make_ability_bar() -> Array:
	_ability_bar_mat = StandardMaterial3D.new()
	_ability_bar_mat.albedo_color = Color(1.0, 0.87, 0.0)
	_ability_bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var segs: Array = []
	var seg_w := ABILITY_BAR_W / ABILITY_BAR_SEGS
	for _i in ABILITY_BAR_SEGS:
		var bm := BoxMesh.new()
		bm.size = Vector3(seg_w * 0.82, 0.07, 0.07)
		var mi := MeshInstance3D.new()
		mi.mesh              = bm
		mi.material_override = _ability_bar_mat
		mi.visible           = false
		_viewport.add_child(mi)
		segs.append(mi)
	return segs

func _sync_ability_bar(delta: float) -> void:
	if _ability_bar_segs.is_empty():
		return
	if not _ability_charging or _ability_charge_pid.is_empty():
		for seg in _ability_bar_segs: (seg as MeshInstance3D).visible = false
		return

	_ability_charge_elapsed = minf(_ability_charge_elapsed + delta, _ability_charge_max_val)

	var player_node: Node = PlayerLookup.get_node(_ability_charge_pid)
	if player_node == null:
		for seg in _ability_bar_segs: (seg as MeshInstance3D).visible = false
		return

	var p2:  Vector2 = player_node.global_position
	var zh:  float   = float(player_node.get("z_height")) * 0.6
	var th:  float   = _terrain_sample_at(p2)
	var center := Vector3(p2.x, 0.12 + zh + th, -p2.y)

	var pct        := _ability_charge_elapsed / _ability_charge_max_val
	var fill_count := int(ABILITY_BAR_SEGS * pct)
	var lerp_t     := clampf((pct - 0.8) / 0.2, 0.0, 1.0)
	_ability_bar_mat.albedo_color = Color(1.0, lerpf(0.87, 0.0, lerp_t), 0.0)

	var seg_w := ABILITY_BAR_W / ABILITY_BAR_SEGS
	for i in ABILITY_BAR_SEGS:
		var seg := _ability_bar_segs[i] as MeshInstance3D
		if i < fill_count:
			seg.global_position = Vector3(
				center.x - ABILITY_BAR_W * 0.5 + (i + 0.5) * seg_w,
				center.y, center.z)
			seg.visible = true
		else:
			seg.visible = false

func _on_ability_charge_started(player_id: String, _slot: int, charge_max: float) -> void:
	_ability_charging       = true
	_ability_charge_elapsed = 0.0
	_ability_charge_max_val = charge_max
	_ability_charge_pid     = player_id

func _on_ability_charge_released(_pid: String, _slot: int, _t: float) -> void:
	_ability_charging       = false
	_ability_charge_elapsed = 0.0
	_ability_charge_max_val = 0.0
	_ability_charge_pid     = ""

# ── Terrain preview / expiry rings ────────────────────────────────────────────

func _build_terrain_indicators() -> void:
	_terrain_preview_mat = StandardMaterial3D.new()
	_terrain_preview_mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	_terrain_preview_mat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	_terrain_preview_mat.albedo_color  = Color.WHITE
	_terrain_preview_imm  = ImmediateMesh.new()
	_terrain_preview_mesh = MeshInstance3D.new()
	_terrain_preview_mesh.mesh              = _terrain_preview_imm
	_terrain_preview_mesh.material_override = _terrain_preview_mat
	_terrain_preview_mesh.visible           = false
	_viewport.add_child(_terrain_preview_mesh)

	_terrain_expiry_mat = StandardMaterial3D.new()
	_terrain_expiry_mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	_terrain_expiry_mat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	_terrain_expiry_mat.albedo_color  = Color.WHITE
	_terrain_expiry_imm  = ImmediateMesh.new()
	_terrain_expiry_mesh = MeshInstance3D.new()
	_terrain_expiry_mesh.mesh              = _terrain_expiry_imm
	_terrain_expiry_mesh.material_override = _terrain_expiry_mat
	_terrain_expiry_mesh.visible           = false
	_viewport.add_child(_terrain_expiry_mesh)

func _sync_terrain_preview(delta: float) -> void:
	if _preview_timer <= 0.0:
		_terrain_preview_mesh.visible = false
		return
	_preview_timer -= delta
	var p     := 1.0 - _preview_timer / TERRAIN_IND_DUR
	var pulse := sin(p * TAU * 3.0) * 0.5 + 0.5
	_terrain_preview_mat.albedo_color = Color(
		_preview_color.r, _preview_color.g, _preview_color.b, pulse * 0.9)
	_terrain_preview_mesh.visible = true
	_terrain_preview_imm.clear_surfaces()
	_draw_ground_ring(_terrain_preview_imm, _preview_pos, _preview_radius, 0.10)
	_draw_ground_ring(_terrain_preview_imm, _preview_pos, _preview_radius * 0.55, 0.10)

func _sync_terrain_expiry(delta: float) -> void:
	if _expiry_timer <= 0.0:
		_terrain_expiry_mesh.visible = false
		return
	_expiry_timer -= delta
	var p     := 1.0 - _expiry_timer / TERRAIN_IND_DUR
	var pulse := sin(p * TAU * 4.0) * 0.5 + 0.5
	var fade  := lerpf(1.0, 0.0, p)
	_terrain_expiry_mat.albedo_color = Color(
		_expiry_color.r, _expiry_color.g, _expiry_color.b, pulse * fade * 0.85)
	_terrain_expiry_mesh.visible = true
	_terrain_expiry_imm.clear_surfaces()
	_draw_ground_ring(_terrain_expiry_imm, _expiry_pos, _expiry_radius, 0.10)

func _draw_ground_ring(imm: ImmediateMesh, center: Vector3, radius: float, y: float) -> void:
	imm.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in TERRAIN_RING_SEGS:
		var a0 := float(i)       / float(TERRAIN_RING_SEGS) * TAU
		var a1 := float(i + 1)  / float(TERRAIN_RING_SEGS) * TAU
		imm.surface_add_vertex(center + Vector3(sin(a0) * radius, y, cos(a0) * radius))
		imm.surface_add_vertex(center + Vector3(sin(a1) * radius, y, cos(a1) * radius))
	imm.surface_end()

func _on_terrain_preview_started(event_type: String, world_pos: Vector2, radius: float, _intensity: float) -> void:
	_preview_pos    = Vector3(world_pos.x, 0.0, -world_pos.y)
	_preview_radius = radius
	_preview_timer  = TERRAIN_IND_DUR
	_preview_color  = _terrain_color_3d(event_type)

func _on_terrain_expiry_warning(event_type: String, world_pos: Vector2, radius: float) -> void:
	_expiry_pos    = Vector3(world_pos.x, 0.0, -world_pos.y)
	_expiry_radius = radius
	_expiry_timer  = TERRAIN_IND_DUR
	_expiry_color  = _terrain_color_3d(event_type)

func _terrain_color_3d(event_type: String) -> Color:
	match event_type:
		"hill":   return Color(0.35, 0.80, 0.15)
		"valley": return Color(0.30, 0.55, 0.95)
		"pit":    return Color(0.90, 0.15, 0.05)
		"mud":    return Color(0.60, 0.40, 0.10)
		"lava":   return Color(1.00, 0.35, 0.00)
		"ice":    return Color(0.50, 0.90, 1.00)
	return Color(0.80, 0.80, 0.80)

# ── Ability VFX 3D overlay ────────────────────────────────────────────────────
# Reads AbilityVfxLayer._active each frame and renders effects as 3D line geometry.
# Coordinate mapping mirrors the rest of ViewLayer3D: 2D(x,y) → 3D(x, elev, -y).

func _build_vfx_overlay() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode                 = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test              = true
	mat.cull_mode                  = BaseMaterial3D.CULL_DISABLED
	_vfx_imm  = ImmediateMesh.new()
	_vfx_mesh = MeshInstance3D.new()
	_vfx_mesh.mesh              = _vfx_imm
	_vfx_mesh.material_override = mat
	_viewport.add_child(_vfx_mesh)

func _sync_vfx() -> void:
	var vfx_layer := get_parent().get_node_or_null("AbilityVfxLayer")
	_vfx_imm.clear_surfaces()
	if vfx_layer == null or vfx_layer._active.is_empty():
		return
	for v in vfx_layer._active:
		var p: float = float(v.t) / float(v.dur)
		_draw_vfx_3d(v, p)

func _draw_vfx_3d(v: Dictionary, p: float) -> void:
	var c: Vector3 = _p3(v.pos)
	var col: Color = v.color
	match v.type:
		"cast_ring":
			var ep := _eo(p)
			var max_r: float = v.data.get("radius", 1.40)
			_vring(c, lerpf(max_r * 0.35, max_r, ep), _ca(col, lerpf(0.90, 0.0, p)))
		"burst_ring":
			var delay: float = v.data.get("delay", 0.0)
			if v.t < delay: return
			var lp := clampf((float(v.t) - delay) / maxf(v.dur - delay, 0.01), 0.0, 1.0)
			var r: float = v.data.get("radius", 1.0)
			_vring(c, lerpf(r * 0.2, r, _eo(lp)), _ca(col, lerpf(0.80, 0.0, lp * lp)))
		"impact_flash":
			_vring(c, lerpf(0.0, 0.5, _eo(p)), _ca(col, lerpf(0.85, 0.0, p * p)))
		"aoe_burst":
			var radius: float = v.data.get("radius", 2.0)
			_vring(c, lerpf(0.0, radius, _eo(p)), _ca(col, lerpf(0.70, 0.0, p)))
		"hit_spark":
			_vspark(c, lerpf(0.10, 0.65, _eo(p)), _ca(col, lerpf(0.90, 0.0, p * p)), 6)
		"heal_rise":
			var delays: Array  = v.data.get("delays",  [0.0, 0.15, 0.10, 0.22])
			var offsets: Array = v.data.get("offsets", [0.0, -0.15, 0.12, -0.07])
			for i in mini(delays.size(), offsets.size()):
				var dp := clampf((p - float(delays[i])) / (1.0 - float(delays[i])), 0.0, 1.0)
				if dp <= 0.0: continue
				var rise := lerpf(0.0, 0.8, _eo(dp))
				_vdot(c + Vector3(float(offsets[i]), rise, 0), 0.07,
					_ca(col, lerpf(0.80, 0.0, dp * dp)))
		"death_burst":
			_vspark(c, lerpf(0.0, 1.8, _eo(p)), _ca(col, lerpf(1.0, 0.0, p)), 10)
		"ultra_burst":
			var r := lerpf(0.0, 3.0, _eo(p))
			_vring(c, r, _ca(col, lerpf(1.0, 0.0, p)))
			_vspark(c, r * 0.85, _ca(Color.WHITE, lerpf(0.9, 0.0, p)), 12)
		"pickup_pulse":
			_vring(c, lerpf(0.30, 0.90, _eo(p)), _ca(col, lerpf(0.80, 0.0, p)))
		"ff_shatter":
			var radius: float = v.data.get("radius", 5.0)
			_vring(c, lerpf(radius * 0.8, radius * 1.7, _eo(p)), _ca(col, lerpf(1.0, 0.0, p * p)))
		"cc_burst":
			_vring(c, lerpf(0.0, 1.6, _eo(p)), _ca(col, lerpf(0.95, 0.0, p * p)))
		"debuff_splash":
			_vspark(c, lerpf(0.08, 0.85, _eo(p)), _ca(col, lerpf(0.80, 0.0, p * p)), 5)
		"buff_pulse":
			_vring(c, lerpf(0.0, 1.1, _eo(p)), _ca(col, lerpf(0.75, 0.0, p * p)))
		"dash_trail":
			_vring(c, lerpf(0.45, 0.80, p), _ca(col, lerpf(0.65, 0.0, p)))
		"double_ring":
			var max_r: float = v.data.get("radius", 0.85)
			var ip := clampf(p / 0.6, 0.0, 1.0)
			_vring(c, lerpf(0.0, max_r * 0.55, _eo(ip)), _ca(col, lerpf(0.90, 0.0, ip)))
			var op := clampf((p - 0.15) / 0.85, 0.0, 1.0)
			if op > 0.0:
				_vring(c, lerpf(0.0, max_r, _eo(op)), _ca(col, lerpf(0.70, 0.0, op)))
		"petal_bloom":
			var max_r: float = v.data.get("radius", 2.0)
			var count: int   = v.data.get("count", 8)
			_varcs(c, lerpf(0.1, max_r, _eo(p)), count, 0.0,
				TAU / float(count) * 0.52, _ca(col, lerpf(0.85, 0.0, p * p)))
		"compressed_rings":
			var max_r: float = v.data.get("radius", 0.9)
			if p < 0.5:
				var cp := p * 2.0
				_vring(c, lerpf(max_r, 0.0, cp * cp * cp), _ca(col, lerpf(0.70, 0.0, cp)))
			else:
				var bp := (p - 0.5) * 2.0
				_vspark(c, lerpf(0.0, 0.80, _eo(bp)), _ca(col, lerpf(0.90, 0.0, bp * bp)), 4)
		"spiral_cast":
			var r: float = v.data.get("radius", 0.4)
			for i in 6:
				var angle := float(i) / 6.0 * TAU + p * TAU * 1.2
				var mr := lerpf(r * 0.3, r, _eo(p))
				_vdot(c + Vector3(cos(angle) * mr, 0.0, sin(angle) * mr), 0.06,
					_ca(col, lerpf(0.90, 0.0, p)))
		"cross_burst":
			var arm: float = v.data.get("arm_len", 0.5)
			var l := lerpf(0.0, arm, _eo(p))
			var a := lerpf(0.90, 0.0, p * p)
			_vline(c - Vector3(l, 0, 0), c + Vector3(l, 0, 0), _ca(col, a))
			_vline(c - Vector3(0, 0, l), c + Vector3(0, 0, l), _ca(col, a))
		"strike_flash":
			var r: float = v.data.get("radius", 0.5)
			_vring(c, lerpf(0.0, r, _eo(p)), _ca(col, lerpf(0.95, 0.0, p * p * 5.0)))
		"mote_ribbon":
			var from: Vector2  = v.data.get("from", v.pos)
			var to: Vector2    = v.data.get("to",   v.pos)
			var count: int     = v.data.get("count", 5)
			var stagger: float = v.data.get("stagger", 0.08)
			var f3 := _p3(from); var t3 := _p3(to)
			var ctrl := (f3 + t3) * 0.5 + Vector3(0, f3.distance_to(t3) * 0.22, 0)
			for i in count:
				var mp0 := float(i) * stagger
				if p < mp0: continue
				var mp  := clampf((p - mp0) / maxf(1.0 - mp0, 0.01), 0.0, 1.0)
				var ep  := _eo(mp)
				var b0  := f3.lerp(ctrl, ep); var b1 := ctrl.lerp(t3, ep)
				_vdot(b0.lerp(b1, ep), 0.07, _ca(col, lerpf(0.85, 0.0, mp * mp)))
		"strike_line":
			var from: Vector2 = v.data.get("from", v.pos)
			var to: Vector2   = v.data.get("to",   v.pos)
			var lines: int    = v.data.get("lines", 1)
			var a := lerpf(0.90, 0.0, p * p * 6.0)
			for i in lines:
				var off := (float(i) - float(lines - 1) * 0.5) * 0.05
				_vline(_p3(from) + Vector3(off, 0, 0), _p3(to) + Vector3(off, 0, 0), _ca(col, a))
		"disc_projectile":
			var from: Vector2 = v.data.get("from", v.pos)
			var to: Vector2   = v.data.get("to",   v.pos)
			var pos3 := _p3(from).lerp(_p3(to), _eo(p))
			_vring(pos3, 0.30, _ca(col, lerpf(0.55, 0.0, p * p)))
		"ring_projectile":
			var from: Vector2 = v.data.get("from", v.pos)
			var to: Vector2   = v.data.get("to",   v.pos)
			var sr: float = v.data.get("start_radius", 0.80)
			var er: float = v.data.get("end_radius",   0.25)
			_vring(_p3(from).lerp(_p3(to), _eo(p)), lerpf(sr, er, p),
				_ca(col, lerpf(0.75, 0.0, p * p)))
		"shield_collapse":
			var sr: float = v.data.get("start_radius", 1.0)
			var count: int = v.data.get("count", 5)
			_varcs(c, lerpf(sr, 0.0, p * p * p), count, p * 0.5,
				TAU / float(count) * 0.60, _ca(col, lerpf(0.85, 0.0, p)))
		"sustained_pulse":
			var tid: String = v.data.get("target_id", "")
			var pos3 := _p3(PlayerLookup.get_position(tid)) if not tid.is_empty() else c
			var r: float = v.data.get("radius", 0.8)
			var pulse := sin(float(v.t) * 0.5 * TAU) * 0.5 + 0.5
			_vring(pos3, r, _ca(col, pulse * 0.25))
		"rotating_arcs":
			var tid: String = v.data.get("target_id", "")
			var pos3 := _p3(PlayerLookup.get_position(tid)) if not tid.is_empty() else c
			var r: float  = v.data.get("radius", 8.0)
			var cnt: int  = v.data.get("count",  12)
			var spd: float = v.data.get("speed", TAU / 3.0)
			var fade := minf(
				lerpf(0.0, 1.0, p / 0.05),
				lerpf(1.0, 0.0, clampf((p - 0.85) / 0.15, 0.0, 1.0)))
			_varcs(pos3, r, cnt, float(v.t) * spd, TAU / float(cnt) * 0.42,
				_ca(col, 0.55 * fade))
		"bolt_travel":
			var delay: float = v.data.get("delay", 0.0)
			if v.t < delay: return
			var lp := clampf((float(v.t) - delay) / 0.22, 0.0, 1.0)
			var from: Vector2 = v.data.get("from", v.pos)
			var to: Vector2   = v.data.get("to",   v.pos)
			# Bolt ribbon
			var ba       := 1.0 - maxf(0.0, (lp - 0.75) / 0.25)
			var zap_seed := Time.get_ticks_msec()
			_vzap_bolt(_p3(from), _p3(to), _ca(col,         ba * 0.90), zap_seed, 12.0)
			_vzap_bolt(_p3(from), _p3(to), _ca(Color.WHITE,  ba * 0.75), zap_seed,  4.0)
		"bolt_impact":
			var delay: float = v.data.get("delay", 0.0)
			if v.t < delay: return
			var lp := clampf((float(v.t) - delay) / 0.40, 0.0, 1.0)
			var bi_ep := _eo(lp)
			_vring(c, lerpf(0.0, 5.5, bi_ep), _ca(col, lerpf(0.85, 0.0, lp)))
			_vring(c, lerpf(0.0, 3.0, _eo(minf(lp * 0.7, 1.0))), _ca(Color(1, 1, 1), lerpf(0.55, 0.0, lp)))
			_vspark(c, lerpf(0.0, 3.5, bi_ep), _ca(col, lerpf(0.90, 0.0, lp)), 12)
		"lightning_discharge":
			var ld_r  : float   = v.data.get("radius", 5.0)
			var ld_d2 : Vector2 = v.data.get("dir", Vector2.ZERO)
			var ld_ep := _eo(p)
			_vring(c, lerpf(0.0, ld_r, ld_ep), _ca(col, lerpf(0.90, 0.0, p * p)))
			_vring(c, lerpf(0.0, ld_r * 0.6, _eo(minf(p * 1.5, 1.0))),
				_ca(Color(1, 1, 1), lerpf(0.60, 0.0, p)))
			if ld_d2.length_squared() > 0.01:
				var la := lerpf(0.95, 0.0, p * p * 3.0)
				for i in 4:
					var ld_fan := ld_d2.rotated((float(i) - 1.5) * 0.25)
					var ld_d3  := Vector3(ld_fan.x, 0.0, -ld_fan.y)
					var b3 := c + ld_d3 * lerpf(0.1, 0.3, ld_ep)
					var t3 := c + ld_d3 * lerpf(0.3, ld_r * 1.05, ld_ep)
					_vline(b3, t3, _ca(col, la))
		"chain_burst":
			var cb_r  : float = v.data.get("radius", 6.5)
			var cb_ep := _eo(p)
			_vring(c, lerpf(0.0, cb_r, cb_ep), _ca(col, lerpf(0.90, 0.0, p * p)))
			_vring(c, lerpf(0.0, cb_r * 0.5, _eo(minf(p * 1.4, 1.0))),
				_ca(Color(1, 1, 1), lerpf(0.70, 0.0, p)))
			var sa := lerpf(0.95, 0.0, p * p * 2.5)
			for i in 8:
				var cb_ang := float(i) * TAU / 8.0 + p * 0.3
				var cb_d3  := Vector3(cos(cb_ang), 0.0, sin(cb_ang))
				var b3 := c + cb_d3 * lerpf(0.1, 0.35, cb_ep)
				var t3 := c + cb_d3 * lerpf(0.35, cb_r * 1.1, cb_ep)
				_vline(b3, t3, _ca(col, sa))
		"heal_spiral_cast":
			# Sparks scatter and rise straight upward
			for i in 16:
				var phase := float(i) / 16.0 * 0.45
				var dp := clampf((p - phase) / maxf(1.0 - phase, 0.01), 0.0, 1.0)
				if dp <= 0.0: continue
				var ep := _eo(dp)
				var ga := float(i) * 2.399963
				var sr := sqrt(float(i + 1) / 16.0) * 1.75
				var rise := lerpf(0.0, 12.0, ep)
				var spark_len := lerpf(2.8, 0.5, dp)
				var base3 := c + Vector3(cos(ga) * sr, rise, sin(ga) * sr)
				_vline(base3, base3 + Vector3(0.0, spark_len, 0.0),
					_ca(Color(0.45, 1.0, 0.30), lerpf(0.92, 0.0, dp * dp)))
		"heal_spiral_travel":
			# Sparks arc parabolically from caster to target, peaking high
			var hst_from: Vector2 = v.data.get("from", v.pos)
			var hst_to: Vector2   = v.data.get("to",   v.pos)
			var hst_f3 := _p3(hst_from); var hst_t3 := _p3(hst_to)
			var hst_dist := hst_f3.distance_to(hst_t3)
			var arc_h3 := minf(hst_dist * 0.55, 12.0)
			for i in 14:
				var phase := float(i) / 14.0 * 0.60
				var dp := clampf((p - phase) / maxf(1.0 - phase, 0.01), 0.0, 1.0)
				if dp <= 0.0: continue
				var t3 := clampf(phase * 0.35 + dp * 0.75, 0.0, 1.0)
				var pos3 := hst_f3.lerp(hst_t3, t3)
				# Arc rises then descends in Y
				pos3.y += arc_h3 * 4.0 * t3 * (1.0 - t3)
				_vdot(pos3, lerpf(0.5, 0.2, dp),
					_ca(Color(0.30, 1.0, 0.25), lerpf(0.88, 0.0, dp * dp)))
		"blue_cloud_cast":
			for i in 14:
				var phase := float(i) / 14.0 * 0.08
				var dp := clampf((p - phase) / maxf(1.0 - phase, 0.01), 0.0, 1.0)
				if dp <= 0.0: continue
				var angle := float(i) / 14.0 * TAU + dp * 0.5
				var r := lerpf(0.5, 7.5, _eo(dp))
				_vdot(c + Vector3(cos(angle) * r, lerpf(0.0, 2.8, _eo(dp)), sin(angle) * r),
					lerpf(0.8, 0.3, dp), _ca(Color(0.30, 0.65, 1.0), lerpf(0.85, 0.0, dp)))
		"blue_cloud_travel":
			var bct_from: Vector2 = v.data.get("from", v.pos)
			var bct_to: Vector2   = v.data.get("to",   v.pos)
			var bct_f3 := _p3(bct_from); var bct_t3 := _p3(bct_to)
			for i in 14:
				var phase := float(i) / 14.0 * 0.6
				var dp := clampf((p - phase) / maxf(1.0 - phase, 0.01), 0.0, 1.0)
				if dp <= 0.0: continue
				var travel_t := clampf(float(i) / 14.0 * 0.4 + dp * 0.65, 0.0, 1.0)
				var pos3 := bct_f3.lerp(bct_t3, travel_t)
				var wave := sin(float(i) * 2.1 + p * TAU * 2.0) * 2.2
				pos3 += Vector3(wave, 0.0, 0.0)
				_vdot(pos3, lerpf(0.8, 0.4, dp),
					_ca(Color(0.30, 0.65, 1.0), lerpf(0.80, 0.0, dp * dp)))
		"blue_cloud_impact":
			for i in 14:
				var phase := float(i) / 14.0 * 0.15
				var dp := clampf((p - phase) / maxf(1.0 - phase, 0.01), 0.0, 1.0)
				if dp <= 0.0: continue
				var angle := float(i) / 14.0 * TAU + p * TAU * 1.5
				var r := lerpf(7.2, 3.0, dp)
				_vdot(c + Vector3(cos(angle) * r, lerpf(0.0, 5.5, dp * dp), sin(angle) * r),
					lerpf(0.7, 0.2, dp), _ca(Color(0.30, 0.65, 1.0), lerpf(0.85, 0.0, dp * dp)))
		"hot_sparkle":
			for i in 6:
				var phase := float(i) / 6.0 * 0.35
				var dp := clampf((p - phase) / maxf(1.0 - phase, 0.01), 0.0, 1.0)
				if dp <= 0.0: continue
				var ep2 := _eo(dp)
				var ga := float(i) * 2.399963
				var sr := sqrt(float(i + 1) / 6.0) * 0.7
				var fall := lerpf(12.0, 0.0, ep2)
				var spark_len := lerpf(2.8, 0.5, dp)
				var base3 := c + Vector3(cos(ga) * sr, fall, sin(ga) * sr)
				_vline(base3, base3 + Vector3(0.0, -spark_len, 0.0),
					_ca(Color(0.30, 1.0, 0.25), lerpf(0.90, 0.0, dp * dp)))

# ── VFX primitive helpers (all use _vfx_imm) ──────────────────────────────────

func _p3(pos2d: Vector2, y: float = 0.15) -> Vector3:
	return Vector3(pos2d.x, y, -pos2d.y)

func _eo(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

func _ca(col: Color, alpha: float) -> Color:
	return Color(col.r, col.g, col.b, clampf(alpha, 0.0, 1.0))

func _vring(center: Vector3, radius: float, color: Color, segs: int = 24) -> void:
	if radius < 0.01: return
	_vfx_imm.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in segs:
		var a0 := float(i)     / float(segs) * TAU
		var a1 := float(i + 1) / float(segs) * TAU
		_vfx_imm.surface_set_color(color)
		_vfx_imm.surface_add_vertex(center + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius))
		_vfx_imm.surface_set_color(color)
		_vfx_imm.surface_add_vertex(center + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius))
	_vfx_imm.surface_end()

func _varcs(center: Vector3, radius: float, count: int, rot: float, span: float,
		color: Color, segs: int = 8) -> void:
	if radius < 0.01: return
	_vfx_imm.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in count:
		var base := float(i) / float(count) * TAU + rot
		for j in segs:
			var a0 := base + float(j)     / float(segs) * span
			var a1 := base + float(j + 1) / float(segs) * span
			_vfx_imm.surface_set_color(color)
			_vfx_imm.surface_add_vertex(center + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius))
			_vfx_imm.surface_set_color(color)
			_vfx_imm.surface_add_vertex(center + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius))
	_vfx_imm.surface_end()

func _vdot(pos: Vector3, size: float, color: Color) -> void:
	_vfx_imm.surface_begin(Mesh.PRIMITIVE_LINES)
	_vfx_imm.surface_set_color(color)
	_vfx_imm.surface_add_vertex(pos + Vector3(-size, 0,     0))
	_vfx_imm.surface_set_color(color)
	_vfx_imm.surface_add_vertex(pos + Vector3( size, 0,     0))
	_vfx_imm.surface_set_color(color)
	_vfx_imm.surface_add_vertex(pos + Vector3(0,     0, -size))
	_vfx_imm.surface_set_color(color)
	_vfx_imm.surface_add_vertex(pos + Vector3(0,     0,  size))
	_vfx_imm.surface_end()

## Zigzag lightning bolt rendered as a vertical ribbon — panels stand upright
## from the ground so they're visible from any overhead camera angle.
## bolt_h controls how tall (metres) each panel rises above its base point.
func _vzap_bolt(from3: Vector3, to3: Vector3, col: Color, seed: int,
		bolt_h: float = 8.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	# Midpoint displacement in XZ — 3 levels → 9 points, 8 segments.
	var pts: Array = [from3, to3]
	var disp := from3.distance_to(to3) * 0.32

	for _lvl in 3:
		var next: Array = [pts[0]]
		for i in range(pts.size() - 1):
			var p0: Vector3 = pts[i]
			var p1: Vector3 = pts[i + 1]
			var mid := (p0 + p1) * 0.5
			var seg_xz := Vector2(p1.x - p0.x, p1.z - p0.z)
			var perp_xz := Vector2(-seg_xz.y, seg_xz.x).normalized()
			var kick := (rng.randf() - 0.5) * 2.0 * disp
			next.append(mid + Vector3(perp_xz.x * kick, 0.0, perp_xz.y * kick))
			next.append(p1)
		pts  = next
		disp *= 0.5

	# Vertical ribbon: each quad rises from the ground point up by bolt_h metres.
	# Visible from any overhead angle because it faces upward.
	var n := pts.size()
	_vfx_imm.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(n - 1):
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		# Taper: kink points flare the height; tip shrinks to 25%.
		var t0 := float(i)     / float(n - 1)
		var t1 := float(i + 1) / float(n - 1)
		var h0 := bolt_h * lerpf(1.0, 0.25, t0)
		var h1 := bolt_h * lerpf(1.0, 0.25, t1)
		if i > 0:
			var pp: Vector3 = pts[i - 1]
			var kink := maxf(0.0, 1.0 - (p0 - pp).normalized().dot((p1 - p0).normalized()))
			h0 *= (1.0 + kink * 2.0)
		if i < n - 2:
			var pn: Vector3 = pts[i + 2]
			var kink := maxf(0.0, 1.0 - (p1 - p0).normalized().dot((pn - p1).normalized()))
			h1 *= (1.0 + kink * 2.0)
		var p0b := p0
		var p0t := p0 + Vector3(0.0, h0, 0.0)
		var p1b := p1
		var p1t := p1 + Vector3(0.0, h1, 0.0)
		_vfx_imm.surface_set_color(col); _vfx_imm.surface_add_vertex(p0b)
		_vfx_imm.surface_set_color(col); _vfx_imm.surface_add_vertex(p0t)
		_vfx_imm.surface_set_color(col); _vfx_imm.surface_add_vertex(p1b)
		_vfx_imm.surface_set_color(col); _vfx_imm.surface_add_vertex(p0t)
		_vfx_imm.surface_set_color(col); _vfx_imm.surface_add_vertex(p1t)
		_vfx_imm.surface_set_color(col); _vfx_imm.surface_add_vertex(p1b)
	_vfx_imm.surface_end()

func _vline(from: Vector3, to: Vector3, color: Color) -> void:
	_vfx_imm.surface_begin(Mesh.PRIMITIVE_LINES)
	_vfx_imm.surface_set_color(color)
	_vfx_imm.surface_add_vertex(from)
	_vfx_imm.surface_set_color(color)
	_vfx_imm.surface_add_vertex(to)
	_vfx_imm.surface_end()

func _vspark(center: Vector3, radius: float, color: Color, count: int) -> void:
	if radius < 0.01: return
	_vfx_imm.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in count:
		var angle := float(i) / float(count) * TAU
		_vfx_imm.surface_set_color(color)
		_vfx_imm.surface_add_vertex(center)
		_vfx_imm.surface_set_color(color)
		_vfx_imm.surface_add_vertex(center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	_vfx_imm.surface_end()
