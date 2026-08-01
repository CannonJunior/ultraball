class_name NumericalEdgeStrategy
extends "res://systems/ai/strategies/BalancedStrategy.gd"

## On defence, all players converge on the weakest (lowest health%) enemy —
## eliminates one opponent fast to gain a numerical advantage.

func _defense_pos(agent: AiView.PlayerView, view: AiView, _my_tid: int, carrier: AiView.PlayerView) -> Vector2:
	var weakest := carrier
	for e in view.enemies():
		if not e.is_alive: continue
		if e.health_pct < weakest.health_pct:
			weakest = e
	return weakest.position
