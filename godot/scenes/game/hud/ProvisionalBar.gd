class_name ProvisionalBar
extends Control

## Health bar with a recoverable ghost zone (SF5-style white health).
## Draw order: background → ghost zone → real HP.

const PROV_COLOR := Color(0.90, 0.88, 0.75)   # warm off-white ghost health

var fill_color: Color = Color(0.20, 0.85, 0.20)
var bg_color:   Color = Color(0.08, 0.08, 0.08, 0.9)
var pct:        float = 1.0   ## real HP fraction [0, 1]
var prov_pct:   float = 0.0   ## ghost zone fraction [0, 1-pct]

func set_health(hp_pct: float, provisional_pct: float) -> void:
	pct      = clampf(hp_pct, 0.0, 1.0)
	prov_pct = clampf(provisional_pct, 0.0, maxf(0.0, 1.0 - pct))
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0.0, 0.0, w, h), bg_color)
	if prov_pct > 0.0:
		draw_rect(Rect2(pct * w, 0.0, prov_pct * w, h), PROV_COLOR)
	if pct > 0.0:
		draw_rect(Rect2(0.0, 0.0, pct * w, h), fill_color)
