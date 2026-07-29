class_name CreatureVisual
extends Node2D

## Square body visual for creatures in 2D mode.
## Body size mirrors body_radius set by the parent Creature.

var _half:  float = 4.0
var _color: Color = Color(0.90, 0.40, 0.10)

## Called by Creature._ready() after _apply_creature_type() sets body_radius.
func setup(radius: float, creature_type: int) -> void:
	_half  = radius
	_color = _type_color(creature_type)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-_half, -_half, _half * 2.0, _half * 2.0), _color)
	draw_circle(Vector2.ZERO, _half * 0.12, Color.WHITE)

func _type_color(ctype: int) -> Color:
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
	return Color(0.90, 0.40, 0.10)
