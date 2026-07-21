class_name PlayerVisual
extends Node2D

## Phase 1 player visual: filled disc + direction dot drawn in world units.
## Phase 8 replaces this with AnimatedSprite2D / 3D mesh.

const BODY_RADIUS := 0.4   # metres
const DOT_RADIUS  := 0.1

var _body_color: Color = Color.WHITE

func _ready() -> void:
	var player := get_parent()
	if player and player.class_definition:
		_body_color = player.class_definition.body_color
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, BODY_RADIUS, _body_color)
	# Direction dot offset in local space — always points "up" (−Y in Godot 2D)
	draw_circle(Vector2(0.0, -(BODY_RADIUS + DOT_RADIUS * 0.5)), DOT_RADIUS, Color.WHITE)
