class_name MatchReplayPlayer
extends Control

## 3D terrain-based match replay. Two cloth-like meshes rise and deform based
## on accumulated possession, phase crossings, and scoring events. Seam between
## the meshes shifts with the ball. Pattern mirrors ViewLayer3D.
## Call setup(report) with a MatchReportSaver Dictionary to initialise.

# ── Palette ───────────────────────────────────────────────────────────────────
const C_HOME  := Color(1.000, 0.231, 0.325)
const C_AWAY  := Color(0.184, 0.514, 1.000)
const C_BALL  := Color(1.000, 0.820, 0.100)
const C_SKY   := Color(0.016, 0.022, 0.047)
const C_GOLD  := Color(1.000, 0.796, 0.239)

# ── World / grid ──────────────────────────────────────────────────────────────
const FW        := 140.0
const FH        :=  40.0
const GRID_NX   :=  28        # columns (5 world-units each)
const GRID_NY   :=   8        # rows    (5 world-units each)
const VERT_NX   := GRID_NX + 1
const VERT_NY   := GRID_NY + 1
const CELL_W    := FW / float(GRID_NX)
const CELL_H    := FH / float(GRID_NY)

# ── Height / threat ───────────────────────────────────────────────────────────
const HEIGHT_SCALE    := 10.0   # world-units of maximum terrain lift
const BALL_ACCUM      := 0.35   # threat per ball_path sample in a cell
const CROSSING_BOOST  := 1.20   # threat per phase_crossing event
const SCORE_PERM      := 3.00   # permanent threat added per goal in endzone cols
const PULSE_PEAK      := 14.0   # initial surge height on goal (world-units, pre-scale)
const PULSE_DECAY     := 3.50   # surge decay per second

# ── Dramatic-time ─────────────────────────────────────────────────────────────
const PACE_NORMAL  := 0.30
const PACE_SCORE   := 3.50
const SCORE_WINDOW := 6.0
const DT_STEP      := 0.20

# ── Serialised data ───────────────────────────────────────────────────────────
var _report:         Dictionary = {}
var _match_duration: float      = 60.0
var _ball_path:      Array      = []   # [{tick, pos:V2, holder_team, charge_norm}]
var _score_events:   Array      = []   # [{tick, team_id, type}] sorted by tick
var _act_boundaries: Array      = []

# ── Dramatic-time map ─────────────────────────────────────────────────────────
var _dt_match:        PackedFloat32Array
var _dt_display:      PackedFloat32Array
var _display_duration: float = 1.0

# ── Playback ──────────────────────────────────────────────────────────────────
var _display_time: float = 0.0
var _match_time:   float = 0.0
var _playing:      bool  = true
var _speed:        float = 1.0
var _scrubbing:    bool  = false

# ── World state ───────────────────────────────────────────────────────────────
var _ball_pos:     Vector2 = Vector2(FW * 0.5, FH * 0.5)
var _seam_norm:    float   = 0.5
var _seam_target:  float   = 0.5
var _home_score:   int     = 0
var _away_score:   int     = 0

# ── Terrain grids ─────────────────────────────────────────────────────────────
var _threat:      PackedFloat32Array   # accumulated, persistent
var _pulse:       PackedFloat32Array   # goal surge, decays each frame
var _smooth:      PackedFloat32Array   # blurred for mesh heights
var _max_threat:  float = 1.0
var _accum_mt:    float = -1.0         # match-time up to which _threat is valid
var _prev_pulse_mt: float = -1.0       # for detecting new scores during playback
var _mesh_dirty:  bool  = true

# ── Momentum strip ────────────────────────────────────────────────────────────
var _momentum: PackedFloat32Array

# ── 3D scene refs ─────────────────────────────────────────────────────────────
var _viewport:    SubViewport    = null
var _camera:      Camera3D       = null
var _terrain_mi:  MeshInstance3D = null
var _ball_mi:     MeshInstance3D = null

# ── UI refs ────────────────────────────────────────────────────────────────────
var _play_btn:  Button  = null
var _speed_lbl: Label   = null
var _scrub:     HSlider = null
var _time_lbl:  Label   = null
var _home_lbl:  Label   = null
var _away_lbl:  Label   = null
var _strip:     Control = null   # momentum strip child

# ─────────────────────────────────────────────────────────────────────────────
# Public
# ─────────────────────────────────────────────────────────────────────────────

func setup(report: Dictionary) -> void:
	_report = report
	_load_data()
	_build_dramatic_time()
	_build_momentum()
	_init_grids()
	_build_viewport()
	_build_ui()
	_display_time  = 0.0
	_match_time    = 0.0
	_playing       = true
	_seam_norm     = 0.5
	_accum_mt      = -1.0
	_prev_pulse_mt = -1.0
	set_process(true)

# ─────────────────────────────────────────────────────────────────────────────
# Data loading
# ─────────────────────────────────────────────────────────────────────────────

func _load_data() -> void:
	_ball_path.clear()
	for b in _report.get("ball_path", []):
		_ball_path.append({
			"tick":        float(b["tick"]),
			"pos":         Vector2(float(b["x"]), float(b["y"])),
			"holder_team": int(b["holder_team"]),
		})

	_score_events.clear()
	for sp in _report.get("score_points", []):
		_score_events.append({
			"tick":    float(sp["tick"]),
			"team_id": int(sp["team_id"]),
			"type":    str(sp["type"]),
		})
	_score_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["tick"]) < float(b["tick"]))

	_act_boundaries.clear()
	var t: float = 0.0
	for s in _report.get("act_summaries", []):
		t += float(s["duration"])
		_act_boundaries.append(t)
	_match_duration = maxf(60.0, t)

func _build_dramatic_time() -> void:
	var n: int = int(_match_duration / DT_STEP) + 2
	_dt_match   = PackedFloat32Array(); _dt_match.resize(n)
	_dt_display = PackedFloat32Array(); _dt_display.resize(n)
	var cum: float = 0.0
	for i in n:
		var mt: float = i * DT_STEP
		_dt_match[i]   = mt
		_dt_display[i] = cum
		var pace: float = PACE_NORMAL
		for ev in _score_events:
			var d: float = absf(mt - float(ev["tick"]))
			if d < SCORE_WINDOW:
				var blend: float = 1.0 - d / SCORE_WINDOW
				pace = maxf(pace, lerpf(PACE_NORMAL, PACE_SCORE, blend * blend))
		cum += DT_STEP * pace
	_display_duration = cum

func _build_momentum() -> void:
	var n: int = int(_match_duration) + 2
	_momentum = PackedFloat32Array(); _momentum.resize(n)
	for i in n:
		_momentum[i] = _interp_holder(float(i))

func _interp_holder(mt: float) -> float:
	if _ball_path.size() < 2: return 0.0
	var lo: int = 0; var hi: int = _ball_path.size() - 1
	while lo < hi - 1:
		var mid: int = (lo + hi) / 2
		if float(_ball_path[mid]["tick"]) <= mt: lo = mid
		else: hi = mid
	var dl: float = absf(mt - float(_ball_path[lo]["tick"]))
	var dh: float = absf(mt - float(_ball_path[hi]["tick"]))
	var ht: int   = int(_ball_path[lo]["holder_team"]) if dl <= dh else int(_ball_path[hi]["holder_team"])
	if ht == 0: return  1.0
	if ht == 1: return -1.0
	return 0.0

func _init_grids() -> void:
	var sz: int = GRID_NX * GRID_NY
	_threat = PackedFloat32Array(); _threat.resize(sz)
	_pulse  = PackedFloat32Array(); _pulse.resize(sz)
	_smooth = PackedFloat32Array(); _smooth.resize(sz)

# ─────────────────────────────────────────────────────────────────────────────
# 3D scene
# ─────────────────────────────────────────────────────────────────────────────

func _build_viewport() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.offset_bottom = -102.0   # momentum strip + control bar
	add_child(container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 520)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	container.add_child(_viewport)

	# Lighting & environment
	var env := Environment.new()
	env.background_mode      = Environment.BG_COLOR
	env.background_color     = C_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.30, 0.38, 0.55)
	env.ambient_light_energy = 0.60
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy     = 1.45
	sun.light_color      = Color(1.0, 0.95, 0.85)
	_viewport.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, -125, 0)
	fill.light_energy     = 0.35
	fill.light_color      = Color(0.50, 0.62, 0.95)
	_viewport.add_child(fill)

	# Camera: oblique 3/4 view, elevated front-centre
	_camera = Camera3D.new()
	_camera.fov  = 60.0
	_camera.near = 0.5
	_camera.far  = 500.0
	_camera.global_position = Vector3(70.0, 42.0, 72.0)
	_camera.look_at(Vector3(70.0, 3.0, -20.0))
	_viewport.add_child(_camera)

	# Terrain mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.82
	mat.metallic  = 0.05
	_terrain_mi = MeshInstance3D.new()
	_terrain_mi.material_override = mat
	_viewport.add_child(_terrain_mi)

	# Ball sphere
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = C_BALL
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.emission_enabled = true
	bmat.emission = C_BALL
	bmat.emission_energy_multiplier = 0.6
	var bm := SphereMesh.new()
	bm.radius = 1.20
	bm.height = 2.40
	_ball_mi = MeshInstance3D.new()
	_ball_mi.mesh = bm
	_ball_mi.material_override = bmat
	_viewport.add_child(_ball_mi)

# ─────────────────────────────────────────────────────────────────────────────
# UI
# ─────────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Score labels overlaid at top of viewport area
	_home_lbl = Label.new()
	_home_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_home_lbl.position = Vector2(10, 8)
	_home_lbl.add_theme_color_override("font_color", C_HOME)
	_home_lbl.add_theme_font_size_override("font_size", 15)
	add_child(_home_lbl)

	_away_lbl = Label.new()
	_away_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_away_lbl.anchor_left  = 1.0
	_away_lbl.anchor_right = 1.0
	_away_lbl.offset_left  = -200.0
	_away_lbl.position.y   = 8.0
	_away_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_away_lbl.add_theme_color_override("font_color", C_AWAY)
	_away_lbl.add_theme_font_size_override("font_size", 15)
	add_child(_away_lbl)

	_update_score_labels()

	# Momentum strip (positioned above control bar)
	_strip = Control.new()
	_strip.anchor_top    = 1.0
	_strip.anchor_bottom = 1.0
	_strip.anchor_left   = 0.0
	_strip.anchor_right  = 1.0
	_strip.offset_top    = -102.0
	_strip.offset_bottom =  -36.0
	add_child(_strip)
	_strip.draw.connect(func() -> void: _draw_momentum_on(_strip))

	# Control bar
	var bar := HBoxContainer.new()
	bar.anchor_top    = 1.0
	bar.anchor_bottom = 1.0
	bar.anchor_left   = 0.0
	bar.anchor_right  = 1.0
	bar.offset_top    = -34.0
	bar.offset_bottom = -2.0
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)

	_play_btn = Button.new()
	_play_btn.text = "⏸"
	_play_btn.custom_minimum_size = Vector2(34, 28)
	_play_btn.pressed.connect(_toggle_play)
	bar.add_child(_play_btn)

	var slower := Button.new()
	slower.text = "−"; slower.custom_minimum_size = Vector2(26, 28)
	slower.pressed.connect(_decrease_speed)
	bar.add_child(slower)

	_speed_lbl = Label.new()
	_speed_lbl.text = "1×"
	_speed_lbl.custom_minimum_size = Vector2(30, 0)
	_speed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(_speed_lbl)

	var faster := Button.new()
	faster.text = "+"; faster.custom_minimum_size = Vector2(26, 28)
	faster.pressed.connect(_increase_speed)
	bar.add_child(faster)

	_scrub = HSlider.new()
	_scrub.min_value = 0.0; _scrub.max_value = 1.0; _scrub.step = 0.001
	_scrub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scrub.value_changed.connect(_on_scrub)
	_scrub.drag_started.connect(func() -> void: _scrubbing = true)
	_scrub.drag_ended.connect(func(_c: bool) -> void: _scrubbing = false)
	bar.add_child(_scrub)

	_time_lbl = Label.new()
	_time_lbl.text = "0:00"
	_time_lbl.custom_minimum_size = Vector2(40, 0)
	bar.add_child(_time_lbl)

func _update_score_labels() -> void:
	var hn: String = _report.get("home_team_name", "HOME")
	var an: String = _report.get("away_team_name", "AWAY")
	if is_instance_valid(_home_lbl):
		_home_lbl.text = "%s  %d" % [hn, _home_score]
	if is_instance_valid(_away_lbl):
		_away_lbl.text = "%d  %s" % [_away_score, an]

# ─────────────────────────────────────────────────────────────────────────────
# Process
# ─────────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _playing and not _scrubbing:
		_display_time = minf(_display_time + delta * _speed, _display_duration)
		if _display_time >= _display_duration:
			_playing = false
			if is_instance_valid(_play_btn): _play_btn.text = "▶"

	_match_time = _display_to_match(_display_time)
	_update_world(_match_time, delta)

	if _mesh_dirty:
		_rebuild_terrain()

	if is_instance_valid(_scrub) and not _scrubbing:
		_scrub.set_value_no_signal(_display_time / maxf(1.0, _display_duration))
	if is_instance_valid(_time_lbl):
		_time_lbl.text = "%d:%02d" % [int(_match_time) / 60, int(_match_time) % 60]

	if is_instance_valid(_strip):
		_strip.queue_redraw()

func _display_to_match(dt: float) -> float:
	var sz: int = _dt_display.size()
	if sz < 2: return dt
	var lo: int = 0; var hi: int = sz - 1
	while lo < hi - 1:
		var mid: int = (lo + hi) / 2
		if _dt_display[mid] <= dt: lo = mid
		else: hi = mid
	var span: float = _dt_display[hi] - _dt_display[lo]
	var f: float = 0.0 if span <= 0.0 else clampf((dt - _dt_display[lo]) / span, 0.0, 1.0)
	return lerpf(_dt_match[lo], _dt_match[hi], f)

# ─────────────────────────────────────────────────────────────────────────────
# World state
# ─────────────────────────────────────────────────────────────────────────────

func _update_world(mt: float, delta: float) -> void:
	# Ball position
	if _ball_path.size() >= 2:
		var lo: int = 0; var hi: int = _ball_path.size() - 1
		while lo < hi - 1:
			var mid: int = (lo + hi) / 2
			if float(_ball_path[mid]["tick"]) <= mt: lo = mid
			else: hi = mid
		var t0: float = float(_ball_path[lo]["tick"])
		var t1: float = float(_ball_path[hi]["tick"])
		var span: float = t1 - t0
		var f: float = 0.0 if span <= 0.0 else clampf((mt - t0) / span, 0.0, 1.0)
		var p0: Vector2 = _ball_path[lo]["pos"]
		var p1: Vector2 = _ball_path[hi]["pos"]
		_ball_pos = p0.lerp(p1, f)

	# Seam tracks ball X
	_seam_target = clampf(_ball_pos.x / FW, 0.0, 1.0)
	var sm: float = clampf(1.0 - exp(-delta * 4.0), 0.0, 1.0)
	_seam_norm = lerpf(_seam_norm, _seam_target, sm)

	# Accumulate threat from events newly in time range
	var dirty: bool = _accumulate_to(mt)

	# Score pulses (only during forward playback, not while scrubbing)
	if not _scrubbing:
		for ev in _score_events:
			var t: float = float(ev["tick"])
			if t > mt: break
			if t > _prev_pulse_mt:
				var endzone_x: float = 130.0 if int(ev["team_id"]) == 0 else 10.0
				var gc: int = clampi(int(endzone_x / CELL_W), 0, GRID_NX - 1)
				for gr in GRID_NY:
					_pulse[gr * GRID_NX + gc] = maxf(_pulse[gr * GRID_NX + gc], PULSE_PEAK)
				dirty = true
		_prev_pulse_mt = mt
		for i in _pulse.size():
			if _pulse[i] > 0.01:
				_pulse[i] = maxf(0.0, _pulse[i] - delta * PULSE_DECAY)
				dirty = true
	else:
		for i in _pulse.size():
			if _pulse[i] > 0.0: _pulse[i] = 0.0
		_prev_pulse_mt = mt

	# Score counts
	_home_score = 0; _away_score = 0
	for ev in _score_events:
		if float(ev["tick"]) <= mt:
			if int(ev["team_id"]) == 0: _home_score += 1
			else: _away_score += 1
	_update_score_labels()

	if dirty or absf(_seam_norm - _seam_target) > 0.005:
		_mesh_dirty = true

	# Ball 3D elevation: sits on the terrain surface
	if is_instance_valid(_ball_mi):
		var gc: int = clampi(int(_ball_pos.x / CELL_W), 0, GRID_NX - 1)
		var gr: int = clampi(int(_ball_pos.y / CELL_H), 0, GRID_NY - 1)
		var bh: float = _sample_height(gc, gr) * HEIGHT_SCALE + 1.4
		_ball_mi.global_position = Vector3(_ball_pos.x, bh, -_ball_pos.y)

func _accumulate_to(mt: float) -> bool:
	var dirty := false

	if mt < _accum_mt - 0.5:
		# Scrubbed backward — reset and reaccumulate
		_threat.fill(0.0)
		_max_threat = 1.0
		_accum_mt = -1.0

	# Ball path samples
	for bs in _ball_path:
		var t: float = float(bs["tick"])
		if t <= _accum_mt: continue
		if t > mt: break
		var pos: Vector2 = bs["pos"]
		var gc: int = clampi(int(float(pos.x) / CELL_W), 0, GRID_NX - 1)
		var gr: int = clampi(int(float(pos.y) / CELL_H), 0, GRID_NY - 1)
		var idx: int = gr * GRID_NX + gc
		_threat[idx] += BALL_ACCUM
		if _threat[idx] > _max_threat: _max_threat = _threat[idx]
		dirty = true

	# Phase crossings
	var crossings: Array = _report.get("phase_crossings", [])
	for cx in crossings:
		var t: float = float(cx["tick"])
		if t <= _accum_mt: continue
		if t > mt: break
		var gx: float = float(cx.get("x", 70.0))
		var gy: float = float(cx.get("y", 20.0))
		var gc: int = clampi(int(gx / CELL_W), 0, GRID_NX - 1)
		var gr: int = clampi(int(gy / CELL_H), 0, GRID_NY - 1)
		var idx: int = gr * GRID_NX + gc
		_threat[idx] += CROSSING_BOOST
		if _threat[idx] > _max_threat: _max_threat = _threat[idx]
		dirty = true

	# Scores → permanent endzone elevation
	for ev in _score_events:
		var t: float = float(ev["tick"])
		if t <= _accum_mt: continue
		if t > mt: break
		var endzone_x: float = 130.0 if int(ev["team_id"]) == 0 else 10.0
		var gc: int = clampi(int(endzone_x / CELL_W), 0, GRID_NX - 1)
		for gr in GRID_NY:
			var idx: int = gr * GRID_NX + gc
			_threat[idx] += SCORE_PERM
			if _threat[idx] > _max_threat: _max_threat = _threat[idx]
		dirty = true

	_accum_mt = mt
	return dirty

# ─────────────────────────────────────────────────────────────────────────────
# Terrain mesh
# ─────────────────────────────────────────────────────────────────────────────

func _rebuild_terrain() -> void:
	if not is_instance_valid(_terrain_mi): return
	_apply_gaussian_blur()

	var verts:   PackedVector3Array = PackedVector3Array()
	var colors:  PackedColorArray   = PackedColorArray()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array   = PackedInt32Array()
	verts.resize(VERT_NX * VERT_NY)
	colors.resize(VERT_NX * VERT_NY)
	normals.resize(VERT_NX * VERT_NY)

	# Fill vertex positions and colours
	for row in VERT_NY:
		for col in VERT_NX:
			var vi: int   = row * VERT_NX + col
			var wx: float = float(col) * CELL_W
			var wy: float = float(row) * CELL_H
			var h:  float = _sample_height(col, row) * HEIGHT_SCALE
			verts[vi]  = Vector3(wx, h, -wy)
			colors[vi] = _vertex_color(float(col))

	# Compute smooth normals from cross-product of neighbours
	for row in VERT_NY:
		for col in VERT_NX:
			var vi: int     = row * VERT_NX + col
			var left:  Vector3 = verts[vi - 1]       if col > 0           else verts[vi]
			var right: Vector3 = verts[vi + 1]       if col < VERT_NX - 1 else verts[vi]
			var up:    Vector3 = verts[vi - VERT_NX] if row > 0           else verts[vi]
			var down:  Vector3 = verts[vi + VERT_NX] if row < VERT_NY - 1 else verts[vi]
			var tang: Vector3  = right - left
			var btan: Vector3  = down  - up
			var n: Vector3     = tang.cross(btan)
			normals[vi] = n.normalized() if n.length_squared() > 0.0001 else Vector3.UP

	# Triangle indices for GRID_NX × GRID_NY quads
	for row in GRID_NY:
		for col in GRID_NX:
			var tl: int = row * VERT_NX + col
			var tr: int = tl + 1
			var bl: int = tl + VERT_NX
			var br: int = bl + 1
			indices.append(tl); indices.append(bl); indices.append(tr)
			indices.append(tr); indices.append(bl); indices.append(br)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR]  = colors
	arrays[Mesh.ARRAY_INDEX]  = indices

	var arr_mesh := ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_terrain_mi.mesh = arr_mesh
	_mesh_dirty = false

func _apply_gaussian_blur() -> void:
	# Start from threat + pulse
	for i in _smooth.size():
		_smooth[i] = _threat[i] + _pulse[i]
	# Two passes of 3×3 box blur
	for _pass in 2:
		var tmp: PackedFloat32Array = _smooth.duplicate()
		for row in GRID_NY:
			for col in GRID_NX:
				var sum: float = 0.0; var cnt: float = 0.0
				for dr in range(-1, 2):
					for dc in range(-1, 2):
						var r2: int = row + dr; var c2: int = col + dc
						if r2 >= 0 and r2 < GRID_NY and c2 >= 0 and c2 < GRID_NX:
							sum += tmp[r2 * GRID_NX + c2]; cnt += 1.0
				_smooth[row * GRID_NX + col] = sum / cnt

func _sample_height(col: int, row: int) -> float:
	var gc: int = clampi(col, 0, GRID_NX - 1)
	var gr: int = clampi(row, 0, GRID_NY - 1)
	var raw: float = _smooth[gr * GRID_NX + gc]
	# Normalise: threat ≥ 4.0 reaches full height; scale softly
	return clampf(raw / maxf(4.0, _max_threat * 0.6), 0.0, 1.0)

func _vertex_color(col_f: float) -> Color:
	var seam: float = _seam_norm * float(GRID_NX)
	var sd: float   = col_f - seam   # signed distance in grid columns from seam
	# Colour blend: −2 = pure home, +2 = pure away
	var blend: float = clampf(sd * 0.5 + 0.5, 0.0, 1.0)
	var base: Color = C_HOME.lerp(C_AWAY, blend)
	# Bright seam highlight within ±0.7 columns
	var seam_t: float = maxf(0.0, 1.0 - absf(sd) / 0.70)
	return base.lerp(Color(1.0, 1.0, 1.0), seam_t * 0.55)

# ─────────────────────────────────────────────────────────────────────────────
# Momentum strip (drawn on _strip child via draw signal)
# ─────────────────────────────────────────────────────────────────────────────

func _draw_momentum_on(s: Control) -> void:
	var sw: float = s.size.x
	var sh: float = s.size.y
	if sw < 4.0 or sh < 4.0: return

	var dur: float = maxf(1.0, _match_duration)
	var mt:  float = _match_time
	var cy:  float = sh * 0.50

	# Background
	s.draw_rect(Rect2(0, 0, sw, sh), Color(0.03, 0.03, 0.09, 0.92))
	s.draw_line(Vector2(0, cy), Vector2(sw, cy), Color(1, 1, 1, 0.18), 1.0)

	if _momentum.is_empty(): return
	var n: int = _momentum.size()

	# Vertical bars + smoothed line
	var run: float = 0.0
	var prev_px: float = 0.0
	var prev_py: float = cy
	for i in n:
		var t: float = float(i)
		if t > mt: break
		var px: float = (t / dur) * sw
		var m:  float = _momentum[i]
		if absf(m) > 0.01:
			var col: Color = C_HOME if m > 0.0 else C_AWAY
			s.draw_line(Vector2(px, cy), Vector2(px, cy - m * sh * 0.44),
						Color(col.r, col.g, col.b, 0.55), 2.0)
		run = lerpf(run, m, 0.20)
		s.draw_line(Vector2(prev_px, prev_py), Vector2(px, cy - run * sh * 0.40),
					Color(1, 1, 1, 0.50), 1.2)
		prev_px = px; prev_py = cy - run * sh * 0.40

	# Act markers
	for ab in _act_boundaries:
		var ax: float = (float(ab) / dur) * sw
		s.draw_line(Vector2(ax, 0), Vector2(ax, sh), Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.55), 1.0)

	# Score event ticks
	for ev in _score_events:
		var t: float = float(ev["tick"])
		if t > mt + 0.5: break
		var ex:  float = (t / dur) * sw
		var col: Color = C_HOME if int(ev["team_id"]) == 0 else C_AWAY
		s.draw_line(Vector2(ex, 0), Vector2(ex, sh * 0.35), Color(col.r, col.g, col.b, 0.90), 2.0)
		s.draw_circle(Vector2(ex, sh * 0.35), 3.5, col)

	# Current-time cursor
	var cx: float = (minf(mt, dur) / dur) * sw
	s.draw_line(Vector2(cx, 0), Vector2(cx, sh), Color(1, 1, 1, 0.85), 1.5)

# ─────────────────────────────────────────────────────────────────────────────
# Control callbacks
# ─────────────────────────────────────────────────────────────────────────────

func _toggle_play() -> void:
	_playing = not _playing
	if is_instance_valid(_play_btn): _play_btn.text = "⏸" if _playing else "▶"
	if _playing and _display_time >= _display_duration:
		_display_time  = 0.0
		_accum_mt      = -1.0
		_prev_pulse_mt = -1.0
		_threat.fill(0.0)
		_pulse.fill(0.0)
		_max_threat    = 1.0
		_mesh_dirty    = true
		_seam_norm     = 0.5

func _increase_speed() -> void:
	_speed = minf(_speed * 2.0, 8.0)
	_update_speed_lbl()

func _decrease_speed() -> void:
	_speed = maxf(_speed * 0.5, 0.25)
	_update_speed_lbl()

func _update_speed_lbl() -> void:
	if not is_instance_valid(_speed_lbl): return
	if   _speed == 0.25: _speed_lbl.text = "¼×"
	elif _speed == 0.5:  _speed_lbl.text = "½×"
	elif _speed == 1.0:  _speed_lbl.text = "1×"
	else:                _speed_lbl.text = "%d×" % int(_speed)

func _on_scrub(v: float) -> void:
	_display_time  = v * _display_duration
	_accum_mt      = -1.0
	_prev_pulse_mt = -1.0
	_threat.fill(0.0)
	_pulse.fill(0.0)
	_max_threat    = 1.0
	_mesh_dirty    = true
