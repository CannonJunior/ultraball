extends Control

func _ready() -> void:
	# CanvasLayer is not a Control, so anchor-based sizing gives zero.
	# Explicitly match the viewport so child anchors resolve correctly.
	var vp := get_viewport_rect()
	position = Vector2.ZERO
	size = vp.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for path in [
		"res://scenes/game/hud/DamageIndicators.gd",
		"res://scenes/game/hud/Scoreboard.gd",
		"res://scenes/game/hud/CharacterPanel.gd",
		"res://scenes/game/hud/BuffDisplay.gd",
		"res://scenes/game/hud/ThrowChargeBar.gd",
	]:
		add_child(load(path).new())
