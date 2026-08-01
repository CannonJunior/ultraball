class_name ElevationQuery

## Single implementation of the fine-elevation grid lookup previously duplicated
## in Player.gd and TerrainMutationSystem.gd.

const COLS   := 168
const ROWS   :=  48
const CELL_W := 140.0 / COLS   # ≈ 0.833 m
const CELL_H :=  40.0 / ROWS   # ≈ 0.833 m

static func at(pos: Vector2) -> float:
	var elev := MatchState.terrain.elevation_heights
	if elev.size() < COLS * ROWS: return 0.0
	var col := clampi(int(pos.x / CELL_W), 0, COLS - 1)
	var row := clampi(int(pos.y / CELL_H), 0, ROWS - 1)
	return elev[row * COLS + col]
