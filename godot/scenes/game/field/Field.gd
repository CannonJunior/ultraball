class_name Field
extends Node2D

## Field rendering: TileMap for the 28×8 coarse terrain grid,
## elevation mesh overlay, and phase line markers.
## Observes EventBus terrain signals — never modifies game state.

## Pixels per world-unit (metre). 1m = SCALE pixels.
const SCALE := 10.0
## Cell size in pixels (5m per cell).
const CELL_PX := 50.0

## TileSet source IDs (configure in Godot editor)
const SOURCE_NORMAL := 0
const SOURCE_MUD    := 1
const SOURCE_LAVA   := 2
const SOURCE_ICE    := 3
const SOURCE_PIT    := 4

@onready var base_tilemap: TileMapLayer = $BaseTileMapLayer
@onready var hazard_tilemap: TileMapLayer = $HazardTileMapLayer
@onready var elevation_mesh: Node2D = $ElevationMesh
@onready var phase_lines: Node2D = $PhaseLines
@onready var endzone_markers: Node2D = $EndzoneMarkers

func _ready() -> void:
	EventBus.terrain_modified.connect(_on_terrain_modified)
	EventBus.pit_opened.connect(_on_pit_opened)
	EventBus.terrain_reset.connect(_on_terrain_reset)
	_build_phase_lines()
	_fill_base_tiles()
	if MatchState.is_three_team:
		queue_redraw()

# ── Initial tile fill ─────────────────────────────────────────────────────────

func _fill_base_tiles() -> void:
	for row in 8:
		for col in 28:
			base_tilemap.set_cell(Vector2i(col, row), SOURCE_NORMAL, Vector2i(0, 0))

# ── Phase lines ───────────────────────────────────────────────────────────────

func _build_phase_lines() -> void:
	if MatchState.is_three_team:
		return   # 3-team phase lines drawn in _draw()
	var positions := [30.0, 50.0, 70.0, 90.0, 110.0]
	for xm in positions:
		var line := Line2D.new()
		line.add_point(Vector2(xm, 0.0))
		line.add_point(Vector2(xm, 40.0))
		line.width = 0.15
		line.default_color = Color(1.0, 1.0, 1.0, 0.4)
		phase_lines.add_child(line)

# ── 3-team field overlay ──────────────────────────────────────────────────────

func _draw() -> void:
	if not MatchState.is_three_team: return
	var center := Vector2(MatchState.FIELD3_CX, MatchState.FIELD3_CY)
	var fill_colors := [
		Color(0.3,  0.5,  1.0, 0.12),
		Color(1.0,  0.35, 0.35, 0.12),
		Color(0.35, 0.9,  0.35, 0.12),
	]
	var line_colors := [
		Color(0.4, 0.6, 1.0, 0.55),
		Color(1.0, 0.4, 0.4, 0.55),
		Color(0.4, 1.0, 0.4, 0.55),
	]
	for t in 3:
		var norm: Vector2 = MatchState.TEAM3_NORMALS[t]
		var perp := Vector2(-norm.y, norm.x)
		var ir  := MatchState.FIELD3_INRADIUS
		var end := MatchState.FIELD3_ARM_END
		var hw  := MatchState.FIELD3_ARM_HALF_W
		var corners := PackedVector2Array([
			center + norm * ir  - perp * hw,
			center + norm * ir  + perp * hw,
			center + norm * end + perp * hw,
			center + norm * end - perp * hw,
		])
		draw_colored_polygon(corners, fill_colors[t])
		draw_polyline(
			PackedVector2Array([corners[0], corners[1], corners[2], corners[3], corners[0]]),
			line_colors[t], 0.15
		)
		# Phase lines within arm
		for d in MatchState.FIELD3_PHASE_DISTS:
			var lp: Vector2 = center + norm * d
			draw_line(lp - perp * hw, lp + perp * hw, Color(1, 1, 1, 0.3), 0.1)
		# Endzone boundary
		var ep := center + norm * MatchState.FIELD3_CHAN_OUTER
		draw_line(ep - perp * hw, ep + perp * hw, Color(1, 1, 0, 0.65), 0.15)

# ── Terrain event handlers ─────────────────────────────────────────────────────

func _on_terrain_modified(event_type: String, world_pos: Vector2, radius: float, _duration: float, _intensity: float) -> void:
	var center := _world_to_cell(world_pos)
	var cell_r := int(ceil(radius / 5.0))
	for dc in range(-cell_r, cell_r + 1):
		for dr in range(-cell_r, cell_r + 1):
			var cell := Vector2i(center.x + dc, center.y + dr)
			if not _valid_cell(cell): continue
			match event_type:
				"mud":
					base_tilemap.set_cell(cell, SOURCE_MUD, Vector2i(0, 0))
				"lava":
					hazard_tilemap.set_cell(cell, SOURCE_LAVA, Vector2i(0, 0))
				"ice":
					base_tilemap.set_cell(cell, SOURCE_ICE, Vector2i(0, 0))

func _on_pit_opened(world_pos: Vector2, radius: float, _duration: float) -> void:
	var center := _world_to_cell(world_pos)
	var cell_r := int(ceil(radius / 5.0))
	for dc in range(-cell_r, cell_r + 1):
		for dr in range(-cell_r, cell_r + 1):
			var cell := Vector2i(center.x + dc, center.y + dr)
			if _valid_cell(cell):
				base_tilemap.set_cell(cell, SOURCE_PIT, Vector2i(0, 0))

func _on_terrain_reset(col: int, row: int) -> void:
	var cell := Vector2i(col, row)
	base_tilemap.set_cell(cell, SOURCE_NORMAL, Vector2i(0, 0))
	hazard_tilemap.erase_cell(cell)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / 5.0), int(world_pos.y / 5.0))

func _valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < 28 and cell.y >= 0 and cell.y < 8

## Convert world metres to screen pixels.
static func world_to_screen(world_pos: Vector2) -> Vector2:
	return world_pos * SCALE
