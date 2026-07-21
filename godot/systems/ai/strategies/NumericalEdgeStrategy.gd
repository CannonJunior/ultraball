class_name NumericalEdgeStrategy
extends "res://systems/ai/strategies/BalancedStrategy.gd"

## On defense, all defenders converge on the weakest (lowest health%) enemy.

func _defense_pos(
	agent: AiView.PlayerView,
	allies: Array,
	carrier: AiView.PlayerView,
	_tid: int,
	view: AiView
) -> Vector2:
	# Find the weakest alive enemy
	var weakest := carrier
	for e in view.enemies():
		if not e.is_alive: continue
		if e.health_pct < weakest.health_pct:
			weakest = e
	return weakest.position
