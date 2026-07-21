extends Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for path in [
		"res://scenes/game/hud/DamageIndicators.gd",
		"res://scenes/game/hud/Scoreboard.gd",
		"res://scenes/game/hud/ManaBars.gd",
		"res://scenes/game/hud/AbilityHotbar.gd",
		"res://scenes/game/hud/BuffDisplay.gd",
		"res://scenes/game/hud/ThrowChargeBar.gd",
	]:
		add_child(load(path).new())
