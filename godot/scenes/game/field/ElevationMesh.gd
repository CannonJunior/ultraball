class_name ElevationMesh
extends Node2D

## Draws coarse 28×8 cell heights as a colored overlay.
## Green = hill (positive height), blue = valley (negative).
## Redraws whenever terrain events fire.

func _ready() -> void:
	EventBus.terrain_modified.connect(func(_et, _wp, _r, _d, _i): queue_redraw())
	EventBus.terrain_reset.connect(func(_c, _r): queue_redraw())

func _draw() -> void:
	var t := MatchState.terrain
	if t.cell_heights.size() < 224: return
	for row in 8:
		for col in 28:
			var h := t.cell_heights[row * 28 + col]
			if absf(h) < 0.05: continue
			var rect := Rect2(col * 5.0, row * 5.0, 5.0, 5.0)
			var alpha := clampf(absf(h) / 3.0, 0.05, 0.6)
			var color := Color(0.2, 0.85, 0.2, alpha) if h > 0.0 \
				else Color(0.2, 0.4, 0.85, alpha)
			draw_rect(rect, color)
