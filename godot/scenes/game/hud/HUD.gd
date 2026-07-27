extends Control

func _ready() -> void:
	var vp := get_viewport_rect()
	position = Vector2.ZERO
	size = vp.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for path in [
		"res://scenes/game/hud/DamageIndicators.gd",
		"res://scenes/game/hud/Scoreboard.gd",
	]:
		add_child(load(path).new())

	# Highlight panels flank the scoreboard — added after so they render on top.
	var _hp_script := load("res://scenes/game/hud/HighlightPanel.gd")
	var _lp: Control = _hp_script.new(); _lp.set("is_left", true);  _lp.set("team_color", Color(1.000, 0.231, 0.325)); _lp.set("team_id", 0); add_child(_lp)
	var _rp: Control = _hp_script.new(); _rp.set("is_left", false); _rp.set("team_color", Color(0.184, 0.514, 1.000)); _rp.set("team_id", 1); add_child(_rp)

	for path in [
		"res://scenes/game/hud/CharacterPanel.gd",
		"res://scenes/game/hud/BuffDisplay.gd",
		"res://scenes/game/hud/ThrowChargeBar.gd",
	]:
		add_child(load(path).new())
	for late_path in [
		"res://scenes/game/hud/AbilityQueueOverlay.gd",
		"res://scenes/game/hud/IntermissionScreen.gd",
		"res://scenes/game/hud/FinalReport.gd",
		"res://scenes/game/hud/EventMessageDisplay.gd",
		"res://scenes/game/hud/HighlightClipList.gd",
		"res://scenes/game/hud/PauseMenu.gd",
	]:
		var s := load(late_path)
		if s == null or not s.can_instantiate():
			push_error("[HUD] failed to load: " + late_path)
			continue
		add_child(s.new())
