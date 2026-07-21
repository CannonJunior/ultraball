class_name TerrainMutationSystem
extends Node

## Applies terrain shape events, handles pit deaths, manages fissure sequence,
## and maintains both the coarse 28×8 grid and the fine 168×48 elevation grid.

const _TricksterTrap = preload("res://scenes/entities/TricksterTrap.gd")

const ELEV_LERP_RATE := 3.0    # coarse height units per second
const LAVA_DPS       := 15.0
const ICE_SPEED_MULT := 1.8
const MUD_SPEED_MULT := 0.45

# Fine elevation grid dimensions
const ELEV_COLS := 168
const ELEV_ROWS := 48
const ELEV_CELL_W := 140.0 / ELEV_COLS   # ≈ 0.833 m
const ELEV_CELL_H :=  40.0 / ELEV_ROWS   # ≈ 0.833 m
const PLATEAU_FRAC := 0.3   # inner fraction of radius that is flat

## Active temporary terrain events: Array[{type, col, row, timer, ...}]
var _active_events: Array = []

## Fissure projectiles in flight: Array[{pos, velocity, target, radius, state, timer}]
var _fissure_projectiles: Array = []

func _ready() -> void:
	EventBus.terrain_modified.connect(_on_terrain_modified)
	EventBus.pit_opened.connect(_on_pit_opened)
	EventBus.trap_spawn_requested.connect(_on_trap_spawn_requested)

func _physics_process(delta: float) -> void:
	if not MatchState.match_active: return
	_tick_elevation(delta)
	_tick_hazards(delta)
	_tick_active_events(delta)
	_tick_fissure_projectiles(delta)
	_check_pit_deaths()

# ── Terrain modification ───────────────────────────────────────────────────────

func _on_terrain_modified(
	event_type: String,
	world_pos: Vector2,
	radius: float,
	duration: float,
	intensity: float
) -> void:
	# Shockwave: immediate radial push to players — no lasting terrain cell change.
	if event_type == "shockwave":
		_apply_shockwave_push(world_pos, radius, intensity)
		return

	var center_col := int(world_pos.x / 5.0)
	var center_row := int(world_pos.y / 5.0)
	var cell_radius := int(ceil(radius / 5.0))

	for dc in range(-cell_radius, cell_radius + 1):
		for dr in range(-cell_radius, cell_radius + 1):
			var col := center_col + dc
			var row := center_row + dr
			if not _valid_cell(col, row): continue
			var idx := _cell_index(col, row)
			_apply_event_to_cell(idx, event_type, intensity)
			if duration > 0.0:
				_active_events.append({
					"type": "restore", "col": col, "row": row,
					"timer": duration, "original_type": event_type
				})

	# Update fine elevation grid for hill/valley events.
	if event_type == "hill" and duration > 0.0:
		_update_fine_elevation(world_pos, radius, intensity, 1.0)
		_active_events.append({
			"type": "restore_elevation",
			"world_pos": world_pos, "radius": radius,
			"timer": duration
		})
	elif event_type == "valley" and duration > 0.0:
		_update_fine_elevation(world_pos, radius, intensity, -1.0)
		_active_events.append({
			"type": "restore_elevation",
			"world_pos": world_pos, "radius": radius,
			"timer": duration
		})

func _apply_event_to_cell(idx: int, event_type: String, intensity: float = 1.0) -> void:
	var t := MatchState.terrain
	match event_type:
		"hill":
			t.cell_target_heights[idx] = intensity * 3.0
		"valley":
			t.cell_target_heights[idx] = -intensity * 2.0
		"mud":
			t.cell_surface_types[idx] = 2
			t.cell_speed_mults[idx] = MUD_SPEED_MULT
		"lava":
			t.cell_surface_types[idx] = 3
			t.cell_hazard_timers[idx] = 999.0
		"ice":
			t.cell_surface_types[idx] = 4
			t.cell_speed_mults[idx] = ICE_SPEED_MULT

func _on_pit_opened(world_pos: Vector2, radius: float, duration: float) -> void:
	var center_col := int(world_pos.x / 5.0)
	var center_row := int(world_pos.y / 5.0)
	var cell_radius := int(ceil(radius / 5.0))
	for dc in range(-cell_radius, cell_radius + 1):
		for dr in range(-cell_radius, cell_radius + 1):
			var col := center_col + dc
			var row := center_row + dr
			if not _valid_cell(col, row): continue
			var idx := _cell_index(col, row)
			MatchState.terrain.cell_is_pit[idx] = 1
			if duration > 0.0:
				_active_events.append({"type": "close_pit", "col": col, "row": row, "timer": duration})
			EventBus.terrain_modified.emit("pit", Vector2(col * 5.0, row * 5.0), 1.0, 0.0, 1.0)

# ── Shockwave: radial knockback to all players ─────────────────────────────────

func _apply_shockwave_push(world_pos: Vector2, radius: float, intensity: float) -> void:
	for player in get_tree().get_nodes_in_group("players"):
		if not player.is_alive or not player.is_on_field: continue
		var diff: Vector2 = player.global_position - world_pos
		var dist: float = diff.length()
		if dist <= 0.0 or dist >= radius: continue
		var force: float = (1.0 - dist / radius) * intensity * 8.0
		var dir: Vector2 = diff.normalized()
		EventBus.debuff_applied.emit(player.player_id, "knockback", 0.0, {
			"direction": dir,
			"distance": force,
		})

# ── Fine elevation grid (168×48) ───────────────────────────────────────────────

func _update_fine_elevation(world_pos: Vector2, radius: float, intensity: float, sign: float) -> void:
	var max_h    := sign * intensity * 4.0
	var plateau_r := radius * PLATEAU_FRAC
	var slope_span := radius - plateau_r
	var noise_amp := absf(max_h) * 0.15

	var col_min := int((world_pos.x - radius) / ELEV_CELL_W)
	var col_max := int((world_pos.x + radius) / ELEV_CELL_W)
	var row_min := int((world_pos.y - radius) / ELEV_CELL_H)
	var row_max := int((world_pos.y + radius) / ELEV_CELL_H)
	col_min = clampi(col_min, 0, ELEV_COLS - 1)
	col_max = clampi(col_max, 0, ELEV_COLS - 1)
	row_min = clampi(row_min, 0, ELEV_ROWS - 1)
	row_max = clampi(row_max, 0, ELEV_ROWS - 1)

	var elev := MatchState.terrain.elevation_heights
	for col in range(col_min, col_max + 1):
		for row in range(row_min, row_max + 1):
			var cell_cx := (col + 0.5) * ELEV_CELL_W
			var cell_cy := (row + 0.5) * ELEV_CELL_H
			var d := Vector2(cell_cx, cell_cy).distance_to(world_pos)
			if d > radius: continue
			var h := max_h if d <= plateau_r \
				else max_h * (1.0 - (d - plateau_r) / slope_span)
			# Per-cell deterministic noise for natural variation
			var hash := ((col * 1013904223) ^ (row * 1664525)) & 0x7FFFFFFF
			var noise := (float(hash % 10000) / 10000.0 * 2.0 - 1.0) * noise_amp
			var final_h := clampf(h + noise, minf(max_h, 0.0), maxf(max_h, 0.0))
			elev[row * ELEV_COLS + col] = final_h

func _clear_fine_elevation(world_pos: Vector2, radius: float) -> void:
	var col_min := clampi(int((world_pos.x - radius) / ELEV_CELL_W), 0, ELEV_COLS - 1)
	var col_max := clampi(int((world_pos.x + radius) / ELEV_CELL_W), 0, ELEV_COLS - 1)
	var row_min := clampi(int((world_pos.y - radius) / ELEV_CELL_H), 0, ELEV_ROWS - 1)
	var row_max := clampi(int((world_pos.y + radius) / ELEV_CELL_H), 0, ELEV_ROWS - 1)
	var elev := MatchState.terrain.elevation_heights
	for col in range(col_min, col_max + 1):
		for row in range(row_min, row_max + 1):
			elev[row * ELEV_COLS + col] = 0.0

# ── Elevation lerping (coarse grid) ───────────────────────────────────────────

func _tick_elevation(delta: float) -> void:
	var t := MatchState.terrain
	for i in t.cell_heights.size():
		var target := t.cell_target_heights[i]
		var current := t.cell_heights[i]
		if abs(target - current) > 0.01:
			t.cell_heights[i] = move_toward(current, target, ELEV_LERP_RATE * delta)

# ── Hazard DoT ────────────────────────────────────────────────────────────────

func _tick_hazards(delta: float) -> void:
	for player in get_tree().get_nodes_in_group("players"):
		if not player.is_alive or not player.is_on_field: continue
		var col := int(player.global_position.x / 5.0)
		var row := int(player.global_position.y / 5.0)
		if not _valid_cell(col, row): continue
		var idx := _cell_index(col, row)
		if MatchState.terrain.cell_surface_types[idx] == 3:  # lava
			EventBus.damage_requested.emit({
				"attacker_id": "",
				"target_id": player.player_id,
				"amount": LAVA_DPS * delta,
				"knockback_distance": 0.0,
				"facing": 0.0,
			})

# ── Active event timer (restore cells after duration) ─────────────────────────

func _tick_active_events(delta: float) -> void:
	var expired: Array = []
	for ev in _active_events:
		ev["timer"] -= delta
		if ev["timer"] <= 0.0:
			expired.append(ev)
	for ev in expired:
		_active_events.erase(ev)
		if ev["type"] == "close_pit":
			MatchState.terrain.cell_is_pit[_cell_index(ev["col"], ev["row"])] = 0
			EventBus.terrain_reset.emit(ev["col"], ev["row"])
		elif ev["type"] == "restore":
			_restore_cell(_cell_index(ev["col"], ev["row"]))
			EventBus.terrain_reset.emit(ev["col"], ev["row"])
		elif ev["type"] == "restore_elevation":
			_clear_fine_elevation(ev["world_pos"], ev["radius"])

func _restore_cell(idx: int) -> void:
	var t := MatchState.terrain
	t.cell_surface_types[idx] = 0
	t.cell_target_heights[idx] = 0.0
	t.cell_speed_mults[idx] = 1.0
	t.cell_hazard_timers[idx] = 0.0

# ── Fissure projectile sequence ───────────────────────────────────────────────

func launch_fissure(from_pos: Vector2, to_pos: Vector2, radius: float) -> void:
	_fissure_projectiles.append({
		"pos":      from_pos,
		"velocity": (to_pos - from_pos).normalized() * 20.0,
		"target":   to_pos,
		"radius":   radius,
		"state":    "flying",
		"timer":    0.0,
	})

func _tick_fissure_projectiles(delta: float) -> void:
	var done: Array = []
	for proj in _fissure_projectiles:
		match proj["state"]:
			"flying":
				proj["pos"] += proj["velocity"] * delta
				if (proj["pos"] as Vector2).distance_to(proj["target"]) < 2.0:
					proj["state"] = "warning"
					proj["timer"] = 1.5
			"warning":
				proj["timer"] -= delta
				if proj["timer"] <= 0.0:
					proj["state"] = "pit"
					_on_pit_opened(proj["target"], proj["radius"], 5.0)
					done.append(proj)
	for p in done:
		_fissure_projectiles.erase(p)

# ── Pit death check ───────────────────────────────────────────────────────────

func _check_pit_deaths() -> void:
	for player in get_tree().get_nodes_in_group("players"):
		if not player.is_alive or not player.is_on_field: continue
		var col := int(player.global_position.x / 5.0)
		var row := int(player.global_position.y / 5.0)
		if not _valid_cell(col, row): continue
		if MatchState.terrain.cell_is_pit[_cell_index(col, row)]:
			# Hills above 1m elevate the player over the gap
			if _elevation_at(player.global_position) >= 1.0: continue
			EventBus.player_died.emit(player.player_id, "pit", "")

# ── Trickster trap spawning ───────────────────────────────────────────────────

func _on_trap_spawn_requested(
	world_pos: Vector2, owner_team_id: int,
	trap_radius: float, snare_duration: float,
	slow_factor: float, trap_timer: float
) -> void:
	var trap: Area2D = _TricksterTrap.new()
	trap.owner_team_id = owner_team_id
	trap.trap_radius = trap_radius
	trap.snare_duration = snare_duration
	trap.slow_factor = slow_factor
	trap.trap_timer = trap_timer
	trap.global_position = world_pos
	get_tree().current_scene.add_child(trap)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _valid_cell(col: int, row: int) -> bool:
	return col >= 0 and col < 28 and row >= 0 and row < 8

func _cell_index(col: int, row: int) -> int:
	return row * 28 + col

func _elevation_at(pos: Vector2) -> float:
	var col := clampi(int(pos.x / ELEV_CELL_W), 0, ELEV_COLS - 1)
	var row := clampi(int(pos.y / ELEV_CELL_H), 0, ELEV_ROWS - 1)
	var elev := MatchState.terrain.elevation_heights
	if elev.size() < ELEV_COLS * ELEV_ROWS: return 0.0
	return elev[row * ELEV_COLS + col]
